// Tests : SaillieRepository — statistiques de reproduction.
// Risque cible : un taux de fertilité ou une mortalité pré-sevrage
// faux trompe l'éleveur sur la santé du troupeau. Les agrégats
// doivent gérer le cas "aucune saillie" et exclure correctement les
// lignes incomplètes (nb_vivants null, nb_sevres null).

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/models/saillie.dart';
import 'package:gestion_cunicole/repositories/saillie_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

void main() {
  late Database db;
  late SaillieRepository repo;
  late int mereId;
  late int pereId;

  setUp(() async {
    db = await openTestDb();
    repo = SaillieRepository(db);
    // Lapins parents pour respecter les FK
    mereId = await db.insert('lapins', {
      'numero_bague': 'M1', 'sexe': 'femelle', 'date_creation': '2026-01-01',
    });
    pereId = await db.insert('lapins', {
      'numero_bague': 'P1', 'sexe': 'male', 'date_creation': '2026-01-01',
    });
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> addSaillie({
    String date = '2026-04-01',
    String statut = 'en_attente',
    bool palpationPositive = false,
    int? nbNes,
    int? nbVivants,
    int? nbMorts,
    int? nbSevres,
  }) {
    final s = Saillie(
      mereId: mereId,
      pereId: pereId,
      dateSaillie: date,
      statut: statut,
      palpationPositive: palpationPositive,
      nbNes: nbNes,
      nbVivants: nbVivants,
      nbMorts: nbMorts,
      nbSevres: nbSevres,
    );
    return repo.insertSaillie(s);
  }

  group('countTerminees', () {
    test('compte uniquement mise_bas, sevrage, termine', () async {
      await addSaillie(statut: 'en_attente');
      await addSaillie(statut: 'mise_bas');
      await addSaillie(statut: 'sevrage');
      await addSaillie(statut: 'termine');
      await addSaillie(statut: 'echec');
      expect(await repo.countTerminees(), 3);
    });
  });

  group('getStatistiquesReproduction', () {
    test('base vide → métriques nulles ou 0', () async {
      final stats = await repo.getStatistiquesReproduction();
      expect(stats['nombre_saillies'], 0);
      expect(stats['taux_fertilite_pct'], isNull);
      expect(stats['prolificite_moyenne'], isNull);
      expect(stats['taux_mortalite_pre_sevrage_pct'], isNull);
    });

    test('taux fertilité = positives / (positives + echecs)', () async {
      // 2 positives (palpation_positive OU statut mise_bas), 1 échec.
      await addSaillie(palpationPositive: true);
      await addSaillie(statut: 'mise_bas', nbVivants: 8, nbNes: 9);
      await addSaillie(statut: 'echec');
      await addSaillie(statut: 'en_attente'); // ni positive ni échec

      final stats = await repo.getStatistiquesReproduction();
      // positives = 2, échecs = 1, palpées = 3 → 66.67%
      expect(stats['nombre_positives'], 2);
      expect(stats['nombre_echecs'], 1);
      expect(stats['taux_fertilite_pct'], closeTo(66.67, 0.1));
    });

    test('prolificité moyenne = avg(nb_vivants) sur les saillies non null',
        () async {
      await addSaillie(statut: 'mise_bas', nbVivants: 8, nbNes: 10);
      await addSaillie(statut: 'mise_bas', nbVivants: 6, nbNes: 8);
      await addSaillie(statut: 'en_attente'); // nb_vivants null → exclu

      final stats = await repo.getStatistiquesReproduction();
      expect((stats['prolificite_moyenne'] as double), closeTo(7.0, 0.01));
      expect(stats['total_nes_vivants'], 14);
      expect(stats['total_nes'], 18);
    });

    test('mortalité pré-sevrage = (vivants - sevres) / vivants', () async {
      // Saillie 1 : 10 vivants → 8 sevrés (2 perdus)
      // Saillie 2 : 6 vivants → 6 sevrés (0 perdu)
      // Saillie 3 : nb_sevres null → exclue du calcul mortalité
      await addSaillie(statut: 'sevrage', nbVivants: 10, nbSevres: 8);
      await addSaillie(statut: 'sevrage', nbVivants: 6, nbSevres: 6);
      await addSaillie(statut: 'mise_bas', nbVivants: 7, nbSevres: null);

      final stats = await repo.getStatistiquesReproduction();
      // 16 vivants suivis, 14 sevrés → (16-14)/16 = 12.5%
      expect(stats['total_sevres'], 14);
      expect((stats['taux_mortalite_pre_sevrage_pct'] as double),
          closeTo(12.5, 0.01));
    });
  });

  group('FK', () {
    test('insert saillie avec mere_id inexistante → exception (FK ON)',
        () async {
      final s = Saillie(
        mereId: 9999, pereId: pereId, dateSaillie: '2026-05-01',
      );
      await expectLater(
        repo.insertSaillie(s),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
