// ─────────────────────────────────────────────────────────────
// Widget test : SyncScreen (état initial = loading)
// ─────────────────────────────────────────────────────────────
// Sans DBHelper initialisé (impossible sous flutter_test sans
// hooks debug), l'écran reste à `_loading = true` car `_load()`
// échoue silencieusement. On vérifie donc l'AppBar + le spinner.
//
// Les tests "tap Sauvegarder maintenant" et "tap Délier" ne sont
// PAS faits ici — ils nécessitent un fake SyncService injectable.
// Reportés à E.2 (tests services) ou à une future itération E.3
// avec hooks debugSetInstance sur les services.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/features/sync/sync_screen.dart';

void main() {
  setUp(() {
    FlutterError.onError = (_) {};
  });

  Future<void> pumpSync(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SyncScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('AppBar affiche le titre "Sauvegarde cloud" avec l\'emoji ☁️',
      (tester) async {
    await pumpSync(tester);
    // CuAppBar concatène emoji + title en un seul Text widget.
    expect(find.textContaining('Sauvegarde cloud'), findsOneWidget);
    expect(find.textContaining('☁️'), findsOneWidget);
  });

  testWidgets('affiche un CircularProgressIndicator pendant le chargement',
      (tester) async {
    await pumpSync(tester);
    // _loading = true par défaut, le body est un spinner centré.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('aucune Card visible tant que les données ne sont pas chargées',
      (tester) async {
    await pumpSync(tester);
    // Status/Actions/Info Cards ne s'affichent que quand _loading = false.
    expect(find.byType(Card), findsNothing);
  });
}
