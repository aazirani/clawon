import 'dart:async';
import 'dart:convert';

import 'package:clawon/data/datasources/openclaw_ws_datasource.dart';
import 'package:clawon/domain/entities/connection_state.dart';
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
    registerFallbackValue(<String>[]);
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
      ),
      channelFactory: (_) => channel,
    );
  }

  /// Pumps the handshake until the client has answered the challenge.
  /// Returns the sent connect frame and the still-pending connect() future
  /// so tests can reply to the request.
  Future<(Map<String, dynamic> connectJson, Future<void> future)>
      pumpConnect() async {
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
    return (
      jsonDecode(channel.sentFrames.first) as Map<String, dynamic>,
      future,
    );
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
    final (connectJson, future) = await pumpConnect();
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
    final (connectJson, future) = await pumpConnect();
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
    final (connectJson, future) = await pumpConnect();
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
    final (connectJson, future) = await pumpConnect();
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
    // Subscribe before closing: broadcast stream drops events with no
    // listener, and the failure is emitted during close handling.
    final failures = <String>[];
    final sub = datasource.stateStream.listen((change) {
      if (change.errorMessage != null) failures.add(change.errorMessage!);
    });
    channel.serverClose(1002, 'protocol mismatch');

    await expectLater(future, throwsA(anything));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(
      failures.any(
          (m) => m.contains('Update ClawOn') || m.contains('protocol')),
      isTrue,
    );
  });
}
