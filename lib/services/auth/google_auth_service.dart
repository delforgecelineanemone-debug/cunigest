// ──────────────────────────────────────────────────────────────
// GoogleAuthService — Sign-In Google natif (V3.1)
// ──────────────────────────────────────────────────────────────
// Flow "one-tap" mobile premium :
//   1. L'utilisateur tape « Continuer avec Google »
//   2. Popup natif Google (pas de navigateur externe)
//   3. On récupère un idToken + accessToken
//   4. On échange contre une session Supabase via signInWithIdToken
//   5. Supabase persiste la session — auto-refresh des tokens géré
//
// Pas de deep link nécessaire grâce à `google_sign_in` natif.
// ──────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/app_config.dart';

/// Résultat d'une tentative de connexion Google.
class GoogleAuthResult {
  /// Session Supabase créée (null si échec ou annulation).
  final Session? session;

  /// Email du compte Google connecté (utile pour pré-remplir le profil).
  final String? email;

  /// Nom affiché du compte Google.
  final String? displayName;

  /// Message d'erreur lisible pour l'utilisateur (null si succès).
  final String? error;

  /// True si l'utilisateur a annulé volontairement (cas non-erreur).
  final bool cancelled;

  const GoogleAuthResult._({
    this.session,
    this.email,
    this.displayName,
    this.error,
    this.cancelled = false,
  });

  factory GoogleAuthResult.success({
    required Session session,
    String? email,
    String? displayName,
  }) =>
      GoogleAuthResult._(
        session: session,
        email: email,
        displayName: displayName,
      );

  factory GoogleAuthResult.cancelled() =>
      const GoogleAuthResult._(cancelled: true);

  factory GoogleAuthResult.error(String message) =>
      GoogleAuthResult._(error: message);

  bool get isSuccess => session != null;
}

class GoogleAuthService {
  GoogleAuthService._();
  static final GoogleAuthService instance = GoogleAuthService._();

  /// `serverClientId` = Web Client ID Google Cloud Console.
  /// L'idToken sera issu avec cet audience, qui doit être autorisé
  /// dans Supabase Dashboard → Auth → Google → "Authorized Client IDs".
  GoogleSignIn _signIn() => GoogleSignIn(
        serverClientId: AppConfig.googleWebClientId,
        scopes: const ['email', 'profile', 'openid'],
      );

  /// Lance le flow Google Sign-In natif + crée une session Supabase.
  ///
  /// Cas d'usage :
  ///   - Premier lancement : onboarding "Continuer avec Google"
  ///   - Reconnexion après expiration : bannière sur Dashboard
  Future<GoogleAuthResult> signIn() async {
    if (!AppConfig.hasGoogleOAuth) {
      return GoogleAuthResult.error(
        'Connexion Google non configurée sur cette version.',
      );
    }
    if (!AppConfig.hasSupabaseDefaults) {
      return GoogleAuthResult.error(
        'Sauvegarde cloud non disponible.',
      );
    }

    try {
      final googleSignIn = _signIn();
      final account = await googleSignIn.signIn();
      if (account == null) {
        // Utilisateur a fermé le popup
        return GoogleAuthResult.cancelled();
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      final accessToken = auth.accessToken;

      if (idToken == null) {
        return GoogleAuthResult.error(
          'Réponse Google incomplète (idToken manquant).',
        );
      }

      // Échange contre une session Supabase
      final supabase = Supabase.instance.client;
      final response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.session == null) {
        return GoogleAuthResult.error(
          'Session Supabase non créée. Réessaye.',
        );
      }

      debugPrint(
          'Google Sign-In ✅ ${account.email} (uid: ${response.user?.id})');
      return GoogleAuthResult.success(
        session: response.session!,
        email: account.email,
        displayName: account.displayName,
      );
    } on AuthException catch (e) {
      debugPrint('Google Sign-In Supabase erreur : ${e.message}');
      return GoogleAuthResult.error(_traduireErreur(e.message));
    } catch (e) {
      debugPrint('Google Sign-In exception : $e');
      return GoogleAuthResult.error(_traduireErreur(e.toString()));
    }
  }

  /// Déconnecte le compte Google natif (révoque le grant local).
  /// Ne touche PAS la session Supabase — utiliser supabase.auth.signOut()
  /// pour ça séparément.
  Future<void> signOutGoogle() async {
    try {
      await _signIn().signOut();
    } catch (e) {
      debugPrint('Google signOut erreur : $e');
    }
  }

  /// Traduit les erreurs techniques en français lisible.
  String _traduireErreur(String raw) {
    final r = raw.toLowerCase();
    if (r.contains('network') || r.contains('internet')) {
      return 'Pas d\'internet. Réessaye dans un moment.';
    }
    if (r.contains('cancel')) {
      return 'Connexion annulée.';
    }
    if (r.contains('developer_error') || r.contains('10:')) {
      return 'Configuration Google incorrecte (SHA-1 ou package). '
          'Contacte le support.';
    }
    if (r.contains('audience') || r.contains('invalid_token')) {
      return 'Identifiant Google non reconnu. Vérifie la config.';
    }
    return 'Connexion Google impossible. Réessaye plus tard.';
  }
}
