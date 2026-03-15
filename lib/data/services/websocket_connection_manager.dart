import 'dart:async';

import '../../domain/entities/connection_state.dart';
import '../datasources/connection_local_datasource.dart';
import '../datasources/openclaw_ws_datasource.dart';
import '../models/gateway_frame.dart';
import 'device_identity_service.dart';
import 'device_info_service.dart';
import 'heartbeat_monitor.dart';
import 'reconnection_manager.dart';

/// Callback type for handling incoming frames
typedef FrameHandler = void Function(String connectionId, GatewayFrame frame);

/// Manages WebSocket connections with lifecycle, reconnection, and heartbeat.
/// Single responsibility: Keep WebSocket connections alive and healthy.
class WebSocketConnectionManager {
  final ConnectionLocalDatasource _localDatasource;
  final DeviceIdentityService _deviceIdentityService;
  final GatewayClientInfo _clientInfo;

  // Active connections
  final Map<String, OpenClawWebSocketDatasource> _connections = {};

  // Per-connection state
  final Map<String, ReconnectionManager> _reconnectionManagers = {};
  final Map<String, HeartbeatMonitor> _heartbeatMonitors = {};
  final Map<String, List<StreamSubscription>> _subscriptions = {};

  // State streams
  final Map<String, StreamController<ConnectionStatus>> _statusControllers = {};
  final Map<String, ConnectionStatus> _lastConnectionStatus = {};

  // Track intentional disconnects so screens don't auto-reconnect
  final Set<String> _intentionallyDisconnected = {};

  // Callbacks
  FrameHandler? _onFrameReceived;

  WebSocketConnectionManager(
    this._localDatasource,
    this._deviceIdentityService,
    this._clientInfo,
  );

  /// Set the frame handler callback
  void setFrameHandler(FrameHandler handler) {
    _onFrameReceived = handler;
  }

  /// Connect to a gateway
  Future<void> connect(String connectionId) async {
    // Clear intentional disconnect flag when user explicitly connects
    _intentionallyDisconnected.remove(connectionId);

    // If already connected, disconnect first
    if (_connections.containsKey(connectionId)) {
      await disconnect(connectionId);
    }

    final config = await _localDatasource.getConnection(connectionId);
    if (config == null) {
      throw Exception('Connection not found: $connectionId');
    }

    // Ensure status controller exists
    _ensureStatusController(connectionId);

    // Create new WebSocket datasource for this connection
    final ws = OpenClawWebSocketDatasource(
        _deviceIdentityService, _clientInfo);
    _connections[connectionId] = ws;

    // Set up frame and connection state listeners
    _setupListeners(connectionId, ws);

    // Connect WebSocket with challenge-response auth
    await ws.connect(
        connectionId, config.gatewayUrl, config.token,
        scopes: ['operator.admin']);

    // Create reconnection manager for this connection
    _reconnectionManagers[connectionId]?.dispose();
    _reconnectionManagers[connectionId] = ReconnectionManager(
      connectCallback: () => _performReconnect(connectionId),
      onRetryScheduled: (attempt, delay) {
        _updateConnectionStatus(connectionId, ConnectionState.reconnecting);
      },
      onMaxRetriesReached: () {
        _updateConnectionStatus(connectionId, ConnectionState.failed,
            errorMessage: 'Max reconnection attempts reached');
      },
    );
  }

  /// Disconnect from a gateway
  Future<void> disconnect(String connectionId) async {
    // Mark as intentionally disconnected
    _intentionallyDisconnected.add(connectionId);

    // Cancel auto-reconnect FIRST
    _reconnectionManagers[connectionId]?.cancel();

    final ws = _connections.remove(connectionId);
    await ws?.disconnect();
    ws?.dispose();

    // Cancel subscriptions for this connection
    final subs = _subscriptions.remove(connectionId);
    if (subs != null) {
      for (final sub in subs) {
        await sub.cancel();
      }
    }

    // Clean up reconnection manager
    _reconnectionManagers[connectionId]?.dispose();
    _reconnectionManagers.remove(connectionId);

    // Clean up heartbeat monitor
    _heartbeatMonitors[connectionId]?.dispose();
    _heartbeatMonitors.remove(connectionId);

    // Clear connection status
    _lastConnectionStatus.remove(connectionId);
  }

  /// Get connection status stream.
  /// Note: This does NOT replay the last status to avoid race conditions
  /// with broadcast streams. Callers should read initial state from
  /// getWebSocket() or getLastStatus() directly.
  Stream<ConnectionStatus> status(String connectionId) {
    _ensureStatusController(connectionId);
    return _statusControllers[connectionId]!.stream;
  }

