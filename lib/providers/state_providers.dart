// ──────────────────────────────────────────────────────────────
// Providers Riverpod — ChangeNotifier wrappers (B.2)
// ──────────────────────────────────────────────────────────────
// Stratégie : ChangeNotifierProvider<T> wraps les classes ChangeNotifier
// existantes sans les réécrire — migration progressive sans casser l'app.
//
// Usage dans un ConsumerWidget :
//   final session = ref.watch(sessionProvider);
//   ref.read(lapinsProvider.notifier).refresh();
// ──────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/app_state.dart';

final sessionProvider =
    ChangeNotifierProvider<SessionState>((ref) => SessionState());

final lapinsProvider =
    ChangeNotifierProvider<LapinsState>((ref) => LapinsState());

final profilProvider =
    ChangeNotifierProvider<ProfilState>((ref) => ProfilState());

final reglagesProvider =
    ChangeNotifierProvider<ReglagesState>((ref) => ReglagesState());

final alertesCountProvider =
    ChangeNotifierProvider<AlertesCountState>((ref) => AlertesCountState());
