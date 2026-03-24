import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../domain/entities/connection_state.dart';
import '../models/gateway_frame.dart';
import '../services/device_identity_service.dart';
import '../services/device_info_service.dart';

/// Thrown when the gateway rejects the connection because the device is not yet approved.
/// The user must approve the device on the server before retrying:
///   openclaw devices list
///   openclaw devices approve REQUEST_ID
class PairingRequiredException implements Exception {
  /// The pairing request ID from the gateway, used to identify the pending device:
  ///   openclaw devices approve REQUEST_ID
  final String? requestId;

  const PairingRequiredException({this.requestId});

  @override
  String toString() => requestId != null
      ? 'Device pairing required (Request ID: $requestId)'
      : 'Device pairing required';
}

/// Wrapper class that provides additional context about connection state changes
class ConnectionStateChange {
  final ConnectionState state;
  final bool unexpected;
  final String? errorMessage;

  ConnectionStateChange(this.state,
      {this.unexpected = false, this.errorMessage});
}

class OpenClawWebSocketDatasource {
  final DeviceIdentityService _deviceIdentityService;
  final GatewayClientInfo _clientInfo;

  WebSocketChannel? _channel;
  final _controller = StreamController<GatewayFrame>.broadcast();
  final _connectionStateController =
      StreamController<ConnectionStateChange>.broadcast();
  final _responseControllers = <String, Completer<GatewayFrame>>{};

  ConnectionState _state = ConnectionState.disconnected;
  bool _intentionalDisconnect = false;

  /// Optional callback that is invoked when any frame is received from the server
  /// Used for heartbeat monitoring to reset pong timeout
  void Function()? onFrameReceived;

  Stream<GatewayFrame> get frameStream => _controller.stream;

  Stream<ConnectionStateChange> get stateStream =>
      _connectionStateController.stream;

  ConnectionState get state => _state;

  OpenClawWebSocketDatasource(
      this._deviceIdentityService, this._clientInfo);

