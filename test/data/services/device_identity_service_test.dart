import 'dart:convert';
import 'dart:typed_data';

import 'package:clawon/data/datasources/device_identity_storage.dart';
import 'package:clawon/data/services/device_identity_service.dart';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDeviceIdentityStorage extends Mock implements DeviceIdentityStorage {}

/// Generates a real Ed25519 keypair and returns the base64url-encoded private
/// key, base64url-encoded public key, and the SHA-256 device ID.
Future<({String privateKeyBase64, String publicKeyBase64, String deviceId})>
    _generateKeyMaterial() async {
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPair();
  final publicKey = await keyPair.extractPublicKey();
  final privateKeyBytes = await keyPair.extractPrivateKeyBytes();

  final publicKeyBase64 = base64Url.encode(publicKey.bytes);
  final privateKeyBase64 =
      base64Url.encode(Uint8List.fromList(privateKeyBytes));
  final deviceId = sha256.convert(publicKey.bytes).toString();

  return (
    privateKeyBase64: privateKeyBase64,
    publicKeyBase64: publicKeyBase64,
    deviceId: deviceId,
  );
}

void main() {
  late DeviceIdentityService service;
  late MockDeviceIdentityStorage mockStorage;

  setUp(() {
    mockStorage = MockDeviceIdentityStorage();
    service = DeviceIdentityService(mockStorage);
  });

  group('ensureDeviceIdentityInitialized', () {
    test('generates keys on first call when no device ID exists', () async {
      when(() => mockStorage.readDeviceId()).thenAnswer((_) async => null);
      when(() => mockStorage.writePrivateKey(any()))
          .thenAnswer((_) async => {});
      when(() => mockStorage.writePublicKey(any()))
          .thenAnswer((_) async => {});
      when(() => mockStorage.writeDeviceId(any()))
          .thenAnswer((_) async => {});

      await service.ensureDeviceIdentityInitialized();

      verify(() => mockStorage.readDeviceId()).called(1);
      verify(() => mockStorage.writePrivateKey(any())).called(1);
      verify(() => mockStorage.writePublicKey(any())).called(1);
      verify(() => mockStorage.writeDeviceId(any())).called(1);
    });

    test('does NOT regenerate keys on second call (idempotent)', () async {
      when(() => mockStorage.readDeviceId())
          .thenAnswer((_) async => 'existing-device-id');

      await service.ensureDeviceIdentityInitialized();

      verify(() => mockStorage.readDeviceId()).called(1);
      verifyNever(() => mockStorage.writePrivateKey(any()));
      verifyNever(() => mockStorage.writePublicKey(any()));
      verifyNever(() => mockStorage.writeDeviceId(any()));
    });
  });

  group('getDeviceIdentity', () {
    test('throws StateError when identity not initialized', () async {
      when(() => mockStorage.readPrivateKey()).thenAnswer((_) async => null);
      when(() => mockStorage.readPublicKey()).thenAnswer((_) async => null);
      when(() => mockStorage.readDeviceId()).thenAnswer((_) async => null);

      expect(
        () => service.getDeviceIdentity(),
        throwsA(isA<StateError>()),
      );
    });

    test('returns consistent identity (cached) after first load', () async {
      final keys = await _generateKeyMaterial();

      when(() => mockStorage.readPrivateKey())
          .thenAnswer((_) async => keys.privateKeyBase64);
      when(() => mockStorage.readPublicKey())
          .thenAnswer((_) async => keys.publicKeyBase64);
      when(() => mockStorage.readDeviceId())
          .thenAnswer((_) async => keys.deviceId);

      final identity1 = await service.getDeviceIdentity();
      final identity2 = await service.getDeviceIdentity();

      // Same object returned on second call (cache hit, no extra storage reads)
      expect(identical(identity1, identity2), isTrue);
      expect(identity1.deviceId, equals(keys.deviceId));
      expect(identity1.publicKeyBase64Url, equals(keys.publicKeyBase64));
      // Storage should only be read once despite two calls
      verify(() => mockStorage.readPrivateKey()).called(1);
      verify(() => mockStorage.readPublicKey()).called(1);
      verify(() => mockStorage.readDeviceId()).called(1);
    });
  });

  group('buildDeviceBlock', () {
    // Shared helper to set up storage mocks and call buildDeviceBlock
    Future<Map<String, dynamic>> buildBlock(
      ({String privateKeyBase64, String publicKeyBase64, String deviceId}) keys, {
      String nonce = 'test-nonce',
      String clientId = 'openclaw-android',
      String clientMode = 'cli',
      String role = 'operator',
      List<String> scopes = const ['operator.admin'],
      String authToken = 'gateway-token',
    }) async {
      when(() => mockStorage.readPrivateKey())
          .thenAnswer((_) async => keys.privateKeyBase64);
      when(() => mockStorage.readPublicKey())
          .thenAnswer((_) async => keys.publicKeyBase64);
      when(() => mockStorage.readDeviceId())
          .thenAnswer((_) async => keys.deviceId);
      return service.buildDeviceBlock(
        nonce: nonce,
        clientId: clientId,
        clientMode: clientMode,
        role: role,
        scopes: scopes,
        authToken: authToken,
      );
    }

    test('returns map with all required keys', () async {
      final keys = await _generateKeyMaterial();
      final block = await buildBlock(keys, nonce: 'test-server-nonce');

      expect(block.containsKey('id'), isTrue);
      expect(block.containsKey('publicKey'), isTrue);
      expect(block.containsKey('signature'), isTrue);
      expect(block.containsKey('signedAt'), isTrue);
      expect(block.containsKey('nonce'), isTrue);
      expect(block['nonce'], equals('test-server-nonce'));
      expect(block['id'], equals(keys.deviceId));
      expect(block['publicKey'], equals(keys.publicKeyBase64));
      expect(block['signedAt'], isA<int>());
    });

    test('signature is cryptographically valid (v2 pipe-delimited payload)', () async {
      final keys = await _generateKeyMaterial();
      const nonce = 'server-nonce-abc';
      const scopes = ['operator.admin'];
      const authToken = 'gateway-token-xyz';

      final block = await buildBlock(
        keys,
        nonce: nonce,
        scopes: scopes,
        authToken: authToken,
      );

      // Reconstruct the exact payload the gateway will verify against
      final signedAt = block['signedAt'] as int;
      final expectedPayload = [
        'v2',
        keys.deviceId,
        'openclaw-android', // clientId
        'cli',              // clientMode
        'operator',         // role
        'operator.admin',   // scopes joined
        signedAt.toString(),
        authToken,
        nonce,
      ].join('|');

      final payloadBytes = utf8.encode(expectedPayload);
      final signatureBytes = base64Url.decode(block['signature'] as String);
      final publicKeyBytes = base64Url.decode(keys.publicKeyBase64);
      final publicKey =
          SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519);

      final isValid = await Ed25519().verify(
        payloadBytes,
        signature: Signature(signatureBytes, publicKey: publicKey),
      );

      expect(isValid, isTrue);
    });

    test('different nonces produce different signatures', () async {
      final keys = await _generateKeyMaterial();

      // Need separate service instances since identity is cached after first call
      final service1 = DeviceIdentityService(mockStorage);
      final service2 = DeviceIdentityService(mockStorage);

      when(() => mockStorage.readPrivateKey())
          .thenAnswer((_) async => keys.privateKeyBase64);
      when(() => mockStorage.readPublicKey())
          .thenAnswer((_) async => keys.publicKeyBase64);
      when(() => mockStorage.readDeviceId())
          .thenAnswer((_) async => keys.deviceId);

      final block1 = await service1.buildDeviceBlock(
        nonce: 'nonce-1',
        clientId: 'openclaw-android',
        clientMode: 'cli',
        role: 'operator',
        scopes: ['operator.admin'],
        authToken: 'token',
      );
      final block2 = await service2.buildDeviceBlock(
        nonce: 'nonce-2',
        clientId: 'openclaw-android',
        clientMode: 'cli',
        role: 'operator',
        scopes: ['operator.admin'],
        authToken: 'token',
      );

      expect(block1['signature'], isNot(equals(block2['signature'])));
      expect(block1['nonce'], equals('nonce-1'));
      expect(block2['nonce'], equals('nonce-2'));
    });
  });

  group('device tokens', () {
    test('storeDeviceToken and getDeviceToken round-trip correctly', () async {
      const connectionId = 'conn-123';
      const token = 'device-token-abc';

      when(() => mockStorage.readDeviceToken(connectionId))
          .thenAnswer((_) async => token);
      when(() => mockStorage.writeDeviceToken(connectionId, token))
          .thenAnswer((_) async => {});

      await service.storeDeviceToken(connectionId, token);
      final result = await service.getDeviceToken(connectionId);

      verify(() => mockStorage.writeDeviceToken(connectionId, token))
          .called(1);
      verify(() => mockStorage.readDeviceToken(connectionId)).called(1);
      expect(result, equals(token));
    });

    test('different connectionIds return different device tokens', () async {
      const connectionId1 = 'conn-123';
      const connectionId2 = 'conn-456';
      const token1 = 'device-token-abc';
      const token2 = 'device-token-xyz';

      when(() => mockStorage.readDeviceToken(connectionId1))
          .thenAnswer((_) async => token1);
      when(() => mockStorage.readDeviceToken(connectionId2))
          .thenAnswer((_) async => token2);

      final result1 = await service.getDeviceToken(connectionId1);
      final result2 = await service.getDeviceToken(connectionId2);

      expect(result1, equals(token1));
      expect(result2, equals(token2));
      expect(result1, isNot(equals(result2)));
    });
  });
}
