// ──────────────────────────────────────────────────────────────
// PBKDF2-HMAC-SHA256 — utilitaire partagé (V3.0)
// ──────────────────────────────────────────────────────────────
// Utilisé par :
//   - AccountService (hash du mot de passe cloud, legacy)
//   - LocalLockService (hash du PIN local)
//
// Calcul dans un isolate via compute() pour ne pas bloquer l'UI.
// Format hash stocké : "pbkdf2$<iter>$<base64url(sel)>$<base64url(clé)>".
// ──────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

const int kPbkdf2Iterations = 100000;
const int kPbkdf2KeyLength = 32; // bytes (256 bits)
const int kPbkdf2SaltLength = 16; // bytes (128 bits)
const String kPbkdf2Prefix = 'pbkdf2\$';

/// Fonction top-level pour compute() — reçoit un record Dart 3.
String pbkdf2HashIsolate(({String password, List<int> salt, int iterations}) args) {
  final passwordBytes = utf8.encode(args.password);
  final hmac = Hmac(sha256, passwordBytes);
  final salt = args.salt;
  final iterations = args.iterations;

  final blocks = <int>[];
  var blockIndex = 1;

  while (blocks.length < kPbkdf2KeyLength) {
    final saltWithIndex = Uint8List(salt.length + 4);
    saltWithIndex.setAll(0, salt);
    saltWithIndex[salt.length + 0] = (blockIndex >> 24) & 0xFF;
    saltWithIndex[salt.length + 1] = (blockIndex >> 16) & 0xFF;
    saltWithIndex[salt.length + 2] = (blockIndex >> 8) & 0xFF;
    saltWithIndex[salt.length + 3] = blockIndex & 0xFF;

    var u = List<int>.from(hmac.convert(saltWithIndex).bytes);
    final block = List<int>.from(u);

    for (var i = 1; i < iterations; i++) {
      u = List<int>.from(hmac.convert(u).bytes);
      for (var j = 0; j < block.length; j++) {
        block[j] ^= u[j];
      }
    }

    blocks.addAll(block);
    blockIndex++;
  }

  final derived = blocks.take(kPbkdf2KeyLength).toList();
  final saltB64 = base64Url.encode(salt);
  final hashB64 = base64Url.encode(derived);
  return '$kPbkdf2Prefix$iterations\$$saltB64\$$hashB64';
}

/// Génère un nouveau hash PBKDF2 (sel aléatoire, dans un isolate).
Future<String> pbkdf2Hash(String password, {int iterations = kPbkdf2Iterations}) {
  final salt = List<int>.generate(
    kPbkdf2SaltLength,
    (_) => Random.secure().nextInt(256),
  );
  return compute(
    pbkdf2HashIsolate,
    (password: password, salt: salt, iterations: iterations),
  );
}

/// Vérifie un mot de passe contre un hash stocké.
/// Le sel et le nombre d'itérations sont extraits du hash.
Future<bool> pbkdf2Verify(String password, String storedHash) async {
  try {
    final parts = storedHash.split('\$');
    if (parts.length != 4 || parts[0] != 'pbkdf2') return false;
    final iterations = int.parse(parts[1]);
    final salt = List<int>.from(base64Url.decode(parts[2]));
    final candidate = await compute(
      pbkdf2HashIsolate,
      (password: password, salt: salt, iterations: iterations),
    );
    return candidate == storedHash;
  } catch (_) {
    return false;
  }
}
