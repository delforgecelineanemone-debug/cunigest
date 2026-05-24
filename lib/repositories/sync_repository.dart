// ──────────────────────────────────────────────────────────────
// Repository : Synchronisation cloud
// ──────────────────────────────────────────────────────────────
// Gère la file `sync_queue` qui contient les modifications
// locales en attente d'envoi vers le serveur Supabase.
//
// Chaque INSERT/UPDATE/DELETE doit pousser une entrée ici via
// `enqueue(...)`. Le SyncService consomme la file quand connecté.
// ──────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../models/sync_entry.dart';
import '../services/data_bus.dart';

class SyncRepository {
  final Database db;
  SyncRepository(this.db);

  /// Enregistre une opération à synchroniser
  Future<int> enqueue({
    required String tableName,
    required int rowId,
    required String operation, // 'insert' | 'update' | 'delete'
    required Map<String, dynamic> payload,
  }) async {
    final id = await db.insert('sync_queue', {
      'table_name': tableName,
      'row_id': rowId,
      'operation': operation,
      'payload_json': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
    });
    // Permet à SyncScreen (compteur "en attente") + auto-push de réagir.
    DataBus.instance.notify(DataTopics.syncQueue);
    return id;
  }

  /// Délais (secondes) avant nouvelle tentative selon `retry_count`.
  /// Backoff exponentiel : 1 → 2 → 4 → 8 → 30 → 120 → 600s. Au-delà,
  /// reste à 600s (10 min). Évite de marteler un serveur en panne.
  static const List<int> kBackoffSeconds = [1, 2, 4, 8, 30, 120, 600];

  /// Calcule le timestamp ISO avant lequel l'entry ne sera pas re-tentée.
  static String _computeNextRetryAt(int retryCount) {
    final idx = (retryCount - 1).clamp(0, kBackoffSeconds.length - 1);
    final delay = kBackoffSeconds[idx];
    return DateTime.now()
        .toUtc()
        .add(Duration(seconds: delay))
        .toIso8601String();
  }

  /// Récupère les entrées non encore synchronisées, en excluant
  /// les entrées qui ont dépassé la limite de tentatives OU qui sont
  /// encore en cooldown (backoff exponentiel).
  Future<List<SyncEntry>> getPending({int limit = 50, int maxRetries = 10}) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final maps = await db.query(
      'sync_queue',
      where:
          'synced_at IS NULL AND retry_count <= ? AND (next_retry_at IS NULL OR next_retry_at <= ?)',
      whereArgs: [maxRetries, nowIso],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return maps.map((m) => SyncEntry.fromMap(m)).toList();
  }

  /// Compte les entrées définitivement abandonnées (dépassé [maxRetries]).
  Future<int> countAbandoned({int maxRetries = 10}) async {
    final r = await db.rawQuery(
      'SELECT COUNT(*) as c FROM sync_queue WHERE synced_at IS NULL AND retry_count > ?',
      [maxRetries],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  /// Compte les entrées en attente
  Future<int> countPending() async {
    final r = await db.rawQuery(
      'SELECT COUNT(*) as c FROM sync_queue WHERE synced_at IS NULL',
    );
    return (r.first['c'] as int?) ?? 0;
  }

  /// Marque une entrée comme synchronisée
  Future<int> markSynced(int id) async {
    final r = await db.update(
      'sync_queue',
      {'synced_at': DateTime.now().toIso8601String(), 'error_message': null},
      where: 'id = ?',
      whereArgs: [id],
    );
    DataBus.instance.notify(DataTopics.syncQueue);
    return r;
  }

  /// Marque une entrée comme échouée (incrémente retry_count, planifie
  /// la prochaine tentative selon le backoff exponentiel).
  Future<int> markFailed(int id, String error) async {
    // 1. Incrémente retry_count + stocke l'erreur
    await db.rawUpdate('''
      UPDATE sync_queue
      SET error_message = ?, retry_count = retry_count + 1
      WHERE id = ?
    ''', [error, id]);
    // 2. Calcule next_retry_at d'après le nouveau retry_count
    final rows = await db.query('sync_queue',
        columns: ['retry_count'], where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isNotEmpty) {
      final n = (rows.first['retry_count'] as int?) ?? 1;
      final nextRetry = _computeNextRetryAt(n);
      await db.update(
        'sync_queue',
        {'next_retry_at': nextRetry},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    DataBus.instance.notify(DataTopics.syncQueue);
    return 1;
  }

  /// Supprime les entrées synchronisées de plus de N jours
  Future<int> nettoyer({int joursRetention = 30}) async {
    final limite = DateTime.now()
        .subtract(Duration(days: joursRetention))
        .toIso8601String();
    return db.delete(
      'sync_queue',
      where: 'synced_at IS NOT NULL AND synced_at < ?',
      whereArgs: [limite],
    );
  }

  /// Configuration de sync
  Future<SyncConfig> getConfig() async {
    final maps =
        await db.query('sync_config', where: 'id = ?', whereArgs: [1], limit: 1);
    if (maps.isEmpty) {
      await db.insert('sync_config', const SyncConfig().toMap());
      return const SyncConfig();
    }
    return SyncConfig.fromMap(maps.first);
  }

  Future<int> updateConfig(SyncConfig c) async {
    final r =
        await db.update('sync_config', c.toMap(), where: 'id = ?', whereArgs: [1]);
    DataBus.instance.notify(DataTopics.syncConfig);
    return r;
  }

  // ═══════════════════════════════════════════════════════════
  // CONFLICT LOG — audit des écrasements LWW au pull cloud
  // ═══════════════════════════════════════════════════════════

  /// Enregistre une trace d'écrasement détecté lors du pull cloud.
  /// L'appelant doit s'assurer que c'est bien un cas de remote > local
  /// (sinon le log devient bruit).
  ///
  /// Si [executor] est fourni (transaction en cours), l'insert s'y fait
  /// pour garantir l'atomicité avec l'écrasement (soit le log ET l'update
  /// sont commit ensemble, soit aucun des deux).
  Future<int> recordConflict({
    required String tableName,
    required int rowId,
    String? localUpdatedAt,
    String? remoteUpdatedAt,
    DatabaseExecutor? executor,
  }) async {
    final exec = executor ?? db;
    return exec.insert('conflict_log', {
      'table_name': tableName,
      'row_id': rowId,
      'local_updated_at': localUpdatedAt,
      'remote_updated_at': remoteUpdatedAt,
      'detected_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Rotation FIFO : ne garde que les `keep` plus récents conflits.
  /// À appeler depuis SyncService après chaque pull (hors transaction).
  Future<int> pruneConflicts({int keep = 200}) async {
    return db.rawDelete('''
      DELETE FROM conflict_log
      WHERE id NOT IN (
        SELECT id FROM conflict_log ORDER BY detected_at DESC LIMIT ?
      )
    ''', [keep]);
  }

  /// Nombre total de conflits dans le log.
  Future<int> countConflicts() async {
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM conflict_log');
    return (r.first['c'] as int?) ?? 0;
  }

  /// N derniers conflits, du plus récent au plus ancien.
  Future<List<ConflictEntry>> getRecentConflicts({int limit = 20}) async {
    final rows = await db.query(
      'conflict_log',
      orderBy: 'detected_at DESC',
      limit: limit,
    );
    return rows.map(ConflictEntry.fromMap).toList();
  }

  /// Vide complètement le log (action utilisateur explicite).
  Future<int> clearConflicts() async {
    final n = await db.delete('conflict_log');
    return n;
  }
}
