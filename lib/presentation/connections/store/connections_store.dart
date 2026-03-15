import 'dart:async';

import 'package:mobx/mobx.dart';
import 'package:uuid/uuid.dart';

import '../../../data/services/device_identity_service.dart';
import '../../../domain/entities/connection.dart';
import '../../../domain/entities/connection_state.dart';
import '../../../domain/exceptions/duplicate_connection_exception.dart';
import '../../../domain/repositories/chat_repository.dart';
import '../../../domain/repositories/connection_repository.dart';

part 'connections_store.g.dart';

const _uuid = Uuid();

class ConnectionsStore = _ConnectionsStore with _$ConnectionsStore;

abstract class _ConnectionsStore with Store {
  final ConnectionRepository _connectionRepository;
  final ChatRepository _chatRepository;
  final DeviceIdentityService _deviceIdentityService;
  StreamSubscription<String>? _metadataSubscription;
  final Map<String, StreamSubscription<ConnectionStatus>> _statusSubscriptions = {};

  _ConnectionsStore(
    this._connectionRepository,
    this._chatRepository,
    this._deviceIdentityService,
  ) {
    _metadataSubscription =
        _chatRepository.connectionMetadataUpdates.listen((_) {
      loadConnections();
    });
  }

  @observable
  ObservableList<Connection> connections = ObservableList<Connection>();

  @observable
  ObservableMap<String, ConnectionState> connectionStates =
      ObservableMap<String, ConnectionState>();

  @observable
  ObservableMap<String, String?> connectionErrors =
      ObservableMap<String, String?>();

  @observable
  ObservableMap<String, bool> pairingStatus = ObservableMap<String, bool>();

  @observable
  bool isLoading = false;

  bool isPaired(String connectionId) {
    return pairingStatus[connectionId] ?? false;
  }

  @action
  Future<void> loadConnections() async {
    isLoading = true;
    try {
      final result = await _connectionRepository.getConnections();
      // Sort by lastMessageAt descending (most recent first)
      result.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
      connections.clear();
      connections.addAll(result);

      // Load pairing status for all connections
      await _loadPairingStatus();

      // Subscribe to connection status for all connections
      _subscribeToConnectionStatuses();
    } finally {
      isLoading = false;
    }
  }

  Future<void> _loadPairingStatus() async {
    for (final connection in connections) {
      final token = await _deviceIdentityService.getDeviceToken(connection.id);
      pairingStatus[connection.id] = token != null && token.isNotEmpty;
    }
  }

  @action
  Future<void> unpairConnection(String connectionId) async {
    // Disconnect if currently connected
    await _chatRepository.disconnect(connectionId);

    // Remove the device token
    await _deviceIdentityService.deleteDeviceToken(connectionId);

    // Update pairing status
    pairingStatus[connectionId] = false;

    // Clear connection state
    connectionStates[connectionId] = ConnectionState.disconnected;
    connectionErrors.remove(connectionId);
  }

  void _subscribeToConnectionStatuses() {
    // Cancel subscriptions for connections that no longer exist
    final currentIds = connections.map((c) => c.id).toSet();
    final subscriptionIds = _statusSubscriptions.keys.toSet();
    for (final id in subscriptionIds.difference(currentIds)) {
      _statusSubscriptions[id]?.cancel();
      _statusSubscriptions.remove(id);
      connectionStates.remove(id);
      connectionErrors.remove(id);
    }

    // Refresh state and subscribe for all connections
    for (final connection in connections) {
      // Always refresh current state from WebSocket
      final ws = _chatRepository.getWebSocketConnection(connection.id);
      if (ws != null) {
        connectionStates[connection.id] = ws.state;
      } else if (!connectionStates.containsKey(connection.id)) {
        connectionStates[connection.id] = ConnectionState.disconnected;
      }

      // Only create new subscriptions
      if (!_statusSubscriptions.containsKey(connection.id)) {
        _statusSubscriptions[connection.id] =
            _chatRepository.connectionStatus(connection.id).listen((status) {
          _updateConnectionState(connection.id, status.state);
          _updateConnectionError(connection.id, status.errorMessage);
        });
      }
    }
  }

  @action
  void _updateConnectionState(String connectionId, ConnectionState state) {
    connectionStates[connectionId] = state;
    if (state == ConnectionState.connected) {
      _onConnected(connectionId);
    }
  }

