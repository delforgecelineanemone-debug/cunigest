// Tests : CertificatePinningService — défense MITM.
//
// Depuis l'audit sécurité, le pinning par ÉMETTEUR est ACTIF PAR
// DÉFAUT (`AppConfig.trustedCertIssuers` → Google Trust Services).
// Ce pinning survit à la rotation du certificat feuille de Supabase
// tous les ~90 jours, car l'autorité de certification reste stable.
//
// Le pinning STRICT par empreinte feuille (`pinnedCertSha256`) reste
// optionnel et vide par défaut.
//
// Les vérifications réseau réelles ne sont pas exécutées ici (elles
// dépendent de la connectivité) — on teste le contrat de configuration.

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_cunicole/services/certificate_pinning_service.dart';
import 'package:gestion_cunicole/utils/app_config.dart';

void main() {
  group('CertificatePinningService — configuration par défaut', () {
    test('aucune empreinte feuille stricte configurée par défaut', () {
      // Sans --dart-define=PINNED_CERT_SHA256, la liste est vide :
      // on ne fige pas le certificat feuille (il tourne tous les 90 j).
      expect(AppConfig.pinnedCertSha256, isEmpty);
    });

    test('un émetteur de confiance est configuré par défaut', () {
      expect(AppConfig.trustedCertIssuers, isNotEmpty);
      expect(AppConfig.trustedCertIssuers, contains('Google Trust Services'));
    });

    test('le pinning est actif par défaut (via l\'émetteur)', () {
      expect(CertificatePinningService.instance.isEnabled, isTrue);
    });
  });

  group('AppConfig.dbKeyMaxAgeDays', () {
    test('vaut 90 jours (politique de rotation)', () {
      expect(AppConfig.dbKeyMaxAgeDays, 90);
    });
  });
}
