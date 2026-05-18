// ─────────────────────────────────────────────────────────────
// Widget test : LoginScreen
// ─────────────────────────────────────────────────────────────
// Vérifie le rendu et les interactions UI **synchrones** :
//   - éléments visibles à l'ouverture
//   - validation locale "mot de passe vide"
//   - dialog d'aide "Mot de passe oublié"
//
// On NE teste PAS la connexion réelle (verifierMotDePasse) qui
// dépend d'AccountService/DBHelper — couvert par les tests
// repositories. Les appels async vers DBHelper en initState() sont
// silencieusement ignorés (FlutterError.onError écarté pendant le
// test) car ils ne bloquent pas l'affichage initial.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/features/auth/login_screen.dart';

void main() {
  // Capture les erreurs async (DBHelper non initialisé sous flutter_test)
  // pour qu'elles ne fassent pas échouer les tests d'UI pure.
  setUp(() {
    FlutterError.onError = (_) {};
  });

  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );
    // pump() sans pumpAndSettle pour éviter d'attendre les futures
    // async (DBHelper) qui ne s'exécuteront pas dans cet environnement.
    await tester.pump();
  }

  testWidgets('affiche les éléments principaux à l\'ouverture', (tester) async {
    await pumpLogin(tester);

    // Branding
    expect(find.text('🐇'), findsOneWidget);
    expect(find.text('CuniGest'), findsOneWidget);

    // Champ mot de passe
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);

    // Bouton de connexion
    expect(find.text('Entrer'), findsOneWidget);

    // Lien d'aide
    expect(find.text('Mot de passe oublié ?'), findsOneWidget);
  });

  testWidgets('soumission vide → message d\'erreur "Saisis ton mot de passe"',
      (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.text('Entrer'));
    await tester.pump();

    expect(find.text('Saisis ton mot de passe'), findsOneWidget);
  });

  testWidgets('tap sur "Mot de passe oublié ?" ouvre l\'AlertDialog d\'aide',
      (tester) async {
    await pumpLogin(tester);

    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.text('Mot de passe oublié ?'));
    await tester.pump();

    expect(find.byType(AlertDialog), findsOneWidget);
    // Titre du dialog
    expect(find.text('Mot de passe oublié'), findsOneWidget);
    // Le contenu mentionne le stockage local
    expect(
      find.textContaining('uniquement sur ce téléphone'),
      findsOneWidget,
    );
    // Bouton de fermeture
    expect(find.widgetWithText(TextButton, 'OK'), findsOneWidget);

    // Fermer le dialog
    await tester.tap(find.widgetWithText(TextButton, 'OK'));
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('toggle visibilité du mot de passe (icône œil)', (tester) async {
    await pumpLogin(tester);

    // Au départ : caché (icône "visibility_outlined")
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);

    // Tap sur l'icône → mode visible
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();

    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });
}
