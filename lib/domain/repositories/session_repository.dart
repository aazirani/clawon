import '../entities/session.dart';

/// Repository for managing gateway sessions
abstract class SessionRepository {
  /// Fetches list of sessions from a connected gateway
  /// Requires an active WebSocket connection
  Future<List<GatewaySession>> fetchSessions(String connectionId);

  /// Fetches list of sessions from gateway with message limit
  /// Requires an active WebSocket connection
  /// [kind] - Filter by session kind. Empty list = show all sessions.
  Future<List<GatewaySession>> fetchSessionsWithMessages(
    String connectionId, {
    int messageLimit = 50,
    int activeMinutes = 10080,
    List<String> kind = const [], // Empty = show all sessions
  });

  /// Creates or resolves a session on the gateway.
  /// Returns the session key in format:
  /// - Regular: `agent:<agentId>:clawon-<connectionId>-<timestamp>`
  /// - With purpose: `agent:<agentId>:clawon-<purpose>-<connectionId>-<timestamp>`
  ///
  /// The session ID format allows filtering sessions by:
  /// - Prefix "clawon-" to identify all ClawOn-created sessions
  /// - Purpose (if provided) to identify creator sessions by pattern
  /// - Connection ID to link sessions to specific connections
  ///
  /// [agentId] is required - the ID of the agent to use for this session.
  /// [agentEmoji] - Optional emoji for the agent (stored with session for offline display)
  /// [kind] - Optional session kind (e.g., 'main', 'skill-creator')
  /// [purpose] - Optional purpose embedded in session ID (e.g., 'skill-creator')
  Future<String> createSession(
    String connectionId, {
    required String agentId,
    String? agentEmoji,
    String? label,
    String? parentSessionKey,
    String? kind,
    String? purpose,
  });

  /// Gets sessions from local cache
  Future<List<GatewaySession>> getCachedSessions(String connectionId);

  /// Saves sessions to local cache
  Future<void> cacheSessions(String connectionId, List<GatewaySession> sessions);

  /// Gets messages for a specific session from gateway
  Future<List<dynamic>> fetchSessionHistory(
    String connectionId,
    String sessionKey, {
    int limit = 100,
  });

  /// Renames a session locally and on the server
  Future<void> renameSession(String connectionId, String sessionKey, String newTitle);

  /// Deletes a session by ID
  Future<void> deleteSession(String connectionId, String sessionId);

  /// Gets the latest message preview for a session from local storage
  Future<Map<String, String>?> getLastMessagePreview(
    String connectionId,
    String sessionKey,
  );

  /// Watch for session changes (stream)
  Stream<List<GatewaySession>> watchSessions(String connectionId);

  /// Creates a skill creator session with hidden system prompt.
  /// This is used for the skill creation assistant flow.
  /// [agentId] - Optional agent ID to scope the skill to. Defaults to 'main'.
  Future<String> createSkillCreatorSession(String connectionId, {String? agentId});

  /// Cleans up any orphaned skill-creator sessions.
  /// Should be called on app startup or when connection is established.
  /// These sessions are temporary and should not persist across app restarts.
  Future<void> cleanupSkillCreatorSessions(String connectionId);

  /// Creates a dedicated agent creator session with hidden system prompt.
  /// This is used for the agent creation assistant flow.
  Future<String> createAgentCreatorSession(String connectionId);

  /// Cleans up orphaned agent-creator sessions for the given connection.
  /// Should be called on app startup or when connection is established.
  Future<void> cleanupAgentCreatorSessions(String connectionId);
}
