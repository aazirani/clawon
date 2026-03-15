import '../local/database/daos/connection_dao.dart';
import '../local/database/daos/message_dao.dart';
import '../local/database/daos/session_dao.dart';
import '../models/connection_config.dart';
import '../models/session_config.dart';
import '../models/chat_message.dart';

class ConnectionLocalDatasource {
  final ConnectionDao _connectionDao;
  final MessageDao _messageDao;
  final SessionDao _sessionDao;

  ConnectionLocalDatasource(
    this._connectionDao,
    this._messageDao,
    this._sessionDao,
  );

  // ─── Connections ─────────────────────────────────

  Future<List<ConnectionConfig>> getConnections() async {
    final rows = await _connectionDao.getAllConnections();
    return rows.map(ConnectionConfig.fromDriftRow).toList();
  }

  Stream<List<ConnectionConfig>> watchConnections() {
    return _connectionDao.watchAllConnections().map(
          (rows) => rows.map(ConnectionConfig.fromDriftRow).toList(),
        );
  }

  Future<ConnectionConfig?> getConnection(String id) async {
    final row = await _connectionDao.getConnectionById(id);
    return row != null ? ConnectionConfig.fromDriftRow(row) : null;
  }

  Future<void> saveConnection(ConnectionConfig config) async {
    await _connectionDao.upsertConnection(config.toDriftCompanion());
  }

  Future<void> updateConnection(ConnectionConfig config) async {
    await _connectionDao.updateConnection(config.toDriftCompanion());
  }

  Future<void> deleteConnection(String id) async {
    await _messageDao.clearMessages(id);
    await _connectionDao.deleteConnectionById(id);
  }

  // ─── Messages ────────────────────────────────────

  Future<List<ChatMessage>> getMessages(String connectionId, {String? sessionKey}) async {
    final rows = await _messageDao.getMessages(connectionId, sessionKey);
    return rows.map(ChatMessage.fromDriftRow).toList();
  }

  Future<List<ChatMessage>> getMessagesPaginated(
    String connectionId, {
    required int limit,
    required int offset,
    String? sessionKey,
  }) async {
    final rows = await _messageDao.getMessagesPaginated(
      connectionId,
      limit: limit,
      offset: offset,
      sessionKey: sessionKey,
    );
    // Reverse from newest-first to chronological order
    return rows.reversed.map(ChatMessage.fromDriftRow).toList();
  }

  /// Save a single message (incremental — no delete-all)
  Future<void> saveMessage(
    String connectionId,
    ChatMessage message, [
    String? sessionKey,
  ]) async {
    await _messageDao.upsertMessage(
      message.toDriftCompanion(connectionId, sessionKey ?? message.sessionKey),
    );
  }

  /// Bulk save messages (for batch operations)
  Future<void> saveMessages(
    String connectionId,
    List<ChatMessage> messages, [
    String? sessionKey,
  ]) async {
    for (final message in messages) {
      await _messageDao.upsertMessage(
        message.toDriftCompanion(connectionId, sessionKey ?? message.sessionKey),
      );
    }
  }

  /// Delete all messages for a connection
  Future<void> clearMessages(String connectionId) async {
    await _messageDao.clearMessages(connectionId);
  }

  /// Delete all messages for a specific session within a connection
  Future<void> clearMessagesForSession(String connectionId, String sessionKey) async {
    await _messageDao.clearMessagesForSession(connectionId, sessionKey);
  }

  /// Delete all messages for a connection (alias for clearMessages)
  Future<void> deleteConnectionMessages(String id) async {
    await _messageDao.clearMessages(id);
  }

  Future<void> updateMessageContent(String id, String content) async {
    await _messageDao.updateMessageContent(id, content);
  }

  Future<void> updateMessageStatus(String id, String status) async {
    await _messageDao.updateMessageStatus(id, status);
  }

  Future<void> updateMessageStreaming(String id, bool isStreaming) async {
    await _messageDao.updateMessageStreaming(id, isStreaming);
  }

  /// Delete a specific message by ID
  Future<void> deleteMessage(String messageId) async {
    await _messageDao.deleteMessage(messageId);
  }

  // ─── Metadata ────────────────────────────────────

  Future<void> updateConnectionMetadata(
    String connectionId, {
    DateTime? lastMessageAt,
    String? lastMessagePreview,
  }) async {
    await _connectionDao.updateMetadata(
      connectionId,
      lastMessageAt: lastMessageAt,
      lastMessagePreview: lastMessagePreview,
    );
  }

  Future<void> updateAgentInfo(
    String connectionId,
    String? agentId,
    String? agentName,
  ) async {
    await _connectionDao.updateAgentInfo(connectionId, agentId, agentName);
  }

  // ─── Sessions ─────────────────────────────────────

  Future<List<SessionConfig>> getSessions(String connectionId) async {
    final rows = await _sessionDao.getSessionsForConnection(connectionId);
    return rows.map((row) => SessionConfig.fromDriftRow(row)).toList();
  }

  Stream<List<SessionConfig>> watchSessions(String connectionId) {
    return _sessionDao.watchSessionsForConnection(connectionId).map(
          (rows) => rows.map((row) => SessionConfig.fromDriftRow(row)).toList(),
        );
  }

  Future<void> saveSession(String connectionId, SessionConfig config) async {
    await _sessionDao.upsertSession(config.toDriftCompanion());
  }

  /// Update a session's title
  Future<void> updateSessionTitle(String sessionKey, String title) async {
    await _sessionDao.updateTitle(sessionKey, title);
  }

  /// Delete a session and its messages
  Future<void> deleteSession(String connectionId, String sessionKey) async {
    await _messageDao.clearMessagesForSession(connectionId, sessionKey);
    await _sessionDao.deleteSession(sessionKey);
  }

  /// Get a single session by key
  Future<SessionConfig?> getSessionByKey(String sessionKey) async {
    final row = await _sessionDao.getSessionByKey(sessionKey);
    return row != null ? SessionConfig.fromDriftRow(row) : null;
  }

  /// Get the latest message for a specific session (for preview display)
  Future<ChatMessage?> getLatestMessageForSession(
    String connectionId,
    String sessionKey,
  ) async {
    final row = await _messageDao.getLatestMessageForSession(connectionId, sessionKey);
    return row != null ? ChatMessage.fromDriftRow(row) : null;
  }
}
