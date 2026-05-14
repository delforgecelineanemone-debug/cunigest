// ──────────────────────────────────────────────────────────────
// AppConfig — Constantes de configuration (V2.5)
// ──────────────────────────────────────────────────────────────
// Les valeurs Supabase sont injectées via --dart-define pour ne PAS
// apparaître en clair dans le code source (P0 audit).
//
// Build de développement offline :
//   flutter run
//
// Build de production (surcharge recommandée) :
//   flutter build apk \
//     --dart-define=SUPABASE_URL=<supabase-url> \
//     --dart-define=SUPABASE_ANON_KEY=<anon-key>
//
// Si les --dart-define ne sont pas fournis, la sync cloud reste non
// préconfigurée. Aucun secret/projet réel ne doit être hardcodé ici.
// ──────────────────────────────────────────────────────────────

class AppConfig {
  AppConfig._();

  /// URL du projet Supabase (injectable via --dart-define=SUPABASE_URL=...)
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Clé anonyme Supabase (injectable via --dart-define=SUPABASE_ANON_KEY=...)
  /// Cette clé est "publique" par design (protégée par le RLS côté serveur),
  /// mais ne doit pas être hardcodée dans le code source.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const bool hasSupabaseDefaults =
      supabaseUrl != '' && supabaseAnonKey != '';

  /// Nom de l'application (affiché dans les rapports PDF)
  static const String appName = 'CuniGest';

  /// Version humaine (mise à jour manuellement à chaque release)
  static const String appVersion = '2.5.0';
}
