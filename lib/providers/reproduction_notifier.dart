// ──────────────────────────────────────────────────────────────
// ReproductionNotifier — données de l'écran reproduction (P1.8)
// ──────────────────────────────────────────────────────────────
// Charge les saillies + la map des lapins parents pour l'affichage.
// Pagination 60/page. Réactivité auto via DataBus (saillies + lapins).
// ──────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/db_helper.dart';
import '../models/lapin.dart';
import '../models/saillie.dart';
import '../services/data_bus.dart';

class ReproductionData {
  final List<Saillie> saillies;
  final Map<int, Lapin> lapinsMap;
  final bool hasMore;
  final bool loadingMore;

  const ReproductionData({
    this.saillies = const [],
    this.lapinsMap = const {},
    this.hasMore = false,
    this.loadingMore = false,
  });

  int count(String statut) =>
      saillies.where((s) => s.statut == statut).length;

  ReproductionData copyWith({
    List<Saillie>? saillies,
    Map<int, Lapin>? lapinsMap,
    bool? hasMore,
    bool? loadingMore,
  }) =>
      ReproductionData(
        saillies: saillies ?? this.saillies,
        lapinsMap: lapinsMap ?? this.lapinsMap,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

class ReproductionNotifier extends AsyncNotifier<ReproductionData> {
  static const int pageSize = 60;

  StreamSubscription<String>? _sub;
  Timer? _debounce;

  @override
  Future<ReproductionData> build() async {
    _sub?.cancel();
    _sub = DataBus.instance.subscribe(
      const [DataTopics.saillies, DataTopics.lapins],
      (_) => _scheduleRefresh(),
    );
    ref.onDispose(() {
      _sub?.cancel();
      _debounce?.cancel();
    });
    return _loadInitial();
  }

  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 60), refresh);
  }

  Future<ReproductionData> _loadInitial() async {
    final saillies =
        await (await DBHelper.instance.saillies).getAllSaillies(limit: pageSize);
    final map = await _lapinsForSaillies(saillies);
    _enrichSaillies(saillies, map);
    return ReproductionData(
      saillies: saillies,
      lapinsMap: map,
      hasMore: saillies.length == pageSize,
    );
  }

  Future<Map<int, Lapin>> _lapinsForSaillies(List<Saillie> saillies) async {
    final repo = await DBHelper.instance.lapins;
    return repo.getLapinsByIds(
      saillies.expand((s) => [s.mereId, s.pereId]),
    );
  }

  void _enrichSaillies(List<Saillie> saillies, Map<int, Lapin> map) {
    for (final s in saillies) {
      s.mereNom = map[s.mereId]?.displayName ?? '?';
      s.pereNom = map[s.pereId]?.displayName ?? '?';
    }
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_loadInitial);
  }

  /// Append la page suivante de saillies (mode "tous" uniquement).
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await (await DBHelper.instance.saillies).getAllSaillies(
        limit: pageSize,
        offset: current.saillies.length,
      );
      final newMap = await _lapinsForSaillies(next);
      _enrichSaillies(next, newMap);
      final mergedMap = {...current.lapinsMap, ...newMap};
      state = AsyncData(current.copyWith(
        saillies: [...current.saillies, ...next],
        lapinsMap: mergedMap,
        hasMore: next.length == pageSize,
        loadingMore: false,
      ));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Map des lapins actifs (utilisée pour pré-remplir le formulaire saillie).
  Future<Map<int, Lapin>> lapinsActifsMap() async {
    final lapins =
        await (await DBHelper.instance.lapins).getLapinsByStatut('actif');
    return {for (final l in lapins) if (l.id != null) l.id!: l};
  }
}

final reproductionProvider =
    AsyncNotifierProvider<ReproductionNotifier, ReproductionData>(
        ReproductionNotifier.new);
