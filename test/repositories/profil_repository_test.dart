// Tests : ProfilRepository — gestion du streak et déblocage des badges.
// Risque cible : streak qui se casse à tort (l'éleveur perd sa motivation)
// ou badge re-débloqué chaque jour. Le calcul de streak doit gérer la
// tolérance, et debloquerBadge doit être idempotent.

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/models/reglages.dart';
import 'package:gestion_cunicole/repositories/profil_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_db.dart';

void main() {
  late Database db;
  late ProfilRepository repo;

  setUp(() async {
    db = await openTestDb();
    repo = ProfilRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  String isoOffset(int days) =>
      DateTime.now().subtract(Duration(days: days)).toIso8601String().substring(0, 10);

  group('mettreAJourScore — streak', () {
    test('1ère activité de la journée → streak = 1', () async {
      final p = await repo.mettreAJourScore(30);
      expect(p.streakActuel, 1);
      expect(p.scoreAujourdhui, 30);
      expect(p.scoreTotal, 30);
      expect(p.meilleurStreak, 1);
    });

    test('même journée appelée 2x → streak ne re-incrémente pas', () async {
      await repo.mettreAJourScore(30);
      final p = await repo.mettreAJourScore(20);
      expect(p.streakActuel, 1);
      expect(p.scoreAujourdhui, 50);
    });

    test('hier activité → streak passe à 2', () async {
      // Pré-remplir profil avec activité d'hier
      final profil = await repo.getProfil();
      profil.derniereActivite = isoOffset(1);
      profil.streakActuel = 5;
      profil.meilleurStreak = 5;
      profil.scoreTotal = 100;
      await repo.updateProfil(profil);

      final p = await repo.mettreAJourScore(10);
      expect(p.streakActuel, 6);
      expect(p.meilleurStreak, 6);
    });

    test('écart > tolérance → streak reset à 1', () async {
      final profil = await repo.getProfil();
      profil.derniereActivite = isoOffset(5);
      profil.streakActuel = 10;
      profil.meilleurStreak = 10;
      await repo.updateProfil(profil);

      final p = await repo.mettreAJourScore(10);
      expect(p.streakActuel, 1);
      expect(p.meilleurStreak, 10, reason: 'record préservé');
    });

    test('points négatifs (décompletion) → score clampé à 0', () async {
      // Pas de gain auparavant, on déduit
      final p = await repo.mettreAJourScore(-100);
      expect(p.scoreTotal, 0);
      expect(p.scoreAujourdhui, 0);
    });
  });

  group('debloquerBadge — idempotence', () {
    test('1ère fois → true, suivantes → false', () async {
      final r1 = await repo.debloquerBadge('test_a', 'A', 'desc', '🎯');
      final r2 = await repo.debloquerBadge('test_a', 'A', 'desc', '🎯');
      expect(r1, isTrue);
      expect(r2, isFalse);
      final badges = await repo.getBadgesObtenus();
      expect(badges.length, 1);
    });
  });

  group('verifierBadges', () {
    test('streak=7 + 10 saillies → débloque semaine_parfaite ET sage_femme',
        () async {
      final profil = await repo.getProfil();
      profil.streakActuel = 7;
      profil.scoreTotal = 100;
      await repo.updateProfil(profil);

      final nouveaux = await repo.verifierBadges(
        profil: profil,
        statsLapins: {'total': 5},
        nbSailliesTerminees: 10,
        nbSoins: 0,
        nbVentes: 0,
      );
      final codes = (await repo.getBadgesObtenus()).map((b) => b.code).toSet();
      expect(codes, containsAll(['semaine_parfaite', 'sage_femme', 'premier_lapin', 'premier_pas']));
      expect(nouveaux.any((n) => n.contains('Semaine')), isTrue);
    });

    test('appel répété ne re-débloque pas', () async {
      final profil = await repo.getProfil();
      profil.streakActuel = 30;
      profil.scoreTotal = 200;
      await repo.updateProfil(profil);

      await repo.verifierBadges(
        profil: profil, statsLapins: {'total': 1},
        nbSailliesTerminees: 0, nbSoins: 0, nbVentes: 0,
      );
      final nouveaux2 = await repo.verifierBadges(
        profil: profil, statsLapins: {'total': 1},
        nbSailliesTerminees: 0, nbSoins: 0, nbVentes: 0,
      );
      expect(nouveaux2, isEmpty);
    });
  });

  group('reglages', () {
    test('updateReglages persiste les changements', () async {
      const r = Reglages(themeMode: 'dark', modeGants: true, devise: 'FCFA');
      await repo.updateReglages(r);
      final loaded = await repo.getReglages();
      expect(loaded.themeMode, 'dark');
      expect(loaded.modeGants, isTrue);
      expect(loaded.devise, 'FCFA');
    });
  });
}
