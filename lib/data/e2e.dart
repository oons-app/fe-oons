import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';

/// Application-layer E2E: X25519 ECDH → HKDF → AES-256-GCM payloads.
class E2ESession {
  E2ESession({required this.sessionId, required this.keyBytes});

  final String sessionId;
  final SecretKeyData keyBytes;

  static const _aad = [111, 111, 110, 115, 45, 101, 50, 101, 45, 118, 49]; // oons-e2e-v1

  static final _x25519 = X25519();
  static final _aes = AesGcm.with256bits();

  static String b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

  static Uint8List b64d(String s) {
    var t = s.replaceAll('-', '+').replaceAll('_', '/');
    while (t.length % 4 != 0) {
      t += '=';
    }
    return Uint8List.fromList(base64.decode(t));
  }

  /// Matches Go: RawStdEncoding (no padding) of standard base64.
  static String b64Raw(List<int> bytes) => base64.encode(bytes).replaceAll('=', '');

  static Uint8List b64RawDecode(String s) {
    var t = s;
    while (t.length % 4 != 0) {
      t += '=';
    }
    return Uint8List.fromList(base64.decode(t));
  }

  static Future<({SimpleKeyPair keyPair, String clientPubB64})> generateClientKeys() async {
    final keyPair = await _x25519.newKeyPair();
    final pub = await keyPair.extractPublicKey();
    return (keyPair: keyPair, clientPubB64: b64Raw(pub.bytes));
  }

  static Future<E2ESession> fromHandshake({
    required SimpleKeyPair clientKeyPair,
    required String serverPubB64,
    required String sessionId,
  }) async {
    final serverPub = SimplePublicKey(b64RawDecode(serverPubB64), type: KeyPairType.x25519);
    final shared = await _x25519.sharedSecretKey(keyPair: clientKeyPair, remotePublicKey: serverPub);
    final sharedBytes = await shared.extractBytes();
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final derived = await hkdf.deriveKey(
      secretKey: SecretKey(sharedBytes),
      nonce: utf8.encode('oons-e2e-v1'),
      info: utf8.encode('payload-aes-256-gcm'),
    );
    final keyBytes = await derived.extractBytes();
    return E2ESession(sessionId: sessionId, keyBytes: SecretKeyData(keyBytes));
  }

  Future<Map<String, dynamic>> sealJson(Object? data) async {
    final plain = utf8.encode(jsonEncode(data ?? {}));
    final box = await _aes.encrypt(
      plain,
      secretKey: keyBytes,
      aad: _aad,
    );
    // Go SealWithAAD: nonce || ciphertext+tag (combined)
    final combined = <int>[...box.nonce, ...box.cipherText, ...box.mac.bytes];
    return {'v': 1, 'ct': b64Raw(combined)};
  }

  Future<Uint8List> sealBytes(List<int> plain) async {
    final box = await _aes.encrypt(plain, secretKey: keyBytes, aad: _aad);
    return Uint8List.fromList([...box.nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  Future<List<int>> openBytes(List<int> blob) async {
    if (blob.length < 28) {
      throw StateError('ciphertext too short');
    }
    final nonce = blob.sublist(0, 12);
    final mac = Mac(blob.sublist(blob.length - 16));
    final ct = blob.sublist(12, blob.length - 16);
    return _aes.decrypt(
      SecretBox(ct, nonce: nonce, mac: mac),
      secretKey: keyBytes,
      aad: _aad,
    );
  }

  Future<dynamic> openJson(Map wire) async {
    final ct = '${wire['ct'] ?? ''}';
    if (wire['v'] != 1 || ct.isEmpty) {
      throw StateError('bad e2e envelope');
    }
    final plain = await openBytes(b64RawDecode(ct));
    return jsonDecode(utf8.decode(plain));
  }
}

class E2EController {
  E2ESession? _session;
  bool _handshaking = false;
  DateTime? _clearedAt;

  E2ESession? get session => _session;

  Future<void> ensure(Dio dio) async {
    if (_session != null || _handshaking) {
      while (_handshaking) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
      if (_session != null) return;
    }
    // Avoid handshake storms after a brief E2E expiry / network blip.
    final cleared = _clearedAt;
    if (cleared != null && DateTime.now().difference(cleared) < const Duration(seconds: 2)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    _handshaking = true;
    try {
      final keys = await E2ESession.generateClientKeys();
      final r = await dio.post('/crypto/session', data: {'clientPub': keys.clientPubB64});
      final data = r.data is Map ? Map<String, dynamic>.from(r.data as Map) : <String, dynamic>{};
      final payload = data.containsKey('data') && data['data'] is Map
          ? Map<String, dynamic>.from(data['data'] as Map)
          : data;
      final sid = '${payload['sessionId'] ?? ''}';
      final sp = '${payload['serverPub'] ?? ''}';
      if (sid.isEmpty || sp.isEmpty) {
        throw StateError('crypto session failed');
      }
      _session = await E2ESession.fromHandshake(
        clientKeyPair: keys.keyPair,
        serverPubB64: sp,
        sessionId: sid,
      );
      _clearedAt = null;
    } finally {
      _handshaking = false;
    }
  }

  void clear() {
    _session = null;
    _clearedAt = DateTime.now();
  }
}
