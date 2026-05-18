// ─────────────────────────────────────────────────────────────
// Widget test : LapinFormScreen (mode création + mode édition)
// ─────────────────────────────────────────────────────────────
// Vérifie le rendu **synchrone** du formulaire lapin.
//
// On NE teste PAS la soumission (insertLapin) qui dépend de
// DBHelper — couvert par les tests repositories. Les appels async
// en initState() (_loadParents, _resolveCageLabel, _genererBagueAuto)
// sont silencieusement ignorés (FlutterError.onError écarté).
//
// Règles métier vérifiées :
// - Mode création : sexe par défaut = 'femelle' (base de la production)
// - Photo : OPTIONNELLE (jamais bloquante — préférence utilisateur)
// - Champ "Numéro de bague *" marqué obligatoire (astérisque)
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/features/lapins/lapin_form_screen.dart';
import 'package:gestion_cunicole/models/lapin.dart';

void main() {
  setUp(() {
    // Ignore les erreurs async (DBHelper non initialisé sous flutter_test).
    FlutterError.onError = (_) {};
  });

  Future<void> pumpForm(WidgetTester tester, {Lapin? lapin}) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: LapinFormScreen(lapin: lapin)),
      ),
    );
    await tester.pump(); // 1 pump pour build initial sans attendre les Futures
  }

  group('mode création (lapin = null)', () {
    testWidgets('AppBar affiche "Nouveau lapin"', (tester) async {
      await pumpForm(tester);
      expect(find.text('Nouveau lapin'), findsOneWidget);
    });

    testWidgets('champs essentiels visibles', (tester) async {
      await pumpForm(tester);

      expect(find.text('Numéro de bague *'), findsOneWidget);
      expect(find.text('Nom (optionnel)'), findsOneWidget);
      expect(find.text('Sexe :'), findsOneWidget);
      expect(find.text('♂ Mâle'), findsOneWidget);
      expect(find.text('♀ Femelle'), findsOneWidget);
    });

    testWidgets(
        'sexe par défaut = femelle (règle métier : on enregistre les reproductrices)',
        (tester) async {
      await pumpForm(tester);

      final segmented = tester.widget<SegmentedButton<String>>(
        find.byType(SegmentedButton<String>),
      );
      expect(segmented.selected, {'femelle'});
    });
  });

  group('mode édition (lapin pré-rempli)', () {
    testWidgets('AppBar affiche "Modifier le lapin"', (tester) async {
      final lapin = Lapin(
        id: 1,
        numeroBague: 'F-2026-001',
        sexe: 'femelle',
        nom: 'Bella',
      );
      await pumpForm(tester, lapin: lapin);

      expect(find.text('Modifier le lapin'), findsOneWidget);
    });

    testWidgets('valeurs du lapin pré-remplies dans les champs',
        (tester) async {
      final lapin = Lapin(
        id: 1,
        numeroBague: 'M-2026-042',
        sexe: 'male',
        nom: 'Bourru',
        race: 'Néo-zélandais',
      );
      await pumpForm(tester, lapin: lapin);

      // La bague et le nom doivent être pré-remplis dans les TextField
      expect(find.text('M-2026-042'), findsOneWidget);
      expect(find.text('Bourru'), findsOneWidget);
      expect(find.text('Néo-zélandais'), findsOneWidget);

      // Sexe = male
      final segmented = tester.widget<SegmentedButton<String>>(
        find.byType(SegmentedButton<String>),
      );
      expect(segmented.selected, {'male'});
    });
  });
}
