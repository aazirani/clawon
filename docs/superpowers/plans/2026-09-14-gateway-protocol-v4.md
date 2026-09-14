# Gateway Protocol v4 Support — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make ClawOn connect to OpenClaw gateways enforcing protocol v4 (≥ 2026.6.8) while keeping v3 gateway compatibility, with readable protocol-mismatch errors (fixes aazirani/clawon#1).

**Architecture:** The WS datasource advertises protocol range 3–4 and captures the negotiated version from `hello-ok`. A new `chat`-event handler in `ChatRepositoryImpl` implements the v4 streaming union (delta/final/aborted/error) alongside the existing v3 `agent`-event path. Protocol-mismatch errors (res error or WS close 1002) map to a human-readable message.

**Tech Stack:** Flutter/Dart, `web_socket_channel` 3.0.3 (no mock lib — hand-rolled fakes), `mocktail` 1.0.4, `uuid` 4.5.3. Test runner: `flutter test`. Codegen: `build_runner`.

**Working branch:** `feat/gateway-protocol-v4` (already created and pushed).

**Authoritative wire reference** (openclaw repo at `/Users/aminazirani/Documents/Projects/GitHub/openclaw`):
- `packages/gateway-protocol/src/version.ts` — `PROTOCOL_VERSION = 4`, `MIN_CLIENT_PROTOCOL_VERSION = 4`.
- `src/gateway/server/ws-connection/connect-admission.ts:239-252` — admission iff `client.maxProtocol >= 4 && client.minProtocol <= 4`.
- `packages/gateway-protocol/src/schema/logs-chat.ts` — `ChatEventSchema` union (status/delta/final/aborted/error), `ChatSendParamsSchema` (idempotencyKey REQUIRED), `ChatHistoryDeltaResultSchema`/`ChatHistoryResetResultSchema`.
- chat.send res = `{runId, status:"started", messageSeq?, interruptedActiveRun?}` (chat-send-handler.ts:505-512) — ClawOn already handles `status:"started"` runId registration; the legacy `status:"ok"` + `result.payloads[0].text` path simply never fires on v4.
- chat.history plain-page res = top-level `messages: [...]` (handler keeps the key ClawOn already reads); v4 items may carry roles ClawOn doesn't know (`custom`, compaction `system` entries) and put stable ids under `__openclaw.id`.
- Mismatch rejection: res error `{code:"INVALID_REQUEST", message:"protocol mismatch", details:{code:"PROTOCOL_MISMATCH", clientMinProtocol, clientMaxProtocol, expectedProtocol, ...}}` then WS close **1002**.

---

### Task 0: Baseline environment

**Files:** none (verification only)

- [ ] **Step 0.1: Fetch deps + codegen**

Run: `flutter pub get && dart run build_runner build --delete-conflicting-outputs`
Expected: exits 0 (generate MobX/Drift code).

- [ ] **Step 0.2: Baseline analyze**

Run: `flutter analyze --no-fatal-warnings --no-fatal-infos`
Expected: no NEW issues vs CI baseline (CI runs same flags). Note any pre-existing infos.

- [ ] **Step 0.3: Baseline tests**

Run: `flutter test`
Expected: all pass. If anything fails BEFORE our changes, stop and report — do not build on red.

---

### Task 1: Datasource — protocol range, negotiated protocol, mismatch errors

**Files:**
- Modify: `lib/data/datasources/openclaw_ws_datasource.dart`
- Test: `test/data/datasources/openclaw_ws_datasource_test.dart` (new)

Context: `connect()` currently sends `'minProtocol': 3, 'maxProtocol': 3` (~L173-174), treats `hello-ok` as success reading only `auth.deviceToken`, and `_handleDone` treats every non-pairing close as generic "Connection closed unexpectedly". `WebSocketChannel.connect` is used directly (~L90) — we add an injectable factory for tests.

- [ ] **Step 1.1: Write the failing test**

Create `test/data/datasources/openclaw_ws_datasource_test.dart`:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:clawon/data/datasources/openclaw_ws_datasource.dart';
import 'package:clawon/data/models/gateway_frame.dart';
import 'package:clawon/data/services/device_identity_service.dart';
import 'package:clawon/data/services/device_info_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class MockDeviceIdentityService extends Mock
    implements DeviceIdentityService {}

/// Hand-rolled WS fake: web_socket_channel 3.x ships no mock library.
/// Only members the datasource touches are implemented; noSuchMethod covers
/// the rest of the WebSocketChannel interface.
class FakeWebSocketSink implements WebSocketSink {
  final void Function(String data) _onData;
  final Future<void> Function() _onClose;
  FakeWebSocketSink(this._onData, this._onClose);

  @override
  void add(dynamic data) => _onData(data as String);

  @override
  Future close([int? code, String? reason]) => _onClose();

