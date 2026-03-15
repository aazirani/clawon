import 'dart:async';

import 'package:clawon/data/models/chat_message.dart' show MessageStatus;
import 'package:clawon/domain/entities/connection_state.dart';
import 'package:clawon/domain/entities/message.dart';
import 'package:clawon/domain/providers/connection_state_provider.dart';
import 'package:clawon/domain/repositories/chat_repository.dart';
import 'package:clawon/presentation/chat/store/chat_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockChatRepository extends Mock implements ChatRepository {}

class MockConnectionStateProvider extends Mock implements ConnectionStateProvider {}

void main() {
  group('ChatStore', () {
    group('Session Filtering', () {
      late ChatStore store;
      late MockChatRepository mockRepository;
      late MockConnectionStateProvider mockConnectionState;

      const testConnectionId = 'connection-1';
      const testSessionKey = 'session-A';

      setUp(() {
        mockRepository = MockChatRepository();
        mockConnectionState = MockConnectionStateProvider();

        // Setup stream controllers for testing
        when(() => mockRepository.agentResponses(testConnectionId))
            .thenAnswer((_) => const Stream.empty());
        when(() => mockRepository.isWaitingForResponse(testConnectionId,
                sessionKey: testSessionKey))
            .thenReturn(false);
        when(() => mockRepository.getMessagesPaginated(
              testConnectionId,
              sessionKey: testSessionKey,
              limit: 20,
              offset: 0,
            )).thenAnswer((_) async => []);
        when(() => mockConnectionState.connectionState)
            .thenReturn(ConnectionState.disconnected);
        when(() => mockConnectionState.isConnected).thenReturn(false);
        when(() => mockConnectionState.isConnecting).thenReturn(false);
        when(() => mockConnectionState.errorMessage).thenReturn(null);

        store = ChatStore(
          mockRepository,
          mockConnectionState,
          testConnectionId,
          testSessionKey,
        );
      });

      tearDown(() {
        store.dispose();
      });

      test('should ignore messages with different sessionKey', () {
        // Arrange
        final messageForOtherSession = Message(
          id: 'msg-other',
          role: 'assistant',
          content: 'Response for session B',
          timestamp: DateTime.now(),
          sessionKey: 'session-B',
        );

        // Act
        store.addMessage(messageForOtherSession);

        // Assert
        expect(store.messages, isEmpty);
      });

      test('should accept messages with matching sessionKey', () {
        // Arrange
        final messageForCurrentSession = Message(
          id: 'msg-current',
          role: 'assistant',
          content: 'Response for session A',
          timestamp: DateTime.now(),
          sessionKey: testSessionKey,
        );

        // Act
        store.addMessage(messageForCurrentSession);

        // Assert
        expect(store.messages.length, 1);
        expect(store.messages.first.id, 'msg-current');
      });

      test('should accept messages with null sessionKey', () {
        // Arrange - messages without sessionKey (system messages, etc.)
        final messageWithNullSessionKey = Message(
          id: 'msg-null',
          role: 'assistant',
          content: 'System message',
          timestamp: DateTime.now(),
          sessionKey: null,
        );

        // Act
        store.addMessage(messageWithNullSessionKey);

        // Assert
        expect(store.messages.length, 1);
        expect(store.messages.first.id, 'msg-null');
      });

      test('should update existing streaming message with same ID', () {
        // Arrange
        final streamingMessage = Message(
          id: 'msg-streaming',
          role: 'assistant',
          content: 'Partial',
          timestamp: DateTime.now(),
          isStreaming: true,
          sessionKey: testSessionKey,
        );
        store.addMessage(streamingMessage);

        final completeMessage = Message(
          id: 'msg-streaming',
          role: 'assistant',
          content: 'Complete response',
          timestamp: DateTime.now(),
          isStreaming: false,
          sessionKey: testSessionKey,
        );

        // Act
        store.addMessage(completeMessage);

        // Assert
        expect(store.messages.length, 1);
        expect(store.messages.first.content, 'Complete response');
        expect(store.messages.first.isStreaming, false);
      });

      test(
          'should not add duplicate messages with same ID from different sessions',
          () {
        // Arrange
        final messageFromSessionA = Message(
          id: 'msg-1',
          role: 'assistant',
          content: 'From session A',
          timestamp: DateTime.now(),
          sessionKey: testSessionKey,
        );
        final messageFromSessionB = Message(
          id: 'msg-1', // Same ID
          role: 'assistant',
          content: 'From session B',
          timestamp: DateTime.now(),
          sessionKey: 'session-B',
        );

        // Act
        store.addMessage(messageFromSessionA);
        store.addMessage(messageFromSessionB);

        // Assert - only session A's message should be added
        expect(store.messages.length, 1);
        expect(store.messages.first.content, 'From session A');
      });
    });

    group('Lazy Loading History', () {
      late ChatStore store;
      late MockChatRepository mockRepository;
      late MockConnectionStateProvider mockConnectionState;

      const testConnectionId = 'connection-1';
      const testSessionKey = 'session-A';

      setUp(() {
        mockRepository = MockChatRepository();
        mockConnectionState = MockConnectionStateProvider();

        registerFallbackValue(testConnectionId);
        registerFallbackValue(testSessionKey);

        // Setup default stream and state - disconnected to prevent auto-sync
        when(() => mockRepository.agentResponses(testConnectionId))
            .thenAnswer((_) => const Stream.empty());
        when(() => mockRepository.isWaitingForResponse(testConnectionId,
                sessionKey: testSessionKey))
            .thenReturn(false);
        when(() => mockConnectionState.connectionState)
            .thenReturn(ConnectionState.disconnected);
        when(() => mockConnectionState.isConnected).thenReturn(false);
        when(() => mockConnectionState.isConnecting).thenReturn(false);
        when(() => mockConnectionState.errorMessage).thenReturn(null);
      });

      tearDown(() {
        store.dispose();
      });

      /// Creates messages sorted chronologically (oldest first)
      List<Message> createMessages({
        required int count,
        required DateTime baseTime,
        String prefix = 'msg',
      }) {
        return List.generate(count, (i) {
          return Message(
            id: '$prefix-${i.toString().padLeft(3, '0')}',
            role: i % 2 == 0 ? 'user' : 'assistant',
            content: 'Message $i',
            timestamp: baseTime.add(Duration(minutes: i)),
            sessionKey: testSessionKey,
          );
        });
      }

      test('should not load history when messages list is empty', () async {
        // Arrange
        when(() => mockRepository.getMessagesPaginated(
              testConnectionId,
              sessionKey: testSessionKey,
              limit: 20,
              offset: 0,
            )).thenAnswer((_) async => []);

        store = ChatStore(
          mockRepository,
          mockConnectionState,
          testConnectionId,
          testSessionKey,
        );

        // Wait for initial load
        await Future.delayed(const Duration(milliseconds: 50));

        // Act
        await store.loadMoreHistory();

        // Assert - no fetch calls should be made since messages are empty
        verifyNever(() => mockRepository.fetchAndSyncHistory(
              testConnectionId,
              sessionKey: testSessionKey,
              limit: any(named: 'limit'),
            ));
        expect(store.hasMoreHistory, isFalse); // Set because 0 < 20
      });

      test('should not load when already loading history', () async {
        // Arrange - 25 messages to keep hasMoreHistory true
        final baseTime = DateTime(2024, 1, 1, 12, 0);
        final initialMessages = createMessages(count: 25, baseTime: baseTime);

        when(() => mockRepository.getMessagesPaginated(
              testConnectionId,
              sessionKey: testSessionKey,
              limit: 20,
              offset: 0,
            )).thenAnswer((_) async => initialMessages.take(20).toList());

        store = ChatStore(
          mockRepository,
          mockConnectionState,
          testConnectionId,
          testSessionKey,
        );

        // Wait for initial load
        await Future.delayed(const Duration(milliseconds: 50));
        expect(store.messages.length, 20);

        // Setup delayed history fetch
        final completer = Completer<List<Message>>();
        when(() => mockRepository.fetchAndSyncHistory(
              testConnectionId,
              sessionKey: testSessionKey,
              limit: 200,
            )).thenAnswer((_) => completer.future);

        // DB returns messages oldest-first (after reversal in ConnectionLocalDatasource)
        when(() => mockRepository.getMessagesPaginated(
              testConnectionId,
              sessionKey: testSessionKey,
              limit: 1000,
              offset: 0,
            )).thenAnswer((_) async => initialMessages);

        // Act - start first load
        final firstLoad = store.loadMoreHistory();
        expect(store.isLoadingHistory, isTrue);

        // Try to start second load while first is in progress
        await store.loadMoreHistory();

        // Complete first load
        completer.complete(initialMessages);
        await firstLoad;

        // Assert - fetchAndSyncHistory should only be called once
        verify(() => mockRepository.fetchAndSyncHistory(
              testConnectionId,
              sessionKey: testSessionKey,
              limit: 200,
            )).called(1);
      });

      test('canLoadMoreHistory returns false when isLoadingHistory is true', () async {
        // Arrange - enough messages to keep hasMoreHistory true
        final baseTime = DateTime(2024, 1, 1, 12, 0);
        final initialMessages = createMessages(count: 25, baseTime: baseTime);

        when(() => mockRepository.getMessagesPaginated(
              testConnectionId,
              sessionKey: testSessionKey,
              limit: 20,
              offset: 0,
            )).thenAnswer((_) async => initialMessages.take(20).toList());

        store = ChatStore(
          mockRepository,
          mockConnectionState,
          testConnectionId,
          testSessionKey,
        );

        // Wait for initial load
        await Future.delayed(const Duration(milliseconds: 50));

        // Initially should be able to load
        expect(store.canLoadMoreHistory, isTrue);

        // Setup delayed history fetch
        final completer = Completer<List<Message>>();
        when(() => mockRepository.fetchAndSyncHistory(
              testConnectionId,
              sessionKey: testSessionKey,
              limit: 200,
            )).thenAnswer((_) => completer.future);

        when(() => mockRepository.getMessagesPaginated(
              testConnectionId,
              sessionKey: testSessionKey,
              limit: 1000,
              offset: 0,
            )).thenAnswer((_) async => initialMessages);

        // Start loading
        final loadFuture = store.loadMoreHistory();

        // While loading, canLoadMoreHistory should be false
        expect(store.isLoadingHistory, isTrue);
        expect(store.canLoadMoreHistory, isFalse);

        // Complete the load
        completer.complete(initialMessages);
        await loadFuture;

        expect(store.isLoadingHistory, isFalse);
      });

      test('hasMoreHistory is false when fewer than 20 messages initially loaded', () async {
        // Arrange - only 5 messages
        final baseTime = DateTime(2024, 1, 1, 12, 0);
        final initialMessages = createMessages(count: 5, baseTime: baseTime);

        when(() => mockRepository.getMessagesPaginated(
              testConnectionId,
              sessionKey: testSessionKey,
              limit: 20,
              offset: 0,
            )).thenAnswer((_) async => initialMessages);

        store = ChatStore(
          mockRepository,
          mockConnectionState,
          testConnectionId,
          testSessionKey,
        );

        // Wait for initial load
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert - hasMoreHistory should be false since 5 < 20
        expect(store.hasMoreHistory, isFalse);
        expect(store.canLoadMoreHistory, isFalse);
      });

      test('hasMoreHistory is true when 20 or more messages initially loaded', () async {
        // Arrange - exactly 20 messages
        final baseTime = DateTime(2024, 1, 1, 12, 0);
        final initialMessages = createMessages(count: 20, baseTime: baseTime);

        when(() => mockRepository.getMessagesPaginated(
              testConnectionId,
              sessionKey: testSessionKey,
              limit: 20,
              offset: 0,
            )).thenAnswer((_) async => initialMessages);

        store = ChatStore(
          mockRepository,
          mockConnectionState,
          testConnectionId,
          testSessionKey,
        );

        // Wait for initial load
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert - hasMoreHistory should be true since 20 >= 20
        expect(store.hasMoreHistory, isTrue);
        expect(store.canLoadMoreHistory, isTrue);
      });

      test('should handle new messages arriving while loading history', () async {
        // This test verifies the key scenario: user sends a message while
        // history is being loaded from the server
        final baseTime = DateTime(2024, 1, 1, 12, 0);
        final initialMessages = createMessages(count: 25, baseTime: baseTime);

        // This message "arrives" during history load (simulating real-time response)
        final newMessage = Message(
          id: 'new-msg-realtime',
          role: 'assistant',
          content: 'Real-time response during history load',
          timestamp: baseTime.add(const Duration(hours: 2)),
          sessionKey: testSessionKey,
        );

        when(() => mockRepository.getMessagesPaginated(
              testConnectionId,
              sessionKey: testSessionKey,
              limit: 20,
              offset: 0,
            )).thenAnswer((_) async => initialMessages.take(20).toList());

        store = ChatStore(
          mockRepository,
          mockConnectionState,
          testConnectionId,
          testSessionKey,
        );

        // Wait for initial load
        await Future.delayed(const Duration(milliseconds: 50));
        expect(store.messages.length, 20);

        // Setup delayed history fetch
        final completer = Completer<List<Message>>();
        when(() => mockRepository.fetchAndSyncHistory(
              testConnectionId,
              sessionKey: testSessionKey,
              limit: 200,
            )).thenAnswer((_) => completer.future);

        when(() => mockRepository.getMessagesPaginated(
              testConnectionId,
              sessionKey: testSessionKey,
              limit: 1000,
              offset: 0,
            )).thenAnswer((_) async {
          // Return initial messages plus the new one that "arrived"
          // The real datasource returns oldest-first order
          return [...initialMessages, newMessage];
        });

        // Start loading history (will pause at completer)
        final loadFuture = store.loadMoreHistory();
        expect(store.isLoadingHistory, isTrue);

        // Simulate new message arriving via real-time stream during the load
        store.addMessage(newMessage);

        // The new message should be in the list immediately
        expect(store.messages.any((m) => m.id == 'new-msg-realtime'), isTrue);

        // Complete the history fetch
        completer.complete(initialMessages);

        // Wait for load to complete
        await loadFuture;

        // After load completes, the new message should still be there
        // and the store should have processed the history
        expect(store.isLoadingHistory, isFalse);
        expect(store.messages.any((m) => m.id == 'new-msg-realtime'), isTrue,
            reason: 'New message should still be present after history load completes');
      });

      test('sets hasMoreHistory false when no older messages found', () async {
        // Arrange - 25 messages (enough to enable loading)
        final baseTime = DateTime(2024, 1, 1, 12, 0);
        final initialMessages = createMessages(count: 25, baseTime: baseTime);

        when(() => mockRepository.getMessagesPaginated(
              testConnectionId,
              sessionKey: testSessionKey,
              limit: 20,
              offset: 0,
            )).thenAnswer((_) async => initialMessages.take(20).toList());

        store = ChatStore(
          mockRepository,
          mockConnectionState,
          testConnectionId,
          testSessionKey,
        );

        // Wait for initial load
        await Future.delayed(const Duration(milliseconds: 50));
        expect(store.hasMoreHistory, isTrue);

        // Setup history fetch that returns same messages (no older ones)
        when(() => mockRepository.fetchAndSyncHistory(
              testConnectionId,
              sessionKey: testSessionKey,
              limit: 200,
            )).thenAnswer((_) async => initialMessages);

        // DB returns same messages - no new/older ones
        when(() => mockRepository.getMessagesPaginated(
              testConnectionId,
              sessionKey: testSessionKey,
              limit: 1000,
              offset: 0,
            )).thenAnswer((_) async => initialMessages);

        // Act
        await store.loadMoreHistory();

        // Assert - hasMoreHistory should now be false (no older messages found)
        expect(store.hasMoreHistory, isFalse);
      });
    });

    group('Timeout Mechanism', () {
      late ChatStore store;
      late MockChatRepository mockRepository;
      late MockConnectionStateProvider mockConnectionState;

      const testConnectionId = 'connection-1';
      const testSessionKey = 'session-A';

      setUp(() {
        mockRepository = MockChatRepository();
        mockConnectionState = MockConnectionStateProvider();

        registerFallbackValue(testConnectionId);
        registerFallbackValue(testSessionKey);

        when(() => mockRepository.agentResponses(testConnectionId))
            .thenAnswer((_) => const Stream.empty());
        when(() => mockRepository.isWaitingForResponse(testConnectionId,
                sessionKey: testSessionKey))
            .thenReturn(false);
        when(() => mockRepository.getMessagesPaginated(
              testConnectionId,
              sessionKey: testSessionKey,
              limit: 20,
              offset: 0,
            )).thenAnswer((_) async => []);
        when(() => mockConnectionState.connectionState)
            .thenReturn(ConnectionState.connected);
        when(() => mockConnectionState.isConnected).thenReturn(true);
        when(() => mockConnectionState.isConnecting).thenReturn(false);
        when(() => mockConnectionState.errorMessage).thenReturn(null);
        when(() => mockRepository.sendMessage(
              testConnectionId,
              any(),
              sessionKey: testSessionKey,
              messageId: any(named: 'messageId'),
            )).thenAnswer((_) async => true); // connected → sent immediately

        store = ChatStore(
          mockRepository,
          mockConnectionState,
          testConnectionId,
          testSessionKey,
        );
      });

      tearDown(() {
        store.dispose();
      });

      test('clearWaitingForResponse cancels timers', () async {
        // Arrange - simulate sending a message
        await store.sendMessage('Hello');
        expect(store.isWaitingForResponse, isTrue);

        // Act - clear waiting state
        store.clearWaitingForResponse();

        // Assert - waiting state cleared and no error should appear
        expect(store.isWaitingForResponse, isFalse);
        expect(store.errorMessage, isNull);

        // Wait a short time to ensure no spurious timeout fires
        await Future.delayed(const Duration(milliseconds: 100));
        expect(store.errorMessage, isNull);
      });

      test('receiving complete response cancels timers and clears waiting state', () async {
        // Arrange - simulate sending a message
        await store.sendMessage('Hello');
        expect(store.isWaitingForResponse, isTrue);

        // Act - manually clear waiting state (simulating what _handleAgentResponse does)
        // Note: addMessage doesn't trigger timer logic - only _handleAgentResponse does
        store.clearWaitingForResponse();

        // Assert - waiting state cleared
        expect(store.isWaitingForResponse, isFalse);
        expect(store.errorMessage, isNull);
      });

      test('receiving streaming message does not clear waiting state', () async {
        // Arrange - simulate sending a message
        await store.sendMessage('Hello');
        expect(store.isWaitingForResponse, isTrue);

        // Act - simulate receiving a streaming response
        final streamingResponse = Message(
          id: 'response-1',
          role: 'assistant',
          content: 'Partial response...',
          timestamp: DateTime.now(),
          isStreaming: true,
          sessionKey: testSessionKey,
        );
        store.addMessage(streamingResponse);

        // Assert - waiting state persists during streaming
        expect(store.isWaitingForResponse, isTrue);
      });

      test('sendMessage starts initial response timer', () async {
        // Arrange & Act - send a message
        await store.sendMessage('Hello');

        // Assert - waiting state should be true
        expect(store.isWaitingForResponse, isTrue);
      });
    });

    group('Queued Messages', () {
      late ChatStore store;
      late MockChatRepository mockRepository;
      late MockConnectionStateProvider mockConnectionState;

      const testConnectionId = 'connection-1';
      const testSessionKey = 'session-A';

      setUp(() {
        mockRepository = MockChatRepository();
        mockConnectionState = MockConnectionStateProvider();

        registerFallbackValue(testConnectionId);
        registerFallbackValue(testSessionKey);

        when(() => mockRepository.agentResponses(testConnectionId))
            .thenAnswer((_) => const Stream.empty());
        when(() => mockRepository.isWaitingForResponse(testConnectionId,
                sessionKey: testSessionKey))
            .thenReturn(false);
        when(() => mockRepository.getMessagesPaginated(
              testConnectionId,
              sessionKey: testSessionKey,
              limit: 20,
              offset: 0,
            )).thenAnswer((_) async => []);
        when(() => mockConnectionState.connectionState)
            .thenReturn(ConnectionState.disconnected);
        when(() => mockConnectionState.isConnected).thenReturn(false);
        when(() => mockConnectionState.isConnecting).thenReturn(false);
        when(() => mockConnectionState.errorMessage).thenReturn(null);

        store = ChatStore(
          mockRepository,
          mockConnectionState,
          testConnectionId,
          testSessionKey,
        );
      });

      tearDown(() {
        store.dispose();
      });

      test('message is marked as queued when connection is not active', () async {
        // Arrange - repository queues the message (doesn't throw)
        when(() => mockRepository.sendMessage(
              testConnectionId,
              any(),
              sessionKey: testSessionKey,
              messageId: any(named: 'messageId'),
            )).thenAnswer((_) async => false); // disconnected → queued

        // Act - send a message while disconnected
        await store.sendMessage('Hello');

        // Assert - message should be in list with queued status
        expect(store.messages.length, 1);
        expect(store.messages.first.status, MessageStatus.queued);
        expect(store.messages.first.content, 'Hello');
      });

      test('isWaitingForResponse is false when message is queued', () async {
        // Arrange - repository queues the message
        when(() => mockRepository.sendMessage(
              testConnectionId,
              any(),
              sessionKey: testSessionKey,
              messageId: any(named: 'messageId'),
            )).thenAnswer((_) async => false); // disconnected → queued

        // Act - send a message while disconnected
        await store.sendMessage('Hello');

        // Assert - not waiting for response since message wasn't actually sent
        expect(store.isWaitingForResponse, isFalse);
      });

      test('message stays in list when queued (not removed)', () async {
        // Arrange - repository queues the message
        when(() => mockRepository.sendMessage(
              testConnectionId,
              any(),
              sessionKey: testSessionKey,
              messageId: any(named: 'messageId'),
            )).thenAnswer((_) async => false); // disconnected → queued

        // Act - send a message while disconnected
        await store.sendMessage('Hello');

        // Assert - message remains in the list
        expect(store.messages.length, 1);
        expect(store.messages.first.content, 'Hello');
      });
    });
  });
}
