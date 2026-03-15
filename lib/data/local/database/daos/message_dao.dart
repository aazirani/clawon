import 'package:drift/drift.dart';
import '../app_database.dart';

part 'message_dao.g.dart';

@DriftAccessor(tables: [ChatMessages])
class MessageDao extends DatabaseAccessor<AppDatabase>
    with _$MessageDaoMixin {
  MessageDao(super.db);

  /// Get all messages for a connection, ordered by timestamp (ascending)
  /// Optional sessionKey parameter for session-scoped filtering
  Future<List<ChatMessage>> getMessages(
    String connectionId, [
    String? sessionKey,
  ]) {
    final query = select(chatMessages)
      ..where((m) => m.connectionId.equals(connectionId))
      ..orderBy([
        (m) => OrderingTerm.asc(m.timestamp),
        (m) => OrderingTerm.asc(m.rowId),
      ]);

    if (sessionKey != null) {
      query.where((m) => m.sessionKey.equals(sessionKey));
    }

    return query.get();
  }

  /// Get paginated messages (newest first for infinite scroll, reversed to chronological)
  /// Optional sessionKey parameter for session-scoped filtering
  Future<List<ChatMessage>> getMessagesPaginated(
    String connectionId, {
    required int limit,
    required int offset,
    String? sessionKey,
  }) async {
    final query = select(chatMessages)
      ..where((m) => m.connectionId.equals(connectionId))
      ..orderBy([
        (m) => OrderingTerm.desc(m.timestamp),
        (m) => OrderingTerm.desc(m.rowId),
      ])
      ..limit(limit, offset: offset);

    if (sessionKey != null) {
      query.where((m) => m.sessionKey.equals(sessionKey));
    }

    return query.get();
  }

  /// Insert or update a message (upsert for streaming updates)
  Future<void> upsertMessage(ChatMessagesCompanion entry) =>
      into(chatMessages).insertOnConflictUpdate(entry);

  /// Update message content (for streaming)
  Future<void> updateMessageContent(String id, String content) =>
      (update(chatMessages)..where((m) => m.id.equals(id))).write(
        ChatMessagesCompanion(content: Value(content)),
      );

  /// Update streaming status
  Future<void> updateMessageStreaming(String id, bool isStreaming) =>
      (update(chatMessages)..where((m) => m.id.equals(id))).write(
        ChatMessagesCompanion(isStreaming: Value(isStreaming)),
      );

  /// Update message status
  Future<void> updateMessageStatus(String id, String status) =>
      (update(chatMessages)..where((m) => m.id.equals(id))).write(
        ChatMessagesCompanion(status: Value(status)),
      );

  /// Delete all messages for a connection
  Future<void> clearMessages(String connectionId) =>
      (delete(chatMessages)..where((m) => m.connectionId.equals(connectionId))).go();

  /// Delete all messages for a specific session
  Future<void> clearMessagesForSession(String connectionId, String sessionKey) =>
      (delete(chatMessages)
            ..where((m) => m.connectionId.equals(connectionId) & m.sessionKey.equals(sessionKey)))
          .go();

  /// Get the latest text message for a specific session (for preview display).
  /// Only returns messages with role 'user' or 'assistant'.
  Future<ChatMessage?> getLatestMessageForSession(
    String connectionId,
    String sessionKey,
  ) {
    final query = select(chatMessages)
      ..where((m) =>
          m.connectionId.equals(connectionId) &
          m.sessionKey.equals(sessionKey) &
          m.role.isIn(['user', 'assistant']))
      ..orderBy([
        (m) => OrderingTerm.desc(m.timestamp),
        (m) => OrderingTerm.desc(m.rowId),
      ])
      ..limit(1);
    return query.getSingleOrNull();
  }

  /// Count messages for a connection
  Future<int> getMessageCount(String connectionId) async {
    final count = chatMessages.id.count();
    final query = selectOnly(chatMessages)
      ..addColumns([count])
      ..where(chatMessages.connectionId.equals(connectionId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Delete a specific message by ID
  Future<void> deleteMessage(String id) =>
      (delete(chatMessages)..where((m) => m.id.equals(id))).go();
}
