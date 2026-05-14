// ──────────────────────────────────────────────────────────────
// Providers Riverpod — Repositories (B.3)
// ──────────────────────────────────────────────────────────────
// FutureProvider pour chaque repository : évite de répéter
// `await DBHelper.instance.xxx` dans chaque widget.
//
// Usage :
//   final repo = await ref.read(lapinsRepositoryProvider.future);
//   // ou dans un AsyncNotifier :
//   final repo = await ref.read(lotsRepositoryProvider.future);
// ──────────────────────────────────────────────────────────────

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/db_helper.dart';

final lapinsRepositoryProvider =
    FutureProvider((ref) => DBHelper.instance.lapins);

final lotsRepositoryProvider =
    FutureProvider((ref) => DBHelper.instance.lots);

final cagesRepositoryProvider =
    FutureProvider((ref) => DBHelper.instance.cages);

final depensesRepositoryProvider =
    FutureProvider((ref) => DBHelper.instance.depenses);

final ventesRepositoryProvider =
    FutureProvider((ref) => DBHelper.instance.ventes);

final usersRepositoryProvider =
    FutureProvider((ref) => DBHelper.instance.users);
