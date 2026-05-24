// ──────────────────────────────────────────────────────────────
// Sync metadata helper — `updated_at` + soft-delete pour les repos
// ──────────────────────────────────────────────────────────────
// Centralise la gestion des deux colonnes de sync présentes sur
// toutes les tables synchronisables (cf. `kSoftDeleteTables`) :
//   - `updated_at` : timestamp ISO-8601 à chaque insert/update
//   - `deleted_at` : timestamp ISO-8601 lors d'une suppression
//
// Avantage : empêche la perte de données offline (soft-delete) et
// permet last-write-wins fiable au pull cloud (updated_at comparé).
// ──────────────────────────────────────────────────────────────

import 'package:sqflite_sqlcipher/sqflite.dart';

/// Étend un payload `Map<String, dynamic>` avec `updated_at = now()`.
/// À appeler juste avant tout `db.insert` / `db.update` sur une table sync.
Map<String, dynamic> stampUpdated(Map<String, dynamic> payload) {
  final now = DateTime.now().toUtc().toIso8601String();
  return {
    ...payload,
    'updated_at': now,
  };
}

/// Renvoie le timestamp courant ISO-8601 UTC. Utile pour les payloads sync.
String nowIso() => DateTime.now().toUtc().toIso8601String();

/// Soft-delete : met `deleted_at = now()` et `updated_at = now()`.
/// Retourne 1 si la row existait, 0 sinon.
Future<int> softDelete(Database db, String table, int id) async {
  final now = nowIso();
  return db.update(
    table,
    {'deleted_at': now, 'updated_at': now},
    where: 'id = ?',
    whereArgs: [id],
  );
}

/// Clause WHERE par défaut à ajouter à toutes les requêtes SELECT
/// pour exclure les rows soft-deleted. Concaténer avec votre own where.
const String kNotDeletedWhere = 'deleted_at IS NULL';

/// Combine une condition optionnelle avec le filtre `deleted_at IS NULL`.
/// Ex: `whereNotDeleted('statut = ?')` → `'statut = ? AND deleted_at IS NULL'`.
String whereNotDeleted([String? extra]) {
  if (extra == null || extra.trim().isEmpty) return kNotDeletedWhere;
  return '($extra) AND $kNotDeletedWhere';
}
