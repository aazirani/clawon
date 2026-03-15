import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Gateway whitelist client IDs (from openclaw/src/gateway/protocol/client-info.ts)
/// Only these IDs are accepted by the gateway.
abstract class GatewayClientIds {
  static const String webchatUi = 'webchat-ui';
  static const String controlUi = 'openclaw-control-ui';
  static const String webchat = 'webchat';
  static const String cli = 'cli';
  static const String gatewayClient = 'gateway-client';
  static const String macos = 'openclaw-macos';
  static const String ios = 'openclaw-ios';
  static const String android = 'openclaw-android';
  static const String nodeHost = 'node-host';
  static const String test = 'test';
  static const String fingerprint = 'fingerprint';
  static const String probe = 'openclaw-probe';
}

/// Identifies the client type for the gateway whitelist.
/// Values must match the whitelist in the OpenClaw gateway configuration.
class GatewayClientInfo {
  final String id; // whitelist enum e.g. 'openclaw-android'
  final String version; // app version from pubspec.yaml (e.g. '1.0.0')
  final String platform; // 'android' | 'ios' | 'macos' | 'windows' | 'linux'
  final String? displayName;
  final String? deviceFamily;
  final String? modelIdentifier;

  const GatewayClientInfo({
    required this.id,
    required this.version,
    required this.platform,
    this.displayName,
    this.deviceFamily,
    this.modelIdentifier,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'version': version,
        'platform': platform,
        'mode': 'cli',
        if (displayName != null) 'displayName': displayName,
        if (deviceFamily != null) 'deviceFamily': deviceFamily,
        if (modelIdentifier != null) 'modelIdentifier': modelIdentifier,
      };
}

/// Resolves platform-specific client info once at startup.
/// [appVersion] should come from PackageInfo.fromPlatform().version.
/// Registered as a singleton in DI.
///
/// NOTE: Windows and Linux use 'cli' as fallback since their
/// dedicated IDs are not yet in the gateway whitelist.
Future<GatewayClientInfo> resolveGatewayClientInfo(String appVersion) async {
  final plugin = DeviceInfoPlugin();

  if (!kIsWeb && Platform.isAndroid) {
    final info = await plugin.androidInfo;
    return GatewayClientInfo(
      id: GatewayClientIds.android,
      version: appVersion,
      platform: 'android',
      displayName: info.model,
      deviceFamily: info.brand,
      modelIdentifier: info.model,
    );
  }

  if (!kIsWeb && Platform.isIOS) {
    final info = await plugin.iosInfo;
    return GatewayClientInfo(
      id: GatewayClientIds.ios,
      version: appVersion,
      platform: 'ios',
      displayName: info.name, // user-assigned name from Settings
      deviceFamily: info.model, // e.g. "iPhone"
      modelIdentifier: info.utsname.machine, // e.g. "iPhone15,2"
    );
  }

  if (!kIsWeb && Platform.isMacOS) {
    final info = await plugin.macOsInfo;
    return GatewayClientInfo(
      id: GatewayClientIds.macos,
      version: appVersion,
      platform: 'macos',
      displayName: info.computerName,
      modelIdentifier: info.model,
    );
  }

  if (!kIsWeb && Platform.isWindows) {
    final info = await plugin.windowsInfo;
    // Windows client ID not yet in gateway whitelist - use cli as fallback
    return GatewayClientInfo(
      id: GatewayClientIds.cli,
      version: appVersion,
      platform: 'windows',
      displayName: info.computerName,
    );
  }

  if (!kIsWeb && Platform.isLinux) {
    final info = await plugin.linuxInfo;
    // Linux client ID not yet in gateway whitelist - use cli as fallback
    return GatewayClientInfo(
      id: GatewayClientIds.cli,
      version: appVersion,
      platform: 'linux',
      displayName: info.name,
    );
  }

  // Fallback (should not be reached in production)
  return GatewayClientInfo(
    id: GatewayClientIds.android,
    version: appVersion,
    platform: 'unknown',
  );
}
