// ──────────────────────────────────────────────────────────────
// Repository : Profil — Gamification, badges, réglages (V3.0)
// ──────────────────────────────────────────────────────────────

import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/profil.dart';
import '../models/reglages.dart';
import '../services/data_bus.dart';

class ProfilRepository {
  final Database db;
  ProfilRepository(this.db);

  Future<ProfilEleveur> getProfil() async {
    final maps = await db.query('profil_eleveur', limit: 1);
    if (maps.isEmpty) {
      final now = DateTime.now().toIso8601String().substring(0, 10);
      await db.insert('profil_eleveur', {
        'streak_actuel': 0, 'meilleur_streak': 0, 'score_total': 0,
        'score_aujourdhui': 0, 'niveau': 1, 'date_creation': now,
      });
      return ProfilEleveur(dateCreation: now);
    }
    return ProfilEleveur.fromMap(maps.first);
  }

  Future<int> updateProfil(ProfilEleveur p) async {
    final r = await db.update('profil_eleveur', p.toMap(),
        where: 'id = ?', whereArgs: [p.id]);
    DataBus.instance.notify(DataTopics.profil);
    return r;
  }

  /// Met à jour le streak et le score après complétion ou décomplétion.
  Future<ProfilEleveur> mettreAJourScore(int pointsAjoutes) async {
    final profil = await getProfil();
    final reglages = await getReglages();
    final today = DateTime.now().toIso8601String().substring(0, 10);

    if (pointsAjoutes < 0) {
      profil.scoreAujourdhui = (profil.scoreAujourdhui + pointsAjoutes).clamp(0, 1 << 30);
      profil.scoreTotal = (profil.scoreTotal + pointsAjoutes).clamp(0, 1 << 30);
      profil.niveau = ProfilEleveur.calculerNiveau(profil.scoreTotal);
      await updateProfil(profil);
      return profil;
    }

    if (profil.derniereActivite != today) {
      final ecart = _ecartJours(profil.derniereActivite, today);
      if (ecart != null && ecart <= reglages.toleranceStreakJours + 1) {
        profil.streakActuel += 1;
      } else {
        profil.streakActuel = 1;
      }
      profil.scoreAujourdhui = 0;
    }

    profil.scoreAujourdhui += pointsAjoutes;
    profil.scoreTotal += pointsAjoutes;
    profil.derniereActivite = today;

    if (profil.streakActuel > profil.meilleurStreak) {
      profil.meilleurStreak = profil.streakActuel;
    }

    profil.niveau = ProfilEleveur.calculerNiveau(profil.scoreTotal);
    await updateProfil(profil);
    return profil;
  }

  int? _ecartJours(String? a, String b) {
    if (a == null) return null;
    final da = DateTime.tryParse(a);
    final dbb = DateTime.tryParse(b);
    if (da == null || dbb == null) return null;
    return dbb.difference(da).inDays;
  }

  Future<BadgeEleveur?> getBadge(String code) async {
    final maps = await db.query('badges', where: 'code = ?', whereArgs: [code]);
    if (maps.isEmpty) return null;
    return BadgeEleveur.fromMap(maps.first);
  }

  Future<List<BadgeEleveur>> getBadgesObtenus() async {
    final maps = await db.query('badges', where: 'date_obtenu IS NOT NULL');
    return maps.map((m) => BadgeEleveur.fromMap(m)).toList();
  }

  Future<bool> debloquerBadge(String code, String nom, String description, String icone) async {
    final existing = await db.query('badges', where: 'code = ?', whereArgs: [code]);
    if (existing.isNotEmpty) return false;
    await db.insert('badges', {
      'code': code, 'nom': nom, 'description': description, 'icone': icone,
      'date_obtenu': DateTime.now().toIso8601String().substring(0, 10),
    });
    return true;
  }

  /// Vérifie et débloque les badges éligibles.
  /// Reçoit les données en paramètre pour éviter les dépendances circulaires.
  Future<List<String>> verifierBadges({
    required ProfilEleveur profil,
    required Map<String, int> statsLapins,
    required int nbSailliesTerminees,
    required int nbSoins,
    required int nbVentes,
  }) async {
    final nouveauxBadges = <String>[];

    if ((statsLapins['total'] ?? 0) >= 1) {
      if (await debloquerBadge('premier_lapin', 'Premier Lapin', 'Enregistrer son premier lapin', '🐇')) {
        nouveauxBadges.add('🐇 Premier Lapin');
      }
    }
    if (profil.scoreTotal > 0) {
      if (await debloquerBadge('premier_pas', 'Premier Pas', 'Compléter sa première routine', '🌱')) {
        nouveauxBadges.add('🌱 Premier Pas');
      }
    }
    if (profil.streakActuel >= 7) {
      if (await debloquerBadge('semaine_parfaite', 'Semaine Parfaite', '7 jours de streak', '🔥')) {
        nouveauxBadges.add('🔥 Semaine Parfaite');
      }
    }
    if (profil.streakActuel >= 30) {
      if (await debloquerBadge('mois_parfait', 'Mois Parfait', '30 jours de streak', '🏆')) {
        nouveauxBadges.add('🏆 Mois Parfait');
      }
    }
    if (profil.streakActuel >= 100) {
      if (await debloquerBadge('centurion', 'Centurion', '100 jours de streak', '💎')) {
        nouveauxBadges.add('💎 Centurion');
      }
    }
    if (nbSailliesTerminees >= 10) {
      if (await debloquerBadge('sage_femme', 'Sage-Femme', '10 mises bas', '🐣')) {
        nouveauxBadges.add('🐣 Sage-Femme');
      }
    }
    if (nbSoins >= 20) {
      if (await debloquerBadge('docteur', 'Docteur', '20 soins enregistrés', '💊')) {
        nouveauxBadges.add('💊 Docteur');
      }
    }
    if (nbVentes >= 10) {
      if (await debloquerBadge('commercial', 'Commercial', '10 ventes effectuées', '💰')) {
        nouveauxBadges.add('💰 Commercial');
      }
    }
    return nouveauxBadges;
  }

  // ═══════════════════════════════════════════════════════════
  // RÉGLAGES
  // ═══════════════════════════════════════════════════════════

  Future<Reglages> getReglages() async {
    final maps = await db.query('reglages', where: 'id = ?', whereArgs: [1], limit: 1);
    if (maps.isEmpty) {
      await db.insert('reglages', const Reglages().toMap());
      return const Reglages();
    }
    return Reglages.fromMap(maps.first);
  }

  Future<int> updateReglages(Reglages r) async {
    final res = await db.update('reglages', r.toMap(),
        where: 'id = ?', whereArgs: [r.id]);
    DataBus.instance.notify(DataTopics.reglages);
    return res;
  }
}
