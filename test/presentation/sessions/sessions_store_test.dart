import 'package:clawon/domain/entities/session.dart';
import 'package:clawon/domain/repositories/chat_repository.dart';
import 'package:clawon/domain/repositories/setting/setting_repository.dart';
import 'package:clawon/domain/repositories/session_repository.dart';
import 'package:clawon/presentation/sessions/sessions_store.dart';
import 'package:clawon/presentation/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSessionRepository extends Mock implements SessionRepository {}

class MockChatRepository extends Mock implements ChatRepository {}

class MockSettingRepository extends Mock implements SettingRepository {}

void main() {
  group('SessionsStore', () {
    late SessionsStore store;
    late MockSessionRepository mockRepository;
    late MockChatRepository mockChatRepository;
    late SettingsStore settingsStore;
    late MockSettingRepository mockSettingRepository;
    const testConnectionId = 'test-connection';

    setUp(() {
      mockRepository = MockSessionRepository();
      mockChatRepository = MockChatRepository();
      mockSettingRepository = MockSettingRepository();

      when(() => mockSettingRepository.showNonClawOnSessions).thenReturn(false);
      when(() => mockSettingRepository.setShowNonClawOnSessions(any()))
          .thenAnswer((_) async {});
      when(() => mockSettingRepository.skillCreatorPrompt).thenReturn(null);
      when(() => mockSettingRepository.agentCreatorPrompt).thenReturn(null);

      // Stub agentResponses stream with empty stream
      when(() => mockChatRepository.agentResponses(testConnectionId))
          .thenAnswer((_) => const Stream.empty());

      settingsStore = SettingsStore(mockSettingRepository);
      store = SessionsStore(mockRepository, mockChatRepository, settingsStore, testConnectionId);
    });

    group('createSession', () {
      test('succeeds when agentId is provided', () async {
        // Arrange
        const agentId = 'test-agent';
        const expectedSessionKey = 'agent:$agentId:clawon-$testConnectionId-1234567890';

        when(() => mockRepository.createSession(
          testConnectionId,
          agentId: agentId,
          label: any(named: 'label'),
          parentSessionKey: any(named: 'parentSessionKey'),
        )).thenAnswer((_) async => expectedSessionKey);

        when(() => mockRepository.fetchSessionsWithMessages(
          testConnectionId,
          messageLimit: any(named: 'messageLimit'),
          activeMinutes: any(named: 'activeMinutes'),
          kind: any(named: 'kind'),
        )).thenAnswer((_) async => []);

        // Act
        final result = await store.createSession(agentId: agentId);

        // Assert
        expect(result, equals(expectedSessionKey));
        expect(store.isCreating, isFalse);
        expect(store.errorMessage, isNull);

        verify(() => mockRepository.createSession(
          testConnectionId,
          agentId: agentId,
          label: null,
        )).called(1);
      });

      test('sets isCreating state correctly during creation', () async {
        // Arrange
        const agentId = 'test-agent';
        bool wasCreatingDuringCall = false;

        when(() => mockRepository.createSession(
          testConnectionId,
          agentId: agentId,
          label: any(named: 'label'),
          parentSessionKey: any(named: 'parentSessionKey'),
        )).thenAnswer((_) async {
          wasCreatingDuringCall = store.isCreating;
          return 'session-key';
        });

        when(() => mockRepository.fetchSessionsWithMessages(
          testConnectionId,
          messageLimit: any(named: 'messageLimit'),
          activeMinutes: any(named: 'activeMinutes'),
          kind: any(named: 'kind'),
        )).thenAnswer((_) async => []);

        // Act
        await store.createSession(agentId: agentId);

        // Assert
        expect(wasCreatingDuringCall, isTrue);
        expect(store.isCreating, isFalse);
      });

      test('handles repository errors correctly', () async {
        // Arrange
        const agentId = 'test-agent';
        final exception = Exception('Connection error');

        when(() => mockRepository.createSession(
          testConnectionId,
          agentId: agentId,
          label: any(named: 'label'),
          parentSessionKey: any(named: 'parentSessionKey'),
        )).thenThrow(exception);

        // Act
        final result = await store.createSession(agentId: agentId);

        // Assert
        expect(result, isNull);
        expect(store.errorMessage, contains('Connection error'));
        expect(store.isCreating, isFalse);
      });

      test('adds new session to list after successful creation', () async {
        // Arrange
        const agentId = 'test-agent';
        const sessionKey = 'agent:$agentId:clawon-$testConnectionId-1234567890';

        when(() => mockRepository.createSession(
          testConnectionId,
          agentId: agentId,
          label: any(named: 'label'),
          parentSessionKey: any(named: 'parentSessionKey'),
        )).thenAnswer((_) async => sessionKey);

        // Act
        final result = await store.createSession(agentId: agentId, label: 'My Chat');

        // Assert
        expect(result, sessionKey);
        expect(store.sessions.length, 1);
        expect(store.sessions[0].sessionKey, sessionKey);
        expect(store.sessions[0].title, 'My Chat');
        expect(store.sessions[0].messageCount, 0);
      });
    });

    group('fetchSessions', () {
      test('fetches sessions successfully', () async {
        // Arrange
        final sessions = [
          GatewaySession(
            sessionKey: 'session-1',
            sessionId: 'sid-1',
            title: 'Session 1',
            createdAt: DateTime.now(),
            lastActive: DateTime.now(),
            messageCount: 5,
          ),
        ];

        when(() => mockRepository.fetchSessions(testConnectionId))
            .thenAnswer((_) async => sessions);

        // Act
        await store.fetchSessions();

        // Assert
        expect(store.sessions.length, equals(1));
        expect(store.sessions[0].sessionKey, equals('session-1'));
        expect(store.isLoading, isFalse);
        expect(store.errorMessage, isNull);
      });

      test('handles fetch errors correctly', () async {
        // Arrange
        final exception = Exception('Network error');
        when(() => mockRepository.fetchSessions(testConnectionId))
            .thenThrow(exception);

        // Act
        await store.fetchSessions();

        // Assert
        expect(store.sessions.isEmpty, isTrue);
        expect(store.errorMessage, contains('Network error'));
        expect(store.isLoading, isFalse);
      });
    });

    group('filteredSessions', () {
      test('returns all sessions when showNonClawOnSessions is true', () async {
        // Arrange
        final sessions = [
          GatewaySession(
            sessionKey: 'agent:test:clawon-conn-123',
            sessionId: 'sid-1',
            title: 'ClawOn Session',
            createdAt: DateTime.now(),
            lastActive: DateTime.now(),
            messageCount: 5,
          ),
          GatewaySession(
            sessionKey: 'agent:test:other-session',
            sessionId: 'sid-2',
            title: 'Other Session',
            createdAt: DateTime.now(),
            lastActive: DateTime.now(),
            messageCount: 3,
          ),
        ];

        when(() => mockRepository.fetchSessions(testConnectionId))
            .thenAnswer((_) async => sessions);

        await settingsStore.setShowNonClawOnSessions(true);
        await store.fetchSessions();

        // Act
        final filtered = store.filteredSessions;

        // Assert
        expect(filtered.length, equals(2));
      });

      test('filters non-ClawOn sessions when showNonClawOnSessions is false', () async {
        // Arrange
        final sessions = [
          GatewaySession(
            sessionKey: 'agent:test:clawon-conn-123',
            sessionId: 'sid-1',
            title: 'ClawOn Session',
            createdAt: DateTime.now(),
            lastActive: DateTime.now(),
            messageCount: 5,
          ),
          GatewaySession(
            sessionKey: 'agent:test:other-session',
            sessionId: 'sid-2',
            title: 'Other Session',
            createdAt: DateTime.now(),
            lastActive: DateTime.now(),
            messageCount: 3,
          ),
        ];

        when(() => mockRepository.fetchSessions(testConnectionId))
            .thenAnswer((_) async => sessions);

        // showNonClawOnSessions is false by default
        await store.fetchSessions();

        // Act
        final filtered = store.filteredSessions;

        // Assert
        expect(filtered.length, equals(1));
        expect(filtered[0].sessionKey, contains('clawon'));
      });
    });

    group('deleteSession', () {
      test('deletes session successfully', () async {
        // Arrange
        final sessions = [
          GatewaySession(
            sessionKey: 'session-1',
            sessionId: 'sid-1',
            title: 'Session 1',
            createdAt: DateTime.now(),
            lastActive: DateTime.now(),
            messageCount: 5,
          ),
        ];

        when(() => mockRepository.fetchSessions(testConnectionId))
            .thenAnswer((_) async => sessions);
        when(() => mockRepository.deleteSession(testConnectionId, 'session-1'))
            .thenAnswer((_) async {});

        await store.fetchSessions();

        // Act
        await store.deleteSession('session-1');

        // Assert
        expect(store.sessions.isEmpty, isTrue);
        expect(store.isDeleting, isFalse);
        expect(store.errorMessage, isNull);
      });

      test('handles delete errors correctly', () async {
        // Arrange
        final exception = Exception('Delete failed');
        when(() => mockRepository.deleteSession(testConnectionId, 'session-1'))
            .thenThrow(exception);

        // Act
        await store.deleteSession('session-1');

        // Assert
        expect(store.errorMessage, contains('Delete failed'));
        expect(store.isDeleting, isFalse);
      });
    });

    group('hasSessions', () {
      test('returns false when no sessions', () {
        expect(store.hasSessions, isFalse);
      });

      test('returns true when sessions exist', () async {
        // Arrange
        final sessions = [
          GatewaySession(
            sessionKey: 'session-1',
            sessionId: 'sid-1',
            title: 'Session 1',
            createdAt: DateTime.now(),
            lastActive: DateTime.now(),
            messageCount: 5,
          ),
        ];

        when(() => mockRepository.fetchSessions(testConnectionId))
            .thenAnswer((_) async => sessions);

        // Act
        await store.fetchSessions();

        // Assert
        expect(store.hasSessions, isTrue);
      });
    });

    group('clearError', () {
      test('clears error message', () async {
        // Arrange
        when(() => mockRepository.fetchSessions(testConnectionId))
            .thenThrow(Exception('Error'));

        await store.fetchSessions();
        expect(store.errorMessage, isNotNull);

        // Act
        store.clearError();

        // Assert
        expect(store.errorMessage, isNull);
      });
    });
  });
}
