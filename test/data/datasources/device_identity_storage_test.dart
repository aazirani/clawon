import 'package:clawon/data/datasources/device_identity_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late DeviceIdentityStorage storage;
  late MockFlutterSecureStorage mockSecureStorage;

  setUp(() {
    mockSecureStorage = MockFlutterSecureStorage();
    storage = DeviceIdentityStorage.withStorage(mockSecureStorage);
  });

  group('DeviceIdentityStorage', () {
    test('writePrivateKey and readPrivateKey round-trip', () async {
      const key = 'dGVzdC1wcml2YXRlLWtleQ==';
      when(() => mockSecureStorage.write(
            key: 'device_private_key',
            value: key,
          )).thenAnswer((_) async {});
      when(() => mockSecureStorage.read(key: 'device_private_key'))
          .thenAnswer((_) async => key);

      await storage.writePrivateKey(key);
      final result = await storage.readPrivateKey();

      verify(() => mockSecureStorage.write(
            key: 'device_private_key',
            value: key,
          )).called(1);
      expect(result, equals(key));
    });

    test('writePublicKey and readPublicKey round-trip', () async {
      const key = 'dGVzdC1wdWJsaWMta2V5AA==';
      when(() => mockSecureStorage.write(
            key: 'device_public_key',
            value: key,
          )).thenAnswer((_) async {});
      when(() => mockSecureStorage.read(key: 'device_public_key'))
          .thenAnswer((_) async => key);

      await storage.writePublicKey(key);
      final result = await storage.readPublicKey();

      verify(() => mockSecureStorage.write(
            key: 'device_public_key',
            value: key,
          )).called(1);
      expect(result, equals(key));
    });

    test('writeDeviceId and readDeviceId round-trip', () async {
      const deviceId =
          'a3f1c2e4b5d6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';
      when(() => mockSecureStorage.write(
            key: 'device_id',
            value: deviceId,
          )).thenAnswer((_) async {});
      when(() => mockSecureStorage.read(key: 'device_id'))
          .thenAnswer((_) async => deviceId);

      await storage.writeDeviceId(deviceId);
      final result = await storage.readDeviceId();

      verify(() => mockSecureStorage.write(
            key: 'device_id',
            value: deviceId,
          )).called(1);
      expect(result, equals(deviceId));
    });

    test('writeDeviceToken and readDeviceToken round-trip (keyed by connectionId)',
        () async {
      const connectionId = 'conn-abc-123';
      const token = 'device-token-xyz';
      when(() => mockSecureStorage.write(
            key: 'device_token_conn-abc-123',
            value: token,
          )).thenAnswer((_) async {});
      when(() => mockSecureStorage.read(key: 'device_token_conn-abc-123'))
          .thenAnswer((_) async => token);

      await storage.writeDeviceToken(connectionId, token);
      final result = await storage.readDeviceToken(connectionId);

      verify(() => mockSecureStorage.write(
            key: 'device_token_conn-abc-123',
            value: token,
          )).called(1);
      expect(result, equals(token));
    });

    test('deleteDeviceToken calls delete with correct key', () async {
      const connectionId = 'conn-abc-123';
      when(() => mockSecureStorage.delete(key: 'device_token_conn-abc-123'))
          .thenAnswer((_) async {});

      await storage.deleteDeviceToken(connectionId);

      verify(() => mockSecureStorage.delete(key: 'device_token_conn-abc-123'))
          .called(1);
    });

    test('deleteAll delegates to underlying storage', () async {
      when(() => mockSecureStorage.deleteAll()).thenAnswer((_) async {});

      await storage.deleteAll();

      verify(() => mockSecureStorage.deleteAll()).called(1);
    });

    test('different connectionIds produce different storage keys', () async {
      when(() => mockSecureStorage.read(key: 'device_token_conn-1'))
          .thenAnswer((_) async => 'token-1');
      when(() => mockSecureStorage.read(key: 'device_token_conn-2'))
          .thenAnswer((_) async => 'token-2');

      final result1 = await storage.readDeviceToken('conn-1');
      final result2 = await storage.readDeviceToken('conn-2');

      expect(result1, equals('token-1'));
      expect(result2, equals('token-2'));
      expect(result1, isNot(equals(result2)));
    });
  });
}
