// Tests : RepositoryValidators — gardes d'intégrité synchrones (P0.3).
//
// Ces assertions sont la dernière barrière avant la base SQLite.
// On vérifie qu'elles bloquent les incohérences DURES et laissent
// passer les données légitimes (y compris incomplètes — un lapin
// mort sans cause reste accepté côté repo, cf. import / sync legacy).

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/models/depense.dart';
import 'package:gestion_cunicole/models/lapin.dart';
import 'package:gestion_cunicole/models/saillie.dart';
import 'package:gestion_cunicole/models/soin.dart';
import 'package:gestion_cunicole/models/vente.dart';
import 'package:gestion_cunicole/repositories/repository_validators.dart';

void main() {
  group('assertValidLapin', () {
    test('accepte un lapin valide', () {
      expect(
        () => RepositoryValidators.assertValidLapin(
            Lapin(numeroBague: 'F-001', sexe: 'femelle')),
        returnsNormally,
      );
    });

    test('rejette une bague vide', () {
      expect(
        () => RepositoryValidators.assertValidLapin(
            Lapin(numeroBague: '   ', sexe: 'male')),
        throwsArgumentError,
      );
    });

    test('rejette un sexe invalide', () {
      expect(
        () => RepositoryValidators.assertValidLapin(
            Lapin(numeroBague: 'X', sexe: 'inconnu')),
        throwsArgumentError,
      );
    });

    test('rejette un poids négatif', () {
      final l = Lapin(numeroBague: 'X', sexe: 'male', poids: -1.5);
      expect(() => RepositoryValidators.assertValidLapin(l),
          throwsArgumentError);
    });

    test('rejette un lapin qui est son propre parent', () {
      final l = Lapin(id: 7, numeroBague: 'X', sexe: 'male', pereId: 7);
      expect(() => RepositoryValidators.assertValidLapin(l),
          throwsArgumentError);
    });

    test('rejette père == mère', () {
      final l = Lapin(
          numeroBague: 'X', sexe: 'male', pereId: 3, mereId: 3);
      expect(() => RepositoryValidators.assertValidLapin(l),
          throwsArgumentError);
    });

    test('accepte le statut quarantaine (régression P3.21)', () {
      final l = Lapin(numeroBague: 'Q', sexe: 'male');
      l.statut = 'quarantaine';
      expect(
          () => RepositoryValidators.assertValidLapin(l), returnsNormally);
    });

    test('accepte un lapin mort SANS cause (import / sync legacy tolérés)',
        () {
      final l = Lapin(numeroBague: 'M', sexe: 'femelle');
      l.statut = 'mort';
      expect(
          () => RepositoryValidators.assertValidLapin(l), returnsNormally);
    });
  });

  group('assertValidSaillie', () {
    Saillie base() => Saillie(
          mereId: 1,
          pereId: 2,
          dateSaillie: '2026-05-01',
        );

    test('accepte une saillie valide', () {
      expect(() => RepositoryValidators.assertValidSaillie(base()),
          returnsNormally);
    });

    test('rejette mère == père', () {
      final s = Saillie(mereId: 5, pereId: 5, dateSaillie: '2026-05-01');
      expect(() => RepositoryValidators.assertValidSaillie(s),
          throwsArgumentError);
    });

    test('rejette une mise bas antérieure à la saillie', () {
      final s = base()..dateMiseBasReelle = '2026-04-01';
      expect(() => RepositoryValidators.assertValidSaillie(s),
          throwsArgumentError);
    });

    test('rejette sevrés > vivants', () {
      final s = base()
        ..nbVivants = 5
        ..nbSevres = 8;
      expect(() => RepositoryValidators.assertValidSaillie(s),
          throwsArgumentError);
    });

    test('rejette un statut invalide', () {
      final s = base()..statut = 'n_importe_quoi';
      expect(() => RepositoryValidators.assertValidSaillie(s),
          throwsArgumentError);
    });
  });

  group('assertValidSoin', () {
    test('accepte un soin valide', () {
      expect(
        () => RepositoryValidators.assertValidSoin(
            Soin(typeSoin: 'Vaccin VHD', dateSoin: '2026-05-01')),
        returnsNormally,
      );
    });

    test('rejette un coût négatif', () {
      final s = Soin(typeSoin: 'X', dateSoin: '2026-05-01', cout: -10);
      expect(() => RepositoryValidators.assertValidSoin(s),
          throwsArgumentError);
    });

    test('rejette un type de soin vide', () {
      final s = Soin(typeSoin: '  ', dateSoin: '2026-05-01');
      expect(() => RepositoryValidators.assertValidSoin(s),
          throwsArgumentError);
    });
  });

  group('assertValidVente', () {
    test('accepte une vente valide', () {
      expect(
        () => RepositoryValidators.assertValidVente(Vente(
            dateVente: '2026-05-01', typeVente: 'vivant', prixVente: 5000)),
        returnsNormally,
      );
    });

    test('rejette un prix négatif', () {
      final v = Vente(
          dateVente: '2026-05-01', typeVente: 'vivant', prixVente: -1);
      expect(() => RepositoryValidators.assertValidVente(v),
          throwsArgumentError);
    });

    test('rejette une quantité nulle', () {
      final v = Vente(
          dateVente: '2026-05-01',
          typeVente: 'vivant',
          prixVente: 100,
          quantite: 0);
      expect(() => RepositoryValidators.assertValidVente(v),
          throwsArgumentError);
    });
  });

  group('assertValidDepense', () {
    test('accepte une dépense valide', () {
      expect(
        () => RepositoryValidators.assertValidDepense(Depense(
            dateDepense: '2026-05-01', categorie: 'aliment', montant: 2000)),
        returnsNormally,
      );
    });

    test('rejette un montant négatif', () {
      final d = Depense(
          dateDepense: '2026-05-01', categorie: 'aliment', montant: -5);
      expect(() => RepositoryValidators.assertValidDepense(d),
          throwsArgumentError);
    });
  });
}
