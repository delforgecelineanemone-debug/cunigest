// Test : CuFormScaffold — PopScope anti-perte de saisie
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/ui/widgets/cu_form_scaffold.dart';

void main() {
  group('CuFormController', () {
    test('initial → propre', () {
      final c = CuFormController();
      expect(c.isDirty, false);
    });

    test('markDirty → notifie', () {
      final c = CuFormController();
      int notified = 0;
      c.addListener(() => notified++);
      c.markDirty();
      expect(c.isDirty, true);
      expect(notified, 1);
    });

    test('markDirty idempotent', () {
      final c = CuFormController();
      int notified = 0;
      c.addListener(() => notified++);
      c.markDirty();
      c.markDirty();
      c.markDirty();
      expect(notified, 1, reason: 'Pas de notif redondante');
    });

    test('markClean après markDirty → notifie', () {
      final c = CuFormController();
      c.markDirty();
      int notified = 0;
      c.addListener(() => notified++);
      c.markClean();
      expect(c.isDirty, false);
      expect(notified, 1);
    });

    test('markClean sur état propre → pas de notif', () {
      final c = CuFormController();
      int notified = 0;
      c.addListener(() => notified++);
      c.markClean();
      expect(notified, 0);
    });
  });

  group('CuFormScaffold (smoke)', () {
    testWidgets('rend son child et appBar', (tester) async {
      final controller = CuFormController();
      await tester.pumpWidget(
        MaterialApp(
          home: CuFormScaffold(
            controller: controller,
            appBar: AppBar(title: const Text('Formulaire')),
            child: const Center(child: Text('contenu form')),
          ),
        ),
      );
      expect(find.text('Formulaire'), findsOneWidget);
      expect(find.text('contenu form'), findsOneWidget);
    });

    testWidgets('pop autorisé si propre', (tester) async {
      final controller = CuFormController();
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.of(ctx).push(
                  MaterialPageRoute(
                    builder: (_) => CuFormScaffold(
                      controller: controller,
                      appBar: AppBar(title: const Text('Form')),
                      child: const Text('child'),
                    ),
                  ),
                ),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      expect(find.text('child'), findsOneWidget);

      // Propre → pop direct sans dialog
      navKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Ouvrir'), findsOneWidget);
    });
  });
}
