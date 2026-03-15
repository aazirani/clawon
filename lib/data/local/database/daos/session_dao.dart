import 'package:drift/drift.dart';
import '../app_database.dart';

part 'session_dao.g.dart';

@DriftAccessor(tables: [Sessions])
class SessionDao extends DatabaseAccessor<AppDatabase> with _$SessionDaoMixin {
  SessionDao(super.db);

  /// Get all sessions for a connection, ordered by last active (most recent first)
  Future<List<Session>> getSessionsForConnection(String connectionId) =>
      (select(sessions)
            ..where((s) => s.connectionId.equals(connectionId))
            ..orderBy([(s) => OrderingTerm.desc(s.lastActive)]))
          .get();

  /// Watch sessions for real-time updates
  Stream<List<Session>> watchSessionsForConnection(String connectionId) =>
      (select(sessions)
            ..where((s) => s.connectionId.equals(connectionId))
            ..orderBy([(s) => OrderingTerm.desc(s.lastActive)]))
          .watch();

  /// Get a single session by key
  Future<Session?> getSessionByKey(String sessionKey) =>
      (select(sessions)..where((s) => s.sessionKey.equals(sessionKey)))
          .getSingleOrNull();

  /// Upsert a session
  Future<void> upsertSession(SessionsCompanion entry) =>
      into(sessions).insertOnConflictUpdate(entry);

  /// Delete a session
  Future<void> deleteSession(String sessionKey) =>
      (delete(sessions)..where((s) => s.sessionKey.equals(sessionKey))).go();

  /// Delete all sessions for a connection
  Future<void> deleteSessionsForConnection(String connectionId) =>
      (delete(sessions)..where((s) => s.connectionId.equals(connectionId))).go();

  /// Update message count for a session
  Future<void> updateMessageCount(String sessionKey, int count) =>
      (update(sessions)..where((s) => s.sessionKey.equals(sessionKey)))
          .write(SessionsCompanion(messageCount: Value(count)));

  /// Update session title
  Future<void> updateTitle(String sessionKey, String title) =>
      (update(sessions)..where((s) => s.sessionKey.equals(sessionKey)))
          .write(SessionsCompanion(title: Value(title)));

  /// Update last active timestamp
  Future<void> updateLastActive(String sessionKey, DateTime lastActive) =>
      (update(sessions)..where((s) => s.sessionKey.equals(sessionKey)))
          .write(SessionsCompanion(lastActive: Value(lastActive)));
}
