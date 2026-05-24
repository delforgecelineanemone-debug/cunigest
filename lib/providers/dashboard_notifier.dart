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

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/db_helper.dart';
import '../models/lot.dart';
import '../models/soin.dart';
import '../models/stock.dart';
import '../services/data_bus.dart';

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
  StreamSubscription<String>? _sub;
  Timer? _debounce;

  @override
  Future<DashboardData> build() {
    // S'abonne au DataBus pour les tables qui alimentent le dashboard.
    // Le ref.onDispose annule la souscription quand le provider est détruit.
    _sub?.cancel();
    _sub = DataBus.instance.subscribe(
      const [
        DataTopics.lapins,
        DataTopics.ventes,
        DataTopics.soins,
        DataTopics.stocks,
        DataTopics.lots,
        DataTopics.saillies,
        DataTopics.distributionsAliment,
      ],
      (_) => _scheduleRefresh(),
    );
    ref.onDispose(() {
      _sub?.cancel();
      _debounce?.cancel();
    });
    return _load();
  }

  /// Coalesce plusieurs broadcasts rapprochés en un seul refresh
  /// (ex. une vente écrit dans `ventes` + `lapins` simultanément).
  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 50), refresh);
  }

  Future<DashboardData> _load() async {
    final db = DBHelper.instance;
    final (soinsRepo, stocksRepo, lapinsRepo, ventesRepo) =
        await (db.soins, db.stocks, db.lapins, db.ventes).wait;

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
      soinsRepo.getRappelsProchains(7),
      stocksRepo.getStocksCritiques(),
      lapinsRepo.getStatistiquesLapins(),
      ventesRepo.getStatistiquesVentes(),
      lapinsRepo.naissancesParMois(1),
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
  /// On garde la donnée précédente affichée pendant le re-chargement
  /// pour éviter un flash. Le widget peut ajouter `skipLoadingOnRefresh: true`.
  Future<void> refresh() async {
    // Préserve l'état "data" actuel pendant le refresh — le when()
    // côté widget gardera l'ancien snapshot affiché si on utilise
    // skipLoadingOnRefresh: true.
    state = await AsyncValue.guard(_load);
  }
}

final dashboardProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardData>(
        DashboardNotifier.new);
