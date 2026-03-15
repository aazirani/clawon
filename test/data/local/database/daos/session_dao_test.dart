import 'package:clawon/data/local/database/app_database.dart';
import 'package:clawon/data/local/database/daos/connection_dao.dart';
import 'package:clawon/data/local/database/daos/session_dao.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ConnectionDao connectionDao;
  late SessionDao dao;
  const testConnectionId = 'conn-test';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    connectionDao = ConnectionDao(db);
    dao = SessionDao(db);

    // Insert parent connection (FK constraint)
    await connectionDao.insertConnection(ConnectionsCompanion.insert(
      id: testConnectionId,
      name: 'Test',
      gatewayUrl: 'wss://test.com/ws',
      token: 'token',
      createdAt: DateTime.now(),
    ));
  });

  tearDown(() async {
    await db.close();
  });

  /// Helper to create a test session companion
  SessionsCompanion testSession({
    required String sessionKey,
    String connectionId = testConnectionId,
    String title = 'Test Session',
    String? agentId,
    String? agentName,
    int messageCount = 0,
    DateTime? createdAt,
    DateTime? lastActive,
    DateTime? syncedAt,
  }) {
    return SessionsCompanion.insert(
      sessionKey: sessionKey,
      connectionId: connectionId,
      title: title,
      createdAt: createdAt ?? DateTime.now(),
      lastActive: lastActive ?? DateTime.now(),
      syncedAt: syncedAt ?? DateTime.now(),
      agentId: Value(agentId),
      agentName: Value(agentName),
      messageCount: Value(messageCount),
    );
  }

  group('SessionDao', () {
    test('upsertSession inserts and retrieves', () async {
      // Arrange
      await dao.upsertSession(testSession(
        sessionKey: 'session-1',
        title: 'Main Session',
        agentId: 'agent-1',
        agentName: 'Test Agent',
        messageCount: 10,
        createdAt: DateTime(2024, 1, 15),
        lastActive: DateTime(2024, 2, 10, 10, 30),
        syncedAt: DateTime(2024, 2, 11, 0, 0),
      ));

      // Act
      final retrieved = await dao.getSessionByKey('session-1');

      // Assert
      expect(retrieved, isNotNull);
      expect(retrieved!.sessionKey, 'session-1');
      expect(retrieved.title, 'Main Session');
      expect(retrieved.agentId, 'agent-1');
      expect(retrieved.agentName, 'Test Agent');
      expect(retrieved.messageCount, 10);
    });

    test('upsertSession updates existing session', () async {
      // Arrange - Insert initial session
      await dao.upsertSession(testSession(
        sessionKey: 'session-1',
        title: 'Original Title',
        messageCount: 5,
        createdAt: DateTime(2024, 1, 1),
        lastActive: DateTime(2024, 1, 1),
      ));

      // Act - Update with same sessionKey
      await dao.upsertSession(testSession(
        sessionKey: 'session-1',
        title: 'Updated Title',
        messageCount: 15,
        createdAt: DateTime(2024, 1, 2),
        lastActive: DateTime(2024, 1, 2),
      ));

      // Assert
      final retrieved = await dao.getSessionByKey('session-1');
      expect(retrieved, isNotNull);
      expect(retrieved!.title, 'Updated Title');
      expect(retrieved.messageCount, 15);
    });

    test('getSessionsForConnection returns ordered by lastActive desc', () async {
      // Arrange
      final now = DateTime.now();
      await dao.upsertSession(testSession(
        sessionKey: 'session-1',
        title: 'Session 1',
        messageCount: 10,
        createdAt: now.subtract(const Duration(days: 2)),
        lastActive: now.subtract(const Duration(days: 1)),
      ));
      await dao.upsertSession(testSession(
        sessionKey: 'session-2',
        title: 'Session 2',
        messageCount: 5,
        createdAt: now.subtract(const Duration(days: 1)),
        lastActive: now.subtract(const Duration(hours: 2)),
      ));

      // Act
      final sessions = await dao.getSessionsForConnection(testConnectionId);

      // Assert - Should be ordered by lastActive descending (most recent first)
      expect(sessions.length, 2);
      expect(sessions[0].sessionKey, 'session-2'); // Most recent
      expect(sessions[1].sessionKey, 'session-1');
    });

    test('getSessionByKey returns null for non-existent session', () async {
      // Act
      final result = await dao.getSessionByKey('non-existent');

      // Assert
      expect(result, isNull);
    });

    test('deleteSession removes session', () async {
      // Arrange
      await dao.upsertSession(testSession(
        sessionKey: 'session-delete',
        title: 'To Delete',
        messageCount: 1,
      ));

      // Act
      await dao.deleteSession('session-delete');

      // Assert
      final retrieved = await dao.getSessionByKey('session-delete');
      expect(retrieved, isNull);
    });

    test('deleteSessionsForConnection removes all sessions', () async {
      // Arrange - Insert multiple sessions
      await dao.upsertSession(testSession(
        sessionKey: 'session-1',
        title: 'Session 1',
        messageCount: 1,
      ));
      await dao.upsertSession(testSession(
        sessionKey: 'session-2',
        title: 'Session 2',
        messageCount: 1,
      ));

      // Act
      await dao.deleteSessionsForConnection(testConnectionId);

      // Assert
      final sessions = await dao.getSessionsForConnection(testConnectionId);
      expect(sessions, isEmpty);
    });

    test('updateMessageCount updates messageCount field', () async {
      // Arrange
      await dao.upsertSession(testSession(
        sessionKey: 'session-count',
        title: 'Count Test',
        messageCount: 5,
      ));

      // Act
      await dao.updateMessageCount('session-count', 42);

      // Assert
      final retrieved = await dao.getSessionByKey('session-count');
      expect(retrieved, isNotNull);
      expect(retrieved!.messageCount, 42);
    });

    test('updateLastActive updates timestamp', () async {
      // Arrange
      final newTime = DateTime(2024, 2, 15, 10, 30);
      await dao.upsertSession(testSession(
        sessionKey: 'session-time',
        title: 'Time Test',
        messageCount: 1,
        createdAt: DateTime(2024, 1, 1),
        lastActive: DateTime(2024, 1, 1),
      ));

      // Act
      await dao.updateLastActive('session-time', newTime);

      // Assert
      final retrieved = await dao.getSessionByKey('session-time');
      expect(retrieved, isNotNull);
      expect(retrieved!.lastActive, newTime);
    });

    test('multiple sessions per connection are isolated', () async {
      // Arrange - Insert sessions for two different connections
      const conn1 = 'conn-1';
      const conn2 = 'conn-2';

      // Create parent connections
      await connectionDao.insertConnection(ConnectionsCompanion.insert(
        id: conn1,
        name: 'Connection 1',
        gatewayUrl: 'wss://test1.com/ws',
        token: 'token1',
        createdAt: DateTime.now(),
      ));
      await connectionDao.insertConnection(ConnectionsCompanion.insert(
        id: conn2,
        name: 'Connection 2',
        gatewayUrl: 'wss://test2.com/ws',
        token: 'token2',
        createdAt: DateTime.now(),
      ));

      await dao.upsertSession(testSession(
        sessionKey: 'session-conn1',
        connectionId: conn1,
        title: 'Conn 1 Session',
        messageCount: 1,
      ));
      await dao.upsertSession(testSession(
        sessionKey: 'session-conn2',
        connectionId: conn2,
        title: 'Conn 2 Session',
        messageCount: 1,
      ));

      // Act
      final conn1Sessions = await dao.getSessionsForConnection(conn1);
      final conn2Sessions = await dao.getSessionsForConnection(conn2);

      // Assert - Sessions should be isolated per connection
      expect(conn1Sessions.length, 1);
      expect(conn2Sessions.length, 1);
      expect(conn1Sessions[0].sessionKey, 'session-conn1');
      expect(conn2Sessions[0].sessionKey, 'session-conn2');
    });

    test('upsertSession handles conflict by updating', () async {
      // Arrange - Insert initial
      await dao.upsertSession(testSession(
        sessionKey: 'session-conflict',
        title: 'Original',
        messageCount: 1,
        createdAt: DateTime(2024, 1, 1),
        lastActive: DateTime(2024, 1, 1),
      ));

      // Act - Insert with same key (should update)
      await dao.upsertSession(testSession(
        sessionKey: 'session-conflict',
        title: 'Updated',
        messageCount: 5,
        createdAt: DateTime(2024, 1, 2),
        lastActive: DateTime(2024, 1, 2),
      ));

      // Assert - Should only have one entry
      final sessions = await dao.getSessionsForConnection(testConnectionId);
      final matching = sessions.where((s) => s.sessionKey == 'session-conflict').toList();
      expect(matching.length, 1);
      expect(matching[0].title, 'Updated');
      expect(matching[0].messageCount, 5);
    });
  });
}
