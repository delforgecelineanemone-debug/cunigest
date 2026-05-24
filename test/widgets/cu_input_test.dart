// ─────────────────────────────────────────────────────────────
// Tests pour CuInput + CuValidators (design system V3)
// ─────────────────────────────────────────────────────────────
// Couvre :
//   - Tous les validators composables (email, decimal, integer,
//     minLength, maxLength, compose) avec cas limites (virgule
//     vs point, min/max, vide = OK, non-numérique = KO).
//   - Le rendu widget (label, astérisque required, password obscure,
//     errorText, type=decimal qui accepte la virgule).
//   - L'exposition Semantics pour TalkBack/VoiceOver.
//
// Le widget n'a aucune dépendance Riverpod/DBHelper → tests purs.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/ui/atoms/cu_input.dart';

void main() {
  // ──────────────────────────────────────────────────────────
  // Validators purs — pas besoin de WidgetTester
  // ──────────────────────────────────────────────────────────

  group('CuValidators.email', () {
    test('valeur vide ou null = OK (le champ optionnel est géré ailleurs)', () {
      expect(CuValidators.email(null), isNull);
      expect(CuValidators.email(''), isNull);
      expect(CuValidators.email('   '), isNull);
    });

    test('email valide', () {
      expect(CuValidators.email('eleveur@cunigest.fr'), isNull);
      expect(CuValidators.email('a.b+tag@sub.example.com'), isNull);
    });

    test('email invalide', () {
      expect(CuValidators.email('pas-un-email'), isNotNull);
      expect(CuValidators.email('manque@tld'), isNotNull);
      expect(CuValidators.email('@nodomain.fr'), isNotNull);
      expect(CuValidators.email('avec espace@x.fr'), isNotNull);
    });
  });

  group('CuValidators.minLength / maxLength', () {
    test('minLength rejette en dessous, accepte au-dessus', () {
      final v = CuValidators.minLength(4);
      expect(v(null), isNotNull);
      expect(v(''), isNotNull);
      expect(v('abc'), isNotNull);
      expect(v('abcd'), isNull);
      expect(v('abcde'), isNull);
    });

    test('maxLength accepte en dessous, rejette au-dessus', () {
      final v = CuValidators.maxLength(3);
      expect(v(null), isNull); // vide = OK
      expect(v(''), isNull);
      expect(v('ab'), isNull);
      expect(v('abc'), isNull);
      expect(v('abcd'), isNotNull);
    });
  });

  group('CuValidators.decimal', () {
    test('vide = OK (le champ optionnel)', () {
      final v = CuValidators.decimal();
      expect(v(null), isNull);
      expect(v(''), isNull);
      expect(v('   '), isNull);
    });

    test('accepte point ET virgule (utilisation francophone)', () {
      final v = CuValidators.decimal();
      expect(v('1.5'), isNull);
      expect(v('1,5'), isNull, reason: 'virgule = format français standard');
      expect(v('0'), isNull);
      expect(v('1234.56'), isNull);
    });

    test('rejette les non-nombres', () {
      final v = CuValidators.decimal();
      expect(v('abc'), isNotNull);
      expect(v('1.2.3'), isNotNull);
      expect(v('--5'), isNotNull);
    });

    test('respecte min/max', () {
      final v = CuValidators.decimal(min: 0.1, max: 12.0);
      expect(v('0.05'), isNotNull, reason: '< min');
      expect(v('0.1'), isNull, reason: '= min OK');
      expect(v('12.0'), isNull, reason: '= max OK');
      expect(v('12.01'), isNotNull, reason: '> max');
      expect(v('6,5'), isNull, reason: 'virgule dans range');
    });
  });

  group('CuValidators.integer', () {
    test('vide = OK', () {
      expect(CuValidators.integer()(null), isNull);
      expect(CuValidators.integer()(''), isNull);
    });

    test('accepte les entiers, rejette les décimaux', () {
      final v = CuValidators.integer();
      expect(v('42'), isNull);
      expect(v('-3'), isNull);
      expect(v('0'), isNull);
      expect(v('3.14'), isNotNull, reason: 'integer n\'accepte pas décimal');
      expect(v('3,14'), isNotNull);
      expect(v('abc'), isNotNull);
    });

    test('respecte min/max', () {
      final v = CuValidators.integer(min: 1, max: 100);
      expect(v('0'), isNotNull);
      expect(v('1'), isNull);
      expect(v('100'), isNull);
      expect(v('101'), isNotNull);
    });
  });

  group('CuValidators.compose', () {
    test('exécute les validators dans l\'ordre, premier qui échoue gagne', () {
      final v = CuValidators.compose([
        CuValidators.minLength(3),
        CuValidators.email,
      ]);
      // 'a' échoue d'abord à minLength (pas à email)
      expect(v('a'), contains('caractères'));
      // 'abcd' passe minLength mais pas email
      expect(v('abcd'), contains('Email'));
      // 'abc@def.fr' passe les deux
      expect(v('abc@def.fr'), isNull);
    });

    test('vide passe si aucun validator ne le rejette', () {
      final v = CuValidators.compose([CuValidators.decimal(), CuValidators.email]);
      expect(v(''), isNull);
    });
  });

  // ──────────────────────────────────────────────────────────
  // Widget CuInput
  // ──────────────────────────────────────────────────────────

  Future<void> pumpInput(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
      ),
    );
    // pumpAndSettle : laisse les animations Material (label floating,
    // décoration d'erreur) se stabiliser avant les `expect(find.text…)`.
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
  }

  group('CuInput rendu', () {
    testWidgets('affiche le label tel quel quand required=false', (tester) async {
      await pumpInput(tester, const CuInput(label: 'Nom'));
      // Material peut rendre le label deux fois (float + content), donc on
      // tolère ≥1 occurrence. Ce qui compte ici : « Nom » est présent et
      // PAS « Nom * » (absence de l'astérisque required).
      expect(find.text('Nom'), findsWidgets);
      expect(find.text('Nom *'), findsNothing);
    });

    testWidgets('ajoute « * » au label quand required=true', (tester) async {
      await pumpInput(tester, const CuInput(label: 'Bague', required: true));
      expect(find.text('Bague *'), findsWidgets);
    });

    testWidgets('affiche le helper text et le hint', (tester) async {
      await pumpInput(
        tester,
        const CuInput(
          label: 'Email',
          helper: 'Format : eleveur@exemple.fr',
          hint: 'eleveur@exemple.fr',
        ),
      );
      expect(find.text('Format : eleveur@exemple.fr'), findsWidgets);
    });

    testWidgets('errorText override le validator (visible immédiatement)',
        (tester) async {
      await pumpInput(
        tester,
        const CuInput(label: 'Bague', errorText: 'Déjà utilisée'),
      );
      expect(find.text('Déjà utilisée'), findsWidgets);
    });

    testWidgets('password type masque le texte saisi', (tester) async {
      final ctrl = TextEditingController();
      await pumpInput(
        tester,
        CuInput(label: 'Mot de passe', type: CuInputType.password, controller: ctrl),
      );
      await tester.enterText(find.byType(TextFormField), 'secret');
      expect(ctrl.text, 'secret');
      // `obscureText` est exposé sur le TextField interne, pas sur le
      // TextFormField (qui est un FormField<String> wrapper).
      final inner = tester.widget<TextField>(find.byType(TextField));
      expect(inner.obscureText, isTrue);
    });

    testWidgets('enabled=false grise le champ', (tester) async {
      await pumpInput(
        tester,
        const CuInput(label: 'Verrouillé', enabled: false),
      );
      // `enabled` n'est pas exposé en getter sur TextFormField ; on vérifie
      // l'état effectif sur le TextField interne (qui le reflète).
      final inner = tester.widget<TextField>(find.byType(TextField));
      expect(inner.enabled, isFalse);
    });
  });

  group('CuInput type=decimal', () {
    testWidgets('accepte virgule ET point (saisie francophone)', (tester) async {
      final ctrl = TextEditingController();
      await pumpInput(
        tester,
        CuInput(label: 'Poids', type: CuInputType.decimal, controller: ctrl),
      );
      // Le formatter `allow([\d.,])` ne doit pas filtrer la virgule.
      await tester.enterText(find.byType(TextFormField), '1,5');
      expect(ctrl.text, '1,5',
          reason: 'L\'utilisateur francophone doit pouvoir taper "1,5"');
    });

    testWidgets('refuse les lettres (formatter actif)', (tester) async {
      final ctrl = TextEditingController();
      await pumpInput(
        tester,
        CuInput(label: 'Poids', type: CuInputType.decimal, controller: ctrl),
      );
      await tester.enterText(find.byType(TextFormField), '1a2b3');
      expect(ctrl.text, '123', reason: 'Les lettres doivent être filtrées');
    });
  });

  group('CuInput type=number', () {
    testWidgets('refuse virgule et point (entier strict)', (tester) async {
      final ctrl = TextEditingController();
      await pumpInput(
        tester,
        CuInput(label: 'Nombre', type: CuInputType.number, controller: ctrl),
      );
      await tester.enterText(find.byType(TextFormField), '1,5');
      expect(ctrl.text, '15',
          reason: 'CuInputType.number = digitsOnly, virgule filtrée');
    });
  });

  group('CuInput validation Form', () {
    testWidgets('validator est appelé via Form.validate()', (tester) async {
      final formKey = GlobalKey<FormState>();
      await pumpInput(
        tester,
        Form(
          key: formKey,
          child: CuInput(
            label: 'Email',
            type: CuInputType.email,
            validator: CuValidators.email,
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), 'pas-un-email');
      // Avant validate() : pas encore d'erreur affichée.
      expect(find.text('Email invalide'), findsNothing);
      formKey.currentState!.validate();
      await tester.pumpAndSettle();
      expect(find.text('Email invalide'), findsWidgets);
    });

    testWidgets('required affiche "Ce champ est obligatoire" si vide', (tester) async {
      final formKey = GlobalKey<FormState>();
      await pumpInput(
        tester,
        Form(
          key: formKey,
          child: const CuInput(label: 'Bague', required: true),
        ),
      );
      formKey.currentState!.validate();
      await tester.pumpAndSettle();
      expect(find.text('Ce champ est obligatoire'), findsWidgets);
    });
  });

  group('CuInput accessibilité (Semantics)', () {
    testWidgets('expose le label en Semantics pour TalkBack/VoiceOver',
        (tester) async {
      // ensureSemantics : active la collecte de l'arbre sémantique.
      // Sans ça, getSemantics retourne des nœuds vides ou throw.
      final handle = tester.ensureSemantics();
      await pumpInput(tester, const CuInput(label: 'Numéro de bague'));
      // On vérifie via un matcher SemanticsFinder qui parcourt l'arbre
      // (plus robuste que getSemantics(find.byType(CuInput)) qui peut
      // pointer un nœud mergé sans label direct).
      expect(
        find.bySemanticsLabel(RegExp('Numéro de bague')),
        findsWidgets,
        reason: 'TalkBack/VoiceOver doit pouvoir annoncer le label du champ',
      );
      handle.dispose();
    });
  });
}
