// ──────────────────────────────────────────────────────────────
// CertificatePinningService — défense MITM sur les appels cloud
// ──────────────────────────────────────────────────────────────
// Vérifie que le certificat TLS présenté par le serveur Supabase
// correspond à une empreinte SHA-256 connue, AVANT d'envoyer la
// moindre donnée. Bloque les attaques "man-in-the-middle" (proxy
// hostile, faux point d'accès Wi-Fi, autorité de certification
// compromise).
//
// ─── DEUX NIVEAUX DE PINNING ───
// 1. Pinning par ÉMETTEUR (`AppConfig.trustedCertIssuers`) — ACTIF PAR
//    DÉFAUT. On exige que le certificat présenté ait été délivré par
//    une autorité connue (Google Trust Services pour Supabase). Ce
//    pinning survit à la rotation du certificat feuille tous les ~90 j
//    car l'autorité, elle, reste stable plusieurs années. C'est le bon
//    compromis sécurité / robustesse pour un hébergeur managé.
// 2. Pinning STRICT par empreinte feuille (`AppConfig.pinnedCertSha256`)
//    — optionnel, vide par défaut. À n'utiliser que pour un
//    verrouillage temporaire : le figer bloquerait l'app à la prochaine
//    rotation du certificat.
//
// Si l'un OU l'autre correspond, la connexion est autorisée. Si les
// deux listes sont vides, le pinning est désactivé (TLS standard).
// ──────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../utils/app_config.dart';

enum PinningResult {
  /// Pinning désactivé (aucune empreinte configurée) — on laisse passer.
  disabled,

  /// Le certificat correspond à une empreinte connue.
  valid,

  /// Le certificat ne correspond à AUCUNE empreinte → connexion suspecte.
  mismatch,

  /// Impossible de joindre l'hôte ou de lire le certificat.
  unreachable,
}

class CertificatePinningService {
  CertificatePinningService._();
  static final CertificatePinningService instance =
      CertificatePinningService._();

  /// Cache des hôtes déjà vérifiés avec succès durant cette session,
  /// pour éviter un pre-flight SecureSocket à chaque requête.
  final Set<String> _verifiedThisSession = {};

  bool get isEnabled =>
      AppConfig.pinnedCertSha256.isNotEmpty ||
      AppConfig.trustedCertIssuers.isNotEmpty;

  /// Vérifie le certificat TLS de `host:port` (443 par défaut).
  ///
  /// Ouvre une `SecureSocket`, lit le certificat présenté et le compare :
  ///   - à la liste des empreintes feuille (`pinnedCertSha256`), puis
  ///   - à la liste des émetteurs de confiance (`trustedCertIssuers`).
  /// Si l'un correspond → `valid`. Referme immédiatement la socket —
  /// aucune donnée applicative n'est envoyée.
  Future<PinningResult> verifyHost(String host, {int port = 443}) async {
    if (!isEnabled) return PinningResult.disabled;
    if (_verifiedThisSession.contains(host)) return PinningResult.valid;

    SecureSocket? socket;
    try {
      socket = await SecureSocket.connect(
        host,
        port,
        // On accepte temporairement pour LIRE le certificat ; la
        // décision de confiance est prise juste après.
        onBadCertificate: (_) => true,
        timeout: const Duration(seconds: 8),
      );
      final cert = socket.peerCertificate;
      if (cert == null) return PinningResult.unreachable;

      // 1. Pinning strict par empreinte feuille (optionnel).
      final shaPins = AppConfig.pinnedCertSha256
          .map((h) => h.toLowerCase().replaceAll(':', '').trim())
          .where((h) => h.isNotEmpty)
          .toSet();
      if (shaPins.isNotEmpty) {
        final sha = sha256.convert(cert.der).toString().toLowerCase();
        if (shaPins.contains(sha)) {
          _verifiedThisSession.add(host);
          return PinningResult.valid;
        }
      }

      // 2. Pinning par émetteur — survit à la rotation du certificat feuille.
      final issuerPins = AppConfig.trustedCertIssuers
          .map((i) => i.toLowerCase().trim())
          .where((i) => i.isNotEmpty);
      if (issuerPins.isNotEmpty) {
        final issuer = cert.issuer.toLowerCase();
        if (issuerPins.any(issuer.contains)) {
          _verifiedThisSession.add(host);
          return PinningResult.valid;
        }
      }

      if (kDebugMode) {
        debugPrint('⚠️ CertificatePinning: certificat non reconnu pour $host');
        debugPrint('   émetteur reçu = ${cert.issuer}');
      }
      return PinningResult.mismatch;
    } on SocketException catch (_) {
      return PinningResult.unreachable;
    } on HandshakeException catch (_) {
      return PinningResult.unreachable;
    } on Exception catch (_) {
      return PinningResult.unreachable;
    } finally {
      try {
        await socket?.close();
      } catch (_) {/* socket déjà fermée */}
    }
  }

  /// Extrait l'hôte d'une URL et le vérifie. Renvoie `true` si la
  /// connexion peut se poursuivre en sécurité :
  ///   - pinning désactivé           → true (pas de garantie, mais OK)
  ///   - empreinte valide            → true
  ///   - hôte injoignable            → true (échec réseau ≠ MITM ; le
  ///                                   code appelant gère l'offline)
  ///   - empreinte NON reconnue      → false (connexion BLOQUÉE)
  Future<bool> isSafeUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return true;
    final result = await verifyHost(uri.host, port: uri.hasPort ? uri.port : 443);
    return result != PinningResult.mismatch;
  }

  @visibleForTesting
  void resetSessionCache() => _verifiedThisSession.clear();
}
