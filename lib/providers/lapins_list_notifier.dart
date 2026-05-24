// ──────────────────────────────────────────────────────────────
// LapinsListNotifier — données de l'écran liste des lapins (P1.8)
// ──────────────────────────────────────────────────────────────
// Extrait toute la logique de chargement / pagination / mapping cage
// hors de l'écran. L'écran reste responsable des filtres UI (search,
// statut, sexe) qui ne nécessitent pas un re-fetch DB.
//
// Réactivité : abonné au DataBus sur `lapins` + `cages` — un ajout/
// suppression/modification dans n'importe quel endroit de l'app
// rafraîchit la liste automatiquement.
// ──────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/db_helper.dart';
import '../models/lapin.dart';
import '../services/data_bus.dart';

class LapinsListData {
  final List<Lapin> lapins;
  final Map<int, String> cageNumero;
  final bool hasMore;
  final bool loadingMore;

  const LapinsListData({
    this.lapins = const [],
    this.cageNumero = const {},
    this.hasMore = false,
    this.loadingMore = false,
  });

  LapinsListData copyWith({
    List<Lapin>? lapins,
    Map<int, String>? cageNumero,
    bool? hasMore,
    bool? loadingMore,
  }) =>
      LapinsListData(
        lapins: lapins ?? this.lapins,
        cageNumero: cageNumero ?? this.cageNumero,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

class LapinsListNotifier extends AsyncNotifier<LapinsListData> {
  static const int pageSize = 80;

  StreamSubscription<String>? _sub;
  Timer? _debounce;

  @override
  Future<LapinsListData> build() async {
    _sub?.cancel();
    _sub = DataBus.instance.subscribe(
      const [DataTopics.lapins, DataTopics.cages],
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

  Future<LapinsListData> _loadInitial() async {
    final db = DBHelper.instance;
    final lapins = await (await db.lapins).getAllLapins(limit: pageSize);
    final cagesRepo = await db.cages;
    final cages = await cagesRepo.getAllCages();
    final cageMap = {
      for (final c in cages)
        if (c.id != null) c.id!: c.numero,
    };
    return LapinsListData(
      lapins: lapins,
      cageNumero: cageMap,
      hasMore: lapins.length == pageSize,
    );
  }

  /// Recharge la 1ère page (et reset la pagination).
  Future<void> refresh() async {
    state = await AsyncValue.guard(_loadInitial);
  }

  /// Charge la page suivante (append). No-op si déjà en cours ou si plus
  /// rien à charger. Le filtre côté UI (search non vide) bloque l'appel
  /// en amont — pagination = mode "non filtré" uniquement.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await (await DBHelper.instance.lapins).getAllLapins(
        limit: pageSize,
        offset: current.lapins.length,
      );
      final updated = current.copyWith(
        lapins: [...current.lapins, ...next],
        hasMore: next.length == pageSize,
        loadingMore: false,
      );
      state = AsyncData(updated);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final lapinsListProvider =
    AsyncNotifierProvider<LapinsListNotifier, LapinsListData>(
        LapinsListNotifier.new);
