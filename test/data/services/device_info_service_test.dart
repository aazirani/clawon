import 'package:clawon/data/services/device_info_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GatewayClientIds', () {
    test('contains all whitelisted client IDs', () {
      expect(GatewayClientIds.webchatUi, equals('webchat-ui'));
      expect(GatewayClientIds.controlUi, equals('openclaw-control-ui'));
      expect(GatewayClientIds.webchat, equals('webchat'));
      expect(GatewayClientIds.cli, equals('cli'));
      expect(GatewayClientIds.macos, equals('openclaw-macos'));
      expect(GatewayClientIds.ios, equals('openclaw-ios'));
      expect(GatewayClientIds.android, equals('openclaw-android'));
    });
  });

  group('GatewayClientInfo', () {
    test('toJson includes required fields: id, version, platform, mode', () {
      const clientInfo = GatewayClientInfo(
        id: GatewayClientIds.android,
        version: '1.0.0',
        platform: 'android',
      );

      final json = clientInfo.toJson();

      expect(json['id'], equals('openclaw-android'));
      expect(json['version'], equals('1.0.0'));
      expect(json['platform'], equals('android'));
      expect(json['mode'], equals('cli'));
    });

    test('version field reflects what was passed to the constructor', () {
      const clientInfo = GatewayClientInfo(
        id: GatewayClientIds.macos,
        version: '2.5.1',
        platform: 'macos',
      );

      final json = clientInfo.toJson();

      expect(json['version'], equals('2.5.1'));
    });

    test('toJson includes optional displayName when provided', () {
      const clientInfo = GatewayClientInfo(
        id: GatewayClientIds.ios,
        version: '1.0.0',
        platform: 'ios',
        displayName: "John's iPhone",
      );

      final json = clientInfo.toJson();

      expect(json['displayName'], equals("John's iPhone"));
    });

    test('toJson includes optional deviceFamily when provided', () {
      const clientInfo = GatewayClientInfo(
        id: GatewayClientIds.android,
        version: '1.0.0',
        platform: 'android',
        deviceFamily: 'Samsung',
      );

      final json = clientInfo.toJson();

      expect(json['deviceFamily'], equals('Samsung'));
    });

    test('toJson includes optional modelIdentifier when provided', () {
      const clientInfo = GatewayClientInfo(
        id: GatewayClientIds.ios,
        version: '1.0.0',
        platform: 'ios',
        modelIdentifier: 'iPhone15,2',
      );

      final json = clientInfo.toJson();

      expect(json['modelIdentifier'], equals('iPhone15,2'));
    });

    test('toJson excludes optional fields when null', () {
      const clientInfo = GatewayClientInfo(
        id: GatewayClientIds.cli,
        version: '1.0.0',
        platform: 'windows',
      );

      final json = clientInfo.toJson();

      expect(json.containsKey('displayName'), isFalse);
      expect(json.containsKey('deviceFamily'), isFalse);
      expect(json.containsKey('modelIdentifier'), isFalse);
    });

    test('toJson includes all optional fields when all are provided', () {
      const clientInfo = GatewayClientInfo(
        id: GatewayClientIds.android,
        version: '1.0.0',
        platform: 'android',
        displayName: 'Pixel 7',
        deviceFamily: 'Google',
        modelIdentifier: 'Pixel 7',
      );

      final json = clientInfo.toJson();

      expect(json['id'], equals('openclaw-android'));
      expect(json['version'], equals('1.0.0'));
      expect(json['platform'], equals('android'));
      expect(json['mode'], equals('cli'));
      expect(json['displayName'], equals('Pixel 7'));
      expect(json['deviceFamily'], equals('Google'));
      expect(json['modelIdentifier'], equals('Pixel 7'));
    });
  });

  // Note: resolveGatewayClientInfo() is platform-dependent and cannot be
  // unit-tested without mocking DeviceInfoPlugin. Test only GatewayClientInfo
  // in isolation. Integration tests would verify the platform-specific logic.
}
