import '../entities/connection_state.dart';
import '../entities/agent.dart';
import '../entities/message.dart';
import '../../data/datasources/openclaw_ws_datasource.dart';

abstract class ChatRepository {
  // Metadata updates - emits connectionId when connection metadata changes
  Stream<String> get connectionMetadataUpdates;

  // Connection
  Future<void> connect(String connectionId);

  Future<void> disconnect(String connectionId);

  Stream<ConnectionStatus> connectionStatus(String connectionId);

  // Messages
  /// Returns true if the message was sent immediately, false if it was queued.
  Future<bool> sendMessage(
    String connectionId,
    String content, {
    String? sessionKey,
    String? messageId,
  });

  /// Retrieves messages for a connection with pagination support
  /// [connectionId] - The connection identifier
  /// [sessionKey] - Optional session key to filter messages by session
  /// [limit] - Maximum number of messages to return (default 20)
  /// [offset] - Number of messages to skip from beginning (default 0)
  /// Returns a list of messages in chronological order (oldest first)
  Future<List<Message>> getMessagesPaginated(
    String connectionId, {
    String? sessionKey,
    int limit = 20,
    int offset = 0,
  });

  /// Fetches chat history from the gateway for a session and saves it locally.
  /// This is useful for syncing message history when opening a session that
  /// was created on another device or when local messages are missing.
  /// [connectionId] - The connection identifier
  /// [sessionKey] - The session key to fetch history for
  /// [limit] - Maximum number of messages to fetch from gateway (default 100)
  /// Returns the list of fetched messages.
  Future<List<Message>> fetchAndSyncHistory(
    String connectionId, {
    required String sessionKey,
    int limit = 100,
  });

  // Agent responses
  Stream<Message> agentResponses(String connectionId);

  // Agents
  /// Fetches available agents from a connected gateway
  /// Requires an active WebSocket connection for [connectionId]
  Future<List<Agent>> fetchAgents(String connectionId);

  // State queries
  /// Whether repository is waiting for an agent response for this connection/session
  /// [connectionId] - The connection identifier
  /// [sessionKey] - Optional session key to check waiting state for a specific session
  bool isWaitingForResponse(String connectionId, {String? sessionKey});

  // Session management
  /// Clears all messages and session state from the repository for a specific session
  Future<void> clearSession(String connectionId, {String? sessionKey});

  /// Gets the current session key used for gateway requests
  /// Note: This is deprecated in favor of multi-session architecture.
  /// Sessions are now managed by SessionRepository.
  @Deprecated('Use SessionRepository for session management')
  String? getSessionKey(String connectionId);

  /// Whether this connection was intentionally disconnected by the user
  bool wasIntentionallyDisconnected(String connectionId);

  // WebSocket access for API calls
  /// Gets the WebSocket datasource for a specific connection (for making API calls)
  /// Returns null if connection is not active
  OpenClawWebSocketDatasource? getWebSocketConnection(String connectionId);

  /// Sends a hidden system message that won't be displayed to the user.
  /// Used for setting context in special sessions like skill creation.
  Future<void> sendSystemMessage(
    String connectionId,
    String sessionKey,
    String content,
  );

  /// Deletes a message from local storage (cache and database).
  /// Also removes the message from the queue if it's queued for delivery.
  Future<void> deleteMessage(
    String connectionId,
    String messageId, {
    String? sessionKey,
  });

  /// Resends a previously failed or queued message.
  /// Returns true if the message was sent immediately, false if it was re-queued.
  Future<bool> resendMessage(
    String connectionId,
    String messageId,
    String content, {
    String? sessionKey,
  });

  /// Marks a message as failed in the database.
  Future<void> markMessageFailed(
    String connectionId,
    String messageId, {
    String? sessionKey,
  });
}
