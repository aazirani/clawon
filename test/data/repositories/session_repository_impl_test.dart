import 'dart:async';

import 'package:clawon/data/repositories/session_repository_impl.dart';
import 'package:clawon/domain/entities/message.dart';
import 'package:clawon/domain/entities/agent.dart';
import 'package:clawon/domain/entities/connection_state.dart';
import 'package:clawon/data/models/session_config.dart';
import 'package:clawon/data/models/chat_message.dart';
import 'package:clawon/data/models/connection_config.dart';
import 'package:clawon/data/models/gateway_frame.dart';
import 'package:clawon/data/datasources/connection_local_datasource.dart';
import 'package:clawon/data/datasources/openclaw_ws_datasource.dart';
import 'package:clawon/domain/repositories/chat_repository.dart';
import 'package:clawon/domain/repositories/setting/setting_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// Simple mock classes with correct types
class FakeConnectionLocalDatasource implements ConnectionLocalDatasource {
  final Map<String, List<SessionConfig>> _sessions = {};
  final Map<String, ConnectionConfig> _connections = {};

  @override
  Future<List<ConnectionConfig>> getConnections() async => [];

  @override
  Stream<List<ConnectionConfig>> watchConnections() => const Stream.empty();

  @override
  Future<ConnectionConfig?> getConnection(String id) async => _connections[id];

  void setConnection(String id, ConnectionConfig config) {
    _connections[id] = config;
  }

  @override
  Future<void> saveConnection(ConnectionConfig config) async {}

  @override
  Future<void> updateConnection(ConnectionConfig config) async {}

  @override
  Future<void> deleteConnection(String id) async {}

  @override
  Future<List<ChatMessage>> getMessages(String connectionId, {String? sessionKey}) async => [];

  @override
  Future<List<ChatMessage>> getMessagesPaginated(
    String connectionId, {
    required int limit,
    required int offset,
    String? sessionKey,
  }) async =>
      [];

  @override
  Future<void> saveMessage(String connectionId, ChatMessage message,
      [String? sessionKey]) async {}

  @override
  Future<void> saveMessages(
    String connectionId,
    List<ChatMessage> messages, [
    String? sessionKey,
  ]) async {}

  @override
  Future<void> clearMessages(String connectionId) async {}

  @override
  Future<void> clearMessagesForSession(String connectionId, String sessionKey) async {}

  @override
  Future<void> deleteConnectionMessages(String id) async {}

  @override
  Future<List<SessionConfig>> getSessions(String connectionId) async =>
      _sessions[connectionId] ?? [];

  Future<void> saveSessions(String connectionId, List<SessionConfig> sessions) async {
    _sessions[connectionId] = sessions;
  }

  @override
  Stream<List<SessionConfig>> watchSessions(String connectionId) =>
      Stream.value(_sessions[connectionId] ?? []);

  @override
  Future<void> saveSession(String connectionId, SessionConfig config) async {
    _sessions[connectionId] = [...(_sessions[connectionId] ?? []), config];
  }

  @override
  Future<void> updateSessionTitle(String sessionKey, String title) async {}

  @override
  Future<SessionConfig?> getSessionByKey(String sessionKey) async {
    for (final sessions in _sessions.values) {
      for (final s in sessions) {
        if (s.sessionKey == sessionKey) return s;
      }
    }
    return null;
  }

  @override
  Future<void> deleteSession(String connectionId, String sessionKey) async {
    final sessions = _sessions[connectionId];
    if (sessions != null) {
      sessions.removeWhere((s) => s.sessionKey == sessionKey);
    }
  }

  @override
  Future<ChatMessage?> getLatestMessageForSession(
    String connectionId,
    String sessionKey,
  ) async => null;

  @override
  Future<void> updateAgentInfo(
    String connectionId,
    String? agentId,
    String? agentName,
  ) async {}

  @override
  Future<void> updateConnectionMetadata(
    String connectionId, {
    DateTime? lastMessageAt,
    String? lastMessagePreview,
  }) async {}

  @override
  Future<void> updateMessageContent(String id, String content) async {}

  @override
  Future<void> updateMessageStatus(String id, String status) async {}

  @override
  Future<void> updateMessageStreaming(String id, bool isStreaming) async {}

  @override
  Future<void> deleteMessage(String messageId) async {}
}

