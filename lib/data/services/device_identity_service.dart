import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

import '../datasources/device_identity_storage.dart';

/// Immutable snapshot of the loaded device identity.
class DeviceIdentity {
  final String deviceId; // SHA-256(publicKeyBytes) hex
  final String publicKeyBase64Url; // URL-safe base64
  final SimpleKeyPair keyPair; // Ed25519 key pair (holds private key)

  const DeviceIdentity({
    required this.deviceId,
    required this.publicKeyBase64Url,
    required this.keyPair,
  });
}

/// Manages the app-level Ed25519 device identity.
/// One instance per app installation — shared across all gateway connections.
class DeviceIdentityService {
  final DeviceIdentityStorage _storage;
  final Ed25519 _algorithm = Ed25519();

  DeviceIdentity? _cached;

  DeviceIdentityService(this._storage);

  /// Ensures a device identity exists, generating one if this is the first launch.
  /// Call once at app startup.
  Future<void> ensureDeviceIdentityInitialized() async {
    final existing = await _storage.readDeviceId();
    if (existing != null) return; // Already initialized

    await _generateAndStoreNewIdentity();
  }

  /// Returns the current device identity, loading from secure storage.
  /// Throws if identity has not been initialized (call [ensureDeviceIdentityInitialized] first).
  Future<DeviceIdentity> getDeviceIdentity() async {
    if (_cached != null) return _cached!;

    final privateKeyBase64 = await _storage.readPrivateKey();
    final publicKeyBase64 = await _storage.readPublicKey();
    final deviceId = await _storage.readDeviceId();

    if (privateKeyBase64 == null ||
        publicKeyBase64 == null ||
        deviceId == null) {
      throw StateError(
          'Device identity not initialized. Call ensureDeviceIdentityInitialized() first.');
    }

    final privateKeyBytes = base64Url.decode(privateKeyBase64);
    final publicKeyBytes = base64Url.decode(publicKeyBase64);

    final keyPair = await _algorithm.newKeyPairFromSeed(privateKeyBytes);
    // Verify public key matches stored
    final pubKey = await keyPair.extractPublicKey();
    assert(
      _bytesEqual(pubKey.bytes, publicKeyBytes),
      'Stored public key does not match derived public key',
    );

    _cached = DeviceIdentity(
      deviceId: deviceId,
      publicKeyBase64Url: publicKeyBase64,
      keyPair: keyPair,
    );
    return _cached!;
  }

  /// Builds the signed `device` block to include in the connect frame.
  ///
  /// The signing payload is the gateway v2 canonical format (pipe-delimited):
  /// `v2|deviceId|clientId|clientMode|role|scopes|signedAtMs|authToken|nonce`
  ///
  /// [nonce]      — server-supplied challenge nonce from `connect.challenge` event.
  /// [clientId]   — gateway whitelist ID (e.g. 'openclaw-android').
  /// [clientMode] — client mode string (e.g. 'cli').
  /// [role]       — requested role (e.g. 'operator').
  /// [scopes]     — requested scopes (comma-joined in payload).
  /// [authToken]  — the token being sent in `auth.token` of the connect frame.
  ///                Must match exactly so the gateway can reproduce the payload.
  Future<Map<String, dynamic>> buildDeviceBlock({
    required String nonce,
    required String clientId,
    required String clientMode,
    required String role,
    required List<String> scopes,
    required String authToken,
  }) async {
    final identity = await getDeviceIdentity();
    final signedAt = DateTime.now().millisecondsSinceEpoch;

    // Canonical payload — must match gateway buildDeviceAuthPayload() exactly.
    final payload = [
      'v2',
      identity.deviceId,
      clientId,
      clientMode,
      role,
      scopes.join(','),
      signedAt.toString(),
      authToken,
      nonce,
    ].join('|');

    final payloadBytes = utf8.encode(payload);

    final signature = await _algorithm.sign(
      payloadBytes,
      keyPair: identity.keyPair,
    );
    final signatureBase64Url = base64Url.encode(signature.bytes);

    return {
      'id': identity.deviceId,
      'publicKey': identity.publicKeyBase64Url,
      'signature': signatureBase64Url,
      'signedAt': signedAt,
      'nonce': nonce,
    };
  }

  /// Returns the stored device token for a specific connection, or null if not yet paired.
  Future<String?> getDeviceToken(String connectionId) =>
      _storage.readDeviceToken(connectionId);

  /// Persists a device token received from the gateway after successful pairing.
  Future<void> storeDeviceToken(String connectionId, String token) =>
      _storage.writeDeviceToken(connectionId, token);

  /// Removes the device token for a specific connection (unpairs the device).
  Future<void> deleteDeviceToken(String connectionId) =>
      _storage.deleteDeviceToken(connectionId);

  // --- Private helpers ---

  Future<void> _generateAndStoreNewIdentity() async {
    final keyPair = await _algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();

    final publicKeyBase64Url = base64Url.encode(publicKey.bytes);
    final privateKeyBase64Url =
        base64Url.encode(Uint8List.fromList(privateKeyBytes));
    final deviceId = _computeDeviceId(publicKey.bytes);

    await _storage.writePrivateKey(privateKeyBase64Url);
    await _storage.writePublicKey(publicKeyBase64Url);
    await _storage.writeDeviceId(deviceId);
  }

  /// SHA-256 of public key bytes, hex-encoded.
  String _computeDeviceId(List<int> publicKeyBytes) {
    final digest = sha256.convert(publicKeyBytes);
    return digest.toString();
  }

  bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
