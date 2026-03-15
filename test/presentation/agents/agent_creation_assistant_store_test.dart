import 'dart:async';

import 'package:clawon/domain/entities/agent.dart';
import 'package:clawon/domain/entities/message.dart';
import 'package:clawon/domain/repositories/chat_repository.dart';
import 'package:clawon/domain/repositories/session_repository.dart';
import 'package:clawon/presentation/agents/agent_creation_assistant_store.dart';
import 'package:clawon/presentation/chat/store/connection_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSessionRepository extends Mock implements SessionRepository {}

class MockChatRepository extends Mock implements ChatRepository {}

class MockConnectionStore extends Mock implements ConnectionStore {}

void main() {
  group('AgentCreationAssistantStore', () {
    late AgentCreationAssistantStore store;
    late MockSessionRepository mockSessionRepository;
    late MockChatRepository mockChatRepository;
    late MockConnectionStore mockConnectionStore;

    const testConnectionId = 'connection-1';
    const testSessionKey = 'agent:main:clawon-connection-1-1234567890';

    setUp(() {
      mockSessionRepository = MockSessionRepository();
      mockChatRepository = MockChatRepository();
      mockConnectionStore = MockConnectionStore();

      // Setup default stream for agent responses
      when(() => mockChatRepository.agentResponses(testConnectionId))
          .thenAnswer((_) => const Stream.empty());

      // Default isConnected to false to prevent null errors in MobX computed
      when(() => mockConnectionStore.isConnected).thenReturn(false);

      store = AgentCreationAssistantStore(
        mockSessionRepository,
        mockChatRepository,
        mockConnectionStore,
        testConnectionId,
      );
    });

    tearDown(() {
      store.dispose();
    });

    group('initialize()', () {
      test('should set errorMessage when not connected', () async {
        // Arrange
        when(() => mockConnectionStore.isConnected).thenReturn(false);

        // Act
        await store.initialize();

        // Assert
        expect(store.errorMessage, isNotNull);
        expect(store.errorMessage, contains('Not connected'));
        expect(store.isInitializing, false);
      });

      test('should cleanup agent-creator sessions before creating new one', () async {
        // Arrange
        when(() => mockConnectionStore.isConnected).thenReturn(true);
        when(() => mockSessionRepository.cleanupAgentCreatorSessions(testConnectionId))
            .thenAnswer((_) async {});
        when(() => mockChatRepository.fetchAgents(testConnectionId))
            .thenAnswer((_) async => []);
        when(() => mockSessionRepository.createAgentCreatorSession(testConnectionId))
            .thenAnswer((_) async => testSessionKey);

        // Act
        await store.initialize();

        // Assert
        verify(() => mockSessionRepository.cleanupAgentCreatorSessions(testConnectionId)).called(1);
      });

      test('should fetch existing agents and track their IDs', () async {
        // Arrange
        final existingAgents = [
          Agent(id: 'agent-1', name: 'Agent One'),
          Agent(id: 'agent-2', name: 'Agent Two'),
        ];
        when(() => mockConnectionStore.isConnected).thenReturn(true);
        when(() => mockSessionRepository.cleanupAgentCreatorSessions(testConnectionId))
            .thenAnswer((_) async {});
        when(() => mockChatRepository.fetchAgents(testConnectionId))
            .thenAnswer((_) async => existingAgents);
        when(() => mockSessionRepository.createAgentCreatorSession(testConnectionId))
            .thenAnswer((_) async => testSessionKey);

        // Act
        await store.initialize();

        // Assert
        verify(() => mockChatRepository.fetchAgents(testConnectionId)).called(1);
      });

      test('should create agent creator session and set sessionKey', () async {
        // Arrange
        when(() => mockConnectionStore.isConnected).thenReturn(true);
        when(() => mockSessionRepository.cleanupAgentCreatorSessions(testConnectionId))
            .thenAnswer((_) async {});
        when(() => mockChatRepository.fetchAgents(testConnectionId))
            .thenAnswer((_) async => []);
        when(() => mockSessionRepository.createAgentCreatorSession(testConnectionId))
            .thenAnswer((_) async => testSessionKey);

        // Act
        await store.initialize();

        // Assert
        expect(store.sessionKey, testSessionKey);
        expect(store.hasSession, true);
      });

      test('should set isWaitingForResponse to true after initialization', () async {
        // Arrange
        when(() => mockConnectionStore.isConnected).thenReturn(true);
        when(() => mockSessionRepository.cleanupAgentCreatorSessions(testConnectionId))
            .thenAnswer((_) async {});
        when(() => mockChatRepository.fetchAgents(testConnectionId))
            .thenAnswer((_) async => []);
        when(() => mockSessionRepository.createAgentCreatorSession(testConnectionId))
            .thenAnswer((_) async => testSessionKey);

        // Act
        await store.initialize();

        // Assert
        expect(store.isWaitingForResponse, true);
      });

      test('should set errorMessage on session creation error', () async {
        // Arrange
        when(() => mockConnectionStore.isConnected).thenReturn(true);
        when(() => mockSessionRepository.cleanupAgentCreatorSessions(testConnectionId))
            .thenAnswer((_) async {});
        when(() => mockChatRepository.fetchAgents(testConnectionId))
            .thenAnswer((_) async => []);
        when(() => mockSessionRepository.createAgentCreatorSession(testConnectionId))
            .thenThrow(Exception('Session creation failed'));

        // Act
        await store.initialize();

        // Assert
        expect(store.errorMessage, isNotNull);
        expect(store.errorMessage, contains('Session creation failed'));
      });
    });

    group('sendMessage()', () {
      setUp(() {
        when(() => mockConnectionStore.isConnected).thenReturn(true);
        when(() => mockSessionRepository.cleanupAgentCreatorSessions(testConnectionId))
            .thenAnswer((_) async {});
        when(() => mockChatRepository.fetchAgents(testConnectionId))
            .thenAnswer((_) async => []);
        when(() => mockSessionRepository.createAgentCreatorSession(testConnectionId))
            .thenAnswer((_) async => testSessionKey);
        when(() => mockChatRepository.sendMessage(
              testConnectionId,
              any(),
              sessionKey: testSessionKey,
            )).thenAnswer((_) async => true);
      });

      test('should not send empty message', () async {
        // Arrange
        when(() => mockConnectionStore.isConnected).thenReturn(true);
        await store.initialize();

        // Act
        await store.sendMessage('');

        // Assert
        expect(store.messages.isEmpty, true);
      });

      test('should not send message with only whitespace', () async {
        // Arrange
        when(() => mockConnectionStore.isConnected).thenReturn(true);
        await store.initialize();

        // Act
        await store.sendMessage('   ');

        // Assert
        expect(store.messages.isEmpty, true);
      });

      test('should add user message to messages list', () async {
        // Arrange
        await store.initialize();

        // Act
        await store.sendMessage('Hello');

        // Assert
        expect(store.messages.length, 1);
        expect(store.messages.first.role, 'user');
        expect(store.messages.first.content, 'Hello');
      });

      test('should call repository sendMessage with correct parameters', () async {
        // Arrange
        await store.initialize();

        // Act
        await store.sendMessage('Test message');

        // Assert
        verify(() => mockChatRepository.sendMessage(
              testConnectionId,
              'Test message',
              sessionKey: testSessionKey,
            )).called(1);
      });

      test('should set isWaitingForResponse to true when sending', () async {
        // Arrange
        await store.initialize();
        store.isWaitingForResponse = false;

        // Act
        await store.sendMessage('Hello');

        // Assert
        expect(store.isWaitingForResponse, true);
      });

      test('should remove message and set error on send failure', () async {
        // Arrange
        await store.initialize();
        when(() => mockChatRepository.sendMessage(
              testConnectionId,
              any(),
              sessionKey: testSessionKey,
            )).thenThrow(Exception('Send failed'));

        // Act
        await store.sendMessage('Hello');

        // Assert
        expect(store.messages.isEmpty, true);
        expect(store.errorMessage, isNotNull);
        expect(store.isWaitingForResponse, false);
      });

      test('should do nothing when sessionKey is null', () async {
        // Arrange - don't initialize, so sessionKey is null

        // Act
        await store.sendMessage('Hello');

        // Assert
        expect(store.messages.isEmpty, true);
      });
    });

    group('reset()', () {
      test('should clear all state', () async {
        // Arrange
        when(() => mockConnectionStore.isConnected).thenReturn(true);
        when(() => mockSessionRepository.cleanupAgentCreatorSessions(testConnectionId))
            .thenAnswer((_) async {});
        when(() => mockChatRepository.fetchAgents(testConnectionId))
            .thenAnswer((_) async => []);
        when(() => mockSessionRepository.createAgentCreatorSession(testConnectionId))
            .thenAnswer((_) async => testSessionKey);

        await store.initialize();
        await store.sendMessage('Hello');
        store.agentCreated = true;
        store.createdAgentName = 'Test Agent';

        // Act
        store.reset();

        // Assert
        expect(store.agentCreated, false);
        expect(store.createdAgentName, isNull);
        expect(store.messages.isEmpty, true);
        expect(store.errorMessage, isNull);
        expect(store.sessionKey, isNull);
        expect(store.isWaitingForResponse, false);
      });
    });

    group('deleteSession()', () {
      test('should call repository deleteSession', () async {
        // Arrange
        when(() => mockConnectionStore.isConnected).thenReturn(true);
        when(() => mockSessionRepository.cleanupAgentCreatorSessions(testConnectionId))
            .thenAnswer((_) async {});
        when(() => mockChatRepository.fetchAgents(testConnectionId))
            .thenAnswer((_) async => []);
        when(() => mockSessionRepository.createAgentCreatorSession(testConnectionId))
            .thenAnswer((_) async => testSessionKey);
        when(() => mockSessionRepository.deleteSession(testConnectionId, testSessionKey))
            .thenAnswer((_) async {});

        await store.initialize();

        // Act
        await store.deleteSession();

        // Assert
        verify(() => mockSessionRepository.deleteSession(testConnectionId, testSessionKey)).called(1);
      });

      test('should clear sessionKey after deletion', () async {
        // Arrange
        when(() => mockConnectionStore.isConnected).thenReturn(true);
        when(() => mockSessionRepository.cleanupAgentCreatorSessions(testConnectionId))
            .thenAnswer((_) async {});
        when(() => mockChatRepository.fetchAgents(testConnectionId))
            .thenAnswer((_) async => []);
        when(() => mockSessionRepository.createAgentCreatorSession(testConnectionId))
            .thenAnswer((_) async => testSessionKey);
        when(() => mockSessionRepository.deleteSession(testConnectionId, testSessionKey))
            .thenAnswer((_) async {});

        await store.initialize();
        expect(store.sessionKey, isNotNull);

        // Act
        await store.deleteSession();

        // Assert
        expect(store.sessionKey, isNull);
      });

      test('should do nothing when sessionKey is null', () async {
        // Arrange - don't initialize, so sessionKey is null

        // Act
        await store.deleteSession();

        // Assert - no exception, sessionKey remains null
        expect(store.sessionKey, isNull);
      });

      test('should handle deletion errors gracefully', () async {
        // Arrange
        when(() => mockConnectionStore.isConnected).thenReturn(true);
        when(() => mockSessionRepository.cleanupAgentCreatorSessions(testConnectionId))
            .thenAnswer((_) async {});
        when(() => mockChatRepository.fetchAgents(testConnectionId))
            .thenAnswer((_) async => []);
        when(() => mockSessionRepository.createAgentCreatorSession(testConnectionId))
            .thenAnswer((_) async => testSessionKey);
        when(() => mockSessionRepository.deleteSession(testConnectionId, testSessionKey))
            .thenThrow(Exception('Delete failed'));

        await store.initialize();

        // Act & Assert - should not throw
        await expectLater(store.deleteSession(), completes);
        expect(store.sessionKey, isNull);
      });
    });

    group('Agent detection', () {
      // Note: Agent detection is tested via the _checkForNewAgent private method
      // which is called after agent responses complete. Testing this requires
      // mocking the stream of agent responses, which is complex.
      // The implementation logic is tested via integration testing.
    });

    group('Computed properties', () {
      test('canViewAgent should be true only when agentCreated and createdAgentName are set', () {
        // Initially false
        expect(store.canViewAgent, false);

        // Set only agentCreated
        store.agentCreated = true;
        expect(store.canViewAgent, false);

        // Set both
        store.createdAgentName = 'Test Agent';
        expect(store.canViewAgent, true);

        // Reset agentCreated
        store.agentCreated = false;
        expect(store.canViewAgent, false);
      });

      test('isConnected should delegate to connection store', () {
        // The default mock returns false, so isConnected should be false
        // This test verifies the delegation works correctly
        when(() => mockConnectionStore.isConnected).thenReturn(true);
        expect(store.isConnected, true);
      });

      test('hasSession should be based on sessionKey', () {
        // Initially false
        expect(store.hasSession, false);

        // Set sessionKey
        store.sessionKey = testSessionKey;
        expect(store.hasSession, true);

        // Empty string
        store.sessionKey = '';
        expect(store.hasSession, false);
      });

      test('hasStartedConversation should be based on messages list', () {
        // Initially false
        expect(store.hasStartedConversation, false);

        // Add message
        store.messages.add(Message(
          id: '1',
          role: 'user',
          content: 'Hello',
          timestamp: DateTime.now(),
        ));
        expect(store.hasStartedConversation, true);
      });
    });
  });
}