  /// Get active WebSocket for API calls
  OpenClawWebSocketDatasource? getWebSocket(String connectionId) {
    return _connections[connectionId];
  }

  /// Check if the user intentionally disconnected this connection
  bool wasIntentionallyDisconnected(String connectionId) {
    return _intentionallyDisconnected.contains(connectionId);
  }

  /// Check if connected
  bool isConnected(String connectionId) {
    return _lastConnectionStatus[connectionId]?.state ==
        ConnectionState.connected;
  }

  /// Get frame stream for a connection
  Stream<GatewayFrame>? frameStream(String connectionId) {
    return _connections[connectionId]?.frameStream;
  }

  /// Get the last connection status
  ConnectionStatus? getLastStatus(String connectionId) {
    return _lastConnectionStatus[connectionId];
  }

  /// Trigger reconnection for a connection
  void triggerReconnect(String connectionId, DisconnectReason reason) {
    _reconnectionManagers[connectionId]?.onDisconnected(reason);
  }

  /// Reset reconnection attempts for a connection
  void resetReconnection(String connectionId) {
    _reconnectionManagers[connectionId]?.reset();
  }

  /// Called by AppLifecycleService when the app returns to the foreground.
  /// Attempts to reconnect any connections that were dropped while backgrounded
  /// or that are in a failed state.
  void onAppResumed() {
    for (final connectionId in _statusControllers.keys.toList()) {
      // Respect intentional disconnects
      if (_intentionallyDisconnected.contains(connectionId)) continue;

      final lastStatus = _lastConnectionStatus[connectionId];
      if (lastStatus == null) continue;

      final state = lastStatus.state;
      // Check for failed/disconnected OR stale reconnecting state
      // Stale reconnecting = state is reconnecting but no active retry in progress
      // (e.g., initial connection failed before ReconnectionManager was created)
      final isStaleReconnecting = state == ConnectionState.reconnecting &&
          !(_reconnectionManagers[connectionId]?.isRetrying ?? false);

      if (state == ConnectionState.failed ||
          state == ConnectionState.disconnected ||
          isStaleReconnecting) {
        _ensureReconnectionManager(connectionId);
        _reconnectOnResume(connectionId);
      }
      // connected: heartbeat resumes with app and will detect stale connections naturally
      // connecting: already in progress, do not interfere
      // active reconnecting (isRetrying=true): let the retry timer handle it
    }
  }

  /// Fires an immediate reconnect attempt (no delay) for app resume scenarios.
  void _reconnectOnResume(String connectionId) async {
    try {
      _reconnectionManagers[connectionId]?.reset(); // clear exhausted retry count
      _updateConnectionStatus(connectionId, ConnectionState.reconnecting);
      await _performReconnect(connectionId);
    } catch (_) {
      // Immediate reconnect failed — hand off to exponential backoff
      _reconnectionManagers[connectionId]
          ?.onDisconnected(DisconnectReason.unexpected);
    }
  }

  /// Guards the edge case where the reconnection manager was never created.
  void _ensureReconnectionManager(String connectionId) {
    if (_reconnectionManagers.containsKey(connectionId)) return;
    _reconnectionManagers[connectionId] = ReconnectionManager(
      connectCallback: () => _performReconnect(connectionId),
      onRetryScheduled: (attempt, delay) {
        _updateConnectionStatus(connectionId, ConnectionState.reconnecting);
      },
      onMaxRetriesReached: () {
        _updateConnectionStatus(connectionId, ConnectionState.failed,
            errorMessage: 'Max reconnection attempts reached');
      },
    );
  }

  void _ensureStatusController(String connectionId) {
    _statusControllers.putIfAbsent(
      connectionId,
      () => StreamController<ConnectionStatus>.broadcast(),
    );
  }

  void _updateConnectionStatus(String connectionId, ConnectionState state,
      {String? errorMessage}) {
    final status = ConnectionStatus(state: state, errorMessage: errorMessage);
    _lastConnectionStatus[connectionId] = status;
    _ensureStatusController(connectionId);
    _statusControllers[connectionId]?.add(status);
  }

  /// Lightweight reconnect that reuses existing configuration
  Future<void> _performReconnect(String connectionId) async {
    // Clean up old WebSocket but keep all other state
    final oldWs = _connections.remove(connectionId);
    if (oldWs != null) {
      _cancelSubscriptions(connectionId);
      try {
        oldWs.disconnect();
      } catch (_) {}
      oldWs.dispose();
    }

    // Load config
    final config = await _localDatasource.getConnection(connectionId);
    if (config == null) throw Exception('Connection config not found');

    // Create fresh WebSocket
    final ws = OpenClawWebSocketDatasource(
        _deviceIdentityService, _clientInfo);
    _connections[connectionId] = ws;

    // Re-setup listeners
    _setupListeners(connectionId, ws);

    // Connect with challenge-response auth
    await ws.connect(
        connectionId, config.gatewayUrl, config.token,
        scopes: ['operator.admin']);
  }

