import 'package:clawon/data/local/database/app_database.dart';
import 'package:clawon/data/local/database/daos/connection_dao.dart';
import 'package:clawon/data/local/database/daos/message_dao.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ConnectionDao connectionDao;
  late MessageDao dao;
  const testConnectionId = 'conn-test';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    connectionDao = ConnectionDao(db);
    dao = MessageDao(db);

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

  ChatMessagesCompanion testMessage({
    required String id,
    String connectionId = testConnectionId,
    String role = 'user',
    String content = 'Hello',
    DateTime? timestamp,
  }) {
    return ChatMessagesCompanion.insert(
      id: id,
      connectionId: connectionId,
      role: role,
      content: content,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  group('MessageDao', () {
    test('upsertMessage inserts and getMessages retrieves', () async {
      await dao.upsertMessage(testMessage(id: 'msg-1'));
      final messages = await dao.getMessages(testConnectionId);
      expect(messages.length, 1);
      expect(messages[0].id, 'msg-1');
    });

    test('getMessages returns ordered by timestamp asc', () async {
      final now = DateTime.now();
      await dao.upsertMessage(testMessage(
          id: 'msg-1', timestamp: now));
      await dao.upsertMessage(testMessage(
          id: 'msg-2', timestamp: now.add(const Duration(seconds: 1))));
      final messages = await dao.getMessages(testConnectionId);
      expect(messages[0].id, 'msg-1');
      expect(messages[1].id, 'msg-2');
    });

    test('getMessagesPaginated returns newest first with limit/offset', () async {
      final now = DateTime.now();
      for (var i = 0; i < 15; i++) {
        await dao.upsertMessage(testMessage(
          id: 'msg-${i.toString().padLeft(3, '0')}',
          content: 'Message $i',
          timestamp: now.add(Duration(seconds: i)),
        ));
      }

      final page1 = await dao.getMessagesPaginated(testConnectionId, limit: 10, offset: 0);
      expect(page1.length, 10);
      // Newest first: msg-014, msg-013, ...
      expect(page1[0].id, 'msg-014');

      final page2 = await dao.getMessagesPaginated(testConnectionId, limit: 10, offset: 10);
      expect(page2.length, 5);
    });

    test('upsertMessage updates existing message', () async {
      await dao.upsertMessage(testMessage(id: 'msg-1', content: 'Original'));
      await dao.upsertMessage(ChatMessagesCompanion.insert(
        id: 'msg-1',
        connectionId: testConnectionId,
        role: 'user',
        content: 'Updated',
        timestamp: DateTime.now(),
      ));
      final messages = await dao.getMessages(testConnectionId);
      expect(messages.length, 1);
      expect(messages[0].content, 'Updated');
    });

    test('updateMessageContent updates only content', () async {
      await dao.upsertMessage(testMessage(id: 'msg-1', content: 'Original'));
      await dao.updateMessageContent('msg-1', 'New content');
      final messages = await dao.getMessages(testConnectionId);
      expect(messages[0].content, 'New content');
    });

    test('updateMessageStreaming updates streaming flag', () async {
      await dao.upsertMessage(testMessage(id: 'msg-1'));
      await dao.updateMessageStreaming('msg-1', true);
      final messages = await dao.getMessages(testConnectionId);
      expect(messages[0].isStreaming, isTrue);
    });

    test('updateMessageStatus updates status field', () async {
      await dao.upsertMessage(testMessage(id: 'msg-1'));
      await dao.updateMessageStatus('msg-1', 'failed');
      final messages = await dao.getMessages(testConnectionId);
      expect(messages[0].status, 'failed');
    });

    test('clearMessages removes all messages for a connection', () async {
      await dao.upsertMessage(testMessage(id: 'msg-1'));
      await dao.upsertMessage(testMessage(id: 'msg-2'));
      await dao.clearMessages(testConnectionId);
      final messages = await dao.getMessages(testConnectionId);
      expect(messages, isEmpty);
    });

    test('getMessageCount returns correct count', () async {
      await dao.upsertMessage(testMessage(id: 'msg-1'));
      await dao.upsertMessage(testMessage(id: 'msg-2'));
      await dao.upsertMessage(testMessage(id: 'msg-3'));
      final count = await dao.getMessageCount(testConnectionId);
      expect(count, 3);
    });

    test('messages are isolated per connection', () async {
      const conn2 = 'conn-test-2';
      await connectionDao.insertConnection(ConnectionsCompanion.insert(
        id: conn2,
        name: 'Test 2',
        gatewayUrl: 'wss://test2.com/ws',
        token: 'token2',
        createdAt: DateTime.now(),
      ));

      await dao.upsertMessage(testMessage(id: 'msg-1', connectionId: testConnectionId));
      await dao.upsertMessage(testMessage(id: 'msg-2', connectionId: conn2));

      final msgs1 = await dao.getMessages(testConnectionId);
      final msgs2 = await dao.getMessages(conn2);
      expect(msgs1.length, 1);
      expect(msgs2.length, 1);
      expect(msgs1[0].id, 'msg-1');
      expect(msgs2[0].id, 'msg-2');
    });
  });
}
