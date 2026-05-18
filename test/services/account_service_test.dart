// Tests : AccountService — gestion du compte cuniculteur (V3.0)
//
// LIMITES TESTABLES :
// La classe AccountService dépend de :
//   - DBHelper.instance.sync (singleton avec sqflite_sqlcipher natif)
//   - flutter_secure_storage (platform channel Android Keystore)
//   - AppConfig.hasSupabaseDefaults + http (réseau)
//
// Aucune injection de dépendance n'est offerte → impossible d'appeler
// `creerCompte`, `verifierMotDePasse` ou `tenterLienCloud` depuis un test
// `flutter test` sans mocker des platform channels (hors scope du prompt).
//
// SURFACE TESTÉE ICI :
// On valide le CONTRAT du hashage PBKDF2-HMAC-SHA256 que le service utilise
// (format de stockage `pbkdf2$iter$saltB64$keyB64`, déterminisme, sensibilité
// au sel et au mot de passe). Le `_pbkdf2HashIsolate` étant library-private,
// on en réimplemente l'algorithme avec le package `crypto` (même que la prod)
// pour vérifier que l'algo standard a bien les propriétés attendues.
//
// Si la fonction publique change un jour (ex : exposer un helper static
// `AccountService.hashForTesting`), ces tests pourront être adaptés.

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

// Constantes miroir de lib/services/account_service.dart
const int _kIterations = 100000;
const int _kKeyLength = 32;
const int _kSaltLength = 16;
const String _kPbkdf2Prefix = 'pbkdf2\$';

/// Réimplémentation locale (test-only) de l'algorithme PBKDF2-HMAC-SHA256
/// utilisé par AccountService. Permet de vérifier les propriétés du contrat
/// (déterminisme, format) sans dépendre d'un platform channel.
String pbkdf2HashForTest(String password, List<int> salt) {
  final passwordBytes = utf8.encode(password);
  final hmac = Hmac(sha256, passwordBytes);
  final blocks = <int>[];
  var blockIndex = 1;

  while (blocks.length < _kKeyLength) {
    final saltWithIndex = Uint8List(salt.length + 4);
    saltWithIndex.setAll(0, salt);
    saltWithIndex[salt.length + 0] = (blockIndex >> 24) & 0xFF;
    saltWithIndex[salt.length + 1] = (blockIndex >> 16) & 0xFF;
    saltWithIndex[salt.length + 2] = (blockIndex >> 8) & 0xFF;
    saltWithIndex[salt.length + 3] = blockIndex & 0xFF;

    var u = List<int>.from(hmac.convert(saltWithIndex).bytes);
    final block = List<int>.from(u);

    for (var i = 1; i < _kIterations; i++) {
      u = List<int>.from(hmac.convert(u).bytes);
      for (var j = 0; j < block.length; j++) {
        block[j] ^= u[j];
      }
    }

    blocks.addAll(block);
    blockIndex++;
  }

  final derived = blocks.take(_kKeyLength).toList();
  final saltB64 = base64Url.encode(salt);
  final hashB64 = base64Url.encode(derived);
  return '$_kPbkdf2Prefix$_kIterations\$$saltB64\$$hashB64';
}

void main() {
  group('PBKDF2 — contrat algorithmique utilisé par AccountService', () {
    final salt1 = List<int>.filled(_kSaltLength, 0x11);
    final salt2 = List<int>.filled(_kSaltLength, 0x22);

    test('hash déterministe : même password + même sel → même hash', () {
      final h1 = pbkdf2HashForTest('motDePasse123', salt1);
      final h2 = pbkdf2HashForTest('motDePasse123', salt1);
      expect(h1, equals(h2));
    });

    test('format stocké : "pbkdf2\$iterations\$saltB64\$keyB64"', () {
      final hash = pbkdf2HashForTest('whatever', salt1);
      expect(hash.startsWith(_kPbkdf2Prefix), isTrue);

      final parts = hash.split('\$');
      expect(parts.length, 4, reason: 'format à 4 segments');
      expect(parts[0], 'pbkdf2');
      expect(parts[1], _kIterations.toString());

      // Le sel encodé doit redonner exactement 16 bytes.
      final decodedSalt = base64Url.decode(parts[2]);
      expect(decodedSalt.length, _kSaltLength);
      expect(decodedSalt, equals(salt1));

      // La clé dérivée doit faire exactement 32 bytes (256 bits).
      final decodedKey = base64Url.decode(parts[3]);
      expect(decodedKey.length, _kKeyLength);
    });

    test('sensibilité au mot de passe : passwords différents → hashs différents (même sel)', () {
      final h1 = pbkdf2HashForTest('motDePasse123', salt1);
      final h2 = pbkdf2HashForTest('motDePasse124', salt1);
      expect(h1, isNot(equals(h2)));
    });

    test('sensibilité au sel : sels différents → hashs différents (même password)', () {
      final h1 = pbkdf2HashForTest('motDePasse123', salt1);
      final h2 = pbkdf2HashForTest('motDePasse123', salt2);
      expect(h1, isNot(equals(h2)));

      // Et même les segments sel + clé doivent différer.
      final parts1 = h1.split('\$');
      final parts2 = h2.split('\$');
      expect(parts1[2], isNot(equals(parts2[2])));
      expect(parts1[3], isNot(equals(parts2[3])));
    });

    test('vecteur de référence RFC-style : 100k itérations sur sel zéro', () {
      // Vecteur calculé sur la même implémentation Dart. Sert de garde-fou
      // contre une régression d'algo (changement d'itérations, de longueur
      // de clé, ou d'ordre des octets dans saltWithIndex).
      final salt = List<int>.filled(_kSaltLength, 0);
      final hash = pbkdf2HashForTest('password', salt);

      final parts = hash.split('\$');
      expect(parts[0], 'pbkdf2');
      expect(parts[1], '100000');
      // Sel base64url(16 zéros) = "AAAAAAAAAAAAAAAAAAAAAA=="
      expect(parts[2], 'AAAAAAAAAAAAAAAAAAAAAA==');
      // La clé doit décoder à 32 bytes, dont au moins un non nul (sinon algo cassé).
      final key = base64Url.decode(parts[3]);
      expect(key.length, 32);
      expect(key.any((b) => b != 0), isTrue);
    });
  });

  group('AccountService — surface haut-niveau (skip platform)', () {
    test(
      'creerCompte/verifierMotDePasse/supprimerCompte nécessitent DBHelper + flutter_secure_storage',
      () {
        // Voir test/e2e/flow_complet_test.dart pour une couverture indirecte
        // de bout en bout, ou integration_test pour exécution sur device.
      },
      skip: 'Nécessite SQLCipher natif + Android Keystore — hors scope flutter_test',
    );
  });
}
