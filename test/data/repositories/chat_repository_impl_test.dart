import 'package:clawon/data/datasources/connection_local_datasource.dart';
import 'package:clawon/data/datasources/openclaw_ws_datasource.dart';
import 'package:clawon/data/models/chat_message.dart';
import 'package:clawon/data/models/gateway_frame.dart';
import 'package:clawon/data/repositories/chat_repository_impl.dart';
import 'package:clawon/data/services/active_session_registry.dart';
import 'package:clawon/data/services/message_service.dart';
import 'package:clawon/data/services/streaming_response_handler.dart';
import 'package:clawon/data/services/websocket_connection_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectionManager extends Mock
    implements WebSocketConnectionManager {}

class MockLocalDatasource extends Mock implements ConnectionLocalDatasource {}

class MockMessageService extends Mock implements MessageService {}

class MockDatasource extends Mock implements OpenClawWebSocketDatasource {}

void main() {
  setUpAll(() {
    registerFallbackValue(GatewayFrame(type: FrameType.res, id: 'x', ok: true));
    registerFallbackValue(
      ChatMessage(
        id: 'x',
        role: MessageRole.user,
        content: '',
        timestamp: DateTime.now(),
      ),
    );
    registerFallbackValue(MessageStatus.sent);
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(<String, dynamic>{});
  });

  late MockConnectionManager manager;
  late MockLocalDatasource localDatasource;
  late MockMessageService messageService;
  late ActiveSessionRegistry registry;
  late StreamingResponseHandler streamingHandler;
  late ChatRepositoryImpl repo;
  late FrameHandler handler;
  final emitted = <ChatMessage>[];

  GatewayFrame chatFrame(Map<String, dynamic> payload) =>
      GatewayFrame(type: FrameType.event, event: 'chat', payload: payload);

  setUp(() {
    manager = MockConnectionManager();
    localDatasource = MockLocalDatasource();
    messageService = MockMessageService();
    registry = ActiveSessionRegistry();
    streamingHandler = StreamingResponseHandler();
    emitted.clear();

    when(() => manager.setFrameHandler(captureAny())).thenAnswer((inv) {
      handler = inv.positionalArguments[0] as FrameHandler;
    });
    when(() => messageService.emitAgentResponse(any(), any())).thenAnswer((
      inv,
    ) {
      emitted.add(inv.positionalArguments[1] as ChatMessage);
    });
    when(
      () => messageService.addMessageToCache(
        any(),
        any(),
        sessionKey: any(named: 'sessionKey'),
      ),
    ).thenReturn(null);
    when(
      () => messageService.updateMessageInCache(
        any(),
        any(),
        sessionKey: any(named: 'sessionKey'),
      ),
    ).thenReturn(null);
    when(
      () => messageService.saveMessages(
        any(),
        sessionKey: any(named: 'sessionKey'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => messageService.persistMessage(
        any(),
        any(),
        sessionKey: any(named: 'sessionKey'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => messageService.updateMessageStatus(any(), any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => messageService.setWaitingForResponse(
        any(),
        any(),
        sessionKey: any(named: 'sessionKey'),
      ),
    ).thenReturn(null);
    when(
      () => localDatasource.updateConnectionMetadata(
        any(),
        lastMessageAt: any(named: 'lastMessageAt'),
        lastMessagePreview: any(named: 'lastMessagePreview'),
      ),
    ).thenAnswer((_) async {});

    repo = ChatRepositoryImpl(
      localDatasource,
      manager,
      registry,
      streamingHandler,
      messageService,
    );
  });

  group('v4 chat events', () {
    test('incremental deltas accumulate into one streaming message', () {
      registry.registerSession('conn-1', 'agent:a:s1');
      registry.registerRunId('conn-1', 'run-1', 'agent:a:s1');

      handler(
        'conn-1',
        chatFrame({
          'runId': 'run-1',
          'sessionKey': 'agent:a:s1',
          'seq': 0,
          'state': 'delta',
          'deltaText': 'Hello',
        }),
      );
      handler(
        'conn-1',
        chatFrame({
          'runId': 'run-1',
          'sessionKey': 'agent:a:s1',
          'seq': 1,
          'state': 'delta',
          'deltaText': ' world',
        }),
      );

      expect(emitted, isNotEmpty);
      final last = emitted.last;
      expect(last.content, equals('Hello world'));
      expect(last.isStreaming, isTrue);
      expect(last.role, equals(MessageRole.assistant));
    });

    test('replace delta resets accumulated text', () {
      registry.registerSession('conn-1', 'agent:a:s1');
      registry.registerRunId('conn-1', 'run-2', 'agent:a:s1');

      handler(
        'conn-1',
        chatFrame({
          'runId': 'run-2',
          'sessionKey': 'agent:a:s1',
          'seq': 0,
          'state': 'delta',
          'deltaText': 'old draft',
        }),
      );
      handler(
        'conn-1',
        chatFrame({
          'runId': 'run-2',
          'sessionKey': 'agent:a:s1',
          'seq': 1,
          'state': 'delta',
          'deltaText': 'new answer',
          'replace': true,
        }),
      );

      expect(emitted.last.content, equals('new answer'));
    });

    test('cumulative message snapshot overrides accumulation', () {
      registry.registerSession('conn-1', 'agent:a:s1');
      registry.registerRunId('conn-1', 'run-3', 'agent:a:s1');

      handler(
        'conn-1',
        chatFrame({
          'runId': 'run-3',
          'sessionKey': 'agent:a:s1',
          'seq': 0,
          'state': 'delta',
          'deltaText': 'partial',
        }),
      );
      handler(
        'conn-1',
        chatFrame({
          'runId': 'run-3',
          'sessionKey': 'agent:a:s1',
          'seq': 1,
          'state': 'delta',
          'deltaText': ' more',
          'message': {
            'role': 'assistant',
            'content': [
              {'type': 'text', 'text': 'partial more (full)'},
            ],
          },
        }),
      );

      expect(emitted.last.content, equals('partial more (full)'));
    });

    test('final event finalizes the streaming message', () {
      registry.registerSession('conn-1', 'agent:a:s1');
      registry.registerRunId('conn-1', 'run-4', 'agent:a:s1');

      handler(
        'conn-1',
        chatFrame({
          'runId': 'run-4',
          'sessionKey': 'agent:a:s1',
          'seq': 0,
          'state': 'delta',
          'deltaText': 'answer text',
        }),
      );
      handler(
        'conn-1',
        chatFrame({
          'runId': 'run-4',
          'sessionKey': 'agent:a:s1',
          'seq': 1,
          'state': 'final',
          'message': {'role': 'assistant', 'content': 'answer text'},
        }),
      );

      expect(emitted.last.isStreaming, isFalse);
      expect(emitted.last.content, equals('answer text'));
      verify(
        () => messageService.setWaitingForResponse(
          'conn-1',
          false,
          sessionKey: 'agent:a:s1',
        ),
      ).called(greaterThanOrEqualTo(1));
    });

    test('error event with no streamed text emits failed message', () {
      registry.registerSession('conn-1', 'agent:a:s1');
      registry.registerRunId('conn-1', 'run-5', 'agent:a:s1');

      handler(
        'conn-1',
        chatFrame({
          'runId': 'run-5',
          'sessionKey': 'agent:a:s1',
          'seq': 0,
          'state': 'error',
          'errorMessage': 'rate limit exceeded',
          'errorKind': 'rate_limit',
        }),
      );

      expect(emitted, isNotEmpty);
      expect(emitted.last.content, equals('rate limit exceeded'));
      expect(emitted.last.isFailed, isTrue);
    });

    test('status events are ignored', () {
      registry.registerSession('conn-1', 'agent:a:s1');
      registry.registerRunId('conn-1', 'run-6', 'agent:a:s1');

      handler(
        'conn-1',
        chatFrame({
          'runId': 'run-6',
          'sessionKey': 'agent:a:s1',
          'seq': 0,
          'state': 'status',
          'phase': 'starting_model',
        }),
      );

      expect(emitted, isEmpty);
    });
  });

  group('v3 agent events (regression)', () {
    test('assistant stream events still update streaming message', () {
      registry.registerSession('conn-1', 'agent:a:s1');
      registry.registerRunId('conn-1', 'run-7', 'agent:a:s1');

      handler(
        'conn-1',
        GatewayFrame(
          type: FrameType.event,
          event: 'agent',
          payload: {
            'stream': 'assistant',
            'runId': 'run-7',
            'sessionKey': 'agent:a:s1',
            'data': {'text': 'legacy stream text'},
          },
        ),
      );

      expect(emitted, isNotEmpty);
      expect(emitted.last.content, equals('legacy stream text'));
    });
  });

  group('chat.send params', () {
    test('includes idempotencyKey (required by protocol v4)', () async {
      final ws = MockDatasource();
      final capturedParams = <Map<String, dynamic>>[];
      when(() => ws.sendRequest('chat.send', captureAny())).thenAnswer((inv) {
        capturedParams.add(
          inv.positionalArguments[1] as Map<String, dynamic>? ??
              <String, dynamic>{},
        );
        return Future.value(
          GatewayFrame(type: FrameType.res, id: 'res-1', ok: true),
        );
      });
      when(() => manager.isConnected(any())).thenReturn(true);
      when(() => manager.getWebSocket(any())).thenReturn(ws);

      await repo.sendMessage('conn-1', 'hi there', sessionKey: 'agent:a:s1');

      expect(capturedParams, hasLength(1));
      expect(capturedParams.first['message'], equals('hi there'));
      expect(capturedParams.first['sessionKey'], equals('agent:a:s1'));
      expect(capturedParams.first['idempotencyKey'], isA<String>());
    });
  });
}