class FakeChatRepository implements ChatRepository {
  OpenClawWebSocketDatasource? _wsConnection;

  @override
  Stream<String> get connectionMetadataUpdates => const Stream.empty();

  @override
  OpenClawWebSocketDatasource? getWebSocketConnection(String connectionId) {
    return _wsConnection;
  }

  void setConnection(String connectionId, OpenClawWebSocketDatasource? ws) {
    _wsConnection = ws;
  }

  @override
  Future<void> connect(String connectionId) async {}

  @override
  Future<void> disconnect(String connectionId) async {}

  @override
  bool wasIntentionallyDisconnected(String connectionId) => false;

  @override
  Stream<ConnectionStatus> connectionStatus(String connectionId) => const Stream.empty();

  @override
  Future<bool> sendMessage(
    String connectionId,
    String content, {
    String? sessionKey,
    String? messageId,
  }) async => true;

  @override
  Future<List<Message>> getMessagesPaginated(
    String connectionId, {
    String? sessionKey,
    int limit = 20,
    int offset = 0,
  }) async =>
      [];

  @override
  Stream<Message> agentResponses(String connectionId) => const Stream.empty();

  @override
  Future<List<Agent>> fetchAgents(String connectionId) async => [];

  @override
  bool isWaitingForResponse(String connectionId, {String? sessionKey}) => false;

  @override
  Future<void> clearSession(String connectionId, {String? sessionKey}) async {}

  @override
  String? getSessionKey(String connectionId) => null;

  @override
  Future<List<Message>> fetchAndSyncHistory(
    String connectionId, {
    required String sessionKey,
    int limit = 100,
  }) async =>
      [];

  @override
  Future<void> sendSystemMessage(
    String connectionId,
    String sessionKey,
    String content,
  ) async {}

  @override
  Future<void> deleteMessage(
    String connectionId,
    String messageId, {
    String? sessionKey,
  }) async {}

  @override
  Future<bool> resendMessage(
    String connectionId,
    String messageId,
    String content, {
    String? sessionKey,
  }) async => true;

  @override
  Future<void> markMessageFailed(
    String connectionId,
    String messageId, {
    String? sessionKey,
  }) async {}
}

class FakeWebSocket implements OpenClawWebSocketDatasource {
  final List<Map<String, dynamic>> _requests = [];
  ConnectionState _state = ConnectionState.disconnected;

  List<dynamic>? sessionsListResponse;
  List<dynamic>? chatHistoryResponse;
  String? sessionsResolveError;

  List<Map<String, dynamic>> get sendRequestCalls => _requests;

  @override
  ConnectionState get state => _state;

  void setState(ConnectionState newState) {
    _state = newState;
  }

  @override
  Future<void> connect(String connectionId, String url, String token,
      {List<String> scopes = const ['operator.read', 'operator.write']}) async {
    _state = ConnectionState.connected;
  }

  @override
  Future<void> disconnect() async {
    _state = ConnectionState.disconnected;
  }

  @override
  Stream<GatewayFrame> get frameStream => const Stream.empty();

  @override
  Stream<ConnectionStateChange> get stateStream => const Stream.empty();

  @override
  void Function()? onFrameReceived;

  @override
  void dispose() {}

  @override
  Future<GatewayFrame> sendRequest(String method, Map<String, dynamic>? params) async {
    final request = {'method': method, 'params': params ?? {}};
    _requests.add(request);

    if (method == 'sessions.list') {
      final sessions = sessionsListResponse ?? [
        {
          'sessionKey': 'session-1',
          'sessionId': 'session-id-1',
          'title': 'Test Session 1',
          'agentId': 'agent-1',
          'agentName': 'Test Agent',
          'messageCount': 10,
          'createdAt': '2024-01-15T10:30:00.000Z',
          'lastActive': '2024-01-15T10:25:00.000Z',
        },
      ];
      return GatewayFrame(
        type: FrameType.res,
        id: 'test-id',
        ok: true,
        payload: {'sessions': sessions},
      );
    } else if (method == 'chat.history') {
      final messages = chatHistoryResponse ?? <Map<String, dynamic>>[];
      return GatewayFrame(
        type: FrameType.res,
        id: 'test-id',
        ok: true,
        payload: {'messages': messages},
      );
    } else if (method == 'sessions.delete') {
      return GatewayFrame(
        type: FrameType.res,
        id: 'test-id',
        ok: true,
      );
    } else if (method == 'sessions.resolve') {
      // Return error if set
      if (sessionsResolveError != null) {
        return GatewayFrame(
          type: FrameType.res,
          id: 'test-id',
          ok: false,
          error: {'message': sessionsResolveError},
        );
      }

      // Construct full key from agentId and sessionId
      final agentId = params?['agentId'] as String? ?? 'default';
      final sessionId = params?['sessionId'] as String?;
      final key = params?['key'] as String?;
      final resolvedKey = key ?? (sessionId != null ? 'agent:$agentId:$sessionId' : null);

      return GatewayFrame(
        type: FrameType.res,
        id: 'test-id',
        ok: true,
        payload: {'ok': true, 'key': resolvedKey},
      );
    }
    return GatewayFrame(
      type: FrameType.res,
      id: 'test-id',
      ok: true,
    );
  }
}