  void _cancelSubscriptions(String connectionId) {
    final subs = _subscriptions[connectionId];
    if (subs != null) {
      for (final sub in subs) {
        sub.cancel();
      }
      _subscriptions.remove(connectionId);
    }
  }

  void _setupListeners(String connectionId, OpenClawWebSocketDatasource ws) {
    // Remove old subscriptions if any
    final existingSubs = _subscriptions[connectionId];
    if (existingSubs != null) {
      for (final sub in existingSubs) {
        sub.cancel();
      }
    }
    _subscriptions[connectionId] = [];

    // Listen to WebSocket frames
    final frameSubscription = ws.frameStream.listen((frame) {
      // Handle gateway shutdown event
      if (frame.type == FrameType.event && frame.event == 'shutdown') {
        _reconnectionManagers[connectionId]
            ?.onDisconnected(DisconnectReason.shutdown);
        return;
      }

      // Forward to external handler
      _onFrameReceived?.call(connectionId, frame);
    });
    _subscriptions[connectionId]!.add(frameSubscription);

    // Listen to connection state
    final stateSubscription = ws.stateStream.listen((stateChange) {
      // Handle unexpected disconnect.
      // Same guard as the failed handler: only trigger auto-reconnect when a
      // ReconnectionManager exists (i.e. the connection was previously
      // established). Without one this is the server closing the socket after
      // an initial-connect rejection (e.g. NOT_PAIRED), so surface it as
      // failed to keep the error visible.
      if (stateChange.state == ConnectionState.disconnected &&
          stateChange.unexpected) {
        final reconnManager = _reconnectionManagers[connectionId];
        if (reconnManager != null) {
          _updateConnectionStatus(connectionId, ConnectionState.reconnecting);
          reconnManager.onDisconnected(DisconnectReason.unexpected);
        } else {
          _updateConnectionStatus(connectionId, ConnectionState.failed,
              errorMessage: stateChange.errorMessage);
        }
        return;
      }

      // Handle failed state.
      // If a ReconnectionManager exists this is a mid-session failure — trigger
      // auto-reconnect and show reconnecting. If there is no manager yet this is
      // an initial connection failure — surface it as failed so the UI can show
      // the error instead of an infinite spinner.
      if (stateChange.state == ConnectionState.failed) {
        final reconnManager = _reconnectionManagers[connectionId];
        if (reconnManager != null) {
          _updateConnectionStatus(connectionId, ConnectionState.reconnecting,
              errorMessage: stateChange.errorMessage);
          reconnManager.onDisconnected(DisconnectReason.unexpected);
        } else {
          _updateConnectionStatus(connectionId, ConnectionState.failed,
              errorMessage: stateChange.errorMessage);
        }
        return;
      }

      // Reset reconnection on successful connect
      if (stateChange.state == ConnectionState.connected) {
        _reconnectionManagers[connectionId]?.reset();

        // Start heartbeat monitor
        _heartbeatMonitors[connectionId]?.dispose();
        final heartbeat = HeartbeatMonitor(
          onConnectionDead: () {
            // Force close the dead connection and trigger reconnect
            ws.disconnect(); // Will trigger _handleDone -> unexpected disconnect
          },
        );
        ws.onFrameReceived = () => heartbeat.onFrameReceived();
        _heartbeatMonitors[connectionId] = heartbeat;
        heartbeat.start();

        // Notify external handler that connection is ready
        // (e.g., to flush queued messages)
      }

      _updateConnectionStatus(connectionId, stateChange.state,
          errorMessage: stateChange.errorMessage);
    });
    _subscriptions[connectionId]!.add(stateSubscription);
  }

  void dispose() {
    // Clean up all connections
    for (final connectionId in _connections.keys.toList()) {
      disconnect(connectionId);
    }

    // Clean up all reconnection managers
    for (final manager in _reconnectionManagers.values) {
      manager.dispose();
    }
    _reconnectionManagers.clear();

    // Clean up all heartbeat monitors
    for (final monitor in _heartbeatMonitors.values) {
      monitor.dispose();
    }
    _heartbeatMonitors.clear();

    // Close all status controllers
    for (final controller in _statusControllers.values) {
      controller.close();
    }
    _statusControllers.clear();
  }
}
