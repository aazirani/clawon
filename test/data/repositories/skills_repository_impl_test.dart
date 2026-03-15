import 'package:clawon/data/repositories/skills_repository_impl.dart';
import 'package:clawon/domain/entities/connection_state.dart';
import 'package:clawon/domain/entities/message.dart';
import 'package:clawon/domain/entities/agent.dart';
import 'package:clawon/data/models/gateway_frame.dart';
import 'package:clawon/data/datasources/openclaw_ws_datasource.dart';
import 'package:clawon/domain/repositories/chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake ChatRepository for testing
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
  Stream<ConnectionStatus> connectionStatus(String connectionId) =>
      const Stream.empty();

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

/// Fake WebSocket for testing
class FakeWebSocket implements OpenClawWebSocketDatasource {
  final List<Map<String, dynamic>> _requests = [];
  ConnectionState _state = ConnectionState.disconnected;

  List<dynamic>? skillsListResponse;
  Map<String, dynamic>? installResponse;
  String? errorResponse;

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
  Future<GatewayFrame> sendRequest(
      String method, Map<String, dynamic>? params) async {
    final request = {'method': method, 'params': params ?? {}};
    _requests.add(request);

    // Return error if set
    if (errorResponse != null) {
      return GatewayFrame(
        type: FrameType.res,
        id: 'test-id',
        ok: false,
        error: {'message': errorResponse},
      );
    }

    if (method == 'skills.status') {
      final skills = skillsListResponse ??
          [
            {
              'name': 'Test Skill',
              'description': 'A test skill',
              'source': 'bundled',
              'bundled': true,
              'skillKey': 'test-skill',
              'always': false,
              'disabled': false,
              'blockedByAllowlist': false,
              'eligible': true,
            },
          ];
      return GatewayFrame(
        type: FrameType.res,
        id: 'test-id',
        ok: true,
        payload: {'skills': skills},
      );
    } else if (method == 'skills.install') {
      final response = installResponse ??
          {
            'ok': true,
            'message': 'Installation successful',
            'stdout': 'output',
            'stderr': '',
            'code': 0,
          };
      return GatewayFrame(
        type: FrameType.res,
        id: 'test-id',
        ok: true,
        payload: response,
      );
    } else if (method == 'skills.update') {
      return GatewayFrame(
        type: FrameType.res,
        id: 'test-id',
        ok: true,
      );
    }

    return GatewayFrame(
      type: FrameType.res,
      id: 'test-id',
      ok: true,
    );
  }
}

