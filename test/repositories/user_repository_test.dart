// Tests : UserRepository — authentification PIN et garde-fous admin.
// Risque cible : compte admin supprimé par erreur → app verrouillée
// sans recours, ou PIN mal haché → faille d'auth. Le hash doit être
// déterministe et la suppression du dernier admin doit être bloquée.

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/repositories/user_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

void main() {
  late Database db;
  late UserRepository repo;

  setUp(() async {
    db = await openTestDb();
    repo = UserRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('hashPin', () {
    test('déterministe : même PIN → même hash', () {
      expect(UserRepository.hashPin('1234'), UserRepository.hashPin('1234'));
    });

    test('PINs différents → hashs différents', () {
      expect(UserRepository.hashPin('1234'),
          isNot(UserRepository.hashPin('1235')));
    });

    test('jamais le PIN en clair', () {
      final h = UserRepository.hashPin('1234');
      expect(h.contains('1234'), isFalse);
      expect(h.length, 64); // SHA-256 hex
    });
  });

  group('authenticate', () {
    test('bon nom + bon PIN → user + maj derniere_connexion', () async {
      await repo.create(nom: 'Admin', role: 'admin', pin: '4242');

      final user = await repo.authenticate('Admin', '4242');
      expect(user, isNotNull);
      expect(user!.nom, 'Admin');

      // Recharge : derniere_connexion doit être renseignée
      final updated = await repo.findByName('Admin');
      expect(updated!.derniereConnexion, isNotNull);
    });

    test('mauvais PIN → null', () async {
      await repo.create(nom: 'Admin', role: 'admin', pin: '4242');
      expect(await repo.authenticate('Admin', '0000'), isNull);
    });

    test('nom inexistant → null', () async {
      expect(await repo.authenticate('Fantome', '0000'), isNull);
    });
  });

  group('delete — garde-fou admin', () {
    test('dernier admin → bloqué', () async {
      final id = await repo.create(nom: 'Admin', role: 'admin', pin: '4242');
      await repo.create(nom: 'Bob', role: 'soigneur', pin: '1111');

      final ok = await repo.delete(id);
      expect(ok, isFalse, reason: 'dernier admin doit être protégé');
      expect((await repo.findByName('Admin')), isNotNull);
    });

    test('un admin parmi 2 → suppression OK', () async {
      final a1 = await repo.create(nom: 'A1', role: 'admin', pin: '1111');
      await repo.create(nom: 'A2', role: 'admin', pin: '2222');

      final ok = await repo.delete(a1);
      expect(ok, isTrue);
      expect(await repo.findByName('A1'), isNull);
    });

    test('soigneur → toujours supprimable même s\'il est seul', () async {
      await repo.create(nom: 'Admin', role: 'admin', pin: '4242');
      final s = await repo.create(nom: 'Sol', role: 'soigneur', pin: '1111');

      expect(await repo.delete(s), isTrue);
    });
  });

  group('UNIQUE nom', () {
    test('création d\'un user avec un nom déjà pris → exception', () async {
      await repo.create(nom: 'Admin', role: 'admin', pin: '4242');
      await expectLater(
        repo.create(nom: 'Admin', role: 'soigneur', pin: '1111'),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
