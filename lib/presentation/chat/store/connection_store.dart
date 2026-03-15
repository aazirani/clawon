import 'dart:async';

import 'package:mobx/mobx.dart';

import '../../../domain/entities/connection_state.dart';
import '../../../domain/providers/connection_state_provider.dart';
import '../../../domain/repositories/chat_repository.dart';
import '../../../domain/repositories/session_repository.dart';

part 'connection_store.g.dart';

class ConnectionStore = _ConnectionStore with _$ConnectionStore;

abstract class _ConnectionStore with Store implements ConnectionStateProvider {
  final ChatRepository _repository;
  final SessionRepository _sessionRepository;
  final String connectionId;
  StreamSubscription<ConnectionStatus>? _statusSubscription;

  _ConnectionStore(
    this._repository,
    this._sessionRepository,
    this.connectionId,
  ) {
    // Check current connection state synchronously so the UI
    // shows the correct status immediately on first build
    final ws = _repository.getWebSocketConnection(connectionId);
    if (ws != null) {
      connectionState = ws.state;
    }

    _statusSubscription =
        _repository.connectionStatus(connectionId).listen((status) {
      connectionState = status.state;
      errorMessage = status.errorMessage;
    });
  }

  @override
  @observable
  ConnectionState connectionState = ConnectionState.disconnected;

  @override
  @observable
  String? errorMessage;

  @override
  @computed
  bool get isConnected => connectionState == ConnectionState.connected;

  @override
  @computed
  bool get isConnecting =>
      connectionState == ConnectionState.connecting ||
      connectionState == ConnectionState.reconnecting;

  @action
  Future<void> connect() async {
    try {
      errorMessage = null;
      await _repository.connect(connectionId);
      // After successful connect, fetch sessions with recent messages
      await _sessionRepository.fetchSessionsWithMessages(
        connectionId,
        messageLimit: 50,
      );
    } catch (e) {
      // Store the error so the UI can display it via the errorMessage observable.
      // Do NOT rethrow — the UI reacts to connectionState/errorMessage observables,
      // not to exceptions. Rethrowing escapes the MobX AsyncAction and causes an
      // unhandled exception at the Dart VM level.
      errorMessage = e.toString();
    }
  }

  @action
  Future<void> disconnect() async {
    await _repository.disconnect(connectionId);
  }

  @action
  void clearError() {
    errorMessage = null;
  }

  /// Sync observable state with the current WebSocket connection state.
  /// Call this after external code establishes or drops a connection
  /// outside of this store (e.g. _initializeSessions).
  @action
  void refreshState() {
    final ws = _repository.getWebSocketConnection(connectionId);
    if (ws != null) {
      connectionState = ws.state;
    }
  }

  void dispose() {
    _statusSubscription?.cancel();
  }
}
