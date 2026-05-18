// Tests : NotificationService — rappels et alertes locales
//
// SURFACE QUASI ENTIÈREMENT PLATFORM :
//   - flutter_local_notifications : platform channel Android natif
//   - flutter_timezone : MethodChannel pour la détection TZ système
//   - timezone : pur Dart MAIS init via tz_data.initializeTimeZones() lit
//     les ressources (OK), `tz.local` n'est défini qu'après `init()`
//   - DBHelper.instance : SQLCipher natif
//
// PURE TESTABLE :
//   - Le parser _Heure ("HH:MM") est privé → impossible à appeler depuis ici
//     sans modifier la prod.
//   - `_prochainHoraire` dépend de `tz.local` → non utilisable sans init().
//
// CONCLUSION : aucun helper public pur n'est exposé. On documente le skip.

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationService — surface entièrement platform-dépendante', () {
    test(
      'init / programmerRappelsQuotidiens / programmerAlertesReproduction / envoyerFelicitation — skip',
      () {
        // Couverture manuelle ou via integration_test sur device.
        // Les fonctions pures (_parseHeure, _prochainHoraire) sont privées
        // et indissociables du contexte timezone initialisé.
      },
      skip: 'Nécessite flutter_local_notifications + flutter_timezone + DBHelper (platform)',
    );
  });
}
