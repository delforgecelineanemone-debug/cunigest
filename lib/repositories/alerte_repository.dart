// ──────────────────────────────────────────────────────────────
// Repository : Alertes — Notifications intelligentes (V3.0)
// ──────────────────────────────────────────────────────────────

import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/alerte.dart';
import '../models/lapin.dart';

class AlerteRepository {
  final Database db;
  AlerteRepository(this.db);

  Future<int> insertAlerte(Alerte a) async {
    return db.insert('alertes', a.toMap());
  }

  Future<List<Alerte>> getAlertesActives() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final maps = await db.query('alertes',
        where: 'est_traitee = 0 AND date_alerte <= ?',
        whereArgs: [today],
        orderBy: "CASE priorite WHEN 'critique' THEN 0 WHEN 'important' THEN 1 ELSE 2 END, date_alerte ASC");
    return maps.map((m) => Alerte.fromMap(m)).toList();
  }

  Future<int> countAlertesNonLues() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM alertes WHERE est_lue = 0 AND est_traitee = 0 AND date_alerte <= ?',
        [today]);
    return result.first['count'] as int;
  }

  Future<int> marquerAlerteLue(int id) async {
    return db.update('alertes', {'est_lue': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> marquerAlerteTraitee(int id) async {
    return db.update('alertes', {'est_traitee': 1, 'est_lue': 1}, where: 'id = ?', whereArgs: [id]);
  }

  /// Supprime les alertes traitées de plus de 30 jours
  Future<int> nettoyerAlertes() async {
    final limite = DateTime.now().subtract(const Duration(days: 30))
        .toIso8601String().substring(0, 10);
    return db.delete('alertes',
        where: 'est_traitee = 1 AND date_alerte < ?', whereArgs: [limite]);
  }

  /// Génère les alertes automatiques depuis les saillies en attente.
  /// Idempotent : les alertes déjà existantes ne sont pas dupliquées.
  /// Nécessite les listes de saillies et lapins pour éviter un couplage circulaire.
  Future<void> genererAlertesReproduction({
    required List<Map<String, dynamic>> sailliesMaps,
    required Map<int, Lapin> lapinsMap,
  }) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final todayDate = DateTime.now();

    Future<bool> alerteExiste(int saillieId, String type) async {
      final existing = await db.query('alertes',
          where: 'reference_id = ? AND reference_type = ? AND type = ?',
          whereArgs: [saillieId, 'saillie', type]);
      return existing.isNotEmpty;
    }

    for (final s in sailliesMaps) {
      if (s['statut'] != 'en_attente') continue;
      final dateSaillie = DateTime.tryParse(s['date_saillie'] as String? ?? '');
      if (dateSaillie == null) continue;

      final sId = s['id'] as int;
      final mereId = s['mere_id'] as int;
      final mereNom = lapinsMap[mereId]?.displayName ?? 'Lapine';
      final joursDepuis = todayDate.difference(dateSaillie).inDays;

      if (joursDepuis >= 10 && joursDepuis <= 14 && !await alerteExiste(sId, 'palpation')) {
        await insertAlerte(Alerte(
          type: 'palpation',
          titre: '🤚 Palper $mereNom',
          message: 'La palpation de $mereNom est prévue (J+$joursDepuis après saillie du ${s['date_saillie']})',
          priorite: joursDepuis >= 12 ? 'critique' : 'important',
          dateAlerte: today,
          referenceId: sId,
          referenceType: 'saillie',
        ));
      }

      if (joursDepuis >= 27 && joursDepuis <= 29 && !await alerteExiste(sId, 'nid')) {
        await insertAlerte(Alerte(
          type: 'nid',
          titre: '🏠 Poser le nid pour $mereNom',
          message: 'Il faut préparer le nid de mise bas pour $mereNom (J+$joursDepuis)',
          priorite: 'critique',
          dateAlerte: today,
          referenceId: sId,
          referenceType: 'saillie',
        ));
      }

      if (joursDepuis >= 30 && joursDepuis <= 33 && !await alerteExiste(sId, 'mise_bas')) {
        await insertAlerte(Alerte(
          type: 'mise_bas',
          titre: '🐣 Mise bas imminente : $mereNom',
          message: 'La mise bas de $mereNom est prévue ! (J+$joursDepuis). Surveillez-la de près.',
          priorite: 'critique',
          dateAlerte: today,
          referenceId: sId,
          referenceType: 'saillie',
        ));
      }
    }

    // ── Alertes POST-mise-bas (mamelles, pesée lapereaux, sevrage) ──
    // Un type distinct par étape pour idempotence simple via alerteExiste().
    // typeIcon mappe mamelles_j4/j10/j20 → 🩺, sevrage_j21/j28 → 🍼.
    for (final s in sailliesMaps) {
      final dateMiseBasStr = s['date_mise_bas_reelle'] as String?;
      if (dateMiseBasStr == null || dateMiseBasStr.isEmpty) continue;
      final statut = s['statut'] as String?;
      if (statut != 'mise_bas' && statut != 'sevrage') continue;

      final dateMiseBas = DateTime.tryParse(dateMiseBasStr);
      if (dateMiseBas == null) continue;

      final sId = s['id'] as int;
      final mereId = s['mere_id'] as int;
      final mereNom = lapinsMap[mereId]?.displayName ?? 'Lapine';
      final j = todayDate.difference(dateMiseBas).inDays;

      if (j >= 4 && j <= 5 && !await alerteExiste(sId, 'mamelles_j4')) {
        await insertAlerte(Alerte(
          type: 'mamelles_j4',
          titre: '🩺 Contrôle mamelles : $mereNom',
          message: 'Mise bas il y a $j jours. Vérifier l\'absence de mammite (J+4).',
          priorite: 'important',
          dateAlerte: today,
          referenceId: sId,
          referenceType: 'saillie',
        ));
      }

      if (j >= 7 && j <= 8 && !await alerteExiste(sId, 'pesee_lapereaux')) {
        await insertAlerte(Alerte(
          type: 'pesee_lapereaux',
          titre: '⚖️ Pesée lapereaux : portée de $mereNom',
          message: 'J+$j après mise bas. Peser les lapereaux (objectif > 80g chacun).',
          priorite: 'important',
          dateAlerte: today,
          referenceId: sId,
          referenceType: 'saillie',
        ));
      }

      if (j >= 10 && j <= 11 && !await alerteExiste(sId, 'mamelles_j10')) {
        await insertAlerte(Alerte(
          type: 'mamelles_j10',
          titre: '🩺 Contrôle mamelles (J+10) : $mereNom',
          message: 'Vérifier mamelles et état général de la mère (J+$j).',
          priorite: 'normal',
          dateAlerte: today,
          referenceId: sId,
          referenceType: 'saillie',
        ));
      }

      if (j >= 20 && j <= 21 && !await alerteExiste(sId, 'mamelles_j20')) {
        await insertAlerte(Alerte(
          type: 'mamelles_j20',
          titre: '🩺 Contrôle mamelles (J+20) : $mereNom',
          message: 'Dernier contrôle mamelles avant sevrage (J+$j).',
          priorite: 'normal',
          dateAlerte: today,
          referenceId: sId,
          referenceType: 'saillie',
        ));
      }

      // V14 — fenêtres décalées : sevrage cuniculture africaine J+35 → J+42
      if (j >= 33 && j <= 35 && !await alerteExiste(sId, 'sevrage_j35')) {
        await insertAlerte(Alerte(
          type: 'sevrage_j35',
          titre: '🍼 Sevrage approche : $mereNom',
          message: 'J+$j. Préparer le sevrage (séparation mère/lapereaux) à J+35-42.',
          priorite: 'important',
          dateAlerte: today,
          referenceId: sId,
          referenceType: 'saillie',
        ));
      }

      if (j >= 40 && j <= 42 && !await alerteExiste(sId, 'sevrage_j42')) {
        await insertAlerte(Alerte(
          type: 'sevrage_j42',
          titre: '🍼 Sevrer la portée de $mereNom',
          message: 'J+$j après mise bas. Séparer la mère, peser le lot, traitement anti-coccidien dans l\'eau.',
          priorite: 'critique',
          dateAlerte: today,
          referenceId: sId,
          referenceType: 'saillie',
        ));
      }

      // ── V13 : sexage J+60 — individualiser le lot ──
      // Crée une seule alerte (fenêtre J+58 → J+90) qui invite à baguer
      // chaque lapereau et déterminer son sexe. La référence pointe sur
      // le lot auto-créé (si présent), sinon sur la saillie.
      if (j >= 58 && j <= 90 && !await alerteExiste(sId, 'sexage_j60')) {
        final lotId = s['lot_id'] as int?;
        await insertAlerte(Alerte(
          type: 'sexage_j60',
          titre: '🏷️ Sexage de la portée de $mereNom',
          message:
              'Lapereaux à J+$j. C\'est le moment de les baguer individuellement et de noter le sexe de chacun.',
          priorite: 'important',
          dateAlerte: today,
          referenceId: lotId ?? sId,
          referenceType: lotId != null ? 'lot' : 'saillie',
        ));
      }
    }
  }
}
