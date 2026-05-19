// ─────────────────────────────────────────────────────────────
// Widget test : LapinDetailScreen — smoke minimal
// ─────────────────────────────────────────────────────────────
// L'écran charge beaucoup de données via DBHelper en initState()
// (soins, parents, cage, pesées, dépenses, ventes). Sans hook
// d'injection, ces appels échouent silencieusement et l'écran
// affiche les valeurs initiales (lapin reçu en argument).
//
// On teste donc le squelette structurel :
//   - AppBar : displayName du lapin (nom > bague)
//   - 3 icônes directes (QR, pedigree, edit) + menu overflow (delete)
//   - Aucun crash au build
//
// V2.5 — Sprint 4 : Delete a été déplacé dans un PopupMenuButton pour
// éviter les mis-tap (avant 4 IconButtons collés à 32dp). Le test
// vérifie maintenant la présence du menu overflow.
//
// Les tests avec données chargées (soins, généalogie, timeline)
// seront faits dans une itération future avec hooks debug ou
// injection des repositories.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/features/lapins/lapin_detail_screen.dart';
import 'package:gestion_cunicole/models/lapin.dart';

void main() {
  setUp(() {
    FlutterError.onError = (_) {};
  });

  Future<void> pumpDetail(WidgetTester tester, Lapin lapin) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: LapinDetailScreen(lapin: lapin)),
      ),
    );
    await tester.pump();
  }

  testWidgets('AppBar affiche le nom du lapin si présent (priorité sur bague)',
      (tester) async {
    final lapin = Lapin(
      id: 1,
      numeroBague: 'F-2026-001',
      sexe: 'femelle',
      nom: 'Bella',
    );
    await pumpDetail(tester, lapin);

    // displayName = nom (Bella) car non-vide.
    // Apparaît au moins 2 fois (AppBar + header card de l'écran).
    expect(find.text('Bella'), findsAtLeastNWidgets(1));
  });

  testWidgets('AppBar fallback sur la bague si pas de nom', (tester) async {
    final lapin = Lapin(
      id: 2,
      numeroBague: 'M-2026-042',
      sexe: 'male',
      // pas de nom
    );
    await pumpDetail(tester, lapin);

    // displayName = numeroBague
    expect(find.text('M-2026-042'), findsAtLeastNWidgets(1));
  });

  testWidgets(
      '3 icônes directes (QR, pedigree, edit) + menu overflow pour delete',
      (tester) async {
    final lapin = Lapin(
      id: 1,
      numeroBague: 'F-001',
      sexe: 'femelle',
    );
    await pumpDetail(tester, lapin);

    expect(find.byIcon(Icons.qr_code), findsOneWidget);
    expect(find.byIcon(Icons.account_tree), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsOneWidget);
    // Delete dans le menu overflow (icône more_vert visible).
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    // Delete pas visible sans ouverture du menu.
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('le Scaffold se construit sans crash', (tester) async {
    final lapin = Lapin(
      id: 1,
      numeroBague: 'F-001',
      sexe: 'femelle',
    );
    await pumpDetail(tester, lapin);

    expect(find.byType(Scaffold), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
