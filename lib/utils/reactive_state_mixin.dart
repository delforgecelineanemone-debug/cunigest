// ──────────────────────────────────────────────────────────────
// ReactiveStateMixin — auto-refresh via DataBus (V3.0)
// ──────────────────────────────────────────────────────────────
// Mixin pour les écrans `StatefulWidget` classiques qui veulent se
// rafraîchir automatiquement quand certaines tables changent —
// sans avoir à migrer en `ConsumerWidget` ni à toucher au reste
// du code.
//
// Usage :
//   class _MonEcranState extends State<MonEcran>
//       with ReactiveStateMixin<MonEcran> {
//
//     @override
//     List<String> get watchedTopics =>
//         [DataTopics.lapins, DataTopics.saillies];
//
//     @override
//     Future<void> onReactiveRefresh() => _load();
//   }
//
// Comportement :
//   - Souscription installée dans initState, annulée dans dispose
//   - `onReactiveRefresh` est appelé à chaque event matching (debounced)
//   - L'écran fait `setState()` dans son `_load()` — rien de plus
// ──────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/widgets.dart';
import '../services/data_bus.dart';

mixin ReactiveStateMixin<T extends StatefulWidget> on State<T> {
  StreamSubscription<String>? _busSub;
  Timer? _busDebounce;

  /// Liste des topics à observer (ex. `[DataTopics.lapins]`).
  List<String> get watchedTopics;

  /// Appelé automatiquement après chaque broadcast matching.
  /// Implémenter en appelant simplement `_load()` ou équivalent.
  Future<void> onReactiveRefresh();

  /// Délai de debounce (par défaut 60 ms) — coalesce les broadcasts
  /// rapprochés (ex. vente touche `ventes` + `lapins`).
  Duration get reactiveRefreshDebounce => const Duration(milliseconds: 60);

  @override
  void initState() {
    super.initState();
    _busSub = DataBus.instance
        .subscribe(watchedTopics, (_) => _scheduleReactiveRefresh());
  }

  void _scheduleReactiveRefresh() {
    _busDebounce?.cancel();
    _busDebounce = Timer(reactiveRefreshDebounce, () {
      if (!mounted) return;
      onReactiveRefresh();
    });
  }

  @override
  void dispose() {
    _busSub?.cancel();
    _busDebounce?.cancel();
    super.dispose();
  }
}
