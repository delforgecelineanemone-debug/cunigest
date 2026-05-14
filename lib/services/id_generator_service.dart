// ──────────────────────────────────────────────────────────────
// Service : Génération d'identifiants auto (V2.5 — Phase 4+)
// ──────────────────────────────────────────────────────────────
// Format unifié : <PREFIX>-AAAA-MM-NNN
//   - LP-2026-05-001  pour les lapins (numéro de bague auto)
//   - LT-2026-05-001  pour les lots
//
// Le compteur NNN est mensuel (3 chiffres → 999 max / mois).
// L'éleveur peut toujours surcharger la valeur dans le formulaire
// (compatibilité avec les bagues physiques existantes).
// ──────────────────────────────────────────────────────────────

import '../database/db_helper.dart';

class IdGeneratorService {
  IdGeneratorService._();

  /// Prochain numéro de bague disponible pour le mois en cours.
  /// Format : LP-AAAA-MM-NNN
  static Future<String> nextLapinId({DateTime? now}) async {
    final d = now ?? DateTime.now();
    final prefix = _prefixe('LP', d);
    final db = await DBHelper.instance.database;
    final rows = await db.rawQuery(
      'SELECT numero_bague FROM lapins WHERE numero_bague LIKE ? '
      'ORDER BY numero_bague DESC LIMIT 1',
      ['$prefix-%'],
    );
    final next = _incrementer(rows.isEmpty ? null : rows.first['numero_bague'] as String?);
    return '$prefix-$next';
  }

  /// Prochain code de lot disponible pour le mois en cours.
  /// Format : LT-AAAA-MM-NNN
  static Future<String> nextLotId({DateTime? now}) async {
    final d = now ?? DateTime.now();
    final prefix = _prefixe('LT', d);
    final db = await DBHelper.instance.database;
    final rows = await db.rawQuery(
      'SELECT code FROM lots WHERE code LIKE ? '
      'ORDER BY code DESC LIMIT 1',
      ['$prefix-%'],
    );
    final next = _incrementer(rows.isEmpty ? null : rows.first['code'] as String?);
    return '$prefix-$next';
  }

  // ── helpers ──

  static String _prefixe(String tag, DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    return '$tag-${d.year}-$mm';
  }

  /// Extrait le compteur (3 derniers chiffres) et l'incrémente.
  /// Renvoie '001' si l'ID est absent ou non parseable.
  static String _incrementer(String? lastId) {
    if (lastId == null || lastId.isEmpty) return '001';
    final parts = lastId.split('-');
    final tail = parts.isNotEmpty ? parts.last : '';
    final n = int.tryParse(tail) ?? 0;
    return (n + 1).toString().padLeft(3, '0');
  }
}
