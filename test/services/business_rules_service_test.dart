// Tests : BusinessRules — règles métier pures (sans DB)
//
// Les méthodes qui dépendent de DBHelper (femelleDejaGestante,
// bagueDejaUtilisee) ne sont pas testées ici car elles exigent un
// setUp lourd de DB en mémoire — couvert par les tests d'intégration.
//
// On teste ici les helpers purs qui n'accèdent pas à la DB.

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/models/lapin.dart';
import 'package:gestion_cunicole/services/business_rules_service.dart';

void main() {
  group('BusinessRules.miseBasCoherente', () {
    test('mise bas null → OK (pas de check)', () {
      expect(
        BusinessRules.miseBasCoherente(
          dateSaillieIso: '2026-01-15',
          dateMiseBasReelleIso: null,
        ),
        isNull,
      );
    });

    test('mise bas avant saillie → erreur', () {
      expect(
        BusinessRules.miseBasCoherente(
          dateSaillieIso: '2026-01-15',
          dateMiseBasReelleIso: '2026-01-10',
        ),
        isNotNull,
      );
    });

    test('mise bas 31 jours après saillie (cas normal) → OK', () {
      expect(
        BusinessRules.miseBasCoherente(
          dateSaillieIso: '2026-01-15',
          dateMiseBasReelleIso: '2026-02-15',
        ),
        isNull,
      );
    });

    test('mise bas même jour que saillie → OK (cas limite)', () {
      expect(
        BusinessRules.miseBasCoherente(
          dateSaillieIso: '2026-01-15',
          dateMiseBasReelleIso: '2026-01-15',
        ),
        isNull,
      );
    });

    test('mise bas 60 jours après saillie → erreur (anormal)', () {
      expect(
        BusinessRules.miseBasCoherente(
          dateSaillieIso: '2026-01-15',
          dateMiseBasReelleIso: '2026-03-15',
        ),
        isNotNull,
      );
    });

    test('format de date invalide → OK (le validator de format gère)', () {
      expect(
        BusinessRules.miseBasCoherente(
          dateSaillieIso: 'pas-une-date',
          dateMiseBasReelleIso: '2026-01-15',
        ),
        isNull,
      );
    });
  });

  group('BusinessRules.lapinsEligiblesSoin', () {
    final lapins = [
      Lapin(id: 1, numeroBague: 'A', sexe: 'femelle', statut: 'actif'),
      Lapin(id: 2, numeroBague: 'B', sexe: 'male', statut: 'mort'),
      Lapin(id: 3, numeroBague: 'C', sexe: 'femelle', statut: 'vendu'),
      Lapin(id: 4, numeroBague: 'D', sexe: 'male', statut: 'actif'),
      Lapin(id: 5, numeroBague: 'E', sexe: 'femelle', statut: 'quarantaine'),
    ];

    test('exclut morts et vendus, garde le reste', () {
      final result = BusinessRules.lapinsEligiblesSoin(lapins);
      expect(result.map((l) => l.numeroBague).toList(), ['A', 'D']);
    });

    test('liste vide → liste vide', () {
      expect(BusinessRules.lapinsEligiblesSoin([]), isEmpty);
    });
  });

  group('BusinessRules.peutRecevoirSoin', () {
    test('null → erreur', () {
      expect(BusinessRules.peutRecevoirSoin(null), isNotNull);
    });
    test('lapin actif → OK', () {
      final l = Lapin(numeroBague: 'A', sexe: 'femelle', statut: 'actif');
      expect(BusinessRules.peutRecevoirSoin(l), isNull);
    });
    test('lapin mort → erreur', () {
      final l = Lapin(numeroBague: 'A', sexe: 'femelle', statut: 'mort');
      expect(BusinessRules.peutRecevoirSoin(l), contains('mort'));
    });
    test('lapin vendu → erreur', () {
      final l = Lapin(numeroBague: 'A', sexe: 'femelle', statut: 'vendu');
      expect(BusinessRules.peutRecevoirSoin(l), contains('vendu'));
    });
    test('lapin quarantaine → OK (peut être soigné)', () {
      final l = Lapin(
          numeroBague: 'A', sexe: 'femelle', statut: 'quarantaine');
      expect(BusinessRules.peutRecevoirSoin(l), isNull);
    });
  });
}
