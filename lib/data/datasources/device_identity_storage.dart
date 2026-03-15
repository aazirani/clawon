import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for the device identity:
/// - Ed25519 private key bytes (base64)
/// - Ed25519 public key bytes (base64)
/// - Device ID (SHA-256 fingerprint of public key, hex)
/// - Per-connection device tokens (keyed by connectionId)
class DeviceIdentityStorage {
  static const _privateKeyKey = 'device_private_key';
  static const _publicKeyKey = 'device_public_key';
  static const _deviceIdKey = 'device_id';
  static const _deviceTokenPrefix = 'device_token_';

  final FlutterSecureStorage _storage;

  DeviceIdentityStorage()
      : _storage = const FlutterSecureStorage(
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock,
          ),
        );

  /// Constructor for testing — injects a pre-built [FlutterSecureStorage].
  @visibleForTesting
  DeviceIdentityStorage.withStorage(this._storage);

  // --- Private key ---
  Future<String?> readPrivateKey() => _storage.read(key: _privateKeyKey);
  Future<void> writePrivateKey(String base64Key) =>
      _storage.write(key: _privateKeyKey, value: base64Key);

  // --- Public key ---
  Future<String?> readPublicKey() => _storage.read(key: _publicKeyKey);
  Future<void> writePublicKey(String base64Key) =>
      _storage.write(key: _publicKeyKey, value: base64Key);

  // --- Device ID ---
  Future<String?> readDeviceId() => _storage.read(key: _deviceIdKey);
  Future<void> writeDeviceId(String deviceId) =>
      _storage.write(key: _deviceIdKey, value: deviceId);

  // --- Per-connection device tokens ---
  Future<String?> readDeviceToken(String connectionId) =>
      _storage.read(key: '$_deviceTokenPrefix$connectionId');

  Future<void> writeDeviceToken(String connectionId, String token) =>
      _storage.write(key: '$_deviceTokenPrefix$connectionId', value: token);

  Future<void> deleteDeviceToken(String connectionId) =>
      _storage.delete(key: '$_deviceTokenPrefix$connectionId');

  // --- Full wipe (for testing / app reset) ---
  Future<void> deleteAll() => _storage.deleteAll();
}
