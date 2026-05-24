// ──────────────────────────────────────────────────────────────
// Service : KPI métier — instrumentation locale (audit observabilité)
// ──────────────────────────────────────────────────────────────
// Compte les événements métier clés (création de lapin, saillie,
// vente, sync…) dans un fichier JSON local. 100 % hors-ligne : aucun
// envoi réseau, aucune donnée personnelle — uniquement des compteurs.
//
// Objectif : disposer de chiffres d'usage pour orienter les décisions
// produit (quelles fonctions servent vraiment, fréquence des sync…).
//
// Usage :
//   KpiService.instance.track(KpiEvent.lapinCree);   // fire-and-forget
//   final stats = await KpiService.instance.snapshot();
// ──────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Événements métier suivis. Ajouter ici toute nouvelle métrique.
enum KpiEvent {
  lapinCree('lapin_cree'),
  saillieEnregistree('saillie_enregistree'),
  soinEnregistre('soin_enregistre'),
  venteEnregistree('vente_enregistree'),
  syncReussie('sync_reussie'),
  syncEchouee('sync_echouee'),
  sauvegardeCreee('sauvegarde_creee');

  const KpiEvent(this.code);

  /// Clé stable utilisée dans le fichier JSON (ne pas renommer).
  final String code;
}

class KpiService {
  static final KpiService instance = KpiService._();
  KpiService._();

  static const String _fileName = 'cunigest_kpi.json';

  /// Nombre de jours de détail quotidien conservés (au-delà : agrégé
  /// uniquement dans les totaux cumulés).
  static const int _dailyRetentionDays = 30;

  File? _file;
  Map<String, dynamic>? _cache;

  /// Initialise le chemin du fichier. À appeler après
  /// WidgetsFlutterBinding.ensureInitialized() (typiquement au démarrage).
  Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File(p.join(dir.path, _fileName));
    } catch (e) {
      debugPrint('KpiService init échoué : $e');
    }
  }

  /// Enregistre une occurrence d'[event]. Fire-and-forget : ne lève
  /// jamais d'exception, ne bloque jamais l'opération métier appelante.
  Future<void> track(KpiEvent event, {int count = 1}) async {
    try {
      final file = _file ?? await _ensureFile();
      if (file == null) return;

      final data = await _load(file);
      final today = _todayKey();

      final totals = (data['totals'] as Map?)?.cast<String, dynamic>() ?? {};
      totals[event.code] = ((totals[event.code] as int?) ?? 0) + count;
      data['totals'] = totals;

      final daily = (data['daily'] as Map?)?.cast<String, dynamic>() ?? {};
      final dayMap =
          (daily[today] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      dayMap[event.code] = ((dayMap[event.code] as int?) ?? 0) + count;
      daily[today] = dayMap;
      _pruneDaily(daily);
      data['daily'] = daily;

      data['firstSeen'] ??= DateTime.now().toUtc().toIso8601String();
      data['lastSeen'] = DateTime.now().toUtc().toIso8601String();

      _cache = data;
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('KpiService.track échoué : $e');
    }
  }

  /// Renvoie un instantané des compteurs : totaux cumulés + détail des
  /// 30 derniers jours. Map vide si rien n'a encore été enregistré.
  Future<Map<String, dynamic>> snapshot() async {
    try {
      final file = _file ?? await _ensureFile();
      if (file == null) return const {};
      return await _load(file);
    } catch (_) {
      return const {};
    }
  }

  /// Total cumulé pour un événement donné.
  Future<int> totalFor(KpiEvent event) async {
    final data = await snapshot();
    final totals = (data['totals'] as Map?)?.cast<String, dynamic>() ?? {};
    return (totals[event.code] as int?) ?? 0;
  }

  /// Efface tous les compteurs.
  Future<void> reset() async {
    _cache = null;
    try {
      final file = _file ?? await _ensureFile();
      if (file != null && await file.exists()) await file.delete();
    } catch (_) {/* non critique */}
  }

  // ── Interne ─────────────────────────────────────────────────

  Future<File?> _ensureFile() async {
    if (_file != null) return _file;
    await init();
    return _file;
  }

  Future<Map<String, dynamic>> _load(File file) async {
    if (_cache != null) return _cache!;
    try {
      if (await file.exists()) {
        final raw = await file.readAsString();
        if (raw.trim().isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            _cache = decoded;
            return decoded;
          }
        }
      }
    } catch (_) {/* fichier illisible → on repart à vide */}
    _cache = <String, dynamic>{};
    return _cache!;
  }

  String _todayKey() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  /// Retire du détail quotidien les jours plus vieux que la rétention.
  void _pruneDaily(Map<String, dynamic> daily) {
    if (daily.length <= _dailyRetentionDays) return;
    final cutoff = DateTime.now().subtract(
      const Duration(days: _dailyRetentionDays),
    );
    daily.removeWhere((key, _) {
      final day = DateTime.tryParse(key);
      return day != null && day.isBefore(cutoff);
    });
  }
}