  Future<void> _onConnected(String connectionId) async {
    final wasAlreadyPaired = pairingStatus[connectionId] ?? false;
    final token = await _deviceIdentityService.getDeviceToken(connectionId);
    final isNowPaired = token != null && token.isNotEmpty;
    _setPairingStatus(connectionId, isNowPaired);

    // If just paired for the first time, clear the gateway token from the DB
    if (isNowPaired && !wasAlreadyPaired) {
      await _clearConnectionToken(connectionId);
    }
  }

  @action
  void _setPairingStatus(String connectionId, bool isPaired) {
    pairingStatus[connectionId] = isPaired;
  }

  Future<void> _clearConnectionToken(String connectionId) async {
    final index = connections.indexWhere((c) => c.id == connectionId);
    if (index == -1) return;
    final connection = connections[index];
    if (connection.token.isEmpty) return;

    final updated = connection.copyWith(token: '');
    await _connectionRepository.updateConnection(updated);
    _replaceConnectionAt(index, updated);
  }

  @action
  void _replaceConnectionAt(int index, Connection connection) {
    if (index >= 0 && index < connections.length) {
      connections[index] = connection;
    }
  }

  @action
  void _updateConnectionError(String connectionId, String? error) {
    if (error != null && error.isNotEmpty) {
      connectionErrors[connectionId] = error;
    } else {
      connectionErrors.remove(connectionId);
    }
  }

  ConnectionState getConnectionState(String connectionId) {
    return connectionStates[connectionId] ?? ConnectionState.disconnected;
  }

  @action
  Future<void> deleteConnection(String id) async {
    await _connectionRepository.deleteConnection(id);
    connections.removeWhere((c) => c.id == id);
  }

  @action
  Future<Connection> addConnection({
    required String name,
    required String gatewayUrl,
    required String token,
  }) async {
    // Check for duplicate connection (same URL + token)
    _validateNoDuplicate(gatewayUrl: gatewayUrl, token: token);

    final connection = Connection(
      id: _generateId(),
      name: name,
      gatewayUrl: gatewayUrl,
      token: token,
      createdAt: DateTime.now(),
    );
    await _connectionRepository.saveConnection(connection);
    connections.insert(0, connection); // Add to top
    return connection;
  }

  @action
  Future<void> updateConnection(Connection connection) async {
    // Check for duplicate connection (same URL + token), excluding current
    _validateNoDuplicate(
      gatewayUrl: connection.gatewayUrl,
      token: connection.token,
      excludeId: connection.id,
    );

    await _connectionRepository.updateConnection(connection);
    final index = connections.indexWhere((c) => c.id == connection.id);
    if (index != -1) {
      connections[index] = connection;
      // Re-sort after update
      final result = List<Connection>.from(connections);
      result.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt;
        final bTime = b.lastMessageAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
      connections.clear();
      connections.addAll(result);
    }
  }

  /// Normalizes a WebSocket URL for duplicate detection by replacing the
  /// scheme with a canonical form. Both ws:// and wss:// point to the same
  /// server host/path, so they are treated as equivalent.
  String _normalizeUrl(String url) {
    return url.trim().toLowerCase().replaceFirst(RegExp(r'^wss?://'), 'ws://');
  }

  /// Validates that no existing connection has the same gateway URL and token.
  /// ws:// and wss:// are treated as equivalent (same server).
  /// If [excludeId] is provided, that connection is excluded from the check
  /// (useful when updating an existing connection).
  void _validateNoDuplicate({
    required String gatewayUrl,
    required String token,
    String? excludeId,
  }) {
    final normalizedUrl = _normalizeUrl(gatewayUrl);
    final normalizedToken = token.trim();

    final isDuplicate = connections.any((c) {
      if (excludeId != null && c.id == excludeId) {
        return false;
      }
      return _normalizeUrl(c.gatewayUrl) == normalizedUrl &&
          c.token.trim() == normalizedToken;
    });

    if (isDuplicate) {
      throw DuplicateConnectionException();
    }
  }

  String _generateId() {
    return _uuid.v4();
  }

  void dispose() {
    _metadataSubscription?.cancel();
    for (final subscription in _statusSubscriptions.values) {
      subscription.cancel();
    }
    _statusSubscriptions.clear();
  }
}