  @override
  Future addStream(Stream<dynamic> stream) async {
    await for (final data in stream) {
      add(data);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeWebSocketChannel implements WebSocketChannel {
  final StreamController<dynamic> _incoming =
      StreamController<dynamic>.broadcast();
  final Completer<void> _ready = Completer<void>();
  final List<String> sentFrames = [];
  int? _closeCode;
  String? _closeReason;

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => FakeWebSocketSink(
        sentFrames.add,
        () async => _incoming.close(),
      );

  @override
  Future get ready => _ready.future;

  @override
  int? get closeCode => _closeCode;

  @override
  String? get closeReason => _closeReason;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  /// Test helpers
  void serverSend(Map<String, dynamic> frame) =>
      _incoming.add(jsonEncode(frame));

  void markReady() => _ready.complete();

  void serverClose(int code, String reason) {
    _closeCode = code;
    _closeReason = reason;
    _incoming.close();
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  late MockDeviceIdentityService deviceIdentity;
  late FakeWebSocketChannel channel;
  late OpenClawWebSocketDatasource datasource;

  OpenClawWebSocketDatasource buildDatasource() {
    channel = FakeWebSocketChannel();
    channel.markReady();
    return OpenClawWebSocketDatasource(
      deviceIdentity,
      GatewayClientInfo(
        id: 'openclaw-macos',
        version: '1.1.0',
        platform: 'macos',
        mode: 'operator',
      ),
      channelFactory: (_) => channel,
    );
  }

  Future<Map<String, dynamic>> pumpConnect() async {
    final future = datasource.connect('conn-1', 'https://gw.example', 'token');
    // Let connect() subscribe to frameStream before the server speaks.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    channel.serverSend({
      'type': 'event',
      'event': 'connect.challenge',
      'payload': {'nonce': 'nonce-1', 'ts': 1737264000000},
    });
    while (channel.sentFrames.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    return future;
  }

  setUp(() {
    deviceIdentity = MockDeviceIdentityService();
    when(() => deviceIdentity.getDeviceToken(any()))
        .thenAnswer((_) async => null);
    when(() => deviceIdentity.buildDeviceBlock(
          nonce: any(named: 'nonce'),
          clientId: any(named: 'clientId'),
          clientMode: any(named: 'clientMode'),
          role: any(named: 'role'),
          scopes: any(named: 'scopes'),
          authToken: any(named: 'authToken'),
        )).thenAnswer((_) async => <String, dynamic>{
          'id': 'device-1',
          'publicKey': 'key',
          'signature': 'sig',
        });
    when(() => deviceIdentity.storeDeviceToken(any(), any()))
        .thenAnswer((_) async {});
  });

  test('connect advertises protocol range 3..4', () async {
    datasource = buildDatasource();
    final future = pumpConnect();
    // Respond to the connect frame with a v4 hello-ok.
    final connectJson =
        jsonDecode(channel.sentFrames.first) as Map<String, dynamic>;
    channel.serverSend({
      'type': 'res',
      'id': connectJson['id'],
      'ok': true,
      'payload': {
        'type': 'hello-ok',
        'protocol': 4,
        'auth': {'deviceToken': 'device-token-1'},
      },
    });
    await future;

    final params = connectJson['params'] as Map<String, dynamic>;
    expect(params['minProtocol'], equals(3));
    expect(params['maxProtocol'], equals(4));
  });

  test('hello-ok captures negotiated protocol and device token', () async {
    datasource = buildDatasource();
    final future = pumpConnect();
    final connectJson =
        jsonDecode(channel.sentFrames.first) as Map<String, dynamic>;
    channel.serverSend({
      'type': 'res',
      'id': connectJson['id'],
      'ok': true,
      'payload': {
        'type': 'hello-ok',
        'protocol': 4,
        'auth': {'deviceToken': 'device-token-1'},
      },
    });
    await future;

    expect(datasource.negotiatedProtocol, equals(4));
    verify(() => deviceIdentity.storeDeviceToken('conn-1', 'device-token-1'))
        .called(1);
  });

  test('v3 gateway negotiation still works (protocol 3)', () async {
    datasource = buildDatasource();
    final future = pumpConnect();
    final connectJson =
        jsonDecode(channel.sentFrames.first) as Map<String, dynamic>;
    channel.serverSend({
      'type': 'res',
      'id': connectJson['id'],
      'ok': true,
      'payload': {
        'type': 'hello-ok',
        'protocol': 3,
        'auth': <String, dynamic>{},
      },
    });
    await future;

    expect(datasource.negotiatedProtocol, equals(3));
  });

  test('PROTOCOL_MISMATCH error surfaces readable message', () async {
    datasource = buildDatasource();
    final future = pumpConnect();
    final connectJson =
        jsonDecode(channel.sentFrames.first) as Map<String, dynamic>;
    channel.serverSend({
      'type': 'res',
      'id': connectJson['id'],
      'ok': false,
      'error': {
        'code': 'INVALID_REQUEST',
        'message': 'protocol mismatch',
        'details': {
          'code': 'PROTOCOL_MISMATCH',
          'clientMinProtocol': 3,
          'clientMaxProtocol': 4,
          'expectedProtocol': 4,
        },
      },
    });

    await expectLater(future, throwsA(isA<Exception>().having(
        (e) => e.toString(), 'message', contains('Update ClawOn'))));
    expect(datasource.state, equals(ConnectionState.failed));
  });

  test('WS close 1002 before handshake surfaces readable failure', () async {
    datasource = buildDatasource();
    final future = datasource.connect('conn-1', 'https://gw.example', 'token');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    channel.serverClose(1002, 'protocol mismatch');

    await expectLater(future, throwsA(anything));
    final failures = <String>[];
    final sub = datasource.stateStream.listen(
        (change) { if (change.errorMessage != null) failures.add(change.errorMessage!); });
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(
      failures.any((m) => m.contains('Update ClawOn') || m.contains('protocol')),
      isTrue,
    );
  });
}
```

Note: `GatewayClientInfo` field names may differ — check `lib/data/services/device_info_service.dart` and adjust the constructor call (keep `id: 'openclaw-macos'` style values). Also add `import 'package:clawon/domain/entities/connection_state.dart';` if the analyzer asks for `ConnectionState`.

- [ ] **Step 1.2: Run test to verify it fails**

Run: `flutter test test/data/datasources/openclaw_ws_datasource_test.dart`
Expected: COMPILE FAIL — `channelFactory` parameter and `negotiatedProtocol` getter don't exist.

- [ ] **Step 1.3: Implement datasource changes**

In `lib/data/datasources/openclaw_ws_datasource.dart`:

3a. Add injectable factory field + constructor param:

```dart
class OpenClawWebSocketDatasource {
  final DeviceIdentityService _deviceIdentityService;
  final GatewayClientInfo _clientInfo;
  final WebSocketChannel Function(Uri uri)? _channelFactory;

  /// Protocol version negotiated with the gateway (from hello-ok).
  /// 3 = legacy gateway, 4 = current gateways. Null before handshake.
  int? negotiatedProtocol;

  WebSocketChannel? _channel;
```

Constructor (replaces the existing one):

```dart
  OpenClawWebSocketDatasource(
    this._deviceIdentityService,
    this._clientInfo, {
    WebSocketChannel Function(Uri uri)? channelFactory,
  }) : _channelFactory = channelFactory;
```

3b. In `connect()`, replace the channel creation line:

```dart
      _channel = (_channelFactory ?? WebSocketChannel.connect)(Uri.parse(wsUrl));
```

3c. In `connect()`, reset negotiated state at the top (after `_intentionalDisconnect = false;`):

```dart
    negotiatedProtocol = null;
```

3d. Replace the protocol literals in the connect frame params (~L173-174):

```dart
        'minProtocol': 3,
        'maxProtocol': 4,
```

3e. In the `hello-ok` success branch, capture the negotiated protocol (add as first line inside `if (response.ok == true) {`):

```dart
        negotiatedProtocol = response.payload?['protocol'] as int?;
```

3f. In the error branch (the final `else`), before the generic `errorMsg` extraction, add mismatch detection:

```dart
        final errorDetails = response.error?['details'] as Map<String, dynamic>?;
        final isProtocolMismatch =
            (errorDetails?['code'] as String?) == 'PROTOCOL_MISMATCH' ||
                (response.error?['message'] as String?)
                    ?.toLowerCase()
                    .contains('protocol mismatch') ==
                    true;
        if (isProtocolMismatch) {
          throw Exception(_protocolMismatchMessage(errorDetails));
        }
```

3g. In `_handleDone()`, add a 1002 branch BEFORE the generic `_updateState(ConnectionState.disconnected, ...)` call (after the pairing 1008 block):

```dart
    // Gateway rejected our protocol version (close 1002 "protocol mismatch").
    if (closeCode == 1002) {
      final error = _protocolMismatchMessage(null);
      for (final completer in _responseControllers.values) {
        completer.completeError(Exception(error));
      }
      _responseControllers.clear();
      _updateState(ConnectionState.failed, errorMessage: error);
      return;
    }
```

3h. Add the helper method to the class:

```dart
  /// Human-readable protocol mismatch error (issue #1: raw "protocol mismatch"
  /// is meaningless to users).
  String _protocolMismatchMessage(Map<String, dynamic>? details) {
    final expected = details?['expectedProtocol'];
    if (expected is int) {
      return 'Gateway requires protocol v$expected. '
          'Update ClawOn or upgrade your gateway.';
    }
    return 'Gateway requires a newer protocol. '
        'Update ClawOn or upgrade your gateway.';
  }
```

- [ ] **Step 1.4: Run test to verify it passes**

Run: `flutter test test/data/datasources/openclaw_ws_datasource_test.dart`
Expected: 5/5 PASS.

- [ ] **Step 1.5: Fix fakes broken by the new getter**

`negotiatedProtocol` is a public member; any test class `implements OpenClawWebSocketDatasource` now misses it.

Run: `rg -l "implements OpenClawWebSocketDatasource" test/`
For each hit (expect `test/data/repositories/session_repository_impl_test.dart`, `test/data/repositories/skills_repository_impl_test.dart`), add inside the class:

```dart
  @override
  int? negotiatedProtocol;
```

Run: `flutter analyze --no-fatal-warnings --no-fatal-infos && flutter test`
Expected: clean analyze, all tests pass.

- [ ] **Step 1.6: Commit**

```bash
git add lib/data/datasources/openclaw_ws_datasource.dart test/data/datasources/openclaw_ws_datasource_test.dart test/data/repositories/
git commit -m "Advertise protocol range 3-4 and capture negotiated gateway protocol"
```

---

### Task 2: Chat repository — v4 `chat` event streaming path

**Files:**
- Modify: `lib/data/repositories/chat_repository_impl.dart`
- Test: `test/data/repositories/chat_repository_impl_test.dart` (new)

Context: `_handleFrame` currently dispatches only `event == 'agent'` (v3: `payload.stream`/`payload.data.text`). v4 streams replies via `event == 'chat'` with payload `{runId, sessionKey, seq, state, ...}`. `StreamingResponseHandler.handleStreamDelta` expects FULL cumulative text (it replaces content). v4 deltas carry INCREMENTAL `deltaText` (+ optional cumulative `message` snapshot), so we accumulate per runId. `chat.send` already includes `idempotencyKey` — no change, but we pin it with a test.

- [ ] **Step 2.1: Write the failing test**

Create `test/data/repositories/chat_repository_impl_test.dart`:

```dart
import 'dart:async';

import 'package:clawon/data/datasources/connection_local_datasource.dart';
import 'package:clawon/data/datasources/openclaw_ws_datasource.dart';
import 'package:clawon/data/models/chat_message.dart';
import 'package:clawon/data/models/gateway_frame.dart';
import 'package:clawon/data/repositories/chat_repository_impl.dart';
import 'package:clawon/data/services/active_session_registry.dart';
import 'package:clawon/data/services/message_service.dart';
import 'package:clawon/data/services/streaming_response_handler.dart';
import 'package:clawon/data/services/websocket_connection_manager.dart';
import 'package:clawon/domain/entities/connection_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectionManager extends Mock implements WebSocketConnectionManager {}
class MockLocalDatasource extends Mock implements ConnectionLocalDatasource {}
class MockMessageService extends Mock implements MessageService {}
class MockDatasource extends Mock implements OpenClawWebSocketDatasource {}

FrameHandler dummyHandler(String _, GatewayFrame __) {}

void main() {
  setUpAll(() {
    registerFallbackValue(FrameHandler((_, __) {}));
    registerFallbackValue(GatewayFrame(
      type: FrameType.res, id: 'x', ok: true));
    registerFallbackValue(ChatMessage(
      id: 'x', role: MessageRole.user, content: '', timestamp: DateTime.now()));
  });

  late MockConnectionManager manager;
  late MockLocalDatasource localDatasource;
  late MockMessageService messageService;
  late ActiveSessionRegistry registry;
  late StreamingResponseHandler streamingHandler;
  late ChatRepositoryImpl repo;
  late FrameHandler handler;
  final emitted = <ChatMessage>[];

  GatewayFrame chatFrame(Map<String, dynamic> payload) => GatewayFrame(
        type: FrameType.event,
        event: 'chat',
        payload: payload,
      );

  setUp(() {
    manager = MockConnectionManager();
    localDatasource = MockLocalDatasource();
    messageService = MockMessageService();
    registry = ActiveSessionRegistry();
    streamingHandler = StreamingResponseHandler();
    emitted.clear();

    when(() => manager.setFrameHandler(captureAny()))
        .thenAnswer((inv) {
      handler = inv.positionalArguments[0] as FrameHandler;
      return null;
    });
    when(() => messageService.emitAgentResponse(any(), any()))
        .thenAnswer((inv) {
      emitted.add(inv.positionalArguments[1] as ChatMessage);
      return null;
    });
    when(() => messageService.addMessageToCache(any(), any(),
            sessionKey: any(named: 'sessionKey')))
        .thenReturn(null);
    when(() => messageService.updateMessageInCache(any(), any(),
            sessionKey: any(named: 'sessionKey')))
        .thenReturn(null);
    when(() => messageService.saveMessages(any(), sessionKey: any(named: 'sessionKey')))
        .thenAnswer((_) async {});
    when(() => messageService.setWaitingForResponse(any(), any(),
            sessionKey: any(named: 'sessionKey')))
        .thenReturn(null);
    when(() => localDatasource.updateConnectionMetadata(any(),
            lastMessageAt: any(named: 'lastMessageAt'),
            lastMessagePreview: any(named: 'lastMessagePreview')))
        .thenAnswer((_) async {});

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

      handler('conn-1', chatFrame({
        'runId': 'run-1', 'sessionKey': 'agent:a:s1', 'seq': 0,
        'state': 'delta', 'deltaText': 'Hello',
      }));
      handler('conn-1', chatFrame({
        'runId': 'run-1', 'sessionKey': 'agent:a:s1', 'seq': 1,
        'state': 'delta', 'deltaText': ' world',
      }));

      expect(emitted, isNotEmpty);
      final last = emitted.last;
      expect(last.content, equals('Hello world'));
      expect(last.isStreaming, isTrue);
      expect(last.role, equals(MessageRole.assistant));
    });

    test('replace delta resets accumulated text', () {
      registry.registerSession('conn-1', 'agent:a:s1');
      registry.registerRunId('conn-1', 'run-2', 'agent:a:s1');

      handler('conn-1', chatFrame({
        'runId': 'run-2', 'sessionKey': 'agent:a:s1', 'seq': 0,
        'state': 'delta', 'deltaText': 'old draft',
      }));
      handler('conn-1', chatFrame({
        'runId': 'run-2', 'sessionKey': 'agent:a:s1', 'seq': 1,
        'state': 'delta', 'deltaText': 'new answer', 'replace': true,
      }));

      expect(emitted.last.content, equals('new answer'));
    });

    test('cumulative message snapshot overrides accumulation', () {
      registry.registerSession('conn-1', 'agent:a:s1');
      registry.registerRunId('conn-1', 'run-3', 'agent:a:s1');

      handler('conn-1', chatFrame({
        'runId': 'run-3', 'sessionKey': 'agent:a:s1', 'seq': 0,
        'state': 'delta', 'deltaText': 'partial',
      }));
      handler('conn-1', chatFrame({
        'runId': 'run-3', 'sessionKey': 'agent:a:s1', 'seq': 1,
        'state': 'delta', 'deltaText': ' more',
        'message': {
          'role': 'assistant',
          'content': [
            {'type': 'text', 'text': 'partial more (full)'},
          ],
        },
      }));

      expect(emitted.last.content, equals('partial more (full)'));
    });

    test('final event finalizes the streaming message', () {
      registry.registerSession('conn-1', 'agent:a:s1');
      registry.registerRunId('conn-1', 'run-4', 'agent:a:s1');

      handler('conn-1', chatFrame({
        'runId': 'run-4', 'sessionKey': 'agent:a:s1', 'seq': 0,
        'state': 'delta', 'deltaText': 'answer text',
      }));
      handler('conn-1', chatFrame({
        'runId': 'run-4', 'sessionKey': 'agent:a:s1', 'seq': 1,
        'state': 'final',
        'message': {
          'role': 'assistant',
          'content': 'answer text',
        },
      }));

      expect(emitted.last.isStreaming, isFalse);
      expect(emitted.last.content, equals('answer text'));
      verify(() => messageService.setWaitingForResponse('conn-1', false,
          sessionKey: 'agent:a:s1')).called(greaterThanOrEqualTo(1));
    });

    test('error event with no streamed text emits failed message', () {
      registry.registerSession('conn-1', 'agent:a:s1');
      registry.registerRunId('conn-1', 'run-5', 'agent:a:s1');

      handler('conn-1', chatFrame({
        'runId': 'run-5', 'sessionKey': 'agent:a:s1', 'seq': 0,
        'state': 'error',
        'errorMessage': 'rate limit exceeded',
        'errorKind': 'rate_limit',
      }));

      expect(emitted, isNotEmpty);
      expect(emitted.last.content, equals('rate limit exceeded'));
      expect(emitted.last.isFailed, isTrue);
    });

    test('status events are ignored', () {
      registry.registerSession('conn-1', 'agent:a:s1');
      registry.registerRunId('conn-1', 'run-6', 'agent:a:s1');

      handler('conn-1', chatFrame({
        'runId': 'run-6', 'sessionKey': 'agent:a:s1', 'seq': 0,
        'state': 'status', 'phase': 'starting_model',
      }));

      expect(emitted, isEmpty);
    });
  });

  group('v3 agent events (regression)', () {
    test('assistant stream events still update streaming message', () {
      registry.registerSession('conn-1', 'agent:a:s1');
      registry.registerRunId('conn-1', 'run-7', 'agent:a:s1');

      handler('conn-1', GatewayFrame(
        type: FrameType.event,
        event: 'agent',
        payload: {
          'stream': 'assistant',
          'runId': 'run-7',
          'sessionKey': 'agent:a:s1',
          'data': {'text': 'legacy stream text'},
        },
      ));

      expect(emitted, isNotEmpty);
      expect(emitted.last.content, equals('legacy stream text'));
    });
  });

  group('chat.send params', () {
    test('includes idempotencyKey (required by protocol v4)', () async {
      final ws = MockDatasource();
      final capturedParams = <Map<String, dynamic>>[];
      when(() => ws.sendRequest('chat.send', captureAny()))
          .thenAnswer((inv) {
        capturedParams.add(inv.positionalArguments[1]
            as Map<String, dynamic>? ?? <String, dynamic>{});
        return Future.value(GatewayFrame(
            type: FrameType.res, id: 'res-1', ok: true));
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
```

Note: `_trackedRunIds[connectionId]` is populated in `connect()` — the event-handler tests bypass `connect()`, so the new `_emitStreamingMessage` helper must tolerate a missing entry by initializing it lazily (`_trackedRunIds.putIfAbsent(connectionId, () => {})`). Adjust mock stubs if the analyzer flags different signatures (e.g. `addMessageToCache` may take a positional `sessionKey` instead of named — match the real `MessageService` signatures in `lib/data/services/message_service.dart`).

- [ ] **Step 2.2: Run test to verify it fails**

Run: `flutter test test/data/repositories/chat_repository_impl_test.dart`
Expected: COMPILE FAIL — no `chat`-event handling exists; v4 groups fail.

- [ ] **Step 2.3: Implement the v4 chat event path**

In `lib/data/repositories/chat_repository_impl.dart`:

3a. Add a delta buffer field next to `_trackedRunIds`:

```dart
  // v4 chat deltas carry incremental text; accumulate per runId until final.
  final Map<String, String> _chatDeltaBuffers = {};
```

3b. In `_handleFrame`, add the `chat` event dispatch next to the existing `agent` dispatch:

```dart
      // Handle v4 chat delta frames - streaming assistant responses
      if (frame.type == FrameType.event && frame.event == 'chat') {
        _handleChatEvent(connectionId, frame);
      }
```

3c. Add the handler methods (after `_handleAgentEvent`):

```dart
  /// v4 streaming: gateway emits `chat` events with a state union
  /// (status | delta | final | aborted | error) instead of `agent` events.
  void _handleChatEvent(String connectionId, GatewayFrame frame) {
    final payload = frame.payload;
    if (payload == null) return;

    final state = payload['state'] as String?;
    final runId = payload['runId']?.toString();
    final eventSessionKey = payload['sessionKey'] as String?;
    if (runId == null || runId.isEmpty) return;
    if (state == 'status') return; // startup/retry status - not rendered yet

    // Ownership gating identical to agent events
    String? effectiveSessionKey = eventSessionKey;
    final sessionBelongs =
        _sessionRegistry.sessionBelongsTo(connectionId, eventSessionKey);
    final runIdBelongs = _sessionRegistry.runIdBelongsTo(connectionId, runId);
    final hasRegisteredSession =
        _sessionRegistry.getSessionKeys(connectionId).isNotEmpty;
    final noEventSessionKey =
        eventSessionKey == null || eventSessionKey.isEmpty;

    if (!sessionBelongs && !runIdBelongs) {
      if (noEventSessionKey && hasRegisteredSession) {
        effectiveSessionKey = _sessionRegistry.getSessionKeyForRunId(runId) ??
            _sessionRegistry.getLastSessionKey(connectionId);
        if (effectiveSessionKey != null) {
          _sessionRegistry.registerRunId(connectionId, runId, effectiveSessionKey);
        }
      } else {
        return;
      }
    }

    if (effectiveSessionKey != null && effectiveSessionKey.isNotEmpty) {
      _sessionRegistry.registerRunId(connectionId, runId, effectiveSessionKey);
    }

    switch (state) {
      case 'delta':
        _handleChatDelta(connectionId, effectiveSessionKey, runId, payload);
        break;
      case 'final':
        _handleChatFinal(connectionId, effectiveSessionKey, runId, payload);
        break;
      case 'aborted':
      case 'error':
        _handleChatTerminalFailure(connectionId, effectiveSessionKey, runId,
            payload,
            isError: state == 'error');
        break;
    }
  }

  void _handleChatDelta(String connectionId, String? sessionKey, String runId,
      Map<String, dynamic> payload) {
    final deltaText = payload['deltaText'] as String?;
    if (deltaText == null || deltaText.isEmpty) return;

    // Cumulative message snapshot wins when present; otherwise accumulate
    // incremental deltaText (replace=true resets the buffer).
    final text = _extractTextFromMessage(payload['message']) ??
        () {
          if (payload['replace'] == true) {
            return _chatDeltaBuffers[runId] = deltaText;
          }
          return _chatDeltaBuffers[runId] =
              (_chatDeltaBuffers[runId] ?? '') + deltaText;
        }();
    _emitStreamingMessage(connectionId, sessionKey, runId, text);
  }

  void _handleChatFinal(String connectionId, String? sessionKey, String runId,
      Map<String, dynamic> payload) {
    final finalText = _extractTextFromMessage(payload['message']);
    if (finalText != null && finalText.isNotEmpty) {
      _chatDeltaBuffers.remove(runId);
      _emitStreamingMessage(connectionId, sessionKey, runId, finalText);
    }

    _messageService.setWaitingForResponse(connectionId, false,
        sessionKey: sessionKey);
    final message =
        _streamingHandler.finalizeStream(connectionId, sessionKey, runId);
    if (message != null) {
      final messageSessionKey = message.sessionKey ?? sessionKey;
      _messageService.updateMessageInCache(connectionId, message,
          sessionKey: messageSessionKey);
      _messageService.emitAgentResponse(connectionId, message);
      _messageService.saveMessages(connectionId, sessionKey: messageSessionKey);
      _sessionRegistry.removeRunIdToSessionKey(runId);
      _localDatasource.updateConnectionMetadata(
        connectionId,
        lastMessageAt: message.timestamp,
        lastMessagePreview: message.content,
      );
      _metadataUpdateController.add(connectionId);
    }
  }

  void _handleChatTerminalFailure(String connectionId, String? sessionKey,
      String runId, Map<String, dynamic> payload,
      {required bool isError}) {
    _chatDeltaBuffers.remove(runId);
    _messageService.setWaitingForResponse(connectionId, false,
        sessionKey: sessionKey);
    final message =
        _streamingHandler.finalizeStream(connectionId, sessionKey, runId);
    if (message != null) {
      final messageSessionKey = message.sessionKey ?? sessionKey;
      _messageService.updateMessageInCache(connectionId, message,
          sessionKey: messageSessionKey);
      _messageService.emitAgentResponse(connectionId, message);
      _messageService.saveMessages(connectionId, sessionKey: messageSessionKey);
    } else if (isError) {
      // Nothing streamed - surface the gateway error so the user sees it.
      final errorMessageText = payload['errorMessage'] as String?;
      if (errorMessageText != null && errorMessageText.isNotEmpty) {
        final errorMessage = ChatMessage(
          id: runId,
          role: MessageRole.assistant,
          content: errorMessageText,
          timestamp: DateTime.now(),
          isFailed: true,
          sessionKey: sessionKey,
        );
        _messageService.addMessageToCache(connectionId, errorMessage,
            sessionKey: sessionKey);
        _messageService.emitAgentResponse(connectionId, errorMessage);
      }
    }
    _sessionRegistry.removeRunIdToSessionKey(runId);
  }

  /// Extract display text from a v4 cumulative `message` snapshot
  /// ({role, content: String | [{type:"text", text}]}), or null.
  String? _extractTextFromMessage(dynamic message) {
    if (message is! Map<String, dynamic>) return null;
    final content = message['content'];
    if (content is String && content.isNotEmpty) return content;
    if (content is List) {
      final text = content
          .whereType<Map<String, dynamic>>()
          .where((c) => c['type'] == 'text')
          .map((c) => c['text'] as String? ?? '')
          .join('\n');
      return text.isEmpty ? null : text;
    }
    return null;
  }

  /// Create/update a streaming assistant message and emit it.
  void _emitStreamingMessage(String connectionId, String? sessionKey,
      String runId, String text) {
    final tracked = _trackedRunIds.putIfAbsent(connectionId, () => {});
    final message = _streamingHandler.handleStreamDelta(
        connectionId, sessionKey, runId, text);
    final isNewRun = !tracked.contains(runId);
    if (isNewRun) {
      _messageService.addMessageToCache(connectionId, message,
          sessionKey: sessionKey);
      tracked.add(runId);
    } else {
      _messageService.updateMessageInCache(connectionId, message,
          sessionKey: sessionKey);
    }
    _messageService.emitAgentResponse(connectionId, message);
  }
```

Note: `_emitStreamingMessage` lazy-initializes `_trackedRunIds` (test bypass of `connect()`); the existing `agent` path keeps its `_trackedRunIds[connectionId]` direct access since `connect()` guarantees the entry.

- [ ] **Step 2.4: Run test to verify it passes**

Run: `flutter test test/data/repositories/chat_repository_impl_test.dart`
Expected: 8/8 PASS.

- [ ] **Step 2.5: Full suite regression**

Run: `flutter analyze --no-fatal-warnings --no-fatal-infos && flutter test`
Expected: clean + all green.

- [ ] **Step 2.6: Commit**

```bash
git add lib/data/repositories/chat_repository_impl.dart test/data/repositories/chat_repository_impl_test.dart
git commit -m "Handle v4 chat delta events alongside legacy agent events"
```

---

### Task 3: History sync — tolerate v4 transcript roles and `__openclaw` ids

**Files:**
- Modify: `lib/data/repositories/chat_repository_impl.dart` (`fetchAndSyncHistory`, ~L149-223)
- Test: extend `test/data/repositories/chat_repository_impl_test.dart`

Context: v4 history items include roles ClawOn has no representation for (`custom` messages, compaction `system` entries) — `ChatMessage.fromGatewayHistory` THROWS `ArgumentError` on unknown roles, which would break the whole history sync. Stable message ids live under `__openclaw.id` on v4. The sync loop already skips `toolResult`/empty assistant items — we extend that skip and prefer `__openclaw.id`.

- [ ] **Step 3.1: Write the failing test**

Add to `test/data/repositories/chat_repository_impl_test.dart` (new group; requires `import 'package:clawon/di/service_locator.dart';`, `import 'package:clawon/domain/repositories/session_repository.dart';`, `import 'package:clawon/domain/entities/message.dart';` — add a `MockSessionRepository extends Mock implements SessionRepository`):

```dart
  group('fetchAndSyncHistory v4 items', () {
    test('skips unknown roles (custom/compaction) without throwing', () async {
      final sessionRepo = MockSessionRepository();
      when(() => sessionRepo.fetchSessionHistory('conn-1', 'agent:a:s1',
              limit: any(named: 'limit')))
          .thenAnswer((_) async => [
                {
                  'role': 'custom',
                  'customType': 'tool_result',
                  'content': 'tool output',
                  'timestamp': 1737264000000,
                  '__openclaw': {'seq': 3, 'transcriptPosition': 'leaf'},
                },
                {
                  'role': 'system',
                  'content': [
                    {'type': 'text', 'text': 'Compaction'},
                  ],
                  'timestamp': 1737264000001,
                  '__openclaw': {'kind': 'compaction', 'seq': 4},
                },
                {
                  'role': 'user',
                  'content': 'real message',
                  'timestamp': 1737264000002,
                  '__openclaw': {'id': 'stable-v4-id', 'seq': 5},
                },
              ]);
      getIt.registerSingleton<SessionRepository>(sessionRepo);
      addTearDown(getIt.reset);

      when(() => messageService.hasMessagesLoaded(any())).thenReturn(true);
      final saved = <ChatMessage>[];
      when(() => messageService.addMessageToCache(any(), captureAny(),
              sessionKey: any(named: 'sessionKey')))
          .thenAnswer((inv) {
        saved.add(inv.positionalArguments[1] as ChatMessage);
        return null;
      });
      when(() => messageService.getMessagesStream(any(),
              sessionKey: any(named: 'sessionKey')))
          .thenAnswer((_) => const Stream.empty());
      when(() => messageService.saveMessages(any(),
              sessionKey: any(named: 'sessionKey')))
          .thenAnswer((_) async {});

      final messages = await repo.fetchAndSyncHistory('conn-1',
          sessionKey: 'agent:a:s1');

      expect(
        messages.where((m) => m.role == MessageRole.user).map((m) => m.content),
        everyElement(isNot(contains('Compaction'))),
      );
      // The user message survived; unknown roles were skipped, not thrown.
      expect(
        messages.any((m) => m.content == 'real message'),
        isTrue,
      );
    });
  });
```

Note: `fetchAndSyncHistory` internals (dedup against local cache, streaming messages) may require extra stubs on `messageService` — read the method body first (~L149-223) and stub exactly what it calls (e.g. `getMessages`, `getStreamingMessagesForConnection`). If it returns `List<Message>` (domain type), assert on that type's fields; keep assertions focused: no throw + user message present.

- [ ] **Step 3.2: Run test to verify it fails**

Run: `flutter test test/data/repositories/chat_repository_impl_test.dart --plain-name "fetchAndSyncHistory v4 items"`
Expected: FAIL — `ArgumentError: Unknown message role: custom` thrown from `fromGatewayHistory`.

- [ ] **Step 3.3: Implement**

3a. In `fetchAndSyncHistory`, find the parse loop over history items calling `ChatMessage.fromGatewayHistory(jsonData)`. At the top of the loop body (alongside the existing toolResult/empty-assistant skips), add:

```dart
        // v4 transcripts contain roles with no local representation
        // (custom messages, compaction entries) - skip instead of throwing.
        final itemRole = jsonData['role'] as String?;
        const knownRoles = {'user', 'assistant', 'system', 'toolResult'};
        if (itemRole == null || !knownRoles.contains(itemRole)) {
          continue;
        }
```

(If the loop variable is named differently, adapt. `system` stays known — plain system messages still render.)

3b. Stable ids: in `lib/data/models/chat_message.dart` `fromGatewayHistory`, change the id resolution to prefer the v4 stable id:

```dart
    final String id;
    if (json['id'] is String) {
      id = json['id'] as String;
    } else {
      final openClawMeta = json['__openclaw'];
      final metaId =
          openClawMeta is Map<String, dynamic> ? openClawMeta['id'] : null;
      if (metaId is String && metaId.isNotEmpty) {
        id = metaId;
      } else {
        final contentKey =
            content.length > 200 ? content.substring(0, 200) : content;
        final name = '${role.name}:${timestamp.millisecondsSinceEpoch}:$contentKey';
        id = const Uuid().v5(Namespace.url.value, name);
      }
    }
```

3c. Add a model test in `test/data/models/chat_message_test.dart` (new test in the existing `fromGatewayHistory` group):

```dart
    test('prefers __openclaw.id as stable v4 message id', () {
      final json = {
        'role': 'assistant',
        'content': 'v4 text',
        'timestamp': 1737264000000,
        '__openclaw': {
          'id': 'stable-v4-id',
          'seq': 7,
          'transcriptPosition': 'leaf',
        },
      };
      final message = ChatMessage.fromGatewayHistory(json);
      expect(message.id, equals('stable-v4-id'));
    });
```

- [ ] **Step 3.4: Run tests to verify they pass**

Run: `flutter test test/data/repositories/chat_repository_impl_test.dart test/data/models/chat_message_test.dart`
Expected: PASS.

- [ ] **Step 3.5: Commit**

```bash
git add lib/data/repositories/chat_repository_impl.dart lib/data/models/chat_message.dart test/
git commit -m "Tolerate v4 history transcript roles and use stable message ids"
```

---

### Task 4: Full verification

- [ ] **Step 4.1: Analyze + full test suite**

Run: `flutter analyze --no-fatal-warnings --no-fatal-infos && flutter test`
Expected: analyze clean, 100% pass.

- [ ] **Step 4.2: Review diff**

Run: `git diff main --stat && git diff main`
Expected: changes limited to datasource, chat repo, chat_message model, tests, (later) version files. No stray files.

---

### Task 5: Release preparation

**Files:**
- Modify: `pubspec.yaml:10` (`version: 1.1.0+11`), `CHANGELOG.md` (new 1.1.0 entry at top), `README.md` (compatibility note)

- [ ] **Step 5.1: Bump version**

In `pubspec.yaml`, replace `version: 1.0.1+10` with `version: 1.1.0+11`.

- [ ] **Step 5.2: CHANGELOG entry**

Insert at the top of `CHANGELOG.md` (match existing entry format — check the 1.0.1 entry's heading style first and mirror it):

```markdown
## 1.1.0

- **Added: OpenClaw Gateway Protocol v4 support** — ClawOn now negotiates protocol range v3–v4, fixing "protocol mismatch" errors with gateways ≥ 2026.6.8 (#1).
- Streaming replies use the v4 `chat` delta stream (incremental deltas, replacement refreshes, final/aborted/error terminal events) while keeping full v3 `agent`-event compatibility for older gateways.
- Protocol-mismatch connection failures now show a readable error ("Gateway requires protocol v4. Update ClawOn or upgrade your gateway.") instead of a raw failure.
- History sync handles v4 transcript entries (custom messages, compaction records) and uses the gateway's stable message ids for reliable deduplication.
```

- [ ] **Step 5.3: README compatibility note**

In `README.md`, add one line to the features/requirements section (find the section describing gateway support):

```markdown
- Compatible with OpenClaw Gateway Protocol v3 and v4 (gateways ≥ 2026.6.8 supported)
```

- [ ] **Step 5.4: Verify + commit**

Run: `flutter analyze --no-fatal-warnings --no-fatal-infos && flutter test`
Expected: green.

```bash
git add pubspec.yaml CHANGELOG.md README.md
git commit -m "Release v1.1.0 — Gateway Protocol v4 support"
git push
```

- [ ] **Step 5.5: Open PR**

Run: `gh pr create --base main --head feat/gateway-protocol-v4 --title "Gateway Protocol v4 support (fixes #1)" --body "Negotiates protocol range 3–4, adds v4 chat-delta streaming, readable protocol-mismatch errors, v4 history tolerance. Fixes #1."`
Expected: PR URL returned. **Do NOT merge or tag yet — user decides.**

- [ ] **Step 5.6: Tag release (after user merges the PR)**

Run (only after user confirms merge):
```bash
git checkout main && git pull && git tag v1.1.0 && git push origin v1.1.0
```
Expected: tag push triggers `.github/workflows/build.yml` → 6-platform builds → GitHub Release `v1.1.0` with `clawon-v1.1.0-{android.apk,macos.dmg,windows.zip,linux.tar.gz}` assets.

---

## Self-Review (completed)

- **Spec coverage:** negotiation (Task 1), streaming dual-path (Task 2), chat.send idempotencyKey (pinned by test in Task 2 — already implemented), chat.history v4 tolerance (Task 3), error UX (Task 1), tests (Tasks 1-3), release (Task 5). Non-goals respected (no message.action, no status UI, no client-ID change).
- **Placeholders:** none — every step has concrete code/commands. Two explicit "adapt if signature differs" notes are bounded by the analyzer/test gates, not open-ended.
- **Type consistency:** `_handleChatEvent`/`_handleChatDelta`/`_handleChatFinal`/`_handleChatTerminalFailure`/`_extractTextFromMessage`/`_emitStreamingMessage` names used identically across definition and tests; `negotiatedProtocol` consistent between datasource and fakes.