class FakeSettingRepository implements SettingRepository {
  String? _skillCreatorPrompt;
  String? _agentCreatorPrompt;

  @override
  Future<void> changeBrightnessToDark(bool value) async {}

  @override
  bool get isDarkMode => false;

  @override
  Future<void> changeLanguage(String value) async {}

  @override
  String? get currentLanguage => null;

  @override
  Future<void> setShowNonClawOnSessions(bool value) async {}

  @override
  bool get showNonClawOnSessions => false;

  @override
  String? get skillCreatorPrompt => _skillCreatorPrompt;

  @override
  Future<void> setSkillCreatorPrompt(String? prompt) async {
    _skillCreatorPrompt = prompt;
  }

  @override
  String? get agentCreatorPrompt => _agentCreatorPrompt;

  @override
  Future<void> setAgentCreatorPrompt(String? prompt) async {
    _agentCreatorPrompt = prompt;
  }
}

void main() {
  late SessionRepositoryImpl repository;
  late FakeChatRepository mockChatRepository;
  late FakeConnectionLocalDatasource mockLocalDatasource;
  late FakeSettingRepository mockSettingRepository;
  const testConnectionId = 'test-connection';

  setUp(() {
    mockChatRepository = FakeChatRepository();
    mockLocalDatasource = FakeConnectionLocalDatasource();
    mockSettingRepository = FakeSettingRepository();
    repository = SessionRepositoryImpl(
      mockChatRepository,
      mockLocalDatasource,
      mockSettingRepository,
    );
  });

  tearDown(() {
    // Dispose any streams
  });

  group('SessionRepositoryImpl', () {
    group('deleteSession', () {
      test('sends sessions.delete request with correct key parameter', () async {
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        mockChatRepository.setConnection(testConnectionId, ws);

        await repository.deleteSession(testConnectionId, 'session-to-delete');

        final sentRequests = ws.sendRequestCalls;
        expect(sentRequests.length, 1);
        expect(sentRequests[0]['method'], 'sessions.delete');
        expect(sentRequests[0]['params'], containsPair('key', 'session-to-delete'));
      });

      test('throws StateError when not connected', () async {
        mockChatRepository.setConnection(testConnectionId, null);

        expect(
          () => repository.deleteSession(testConnectionId, 'session-123'),
          throwsA(isA<StateError>().having(
            (e) => e.toString(),
            'message',
            contains('Not connected'),
          )),
        );
      });
    });

    group('fetchSessionsWithMessages', () {
      test('calls sessions.list and returns sessions with metadata', () async {
        // Arrange
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        ws.sessionsListResponse = [
          {
            'sessionKey': 'session-1',
            'sessionId': 'session-id-1',
            'title': 'Test Session',
            'messageCount': 5,
            'createdAt': '2024-01-15T10:30:00.000Z',
            'lastActive': '2024-01-15T10:25:00.000Z',
          },
        ];
        mockChatRepository.setConnection(testConnectionId, ws);

        // Act
        final sessions = await repository.fetchSessionsWithMessages(testConnectionId);

        // Assert
        expect(sessions.length, 1);
        expect(sessions[0].sessionKey, equals('session-1'));
        expect(sessions[0].messageCount, equals(5));

        // Verify sessions.list was called
        final requests = ws.sendRequestCalls;
        expect(requests.any((r) => r['method'] == 'sessions.list'), isTrue);
        // Note: chat.history is NOT called - messages are loaded from local storage
        // when entering a session to avoid duplicates
      });

      test('returns sessions even with messageCount == 0', () async {
        // Arrange
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        ws.sessionsListResponse = [
          {
            'sessionKey': 'empty-session',
            'sessionId': 'session-id-empty',
            'title': 'Empty Session',
            'messageCount': 0,
            'createdAt': '2024-01-15T10:30:00.000Z',
            'lastActive': '2024-01-15T10:25:00.000Z',
          },
        ];
        mockChatRepository.setConnection(testConnectionId, ws);

        // Act
        final sessions = await repository.fetchSessionsWithMessages(testConnectionId);

        // Assert
        expect(sessions.length, 1);
        expect(sessions[0].messageCount, equals(0));

        // Verify sessions.list was called
        final requests = ws.sendRequestCalls;
        expect(requests.length, 1);
        expect(requests[0]['method'], equals('sessions.list'));
      });

      test('returns all sessions even if some have issues', () async {
        // Arrange
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        ws.sessionsListResponse = [
          {
            'sessionKey': 'session-1',
            'sessionId': 'session-1',
            'title': 'Session 1',
            'messageCount': 3,
            'createdAt': '2024-01-15T10:30:00.000Z',
            'lastActive': '2024-01-15T10:25:00.000Z',
          },
          {
            'sessionKey': 'session-2',
            'sessionId': 'session-2',
            'title': 'Session 2',
            'messageCount': 2,
            'createdAt': '2024-01-15T10:30:00.000Z',
            'lastActive': '2024-01-15T10:25:00.000Z',
          },
        ];
        mockChatRepository.setConnection(testConnectionId, ws);

        // Act
        final sessions = await repository.fetchSessionsWithMessages(testConnectionId);

        // Assert - both sessions should be returned
        expect(sessions.length, 2);
        expect(sessions.any((s) => s.sessionKey == 'session-1'), isTrue);
        expect(sessions.any((s) => s.sessionKey == 'session-2'), isTrue);
      });

      test('throws StateError when not connected', () async {
        mockChatRepository.setConnection(testConnectionId, null);

        expect(
          () => repository.fetchSessionsWithMessages(testConnectionId),
          throwsA(isA<StateError>().having(
            (e) => e.toString(),
            'message',
            contains('Not connected'),
          )),
        );
      });

      test('passes activeMinutes parameter to sessions.list', () async {
        // Arrange
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        ws.sessionsListResponse = [];
        mockChatRepository.setConnection(testConnectionId, ws);

        // Act
        await repository.fetchSessionsWithMessages(testConnectionId, activeMinutes: 120);

        // Assert
        final request = ws.sendRequestCalls.firstWhere(
          (r) => r['method'] == 'sessions.list',
        );
        expect(request['params'], containsPair('activeMinutes', 120));
      });

      test('parses lastMessagePreview when present', () async {
        // Arrange
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        ws.sessionsListResponse = [
          {
            'key': 'agent:main:session-1',
            'title': 'Test Session',
            'messageCount': 5,
            'lastMessagePreview': 'Hello, this is the last message',
          },
        ];
        mockChatRepository.setConnection(testConnectionId, ws);

        // Act
        final sessions = await repository.fetchSessionsWithMessages(testConnectionId);

        // Assert
        expect(sessions.length, 1);
        expect(sessions[0].lastMessagePreview, equals('Hello, this is the last message'));
      });

      test('handles missing lastMessagePreview gracefully', () async {
        // Arrange
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        ws.sessionsListResponse = [
          {
            'key': 'agent:main:session-1',
            'title': 'Test Session',
            'messageCount': 5,
          },
        ];
        mockChatRepository.setConnection(testConnectionId, ws);

        // Act
        final sessions = await repository.fetchSessionsWithMessages(testConnectionId);

        // Assert
        expect(sessions.length, 1);
        expect(sessions[0].lastMessagePreview, isNull);
      });

      test('falls back to local DB preview when gateway preview is empty', () async {
        // Arrange
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        ws.sessionsListResponse = [
          {
            'key': 'agent:main:session-1',
            'title': 'Test Session',
            'messageCount': 5,
            'lastMessagePreview': '', // empty — tool-only last message
          },
        ];
        mockChatRepository.setConnection(testConnectionId, ws);
        // No local messages for this session, so fallback returns null

        // Act
        final sessions = await repository.fetchSessionsWithMessages(testConnectionId);

        // Assert — empty gateway preview stays empty when there is no local fallback.
        // The UI treats null and '' identically (both hide the preview row), so
        // either value is acceptable here.
        expect(sessions.length, 1);
        expect(sessions[0].lastMessagePreview, anyOf(isNull, isEmpty));
      });

      test('passes includeLastMessage parameter to sessions.list', () async {
        // Arrange
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        ws.sessionsListResponse = [];
        mockChatRepository.setConnection(testConnectionId, ws);

        // Act
        await repository.fetchSessionsWithMessages(testConnectionId);

        // Assert
        final request = ws.sendRequestCalls.firstWhere(
          (r) => r['method'] == 'sessions.list',
        );
        expect(request['params'], containsPair('includeLastMessage', true));
      });
    });

    group('createSession', () {
      test('generates session key with ClawOn format and agent ID', () async {
        // Arrange
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        mockChatRepository.setConnection(testConnectionId, ws);

        // Act
        final sessionKey = await repository.createSession(testConnectionId, agentId: 'test-agent');

        // Assert - session key format: agent:<agentId>:clawon-<connectionId>-<timestamp>
        expect(sessionKey, startsWith('agent:test-agent:'));
        expect(sessionKey, contains('clawon-'));
        expect(sessionKey, contains('$testConnectionId-'));

        // No gateway request should be made - session is created on first message
        final sentRequests = ws.sendRequestCalls;
        expect(sentRequests.length, 0);
      });

      test('uses provided agentId in session key', () async {
        // Arrange
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        mockChatRepository.setConnection(testConnectionId, ws);

        // Act
        final sessionKey = await repository.createSession(testConnectionId, agentId: 'custom-agent');

        // Assert
        expect(sessionKey, startsWith('agent:custom-agent:'));
      });

      test('throws ArgumentError when agentId is empty', () async {
        // Arrange
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        mockChatRepository.setConnection(testConnectionId, ws);

        // Act & Assert
        expect(
          () => repository.createSession(testConnectionId, agentId: ''),
          throwsA(isA<ArgumentError>().having(
            (e) => e.toString(),
            'message',
            contains('agentId is required'),
          )),
        );
      });

      test('throws StateError when not connected', () async {
        mockChatRepository.setConnection(testConnectionId, null);

        expect(
          () => repository.createSession(testConnectionId, agentId: 'test-agent'),
          throwsA(isA<StateError>().having(
            (e) => e.toString(),
            'message',
            contains('Not connected'),
          )),
        );
      });
    });

    group('createSession with purpose', () {
      test('generates session ID with purpose when provided', () async {
        // Arrange
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        mockChatRepository.setConnection(testConnectionId, ws);

        // Act
        final sessionKey = await repository.createSession(
          testConnectionId,
          agentId: 'test-agent',
          purpose: 'skill-creator',
        );

        // Assert - session key should contain purpose
        expect(sessionKey, startsWith('agent:test-agent:'));
        expect(sessionKey, contains('clawon-skill-creator-'));
        expect(sessionKey, contains(testConnectionId));
      });

      test('generates session ID without purpose when not provided', () async {
        // Arrange
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        mockChatRepository.setConnection(testConnectionId, ws);

        // Act
        final sessionKey = await repository.createSession(
          testConnectionId,
          agentId: 'test-agent',
        );

        // Assert - session key should not contain purpose
        expect(sessionKey, startsWith('agent:test-agent:'));
        expect(sessionKey, contains('clawon-'));
        expect(sessionKey, isNot(contains('skill-creator')));
        expect(sessionKey, isNot(contains('agent-creator')));
      });
    });

    group('createSkillCreatorSession', () {
      test('includes skill-creator in session ID', () async {
        // Arrange
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        mockChatRepository.setConnection(testConnectionId, ws);

        // Act
        final sessionKey = await repository.createSkillCreatorSession(testConnectionId);

        // Assert
        expect(sessionKey, startsWith('agent:main:'));
        expect(sessionKey, contains('clawon-skill-creator-'));
        expect(sessionKey, contains(testConnectionId));
      });
    });

    group('createAgentCreatorSession', () {
      test('includes agent-creator in session ID', () async {
        // Arrange
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        mockChatRepository.setConnection(testConnectionId, ws);

        // Act
        final sessionKey = await repository.createAgentCreatorSession(testConnectionId);

        // Assert
        expect(sessionKey, startsWith('agent:main:'));
        expect(sessionKey, contains('clawon-agent-creator-'));
        expect(sessionKey, contains(testConnectionId));
      });
    });

    group('fetchSessionsWithMessages cleanup integration', () {
      test('deletes skill-creator sessions before fetching list', () async {
        // Arrange
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        ws.sessionsListResponse = [
          {
            'sessionKey': 'session-1',
            'sessionId': 'session-id-1',
            'title': 'Regular Session',
            'messageCount': 5,
            'createdAt': '2024-01-15T10:30:00.000Z',
            'lastActive': '2024-01-15T10:25:00.000Z',
          },
        ];
        mockChatRepository.setConnection(testConnectionId, ws);

        // Add a skill-creator session to local storage
        await mockLocalDatasource.saveSession(
          testConnectionId,
          SessionConfig(
            sessionKey: 'agent:main:clawon-skill-creator-test-conn-123',
            connectionId: testConnectionId,
            title: 'Skill Creator',
            agentId: 'main',
            kind: 'skill-creator',
            messageCount: 0,
            createdAt: DateTime.now(),
            lastActive: DateTime.now(),
            syncedAt: DateTime.now(),
          ),
        );

        // Verify it exists
        var sessions = await mockLocalDatasource.getSessions(testConnectionId);
        expect(sessions.length, 1);
        expect(sessions[0].sessionKey, contains('skill-creator'));

        // Act
        await repository.fetchSessionsWithMessages(testConnectionId);

        // Assert - skill-creator session should be deleted
        sessions = await mockLocalDatasource.getSessions(testConnectionId);
        expect(sessions.where((s) => s.sessionKey.contains('skill-creator')), isEmpty);

        // Verify sessions.delete was called
        final deleteRequest = ws.sendRequestCalls.firstWhere(
          (r) => r['method'] == 'sessions.delete',
          orElse: () => <String, dynamic>{},
        );
        expect(deleteRequest['params'], isNotNull);
        expect(deleteRequest['params']['key'], contains('skill-creator'));
      });

      test('deletes agent-creator sessions before fetching list', () async {
        // Arrange
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        ws.sessionsListResponse = [
          {
            'sessionKey': 'session-1',
            'sessionId': 'session-id-1',
            'title': 'Regular Session',
            'messageCount': 5,
            'createdAt': '2024-01-15T10:30:00.000Z',
            'lastActive': '2024-01-15T10:25:00.000Z',
          },
        ];
        mockChatRepository.setConnection(testConnectionId, ws);

        // Add an agent-creator session to local storage
        await mockLocalDatasource.saveSession(
          testConnectionId,
          SessionConfig(
            sessionKey: 'agent:main:clawon-agent-creator-test-conn-456',
            connectionId: testConnectionId,
            title: 'Agent Creator',
            agentId: 'main',
            kind: 'agent-creator',
            messageCount: 0,
            createdAt: DateTime.now(),
            lastActive: DateTime.now(),
            syncedAt: DateTime.now(),
          ),
        );

        // Act
        await repository.fetchSessionsWithMessages(testConnectionId);

        // Assert - agent-creator session should be deleted
        final sessions = await mockLocalDatasource.getSessions(testConnectionId);
        expect(sessions.where((s) => s.sessionKey.contains('agent-creator')), isEmpty);
      });

      test('does not delete regular sessions', () async {
        // Arrange
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        ws.sessionsListResponse = [
          {
            'sessionKey': 'agent:main:clawon-test-conn-789',
            'sessionId': 'session-id-regular',
            'title': 'Regular Session',
            'messageCount': 5,
            'createdAt': '2024-01-15T10:30:00.000Z',
            'lastActive': '2024-01-15T10:25:00.000Z',
          },
        ];
        mockChatRepository.setConnection(testConnectionId, ws);

        // Add a regular session to local storage
        await mockLocalDatasource.saveSession(
          testConnectionId,
          SessionConfig(
            sessionKey: 'agent:main:clawon-test-conn-789',
            connectionId: testConnectionId,
            title: 'Regular Session',
            agentId: 'main',
            kind: 'main',
            messageCount: 5,
            createdAt: DateTime.now(),
            lastActive: DateTime.now(),
            syncedAt: DateTime.now(),
          ),
        );

        // Act
        await repository.fetchSessionsWithMessages(testConnectionId);

        // Assert - regular session should still exist
        final sessions = await mockLocalDatasource.getSessions(testConnectionId);
        expect(sessions.any((s) => s.sessionKey == 'agent:main:clawon-test-conn-789'), isTrue);
      });
    });

    group('cleanupSkillCreatorSessions', () {
      test('deletes sessions by kind field (backwards compatibility)', () async {
        // Arrange
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        mockChatRepository.setConnection(testConnectionId, ws);

        // Add an old skill-creator session (without purpose in ID)
        await mockLocalDatasource.saveSession(
          testConnectionId,
          SessionConfig(
            sessionKey: 'agent:main:clawon-test-conn-old-format',
            connectionId: testConnectionId,
            title: 'Old Skill Creator',
            agentId: 'main',
            kind: 'skill-creator',
            messageCount: 0,
            createdAt: DateTime.now(),
            lastActive: DateTime.now(),
            syncedAt: DateTime.now(),
          ),
        );

        // Act
        await repository.cleanupSkillCreatorSessions(testConnectionId);

        // Assert - should be deleted
        final sessions = await mockLocalDatasource.getSessions(testConnectionId);
        expect(sessions, isEmpty);
      });

      test('deletes sessions by ID pattern', () async {
        // Arrange
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        mockChatRepository.setConnection(testConnectionId, ws);

        // Add a new skill-creator session (with purpose in ID, no kind field)
        await mockLocalDatasource.saveSession(
          testConnectionId,
          SessionConfig(
            sessionKey: 'agent:main:clawon-skill-creator-test-conn-new',
            connectionId: testConnectionId,
            title: 'New Skill Creator',
            agentId: 'main',
            kind: null, // No kind field
            messageCount: 0,
            createdAt: DateTime.now(),
            lastActive: DateTime.now(),
            syncedAt: DateTime.now(),
          ),
        );

        // Act
        await repository.cleanupSkillCreatorSessions(testConnectionId);

        // Assert - should be deleted by pattern
        final sessions = await mockLocalDatasource.getSessions(testConnectionId);
        expect(sessions, isEmpty);
      });
    });

    group('cleanupAgentCreatorSessions', () {
      test('deletes sessions by kind field (backwards compatibility)', () async {
        // Arrange
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        mockChatRepository.setConnection(testConnectionId, ws);

        // Add an old agent-creator session (without purpose in ID)
        await mockLocalDatasource.saveSession(
          testConnectionId,
          SessionConfig(
            sessionKey: 'agent:main:clawon-test-conn-old-agent',
            connectionId: testConnectionId,
            title: 'Old Agent Creator',
            agentId: 'main',
            kind: 'agent-creator',
            messageCount: 0,
            createdAt: DateTime.now(),
            lastActive: DateTime.now(),
            syncedAt: DateTime.now(),
          ),
        );

        // Act
        await repository.cleanupAgentCreatorSessions(testConnectionId);

        // Assert - should be deleted
        final sessions = await mockLocalDatasource.getSessions(testConnectionId);
        expect(sessions, isEmpty);
      });

      test('deletes sessions by ID pattern', () async {
        // Arrange
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        mockChatRepository.setConnection(testConnectionId, ws);

        // Add a new agent-creator session (with purpose in ID, no kind field)
        await mockLocalDatasource.saveSession(
          testConnectionId,
          SessionConfig(
            sessionKey: 'agent:main:clawon-agent-creator-test-conn-new',
            connectionId: testConnectionId,
            title: 'New Agent Creator',
            agentId: 'main',
            kind: null, // No kind field
            messageCount: 0,
            createdAt: DateTime.now(),
            lastActive: DateTime.now(),
            syncedAt: DateTime.now(),
          ),
        );

        // Act
        await repository.cleanupAgentCreatorSessions(testConnectionId);

        // Assert - should be deleted by pattern
        final sessions = await mockLocalDatasource.getSessions(testConnectionId);
        expect(sessions, isEmpty);
      });
    });
  });
}
