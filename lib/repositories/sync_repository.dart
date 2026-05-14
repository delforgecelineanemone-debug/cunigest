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

class SyncRepository {
  final Database db;
  SyncRepository(this.db);

  /// Enregistre une opération à synchroniser
  Future<int> enqueue({
    required String tableName,
    required int rowId,
    required String operation, // 'insert' | 'update' | 'delete'
    required Map<String, dynamic> payload,
  }) {
    return db.insert('sync_queue', {
      'table_name': tableName,
      'row_id': rowId,
      'operation': operation,
      'payload_json': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
    });
  }

  /// Récupère les entrées non encore synchronisées, en excluant
  /// les entrées qui ont dépassé la limite de tentatives.
  Future<List<SyncEntry>> getPending({int limit = 50, int maxRetries = 10}) async {
    final maps = await db.query(
      'sync_queue',
      where: 'synced_at IS NULL AND retry_count <= ?',
      whereArgs: [maxRetries],
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
    return db.update(
      'sync_queue',
      {'synced_at': DateTime.now().toIso8601String(), 'error_message': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Marque une entrée comme échouée (incrémente retry_count)
  Future<int> markFailed(int id, String error) async {
    return db.rawUpdate('''
      UPDATE sync_queue
      SET error_message = ?, retry_count = retry_count + 1
      WHERE id = ?
    ''', [error, id]);
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
    return db.update('sync_config', c.toMap(), where: 'id = ?', whereArgs: [1]);
  }
}
