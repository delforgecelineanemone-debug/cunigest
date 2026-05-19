// Tests : Validators — bornes métier élevage cunicole
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/utils/validators.dart';

void main() {
  group('Validators.requis', () {
    test('null → erreur', () => expect(Validators.requis(null), isNotNull));
    test('vide → erreur', () => expect(Validators.requis(''), isNotNull));
    test('espaces → erreur', () => expect(Validators.requis('   '), isNotNull));
    test('valeur → OK', () => expect(Validators.requis('x'), isNull));
  });

  group('Validators.choixRequis', () {
    test('null → erreur', () => expect(Validators.choixRequis(null), isNotNull));
    test('int → OK', () => expect(Validators.choixRequis(42), isNull));
    test('string vide → erreur',
        () => expect(Validators.choixRequis(''), isNotNull));
    test('string valeur → OK',
        () => expect(Validators.choixRequis('male'), isNull));
  });

  group('Validators.poidsLapin', () {
    test('vide optionnel → OK', () => expect(Validators.poidsLapin(''), isNull));
    test('vide obligatoire → erreur',
        () => expect(Validators.poidsLapin('', requisField: true), isNotNull));
    test('texte → erreur',
        () => expect(Validators.poidsLapin('abc'), 'Nombre invalide'));
    test('négatif → erreur',
        () => expect(Validators.poidsLapin('-2'), isNotNull));
    test('zéro → erreur', () => expect(Validators.poidsLapin('0'), isNotNull));
    test('trop faible → erreur',
        () => expect(Validators.poidsLapin('0.005'), isNotNull));
    test('trop élevé → erreur',
        () => expect(Validators.poidsLapin('50'), isNotNull));
    test('2.5 kg → OK', () => expect(Validators.poidsLapin('2.5'), isNull));
    test('virgule décimale → OK',
        () => expect(Validators.poidsLapin('2,5'), isNull));
    test('limite haute 12 kg → OK',
        () => expect(Validators.poidsLapin('12'), isNull));
  });

  group('Validators.prix', () {
    test('vide → erreur',
        () => expect(Validators.prix(''), 'Prix obligatoire'));
    test('négatif → erreur', () => expect(Validators.prix('-100'), isNotNull));
    test('zéro → erreur', () => expect(Validators.prix('0'), isNotNull));
    test('5000 FCFA → OK', () => expect(Validators.prix('5000'), isNull));
    test('décimales → OK', () => expect(Validators.prix('12.50'), isNull));
    test('trop élevé → erreur',
        () => expect(Validators.prix('999999999999'), isNotNull));
  });

  group('Validators.prixOuZero', () {
    test('zéro → OK', () => expect(Validators.prixOuZero('0'), isNull));
    test('négatif → erreur',
        () => expect(Validators.prixOuZero('-1'), isNotNull));
    test('positif → OK', () => expect(Validators.prixOuZero('100'), isNull));
  });

  group('Validators.delaiAttenteJours', () {
    test('vide optionnel → OK',
        () => expect(Validators.delaiAttenteJours(''), isNull));
    test('négatif → erreur',
        () => expect(Validators.delaiAttenteJours('-5'), isNotNull));
    test('0 (pas de délai) → OK',
        () => expect(Validators.delaiAttenteJours('0'), isNull));
    test('décimal refusé',
        () => expect(Validators.delaiAttenteJours('7.5'), isNotNull));
    test('14 j → OK', () => expect(Validators.delaiAttenteJours('14'), isNull));
    test('aberrant 999 j → erreur',
        () => expect(Validators.delaiAttenteJours('999'), isNotNull));
  });

  group('Validators.nombreLapinsPortee', () {
    test('vide optionnel → OK',
        () => expect(Validators.nombreLapinsPortee(''), isNull));
    test('négatif → erreur',
        () => expect(Validators.nombreLapinsPortee('-2'), isNotNull));
    test('0 → OK (mortalité totale possible)',
        () => expect(Validators.nombreLapinsPortee('0'), isNull));
    test('8 → OK', () => expect(Validators.nombreLapinsPortee('8'), isNull));
    test('aberrant 50 → erreur',
        () => expect(Validators.nombreLapinsPortee('50'), isNotNull));
  });

  group('Validators.quantiteEntiere', () {
    test('0 par défaut (min=1) → erreur',
        () => expect(Validators.quantiteEntiere('0'), isNotNull));
    test('1 → OK', () => expect(Validators.quantiteEntiere('1'), isNull));
    test('min custom 0 → OK',
        () => expect(Validators.quantiteEntiere('0', min: 0), isNull));
    test('max dépassé → erreur',
        () => expect(Validators.quantiteEntiere('99999', max: 100), isNotNull));
  });

  group('Validators.pourcentage', () {
    test('vide optionnel → OK',
        () => expect(Validators.pourcentage(''), isNull));
    test('-5 → erreur', () => expect(Validators.pourcentage('-5'), isNotNull));
    test('0 → OK', () => expect(Validators.pourcentage('0'), isNull));
    test('100 → OK', () => expect(Validators.pourcentage('100'), isNull));
    test('150 → erreur', () => expect(Validators.pourcentage('150'), isNotNull));
  });

  group('Validators.dateIsoPassee', () {
    test('vide optionnel → OK',
        () => expect(Validators.dateIsoPassee(''), isNull));
    test('hier → OK', () {
      final hier = DateTime.now().subtract(const Duration(days: 1));
      expect(Validators.dateIsoPassee(hier.toIso8601String()), isNull);
    });
    test('demain → erreur', () {
      final demain = DateTime.now().add(const Duration(days: 1));
      expect(Validators.dateIsoPassee(demain.toIso8601String()), isNotNull);
    });
    test('format invalide → erreur',
        () => expect(Validators.dateIsoPassee('pas-une-date'), isNotNull));
  });

  group('Validators.dateApres', () {
    test('date2 avant date1 → erreur', () {
      final r = Validators.dateApres(
        date1Iso: '2026-01-15',
        date2Iso: '2026-01-10',
        label1: 'saillie',
        label2: 'mise bas',
      );
      expect(r, isNotNull);
    });
    test('date2 après date1 → OK', () {
      expect(
        Validators.dateApres(date1Iso: '2026-01-15', date2Iso: '2026-02-15'),
        isNull,
      );
    });
    test('dates égales → OK', () {
      expect(
        Validators.dateApres(date1Iso: '2026-01-15', date2Iso: '2026-01-15'),
        isNull,
      );
    });
    test('null → OK (rien à comparer)', () {
      expect(Validators.dateApres(date1Iso: null, date2Iso: '2026-01-15'),
          isNull);
    });
  });

  group('Validators.coherenceNaissances', () {
    test('vivants > nés → erreur', () {
      expect(
        Validators.coherenceNaissances(nes: 5, vivants: 7),
        isNotNull,
      );
    });
    test('morts > nés → erreur', () {
      expect(
        Validators.coherenceNaissances(nes: 5, morts: 8),
        isNotNull,
      );
    });
    test('vivants + morts > nés → erreur', () {
      expect(
        Validators.coherenceNaissances(nes: 8, vivants: 5, morts: 5),
        isNotNull,
      );
    });
    test('vivants + morts = nés → OK', () {
      expect(
        Validators.coherenceNaissances(nes: 8, vivants: 6, morts: 2),
        isNull,
      );
    });
    test('vivants + morts < nés → OK (cas où morts non renseignés)', () {
      expect(
        Validators.coherenceNaissances(nes: 8, vivants: 6),
        isNull,
      );
    });
  });

  group('Validators.compose', () {
    test('chaîne de validators → premier message', () {
      final v = Validators.compose([
        (x) => Validators.requis(x),
        (x) => Validators.prix(x),
      ]);
      expect(v(''), 'Champ obligatoire');
      expect(v('-5'), isNotNull);
      expect(v('100'), isNull);
    });
  });
}
