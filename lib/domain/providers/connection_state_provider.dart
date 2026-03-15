import '../entities/connection_state.dart';

/// Interface for providing connection state.
/// Allows ChatStore to depend on abstraction instead of concrete ConnectionStore.
/// This decouples the chat functionality from the specific connection management implementation.
abstract class ConnectionStateProvider {
  /// Current connection state
  ConnectionState get connectionState;

  /// Whether currently connected
  bool get isConnected;

  /// Whether currently connecting (including reconnecting)
  bool get isConnecting;

  /// Optional error message if connection failed
  String? get errorMessage;
}