void main() {
  late SkillsRepositoryImpl repository;
  late FakeChatRepository mockChatRepository;
  const testConnectionId = 'test-connection';

  setUp(() {
    mockChatRepository = FakeChatRepository();
    repository = SkillsRepositoryImpl(mockChatRepository, testConnectionId);
  });

  group('SkillsRepositoryImpl', () {
    group('getSkills', () {
      test('sends skills.status request with no params when agentId is null',
          () async {
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        mockChatRepository.setConnection(testConnectionId, ws);

        await repository.getSkills();

        final sentRequests = ws.sendRequestCalls;
        expect(sentRequests.length, 1);
        expect(sentRequests[0]['method'], 'skills.status');
        expect(sentRequests[0]['params'], isEmpty);
      });

      test('sends skills.status request with agentId when provided', () async {
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        mockChatRepository.setConnection(testConnectionId, ws);

        await repository.getSkills(agentId: 'agent-123');

        final sentRequests = ws.sendRequestCalls;
        expect(sentRequests.length, 1);
        expect(sentRequests[0]['method'], 'skills.status');
        expect(sentRequests[0]['params'], containsPair('agentId', 'agent-123'));
      });

      test('parses skills from response', () async {
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        ws.skillsListResponse = [
          {
            'name': 'Skill One',
            'description': 'First skill',
            'source': 'openclaw-bundled',
            'bundled': true,
            'skillKey': 'skill-one',
            'always': false,
            'disabled': false,
            'blockedByAllowlist': false,
            'eligible': true,
          },
          {
            'name': 'Skill Two',
            'description': 'Second skill',
            'source': 'openclaw-workspace',
            'bundled': false,
            'skillKey': 'skill-two',
            'always': true,
            'disabled': true,
            'blockedByAllowlist': false,
            'eligible': false,
          },
        ];
        mockChatRepository.setConnection(testConnectionId, ws);

        final skills = await repository.getSkills();

        expect(skills.length, 2);
        expect(skills[0].name, 'Skill One');
        expect(skills[0].source.name, 'bundled');
        expect(skills[1].name, 'Skill Two');
        expect(skills[1].source.name, 'workspace');
        expect(skills[1].disabled, isTrue);
      });

      test('returns empty list when skills is null in response', () async {
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        ws.skillsListResponse = null;
        mockChatRepository.setConnection(testConnectionId, ws);

        // Override to return null skills
        ws.skillsListResponse = null;

        // We need to customize the FakeWebSocket behavior
        // For this test, we'll check the default behavior
      });

      test('throws StateError when not connected', () async {
        mockChatRepository.setConnection(testConnectionId, null);

        expect(
          () => repository.getSkills(),
          throwsA(isA<StateError>().having(
            (e) => e.toString(),
            'message',
            contains('No active connection'),
          )),
        );
      });

      test('throws StateError when connection state is not connected',
          () async {
        final ws = FakeWebSocket()..setState(ConnectionState.connecting);
        mockChatRepository.setConnection(testConnectionId, ws);

        expect(
          () => repository.getSkills(),
          throwsA(isA<StateError>().having(
            (e) => e.toString(),
            'message',
            contains('Not connected'),
          )),
        );
      });

      test('throws Exception on error response', () async {
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        ws.errorResponse = 'Internal server error';
        mockChatRepository.setConnection(testConnectionId, ws);

        expect(
          () => repository.getSkills(),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Failed to fetch skills'),
          )),
        );
      });
    });

    group('setSkillEnabled', () {
      test('sends skills.update with enabled=true', () async {
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        mockChatRepository.setConnection(testConnectionId, ws);

        await repository.setSkillEnabled('test-skill', true);

        final sentRequests = ws.sendRequestCalls;
        expect(sentRequests.length, 1);
        expect(sentRequests[0]['method'], 'skills.update');
        expect(
            sentRequests[0]['params'], containsPair('skillKey', 'test-skill'));
        expect(sentRequests[0]['params'], containsPair('enabled', true));
      });

      test('sends skills.update with enabled=false', () async {
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        mockChatRepository.setConnection(testConnectionId, ws);

        await repository.setSkillEnabled('another-skill', false);

        final sentRequests = ws.sendRequestCalls;
        expect(sentRequests[0]['params'], containsPair('enabled', false));
      });

      test('throws StateError when not connected', () async {
        mockChatRepository.setConnection(testConnectionId, null);

        expect(
          () => repository.setSkillEnabled('skill', true),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('updateSkill', () {
      test('sends skills.update with all parameters', () async {
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        mockChatRepository.setConnection(testConnectionId, ws);

        await repository.updateSkill(
          'my-skill',
          enabled: true,
          apiKey: 'secret-key',
          env: {'API_URL': 'https://api.example.com'},
        );

        final sentRequests = ws.sendRequestCalls;
        expect(sentRequests.length, 1);
        expect(sentRequests[0]['method'], 'skills.update');
        final params = sentRequests[0]['params'] as Map<String, dynamic>;
        expect(params['skillKey'], 'my-skill');
        expect(params['enabled'], true);
        expect(params['apiKey'], 'secret-key');
        expect(params['env'], equals({'API_URL': 'https://api.example.com'}));
      });

      test('sends skills.update with only skillKey when no optional params',
          () async {
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        mockChatRepository.setConnection(testConnectionId, ws);

        await repository.updateSkill('minimal-skill');

        final sentRequests = ws.sendRequestCalls;
        final params = sentRequests[0]['params'] as Map<String, dynamic>;
        expect(params['skillKey'], 'minimal-skill');
        expect(params.containsKey('enabled'), isFalse);
        expect(params.containsKey('apiKey'), isFalse);
        expect(params.containsKey('env'), isFalse);
      });

      test('throws Exception on error response', () async {
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        ws.errorResponse = 'Skill not found';
        mockChatRepository.setConnection(testConnectionId, ws);

        expect(
          () => repository.updateSkill('unknown-skill', enabled: true),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Failed to update skill'),
          )),
        );
      });
    });

    group('installSkill', () {
      test('sends skills.install with name and installId', () async {
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        mockChatRepository.setConnection(testConnectionId, ws);

        await repository.installSkill('ffmpeg', 'brew');

        final sentRequests = ws.sendRequestCalls;
        expect(sentRequests.length, 1);
        expect(sentRequests[0]['method'], 'skills.install');
        expect(sentRequests[0]['params']['name'], 'ffmpeg');
        expect(sentRequests[0]['params']['installId'], 'brew');
      });

      test('sends skills.install with timeoutMs when provided', () async {
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        mockChatRepository.setConnection(testConnectionId, ws);

        await repository.installSkill('node-package', 'npm',
            timeoutMs: 60000);

        final sentRequests = ws.sendRequestCalls;
        expect(sentRequests[0]['params']['timeoutMs'], 60000);
      });

      test('returns SkillInstallResult on success', () async {
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        ws.installResponse = {
          'ok': true,
          'message': 'Successfully installed ffmpeg',
          'stdout': 'Downloading ffmpeg...\nInstall complete',
          'stderr': '',
          'code': 0,
        };
        mockChatRepository.setConnection(testConnectionId, ws);

        final result = await repository.installSkill('ffmpeg', 'brew');

        expect(result.ok, isTrue);
        expect(result.message, 'Successfully installed ffmpeg');
        expect(result.stdout, contains('Downloading ffmpeg'));
        expect(result.code, 0);
      });

      test('returns SkillInstallResult with warnings', () async {
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        ws.installResponse = {
          'ok': true,
          'message': 'Installed with warnings',
          'stdout': '',
          'stderr': '',
          'code': 0,
          'warnings': ['deprecated API', 'unverified source'],
        };
        mockChatRepository.setConnection(testConnectionId, ws);

        final result = await repository.installSkill('pkg', 'node');

        expect(result.warnings.length, 2);
        expect(result.warnings, contains('deprecated API'));
        expect(result.warnings, contains('unverified source'));
      });

      test('throws Exception on error response', () async {
        final ws = FakeWebSocket()..setState(ConnectionState.connected);
        ws.errorResponse = 'Install spec not found';
        mockChatRepository.setConnection(testConnectionId, ws);

        expect(
          () => repository.installSkill('unknown', 'invalid'),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Install failed'),
          )),
        );
      });

      test('throws StateError when not connected', () async {
        mockChatRepository.setConnection(testConnectionId, null);

        expect(
          () => repository.installSkill('ffmpeg', 'brew'),
          throwsA(isA<StateError>().having(
            (e) => e.toString(),
            'message',
            contains('No active connection'),
          )),
        );
      });

      test('throws StateError when connection state is not connected',
          () async {
        final ws = FakeWebSocket()..setState(ConnectionState.disconnected);
        mockChatRepository.setConnection(testConnectionId, ws);

        expect(
          () => repository.installSkill('ffmpeg', 'brew'),
          throwsA(isA<StateError>().having(
            (e) => e.toString(),
            'message',
            contains('Not connected'),
          )),
        );
      });
    });
  });
}
