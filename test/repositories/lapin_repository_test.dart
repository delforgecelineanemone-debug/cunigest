// Tests : LapinRepository — détection de consanguinité.
// Risque cible : un lapin reproduit avec un proche → portées chétives,
// mortalité élevée. La détection doit attraper les cas évidents.

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/models/lapin.dart';
import 'package:gestion_cunicole/repositories/lapin_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

void main() {
  late Database db;
  late LapinRepository repo;

  setUp(() async {
    db = await openTestDb();
    repo = LapinRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> addLapin(String bague, String sexe, {int? pere, int? mere}) {
    return repo.insertLapin(Lapin(
      numeroBague: bague, sexe: sexe, pereId: pere, mereId: mere,
    ));
  }

  group('verifierConsanguinite', () {
    test('même individu → "Même individu !"', () async {
      final id = await addLapin('A', 'male');
      expect(await repo.verifierConsanguinite(id, id), 'Même individu !');
    });

    test('parent direct → "Parent/grand-parent direct"', () async {
      final pere = await addLapin('P', 'male');
      final mere = await addLapin('M', 'femelle');
      final enfant = await addLapin('E', 'male', pere: pere, mere: mere);

      // pere × enfant → consanguinité (parent direct)
      final res = await repo.verifierConsanguinite(pere, enfant);
      expect(res, isNotNull);
      expect(res!.toLowerCase(), contains('enfant'));

      final inverse = await repo.verifierConsanguinite(enfant, pere);
      expect(inverse, isNotNull);
      expect(inverse!.toLowerCase(), contains('parent'));
    });

    test('frères/sœurs (mêmes parents) → détectés', () async {
      final pere = await addLapin('P', 'male');
      final mere = await addLapin('M', 'femelle');
      final f1 = await addLapin('F1', 'femelle', pere: pere, mere: mere);
      final f2 = await addLapin('F2', 'male', pere: pere, mere: mere);

      final res = await repo.verifierConsanguinite(f1, f2);
      expect(res, isNotNull);
      expect(res!.toLowerCase(), contains('frère'));
    });

    test('demi-frères (un seul parent commun) → détectés', () async {
      final pere1 = await addLapin('P1', 'male');
      final pere2 = await addLapin('P2', 'male');
      final mere = await addLapin('M', 'femelle');
      final f1 = await addLapin('F1', 'femelle', pere: pere1, mere: mere);
      final f2 = await addLapin('F2', 'male', pere: pere2, mere: mere);

      final res = await repo.verifierConsanguinite(f1, f2);
      expect(res, isNotNull);
      expect(res!.toLowerCase(), contains('demi'));
    });

    test('grand-parent commun (cousins) → ancêtre commun détecté', () async {
      // Arbre :
      //   GP × GM
      //    /    \
      //   P1    P2
      //   |      |
      //   E1    E2  → cousins, partagent GP et GM comme ancêtres
      final gp = await addLapin('GP', 'male');
      final gm = await addLapin('GM', 'femelle');
      final p1 = await addLapin('P1', 'male', pere: gp, mere: gm);
      final p2 = await addLapin('P2', 'femelle', pere: gp, mere: gm);
      final autreParent1 = await addLapin('X1', 'femelle');
      final autreParent2 = await addLapin('X2', 'male');
      final e1 = await addLapin('E1', 'male', pere: p1, mere: autreParent1);
      final e2 = await addLapin('E2', 'femelle', pere: autreParent2, mere: p2);

      final res = await repo.verifierConsanguinite(e1, e2);
      expect(res, isNotNull, reason: 'cousins doivent être détectés');
      expect(res!.toLowerCase(), contains('ancêtre'));
    });

    test('non apparentés → null', () async {
      final a = await addLapin('A', 'male');
      final b = await addLapin('B', 'femelle');
      expect(await repo.verifierConsanguinite(a, b), isNull);
    });

    test('au-delà de la profondeur de recherche → null', () async {
      // Créer 5 générations en ligne
      final prev = await addLapin('Gen0_P', 'male');
      int? lignee = prev;
      for (int g = 1; g <= 5; g++) {
        final autreParent = await addLapin('autre_$g', g.isEven ? 'femelle' : 'male');
        lignee = await addLapin(
          'Gen$g',
          g.isEven ? 'male' : 'femelle',
          pere: g.isEven ? autreParent : lignee,
          mere: g.isEven ? lignee : autreParent,
        );
      }
      // Avec depth=2 (plus restrictif que défaut), on ne doit PAS détecter
      // l'ancêtre tout en haut.
      final res = await repo.verifierConsanguinite(prev, lignee!, depth: 2);
      // prev est un parent direct (depth 1) du Gen1, pas du Gen5.
      // À depth=2 on remonte 2 générations depuis Gen5 → ne voit pas Gen0.
      expect(res, isNull, reason: 'depth=2 ne doit pas atteindre Gen0 depuis Gen5');
    });
  });

  group('getAncetres', () {
    test('lapin isolé → ensemble vide', () async {
      final id = await addLapin('Solo', 'male');
      expect(await repo.getAncetres(id), isEmpty);
    });

    test('1 génération de parents → 2 ancêtres', () async {
      final p = await addLapin('P', 'male');
      final m = await addLapin('M', 'femelle');
      final e = await addLapin('E', 'male', pere: p, mere: m);
      expect(await repo.getAncetres(e, depth: 1), {p, m});
    });

    test('depth=2 inclut grand-parents', () async {
      final gp = await addLapin('GP', 'male');
      final gm = await addLapin('GM', 'femelle');
      final p = await addLapin('P', 'male', pere: gp, mere: gm);
      final m = await addLapin('M', 'femelle');
      final e = await addLapin('E', 'male', pere: p, mere: m);
      expect(await repo.getAncetres(e, depth: 2), {p, m, gp, gm});
    });

    test('boucle dans la généalogie ne fait pas planter (set deduplique)', () async {
      // Cas pathologique mais possible : par erreur l'utilisateur fait
      // pointer un lapin vers lui-même comme ancêtre via update direct.
      final a = await addLapin('A', 'male');
      // Force un cycle (n'arrive pas via UI mais robuste à un import bidon)
      await db.update('lapins', {'pere_id': a}, where: 'id = ?', whereArgs: [a]);
      final ancetres = await repo.getAncetres(a, depth: 5);
      expect(ancetres, {a});
    });
  });
}
