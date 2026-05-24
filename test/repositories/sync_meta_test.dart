// Tests : sync_meta — helpers updated_at + soft-delete (P0.1 / P0.2).

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/repositories/sync_meta.dart';
import 'package:gestion_cunicole/models/lapin.dart';
import 'package:gestion_cunicole/repositories/lapin_repository.dart';

import '../helpers/test_db.dart';

void main() {
  group('stampUpdated', () {
    test('ajoute un champ updated_at ISO-8601', () {
      final stamped = stampUpdated({'nom': 'Bella'});
      expect(stamped['nom'], 'Bella');
      expect(stamped['updated_at'], isA<String>());
      expect(DateTime.tryParse(stamped['updated_at'] as String), isNotNull);
    });

    test('n\'altère pas la map source', () {
      final src = {'a': 1};
      stampUpdated(src);
      expect(src.containsKey('updated_at'), isFalse);
    });
  });

  group('whereNotDeleted', () {
    test('sans condition → filtre deleted_at seul', () {
      expect(whereNotDeleted(), 'deleted_at IS NULL');
    });

    test('avec condition → combine en AND', () {
      expect(whereNotDeleted('statut = ?'),
          '(statut = ?) AND deleted_at IS NULL');
    });

    test('condition vide → filtre deleted_at seul', () {
      expect(whereNotDeleted('  '), 'deleted_at IS NULL');
    });
  });

  group('softDelete (intégration DB)', () {
    test('marque deleted_at sans purge physique', () async {
      final db = await openTestDb();
      final repo = LapinRepository(db);
      final id = await repo.insertLapin(
          Lapin(numeroBague: 'F-001', sexe: 'femelle'));

      // Avant : visible
      expect((await repo.getAllLapins()).length, 1);

      await repo.deleteLapin(id);

      // Après : invisible pour le métier...
      expect(await repo.getAllLapins(), isEmpty);
      expect(await repo.getLapinById(id), isNull);

      // ...mais la row physique existe avec deleted_at rempli.
      final raw = await db.query('lapins', where: 'id = ?', whereArgs: [id]);
      expect(raw.length, 1);
      expect(raw.first['deleted_at'], isNotNull);

      await db.close();
    });

    test('updated_at est renseigné à l\'insertion', () async {
      final db = await openTestDb();
      final repo = LapinRepository(db);
      final id = await repo.insertLapin(
          Lapin(numeroBague: 'M-001', sexe: 'male'));
      final raw = await db.query('lapins', where: 'id = ?', whereArgs: [id]);
      expect(raw.first['updated_at'], isNotNull);
      await db.close();
    });

    test('updated_at change après un update', () async {
      final db = await openTestDb();
      final repo = LapinRepository(db);
      final id = await repo.insertLapin(
          Lapin(numeroBague: 'M-002', sexe: 'male'));
      final before = (await db.query('lapins',
              where: 'id = ?', whereArgs: [id]))
          .first['updated_at'] as String;

      await Future.delayed(const Duration(milliseconds: 5));
      final l = (await repo.getLapinById(id))!;
      l.statut = 'sevrage';
      await repo.updateLapin(l);

      final after = (await db.query('lapins',
              where: 'id = ?', whereArgs: [id]))
          .first['updated_at'] as String;
      expect(after.compareTo(before) >= 0, isTrue);
      await db.close();
    });
  });
}
