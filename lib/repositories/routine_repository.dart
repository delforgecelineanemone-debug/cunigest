// ──────────────────────────────────────────────────────────────
// Repository : Routines — Tâches quotidiennes (V3.0)
// ──────────────────────────────────────────────────────────────

import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/tache.dart';
import '../services/data_bus.dart';

class RoutineRepository {
  final Database db;
  RoutineRepository(this.db);

  Future<List<Tache>> getTachesActives() async {
    final maps = await db.query('taches_quotidiennes',
        where: "est_active = 1 AND (statut IS NULL OR statut != 'reporte')",
        orderBy: 'priorite DESC, heure_rappel ASC');
    return maps.map((m) => Tache.fromMap(m)).toList();
  }

  /// Liste des tâches mises de côté ('reporte') — pour réactivation manuelle.
  Future<List<Tache>> getTachesReportees() async {
    final maps = await db.query('taches_quotidiennes',
        where: "est_active = 1 AND statut = 'reporte'",
        orderBy: 'priorite DESC, heure_rappel ASC');
    return maps.map((m) => Tache.fromMap(m)).toList();
  }

  Future<List<Tache>> getTachesDuJour() async {
    final now = DateTime.now();
    final todayStr = now.toIso8601String().substring(0, 10);
    final maps = await db.query('taches_quotidiennes',
        where: 'est_active = 1', orderBy: 'priorite DESC, heure_rappel ASC');
    final taches = maps.map((m) => Tache.fromMap(m)).toList();

    final lundi = now.subtract(Duration(days: now.weekday - 1));
    final lundiStr = lundi.toIso8601String().substring(0, 10);
    final dimancheStr = lundi.add(const Duration(days: 6)).toIso8601String().substring(0, 10);
    final premierMois = DateTime(now.year, now.month, 1);
    final premierMoisStr = premierMois.toIso8601String().substring(0, 10);
    final dernierMois = DateTime(now.year, now.month + 1, 0);
    final dernierMoisStr = dernierMois.toIso8601String().substring(0, 10);

    final result = <Tache>[];
    for (final t in taches) {
      final completeeAujourdhui = await _hasCompletion(t.id!, todayStr, todayStr);
      switch (t.recurrence) {
        case 'quotidien':
          result.add(t);
          break;
        case 'hebdomadaire':
          final completeeSemaine = await _hasCompletion(t.id!, lundiStr, dimancheStr);
          if (!completeeSemaine || completeeAujourdhui) result.add(t);
          break;
        case 'mensuel':
          final completeeMois = await _hasCompletion(t.id!, premierMoisStr, dernierMoisStr);
          if (!completeeMois || completeeAujourdhui) result.add(t);
          break;
        case 'ponctuel':
          if (t.dateCreation == todayStr || completeeAujourdhui) result.add(t);
          break;
        default:
          result.add(t);
      }
    }
    return result;
  }

  Future<bool> _hasCompletion(int tacheId, String from, String to) async {
    final rows = await db.rawQuery(
      'SELECT 1 FROM completions WHERE tache_id = ? AND date_completion BETWEEN ? AND ? LIMIT 1',
      [tacheId, from, to],
    );
    return rows.isNotEmpty;
  }

  Future<int> insertTache(Tache t) async {
    final id = await db.insert('taches_quotidiennes', t.toMap());
    DataBus.instance.notify(DataTopics.taches);
    return id;
  }

  Future<int> updateTache(Tache t) async {
    final r = await db.update('taches_quotidiennes', t.toMap(),
        where: 'id = ?', whereArgs: [t.id]);
    DataBus.instance.notify(DataTopics.taches);
    return r;
  }

  Future<int> deleteTache(int id) async {
    final r = await db.delete('taches_quotidiennes',
        where: 'id = ?', whereArgs: [id]);
    DataBus.instance.notify(DataTopics.taches);
    return r;
  }

  Future<bool> estTacheCompletee(int tacheId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final result = await db.query('completions',
        where: 'tache_id = ? AND date_completion = ?', whereArgs: [tacheId, today]);
    return result.isNotEmpty;
  }

  Future<int> completerTache(int tacheId, {String? notes}) async {
    final now = DateTime.now();
    final id = await db.insert('completions', {
      'tache_id': tacheId,
      'date_completion': now.toIso8601String().substring(0, 10),
      'heure_completion': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      'notes': notes,
    });
    DataBus.instance.notify(DataTopics.completions);
    DataBus.instance.notify(DataTopics.taches);
    return id;
  }

  Future<int> deCompleterTache(int tacheId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final r = await db.delete('completions',
        where: 'tache_id = ? AND date_completion = ?', whereArgs: [tacheId, today]);
    DataBus.instance.notify(DataTopics.completions);
    DataBus.instance.notify(DataTopics.taches);
    return r;
  }

  Future<Set<int>> getTachesCompleteesAujourdhui() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final maps = await db.query('completions', where: 'date_completion = ?', whereArgs: [today]);
    return maps.map((m) => m['tache_id'] as int).toSet();
  }

  Future<int> countCompletions(String date) async {
    final result = await db.rawQuery(
        'SELECT COUNT(DISTINCT tache_id) as count FROM completions WHERE date_completion = ?', [date]);
    return result.first['count'] as int;
  }
}
