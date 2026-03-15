/// Unified connection state used across all layers.
/// This replaces both AppConnectionState and data/ConnectionState.
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
  pairingRequired,
}

extension ConnectionStateExtension on ConnectionState {
  bool get isConnected => this == ConnectionState.connected;

  bool get isConnecting =>
      this == ConnectionState.connecting ||
      this == ConnectionState.reconnecting;

  bool get isFailed => this == ConnectionState.failed;
}

/// Connection status with optional error message
class ConnectionStatus {
  final ConnectionState state;
  final String? errorMessage;

  ConnectionStatus({required this.state, this.errorMessage});
}
