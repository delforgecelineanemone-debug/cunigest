// ──────────────────────────────────────────────────────────────
// Tests unitaires — Logique métier des modèles
// ──────────────────────────────────────────────────────────────
// Ces tests couvrent les calculs critiques qui pourraient
// silencieusement échouer en production :
// - Calcul du niveau à partir du score
// - Délai d'attente actif (vente bloquée)
// - Mortalité pré-sevrage
// - Affichage de l'âge
// ──────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/models/profil.dart';
import 'package:gestion_cunicole/models/soin.dart';
import 'package:gestion_cunicole/models/saillie.dart';
import 'package:gestion_cunicole/models/lapin.dart';

void main() {
  group('ProfilEleveur.calculerNiveau', () {
    test('niveau 1 quand score = 0', () {
      expect(ProfilEleveur.calculerNiveau(0), 1);
    });

    test('niveau 1 tant que score < 500', () {
      expect(ProfilEleveur.calculerNiveau(499), 1);
    });

    test('niveau 2 atteint à 500 points', () {
      expect(ProfilEleveur.calculerNiveau(500), 2);
    });

    test('niveau 3 atteint à 500+1000=1500 points', () {
      expect(ProfilEleveur.calculerNiveau(1500), 3);
    });

    test('niveau croissant, plafond à 50', () {
      expect(ProfilEleveur.calculerNiveau(10000000), lessThanOrEqualTo(50));
    });
  });

  group('Soin — délai d\'attente', () {
    test('délai null → pas actif', () {
      final s = Soin(typeSoin: 'Pesée', dateSoin: '2024-01-01');
      expect(s.delaiAttenteActif, false);
      expect(s.finDelaiAttente, null);
    });

    test('délai 0 → pas actif', () {
      final s = Soin(
          typeSoin: 'Pesée', dateSoin: '2024-01-01', delaiAttenteJours: 0);
      expect(s.delaiAttenteActif, false);
    });

    test('délai dépassé → pas actif', () {
      final ilYa10Jours =
          DateTime.now().subtract(const Duration(days: 10)).toIso8601String().substring(0, 10);
      final s =
          Soin(typeSoin: 'Antibiotique', dateSoin: ilYa10Jours, delaiAttenteJours: 5);
      expect(s.delaiAttenteActif, false);
    });

    test('délai en cours → actif', () {
      final ilYa3Jours =
          DateTime.now().subtract(const Duration(days: 3)).toIso8601String().substring(0, 10);
      final s = Soin(
          typeSoin: 'Antibiotique', dateSoin: ilYa3Jours, delaiAttenteJours: 28);
      expect(s.delaiAttenteActif, true);
    });

    test('finDelaiAttente = dateSoin + délai', () {
      final s = Soin(
          typeSoin: 'Antibiotique',
          dateSoin: '2024-01-01',
          delaiAttenteJours: 28);
      final fin = s.finDelaiAttente!;
      expect(fin.day, 29);
      expect(fin.month, 1);
      expect(fin.year, 2024);
    });
  });

  group('Soin.delaisAttenteParDefaut', () {
    test('antibiotique a un délai par défaut', () {
      expect(Soin.delaisAttenteParDefaut['Antibiotique'], isNotNull);
      expect(Soin.delaisAttenteParDefaut['Antibiotique']! > 0, true);
    });

    test('pesée n\'a pas de délai par défaut', () {
      expect(Soin.delaisAttenteParDefaut['Pesée'], null);
    });
  });

  group('Saillie.mortalitePreSevrage', () {
    test('null si pas de données vivants', () {
      final s = Saillie(mereId: 1, pereId: 2, dateSaillie: '2024-01-01');
      expect(s.mortalitePreSevrage, null);
    });

    test('null si vivants = 0', () {
      final s = Saillie(
          mereId: 1, pereId: 2, dateSaillie: '2024-01-01', nbVivants: 0, nbSevres: 0);
      expect(s.mortalitePreSevrage, null);
    });

    test('0% si tous sevrés', () {
      final s = Saillie(
          mereId: 1, pereId: 2, dateSaillie: '2024-01-01', nbVivants: 8, nbSevres: 8);
      expect(s.mortalitePreSevrage, 0.0);
    });

    test('25% si 2/8 perdus avant sevrage', () {
      final s = Saillie(
          mereId: 1, pereId: 2, dateSaillie: '2024-01-01', nbVivants: 8, nbSevres: 6);
      expect(s.mortalitePreSevrage, 25.0);
    });

    test('100% si 0 sevré sur 5 vivants', () {
      final s = Saillie(
          mereId: 1, pereId: 2, dateSaillie: '2024-01-01', nbVivants: 5, nbSevres: 0);
      expect(s.mortalitePreSevrage, 100.0);
    });

    test('0% si sevrés > vivants (donnée incohérente, on clamp)', () {
      final s = Saillie(
          mereId: 1, pereId: 2, dateSaillie: '2024-01-01', nbVivants: 5, nbSevres: 7);
      expect(s.mortalitePreSevrage, 0.0);
    });
  });

  group('Lapin.ageDisplay', () {
    test('Inconnu si pas de date', () {
      final l = Lapin(numeroBague: '001', sexe: 'male');
      expect(l.ageDisplay, 'Inconnu');
    });

    test('jours pour < 30 jours', () {
      final ilYa15Jours = DateTime.now()
          .subtract(const Duration(days: 15))
          .toIso8601String()
          .substring(0, 10);
      final l = Lapin(numeroBague: '001', sexe: 'male', dateNaissance: ilYa15Jours);
      expect(l.ageDisplay, '15 jours');
    });

    test('mois pour 30j à 365j', () {
      final ilYa90Jours = DateTime.now()
          .subtract(const Duration(days: 90))
          .toIso8601String()
          .substring(0, 10);
      final l = Lapin(numeroBague: '001', sexe: 'male', dateNaissance: ilYa90Jours);
      expect(l.ageDisplay.contains('mois'), true);
    });

    test('an + mois pour > 365j', () {
      final ilYa400Jours = DateTime.now()
          .subtract(const Duration(days: 400))
          .toIso8601String()
          .substring(0, 10);
      final l = Lapin(numeroBague: '001', sexe: 'male', dateNaissance: ilYa400Jours);
      expect(l.ageDisplay.contains('an'), true);
    });
  });

  group('Lapin.displayName', () {
    test('utilise le nom si présent', () {
      final l = Lapin(numeroBague: '001', sexe: 'male', nom: 'Roger');
      expect(l.displayName, 'Roger');
    });

    test('fallback sur la bague si pas de nom', () {
      final l = Lapin(numeroBague: '001', sexe: 'male');
      expect(l.displayName, '001');
    });

    test('fallback sur la bague si nom vide', () {
      final l = Lapin(numeroBague: '001', sexe: 'male', nom: '');
      expect(l.displayName, '001');
    });
  });

  group('Saillie.statutLabel', () {
    test('chaque statut a un label avec emoji', () {
      for (final st in [
        'en_attente',
        'mise_bas',
        'sevrage',
        'termine',
        'echec'
      ]) {
        final s =
            Saillie(mereId: 1, pereId: 2, dateSaillie: '2024-01-01', statut: st);
        expect(s.statutLabel.length > 2, true);
      }
    });
  });
}