  Future<void> connect(
    String connectionId,
    String url,
    String token, {
    List<String> scopes = const ['operator.read', 'operator.write'],
  }) async {
    if (_channel != null) {
      await disconnect();
    }

    _intentionalDisconnect = false;
    _updateState(ConnectionState.connecting);

    try {
      // Build WebSocket URL (ws:// or wss:// from http:// or https://)
      var wsUrl = url.trim();
      if (wsUrl.endsWith('/')) {
        wsUrl = wsUrl.substring(0, wsUrl.length - 1);
      }
      wsUrl = wsUrl
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://');
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Set up listener BEFORE waiting for challenge
      _channel!.stream.listen(
        _handleMessage,
        onDone: _handleDone,
        onError: _handleError,
      );

      // On web, connection failures surface through the ready future rather than
      // the stream's onError. Awaiting it here ensures they are caught by the
      // surrounding try/catch and reported as a failed connection state instead
      // of becoming an unhandled zone exception.
      await _channel!.ready;

      // --- Step 1: Wait for connect.challenge event ---
      final challengeCompleter = Completer<Map<String, dynamic>>();
      StreamSubscription<GatewayFrame>? challengeSub;
      StreamSubscription<ConnectionStateChange>? challengeStateSub;

      void cancelChallengeSubs() {
        challengeSub?.cancel();
        challengeStateSub?.cancel();
      }

      challengeSub = frameStream.listen((frame) {
        if (frame.type == FrameType.event &&
            frame.event == 'connect.challenge' &&
            !challengeCompleter.isCompleted) {
          cancelChallengeSubs();
          challengeCompleter.complete(frame.payload ?? {});
        }
      });

      // If the socket fails or closes before the challenge arrives, fail fast
      // instead of hanging until the 30-second timeout fires.
      challengeStateSub = _connectionStateController.stream.listen((change) {
        if (!challengeCompleter.isCompleted &&
            (change.state == ConnectionState.failed ||
                change.state == ConnectionState.disconnected ||
                change.state == ConnectionState.pairingRequired)) {
          cancelChallengeSubs();
          challengeCompleter.completeError(
            change.state == ConnectionState.pairingRequired
                ? const PairingRequiredException() // requestId not available at this stage
                : Exception(
                    change.errorMessage ?? 'Connection closed before challenge'),
          );
        }
      });

      // Challenge timeout — remote connections should receive it in < 1 s
      Future.delayed(const Duration(seconds: 15), () {
        if (!challengeCompleter.isCompleted) {
          cancelChallengeSubs();
          challengeCompleter.completeError(
            TimeoutException('connect.challenge not received within 15 s'),
          );
        }
      });

      final challengePayload = await challengeCompleter.future;
      final nonce = challengePayload['nonce'] as String;

      // --- Step 2: Resolve auth token (deviceToken overrides gateway token if paired) ---
      final storedDeviceToken =
          await _deviceIdentityService.getDeviceToken(connectionId);
      final authToken = storedDeviceToken ?? token;

      // --- Step 3: Build device block (authToken must match what goes in auth.token) ---
      final deviceBlock = await _deviceIdentityService.buildDeviceBlock(
        nonce: nonce,
        clientId: _clientInfo.id,
        clientMode: 'cli',
        role: 'operator',
        scopes: scopes,
        authToken: authToken,
      );

      // --- Step 4: Build and send connect frame ---
      final requestId = _generateId();
      final connectFrame = GatewayFrame.request(
        id: requestId,
        method: 'connect',
        params: {
          'minProtocol': 3,
          'maxProtocol': 3,
          'client': _clientInfo.toJson(),
          'role': 'operator',
          'scopes': scopes,
          'auth': {'token': authToken},
          'device': deviceBlock,
        },
      );

      _sendFrame(connectFrame);

      // --- Step 5: Wait for hello-ok ---
      final response = await _waitForResponse(requestId);
      if (response.ok == true) {
        // Store device token if gateway issued one (first pairing or token rotation).
        // hello-ok payload: { auth: { deviceToken: "...", role: "...", scopes: [...] } }
        final auth = response.payload?['auth'] as Map<String, dynamic>?;
        final newDeviceToken = auth?['deviceToken'] as String?;
        if (newDeviceToken != null) {
          await _deviceIdentityService.storeDeviceToken(
              connectionId, newDeviceToken);
        }
        _updateState(ConnectionState.connected);
      } else {
        final errorCode = response.error?['code'] as String?;

        if (errorCode == 'NOT_PAIRED') {
          final details = response.error?['details'] as Map<String, dynamic>?;
          final requestId = details?['requestId'] as String?;
          // Store requestId in errorMessage so the UI can show it
          _updateState(ConnectionState.pairingRequired, errorMessage: requestId);
          throw PairingRequiredException(requestId: requestId);
        }

        // Extract the human-readable message from the error object when available
        final errorMsg = response.error?['message'] as String? ??
            response.error?.toString() ??
            'Connection failed';
        throw Exception(errorMsg);
      }
    } catch (e) {
      // Don't overwrite pairingRequired with failed — the specific state was
      // already set by _handleDone() and carries important UI meaning.
      if (_state != ConnectionState.pairingRequired) {
        // Pass the error message so it propagates via the state stream to the UI
        _updateState(ConnectionState.failed, errorMessage: e.toString());
      }
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    await _channel?.sink.close();
    _channel = null;
    _updateState(ConnectionState.disconnected);
  }

  Future<GatewayFrame> sendRequest(
      String method, Map<String, dynamic>? params) async {
    if (_state != ConnectionState.connected) {
      throw StateError('Not connected');
    }

    final requestId = _generateId();
    final frame = GatewayFrame.request(
      id: requestId,
      method: method,
      params: params,
    );

    _sendFrame(frame);
    return _waitForResponse(requestId);
  }

  void _handleMessage(dynamic message) {
    if (message is! String) return;

    try {
      final json = Map<String, dynamic>.from(
        jsonDecode(message) as Map,
      );

      final frame = GatewayFrame.fromJson(json);

      // Route responses to waiting completers
      if (frame.type == FrameType.res && frame.id != null) {
        final completer = _responseControllers.remove(frame.id);
        completer?.complete(frame);
      }

      // Broadcast all frames
      if (!_controller.isClosed) {
        _controller.add(frame);
      }
    } catch (e) {
      // Ignore parse errors for non-JSON messages
    } finally {
      // Notify heartbeat monitor that we received a frame
      onFrameReceived?.call();
    }
  }

  void _handleDone() {
    if (_intentionalDisconnect) return;

    final closeCode = _channel?.closeCode;
    final closeReason = _channel?.closeReason ?? '';

    // Gateway closed with 1008 "pairing required" — device not yet approved.
    // Do NOT trigger auto-reconnect; user must approve via:
    //   openclaw devices list
    //   openclaw devices approve <REQUEST_ID>
    if (closeCode == 1008 && closeReason.toLowerCase().contains('pairing')) {
      final error = const PairingRequiredException(); // no requestId available from close frame
      for (final completer in _responseControllers.values) {
        completer.completeError(error);
      }
      _responseControllers.clear();
      _updateState(ConnectionState.pairingRequired, errorMessage: 'Device pairing required');
      return;
    }

    _updateState(
      ConnectionState.disconnected,
      unexpected: true,
      errorMessage: 'Connection closed unexpectedly',
    );

    // Complete all pending response completers with a StateError
    // This prevents the 30-second hang when WebSocket closes unexpectedly
    final error = StateError('WebSocket closed unexpectedly');
    for (final completer in _responseControllers.values) {
      completer.completeError(error);
    }
    _responseControllers.clear();
  }

  void _handleError(dynamic error) {
    _updateState(ConnectionState.failed, errorMessage: error.toString());

    // Complete all pending response completers with the error
    // This prevents the 30-second hang when WebSocket errors immediately
    // (e.g., iOS local network permission blocking the connection)
    for (final completer in _responseControllers.values) {
      completer.completeError(error);
    }
    _responseControllers.clear();
  }

  void _sendFrame(GatewayFrame frame) {
    _channel?.sink.add(jsonEncode(frame.toJson()));
  }

  Future<GatewayFrame> _waitForResponse(String id,
      {Duration timeout = const Duration(seconds: 30)}) {
    final completer = Completer<GatewayFrame>();
    _responseControllers[id] = completer;

    // Timeout handling
    Future.delayed(timeout, () {
      if (_responseControllers.containsKey(id)) {
        _responseControllers.remove(id);
        completer.completeError(TimeoutException('Request timeout'));
      }
    });

    return completer.future;
  }

  void _updateState(ConnectionState newState,
      {bool unexpected = false, String? errorMessage}) {
    _state = newState;
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(
          ConnectionStateChange(newState,
              unexpected: unexpected, errorMessage: errorMessage));
    }
  }

  static const _uuid = Uuid();

  String _generateId() {
    return _uuid.v4();
  }

  void dispose() {
    _channel?.sink.close();
    _controller.close();
    _connectionStateController.close();
  }
}
