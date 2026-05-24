// Tests : SyncService — synchronisation cloud Supabase
//
// SURFACE TESTÉE :
//   - kSyncedTables : ordre stable garant de l'intégrité référentielle
//     (parents avant enfants au pull) et liste exhaustive des tables miroir.
//   - SyncReport : modèle de retour exposé à l'UI.
//
// NON TESTÉ ICI (skip) :
//   - signUp / signIn / signOut / _refreshToken : appels HTTP réels
//     (package http) + écriture DBHelper. Sans mock HTTP ni DI on ne peut
//     pas exécuter ces chemins de manière déterministe.
//   - synchroniser / _pushPending / _pullDistant : combinent connectivity_plus,
//     http et DBHelper.
//   - listenConnectivity / disposeConnectivity : connectivity_plus
//     platform channel.
//   - _traduireErreurServeur, _clean : helpers privés.

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/services/sync_service.dart';

void main() {
  group('kSyncedTables — contrat d\'ordre et de contenu', () {
    test('couvre toutes les tables miroir attendues', () {
      // V17 — couverture étendue : cheptel + cages + finances + routines
      // + profil. La liste doit contenir exactement ce socle.
      const attendues = {
        'batiments', 'clapiers', 'cages',
        'lapins', 'lots', 'stocks',
        'mouvements_cage', 'pesees_lapin',
        'saillies', 'soins', 'ventes', 'depenses',
        'pesees', 'distributions_aliment',
        'consommations', 'lot_lapins',
        'taches_quotidiennes', 'completions',
        'profil_eleveur', 'reglages',
      };
      expect(kSyncedTables.toSet(), attendues);
    });

    test('aucun doublon dans kSyncedTables', () {
      expect(kSyncedTables.length, kSyncedTables.toSet().length);
    });

    test('hiérarchie cages : bâtiment avant clapier avant cage', () {
      final iBat = kSyncedTables.indexOf('batiments');
      final iClapier = kSyncedTables.indexOf('clapiers');
      final iCage = kSyncedTables.indexOf('cages');
      expect(iBat, lessThan(iClapier));
      expect(iClapier, lessThan(iCage));
    });

    test('lapins arrive AVANT ses dépendants (saillies, soins, ventes)', () {
      final iLapins = kSyncedTables.indexOf('lapins');
      expect(iLapins, isNonNegative);
      expect(iLapins, lessThan(kSyncedTables.indexOf('saillies')));
      expect(iLapins, lessThan(kSyncedTables.indexOf('soins')));
      expect(iLapins, lessThan(kSyncedTables.indexOf('ventes')));
    });

    test('lots arrive AVANT ses dépendants (pesees, distributions_aliment)', () {
      final iLots = kSyncedTables.indexOf('lots');
      expect(iLots, isNonNegative);
      expect(iLots, lessThan(kSyncedTables.indexOf('pesees')));
      expect(iLots, lessThan(kSyncedTables.indexOf('distributions_aliment')));
    });

    test('stocks arrive AVANT distributions_aliment', () {
      expect(
        kSyncedTables.indexOf('stocks'),
        lessThan(kSyncedTables.indexOf('distributions_aliment')),
      );
    });

    test('aucun doublon (la queue ne doit pas pousser une table 2 fois)', () {
      expect(kSyncedTables.length, kSyncedTables.toSet().length);
    });
  });

  group('SyncReport — modèle de retour', () {
    test('valeurs par défaut : pushed/pulled/errors à 0', () {
      const r = SyncReport(success: true);
      expect(r.success, isTrue);
      expect(r.pushed, 0);
      expect(r.pulled, 0);
      expect(r.errors, 0);
      expect(r.message, isNull);
    });

    test('expose tous les compteurs et message', () {
      const r = SyncReport(
        success: false,
        pushed: 3,
        pulled: 7,
        errors: 2,
        message: 'partiel',
      );
      expect(r.success, isFalse);
      expect(r.pushed, 3);
      expect(r.pulled, 7);
      expect(r.errors, 2);
      expect(r.message, 'partiel');
    });
  });

  group('SyncService — singleton', () {
    test('instance est unique et non null', () {
      expect(SyncService.instance, isNotNull);
      expect(identical(SyncService.instance, SyncService.instance), isTrue);
    });
  });

  group('Opérations HTTP + DB + connectivity', () {
    test(
      'signUp / signIn / signOut / synchroniser / listenConnectivity — skip',
      () {
        // Nécessitent http réel + DBHelper (SQLCipher) + connectivity_plus.
        // Couverture via integration_test sur device, ou unit tests à venir
        // une fois que SyncService accepte une injection de http.Client +
        // d'un repo SyncConfig.
      },
      skip: 'Nécessite mocks HTTP + platform channels (hors scope flutter_test)',
    );
  });
}
