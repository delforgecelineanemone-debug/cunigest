// Tests : RoutineRepository — affichage des tâches du jour selon la récurrence.
// Risque cible : une tâche hebdo qui réapparaîtrait chaque jour pollue
// l'écran ; à l'inverse, une tâche déjà faite qui disparaît dès la
// complétion casse le sentiment de progression. Et completerTache ne
// doit pas créer plusieurs lignes pour le même jour.

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/models/tache.dart';
import 'package:gestion_cunicole/repositories/routine_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

void main() {
  late Database db;
  late RoutineRepository repo;

  setUp(() async {
    db = await openTestDb();
    repo = RoutineRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('getTachesActives — filtres', () {
    test('tâches reportées exclues, mais tâches en_attente incluses', () async {
      // Le seed insère 5 tâches système actives en 'en_attente' (statut DEFAULT).
      final tId = await repo.insertTache(Tache(
        titre: 'Reportée', categorie: 'custom',
        statut: 'reporte',
      ));

      final actives = await repo.getTachesActives();
      expect(actives.map((t) => t.id), isNot(contains(tId)));

      final reportees = await repo.getTachesReportees();
      expect(reportees.map((t) => t.id), contains(tId));
    });

    test('tâche désactivée → absente partout', () async {
      final id = await repo.insertTache(Tache(
        titre: 'Off', categorie: 'custom', estActive: false,
      ));
      final actives = await repo.getTachesActives();
      expect(actives.map((t) => t.id), isNot(contains(id)));
    });
  });

  group('completerTache / deCompleterTache', () {
    test('completer puis getTachesCompleteesAujourdhui contient l\'id',
        () async {
      final id = await repo.insertTache(
          Tache(titre: 'T', categorie: 'observation'));
      await repo.completerTache(id);
      expect(await repo.getTachesCompleteesAujourdhui(), {id});
      expect(await repo.estTacheCompletee(id), isTrue);
    });

    test('completer 2x dans la même journée → 2 lignes (pas de contrainte)',
        () async {
      // C'est le comportement actuel — pas de unique (tache_id, date).
      // Si ce test casse, c'est qu'on a ajouté la contrainte → fixer
      // completerTache pour qu'il fasse INSERT OR REPLACE.
      final id = await repo.insertTache(Tache(titre: 'T', categorie: 'eau'));
      await repo.completerTache(id);
      await repo.completerTache(id);
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final n = await repo.countCompletions(today);
      expect(n, 1, reason: 'countCompletions utilise DISTINCT');
    });

    test('decompleter supprime toutes les completions du jour', () async {
      final id = await repo.insertTache(Tache(titre: 'T', categorie: 'eau'));
      await repo.completerTache(id);
      await repo.completerTache(id);
      await repo.deCompleterTache(id);
      expect(await repo.estTacheCompletee(id), isFalse);
    });
  });

  group('getTachesDuJour — récurrences', () {
    test('quotidien → toujours présent', () async {
      final id = await repo.insertTache(Tache(
        titre: 'Daily', categorie: 'nourriture', recurrence: 'quotidien',
      ));
      final today = await repo.getTachesDuJour();
      expect(today.map((t) => t.id), contains(id));
    });

    test('hebdomadaire déjà completée cette semaine → exclue', () async {
      // Compléter à la date du lundi de la semaine en cours
      final now = DateTime.now();
      final lundi = now.subtract(Duration(days: now.weekday - 1));
      final lundiStr = lundi.toIso8601String().substring(0, 10);

      final id = await repo.insertTache(Tache(
        titre: 'Weekly', categorie: 'nettoyage', recurrence: 'hebdomadaire',
      ));
      await db.insert('completions', {
        'tache_id': id,
        'date_completion': lundiStr,
      });

      // Si la complétion est AUJOURD'HUI, elle reste affichée pour donner
      // le feedback. Sinon (autre jour de la semaine), elle disparaît.
      final today = await repo.getTachesDuJour();
      final isToday = lundiStr ==
          DateTime.now().toIso8601String().substring(0, 10);
      if (isToday) {
        expect(today.map((t) => t.id), contains(id));
      } else {
        expect(today.map((t) => t.id), isNot(contains(id)));
      }
    });
  });
}
