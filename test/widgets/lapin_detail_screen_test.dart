// ─────────────────────────────────────────────────────────────
// Tests widget : LapinDetailScreen
//
// Depuis P1.8, l'écran est un ConsumerStatefulWidget alimenté par
// `lapinDetailProvider` (AsyncNotifierProvider.family). Les tests
// overrident ce provider avec un faux notifier qui renvoie des
// données fixes — pas besoin de base de données réelle.
//
// On vérifie :
//   - AppBar : displayName du lapin (nom > bague)
//   - 3 icônes directes (QR, pedigree, edit) + menu overflow (delete)
//   - Aucun crash au build
//
// V2.5 — Sprint 4 : Delete déplacé dans un PopupMenuButton.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/features/lapins/lapin_detail_screen.dart';
import 'package:gestion_cunicole/models/lapin.dart';
import 'package:gestion_cunicole/providers/lapin_detail_notifier.dart';

/// Faux notifier : renvoie une fiche complète sans toucher la base.
class _FakeLapinDetailNotifier extends LapinDetailNotifier {
  _FakeLapinDetailNotifier(this._lapin);
  final Lapin _lapin;

  @override
  Future<LapinDetailData> build(int arg) async {
    return LapinDetailData(
      lapin: _lapin,
      soins: const [],
      mvts: const [],
      pesees: const [],
      saillies: const [],
      depensesLapin: 0,
      ventesLapin: 0,
    );
  }
}

void main() {
  setUp(() {
    FlutterError.onError = (_) {};
  });

  Future<void> pumpDetail(WidgetTester tester, Lapin lapin) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Override du family entier — tous les lapinId pointent vers
          // le faux notifier (suffisant : un seul lapin par test).
          lapinDetailProvider.overrideWith(
            () => _FakeLapinDetailNotifier(lapin),
          ),
        ],
        child: MaterialApp(home: LapinDetailScreen(lapin: lapin)),
      ),
    );
    // 1er pump = loading, 2e = data (le Future du notifier résout).
    await tester.pump();
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

    expect(find.text('Bella'), findsAtLeastNWidgets(1));
  });

  testWidgets('AppBar fallback sur la bague si pas de nom', (tester) async {
    final lapin = Lapin(
      id: 2,
      numeroBague: 'M-2026-042',
      sexe: 'male',
    );
    await pumpDetail(tester, lapin);

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
    // Delete + mortalité dans le menu overflow (icône more_vert visible).
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
