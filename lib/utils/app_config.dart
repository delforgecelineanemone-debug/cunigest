// ──────────────────────────────────────────────────────────────
// AppConfig — Constantes de configuration (V3.1)
// ──────────────────────────────────────────────────────────────
// URL Supabase + anon key + Google Web Client ID sont PUBLIQUES par
// design — toute application mobile les embarque en clair (RLS et
// OAuth les protègent côté serveur). On les met donc en defaultValue
// pour que l'app marche aussi bien via `flutter run` qu'Android Studio
// sans avoir à passer des --dart-define à chaque lancement.
//
// Les vraies secrets (Service Role Key Supabase, Google Client Secret)
// ne sont JAMAIS dans le code — uniquement côté serveur Supabase.
//
// Override possible via --dart-define pour les builds release / autre
// environnement (cf. build_debug.bat).
// ──────────────────────────────────────────────────────────────

class AppConfig {
  AppConfig._();

  /// URL du projet Supabase (override via --dart-define=SUPABASE_URL=...)
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://psqjcgdzauwsdplxgdjn.supabase.co',
  );

  /// Clé anonyme Supabase — publique par design (protégée par RLS).
  /// Override via --dart-define=SUPABASE_ANON_KEY=...
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBzcWpjZ2R6YXV3c2RwbHhnZGpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc1MzAxMDIsImV4cCI6MjA5MzEwNjEwMn0.Hpcp_5eWgLbrNKzbefQ2AexLk8G_n-EOM5AlXdv68IM',
  );

  static const bool hasSupabaseDefaults =
      supabaseUrl != '' && supabaseAnonKey != '';

  /// Web OAuth 2.0 Client ID (Google Cloud Console — type "Web application").
  /// Utilisé côté Flutter comme `serverClientId` dans google_sign_in pour
  /// que l'idToken soit issu avec cet audience, qui doit être listé dans
  /// Supabase Dashboard → Auth → Google → "Authorized Client IDs".
  ///
  /// Cette valeur est PUBLIQUE par design (présente dans le code mobile) ;
  /// le Client Secret correspondant reste uniquement sur Supabase serveur.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '987378365809-fphspu8db5q25dfb3qn4sf8i8jtfkc92.apps.googleusercontent.com',
  );

  static const bool hasGoogleOAuth = googleWebClientId != '';

  /// Empreintes SHA-256 (DER) de certificats FEUILLE autorisés —
  /// pinning « strict » optionnel utilisé par [CertificatePinningService].
  ///
  /// VIDE PAR DÉFAUT : le certificat feuille de Supabase est renouvelé
  /// tous les ~90 jours ; le figer ici bloquerait l'app à chaque
  /// rotation. On préfère le pinning par ÉMETTEUR (cf. [trustedCertIssuers])
  /// qui, lui, survit aux rotations. Ne renseigner des empreintes ici
  /// que pour un verrouillage temporaire très strict.
  ///
  /// Override possible via --dart-define=PINNED_CERT_SHA256=hash1,hash2
  static List<String> get pinnedCertSha256 {
    const raw = String.fromEnvironment('PINNED_CERT_SHA256', defaultValue: '');
    if (raw.isEmpty) return const [];
    return raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  /// Émetteur(s) de confiance du certificat Supabase — pinning par
  /// autorité de certification. ACTIF PAR DÉFAUT.
  ///
  /// Le certificat feuille de `*.supabase.co` est délivré par Google
  /// Trust Services. On exige que la chaîne TLS présentée provienne bien
  /// de cet émetteur : un proxy MITM (CA pirate ajoutée dans le magasin
  /// de l'appareil, faux Wi-Fi d'entreprise) présenterait un certificat
  /// signé par une autre autorité → connexion bloquée.
  ///
  /// Contrairement au pinning du certificat feuille, ce pinning survit
  /// à la rotation tous les 90 jours : l'autorité reste stable des années.
  ///
  /// Override possible via --dart-define=TRUSTED_CERT_ISSUERS=a,b
  static List<String> get trustedCertIssuers {
    const raw = String.fromEnvironment('TRUSTED_CERT_ISSUERS', defaultValue: '');
    if (raw.isEmpty) return const ['Google Trust Services'];
    return raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  /// DSN Sentry — crash reporting. Mis en defaultValue pour que les
  /// builds release remontent TOUJOURS les crashs, même si le script
  /// de build oublie le --dart-define. Le DSN est public par design
  /// (embarqué dans toute app cliente Sentry — il autorise uniquement
  /// l'envoi d'événements, jamais la lecture).
  /// Override possible via --dart-define=SENTRY_DSN=...
  static const String sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue:
        'https://d4e8b89b6099612275981b3aec48ff89@o4511347316359168.ingest.de.sentry.io/4511347322126416',
  );

  /// Environnement Sentry (`production` par défaut, `debug` en dev).
  static const String sentryEnv = String.fromEnvironment(
    'SENTRY_ENV',
    defaultValue: 'production',
  );

  /// Âge maximal (jours) de la clé de chiffrement SQLCipher avant
  /// qu'une rotation soit proposée. Cf. EncryptionKeyService.
  static const int dbKeyMaxAgeDays = 90;

  /// Nom de l'application (affiché dans les rapports PDF)
  static const String appName = 'CuniGest';

  /// Version humaine (mise à jour manuellement à chaque release)
  static const String appVersion = '2.5.0';
}
