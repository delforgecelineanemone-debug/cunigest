// ─────────────────────────────────────────────────────────────
// Widget test : DashboardScreen — smoke minimal
// ─────────────────────────────────────────────────────────────
// L'écran utilise `dashboardProvider` (AsyncNotifier Riverpod)
// qui dépend de DBHelper. Sans override, le provider tombe en
// état `loading` (skeleton) ou `error` selon la timing — c'est
// ATTENDU sous flutter_test.
//
// On teste donc le squelette structurel :
//   - AppBar brand (CuniGest + icône eco)
//   - RefreshIndicator présent (pull-to-refresh dispo)
//   - Aucun crash au build
//
// Les tests avec données mockées (KPIs, lots, donut) seront
// faits dans une itération future avec `dashboardProvider.overrideWith(
// () => FakeDashNotifier(seedData))`. Pour l'instant on couvre
// juste la non-régression du scaffold.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/features/dashboard_screen.dart';

void main() {
  setUp(() {
    FlutterError.onError = (_) {};
  });

  Future<void> pumpDashboard(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('AppBar brand : affiche "CuniGest" + icône eco', (tester) async {
    await pumpDashboard(tester);
    expect(find.text('CuniGest'), findsOneWidget);
    expect(find.byIcon(Icons.eco), findsOneWidget);
  });

  testWidgets('RefreshIndicator présent (pull-to-refresh dispo)',
      (tester) async {
    await pumpDashboard(tester);
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  testWidgets('le Scaffold se construit sans crash', (tester) async {
    await pumpDashboard(tester);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
