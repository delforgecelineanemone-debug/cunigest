// ──────────────────────────────────────────────────────────────
// DashboardNotifier — Logique de chargement du tableau de bord (B.5)
// ──────────────────────────────────────────────────────────────
// Extrait la logique de _loadLocalData() hors du widget DashboardScreen
// dans un AsyncNotifier testable indépendamment de l'UI.
//
// DashboardData   : snapshot immuable des données du tableau de bord.
// DashboardNotifier : charge les données en parallèle via DBHelper.
//
// Usage dans DashboardScreen :
//   final dashAsync = ref.watch(dashboardProvider);
//   dashAsync.when(
//     skipLoadingOnRefresh: true,
//     loading: () => ...,
//     error: (e, _) => ...,
//     data: (data) => _buildBody(data),
//   );
// ──────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/db_helper.dart';
import '../models/lot.dart';
import '../models/soin.dart';
import '../models/stock.dart';

// ── Snapshot des données du tableau de bord ──────────────────

class DashboardData {
  final Map<String, int> statsLapins;
  final Map<String, int> repartitionStatuts;
  final Map<String, dynamic> statsVentes;
  final int naissancesMois;
  final int lapereauxEnElevage;
  final List<Soin> rappels;
  final List<Stock> stocksCritiques;
  final List<Lot> lotsActifs;

  const DashboardData({
    required this.statsLapins,
    required this.repartitionStatuts,
    required this.statsVentes,
    required this.naissancesMois,
    required this.lapereauxEnElevage,
    required this.rappels,
    required this.stocksCritiques,
    required this.lotsActifs,
  });
}

// ── Notifier ──────────────────────────────────────────────────

class DashboardNotifier extends AsyncNotifier<DashboardData> {
  @override
  Future<DashboardData> build() => _load();

  Future<DashboardData> _load() async {
    final db = DBHelper.instance;

    final lotsF = db.lots.then((r) => r.getEnCours());
    final repartitionF = db.database
        .then((d) => d.rawQuery(
              'SELECT statut, COUNT(*) as c FROM lapins GROUP BY statut',
            ))
        .then((rows) => <String, int>{
              for (final r in rows)
                (r['statut'] as String): (r['c'] as int? ?? 0),
            });

    final (rappels, stocks, lapinsStats, ventes, naissances, lots, repartition) =
        await (
      db.getRappelsProchains(7),
      db.getStocksCritiques(),
      db.getStatistiquesLapins(),
      db.getStatistiquesVentes(),
      db.naissancesParMois(1),
      lotsF,
      repartitionF,
    ).wait;

    final totalLapereaux =
        lots.fold<int>(0, (sum, l) => sum + l.nombreInitial);

    return DashboardData(
      rappels: rappels,
      stocksCritiques: stocks,
      statsLapins: lapinsStats,
      statsVentes: ventes,
      naissancesMois:
          naissances.values.isEmpty ? 0 : naissances.values.last,
      lotsActifs: lots.take(3).toList(),
      lapereauxEnElevage: totalLapereaux,
      repartitionStatuts: repartition,
    );
  }

  /// Force le rechargement complet (pull-to-refresh, retour de sous-écran).
  /// [skipLoadingOnRefresh] dans le widget évite le flash de chargement.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }
}

final dashboardProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardData>(
        DashboardNotifier.new);
