// ──────────────────────────────────────────────────────────────
// Modèle de données : Réglages de l'application
// ──────────────────────────────────────────────────────────────
// Stocke les préférences utilisateur :
// - Activation/désactivation de la gamification (streaks, badges)
// - Tolérance de streak (nombre de jours de pause autorisés)
// - Heures de notifications quotidiennes
//
// Une seule ligne dans la table `reglages` (id=1, singleton).
// ──────────────────────────────────────────────────────────────

/// Modes de thème supportés (V2.3 — Phase 3)
const kThemeModes = ['system', 'light', 'dark'];

String themeModeLabel(String m) => switch (m) {
      'light' => 'Clair',
      'dark' => 'Sombre',
      _ => 'Système',
    };

/// Devises disponibles (code affiché dans l'app)
const kDevises = ['€', '\$', '£', 'FCFA', 'MAD', 'DZD', 'TND', 'GNF'];

class Reglages {
  final int id;
  final bool gamificationActive;       // Afficher streaks, badges, niveaux
  final int toleranceStreakJours;      // Jours de pause autorisés sans casser le streak (par défaut 1)
  final String heureRappelMatin;       // HH:MM
  final String heureRappelMidi;        // HH:MM
  final String heureRappelSoir;        // HH:MM
  final bool notificationsActives;     // Désactiver toutes les notifications
  final String themeMode;              // 'system' | 'light' | 'dark' (V2.3)
  final bool onboardingDone;           // Onboarding effectué (V2.3)
  final String devise;                 // Symbole devise (V2.5)
  final bool modeSoleil;               // Texte +25%, thème forcé clair (R5)
  final bool modeGants;                // Cibles tactiles agrandies (R5)

  const Reglages({
    this.id = 1,
    this.gamificationActive = true,
    this.toleranceStreakJours = 1,
    this.heureRappelMatin = '07:00',
    this.heureRappelMidi = '12:00',
    this.heureRappelSoir = '18:00',
    this.notificationsActives = true,
    this.themeMode = 'system',
    this.onboardingDone = false,
    this.devise = '€',
    this.modeSoleil = false,
    this.modeGants = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'gamification_active': gamificationActive ? 1 : 0,
        'tolerance_streak_jours': toleranceStreakJours,
        'heure_rappel_matin': heureRappelMatin,
        'heure_rappel_midi': heureRappelMidi,
        'heure_rappel_soir': heureRappelSoir,
        'notifications_actives': notificationsActives ? 1 : 0,
        'theme_mode': themeMode,
        'onboarding_done': onboardingDone ? 1 : 0,
        'devise': devise,
        'mode_soleil': modeSoleil ? 1 : 0,
        'mode_gants': modeGants ? 1 : 0,
      };

  factory Reglages.fromMap(Map<String, dynamic> m) => Reglages(
        id: m['id'] ?? 1,
        gamificationActive: (m['gamification_active'] ?? 1) == 1,
        toleranceStreakJours: m['tolerance_streak_jours'] ?? 1,
        heureRappelMatin: m['heure_rappel_matin'] ?? '07:00',
        heureRappelMidi: m['heure_rappel_midi'] ?? '12:00',
        heureRappelSoir: m['heure_rappel_soir'] ?? '18:00',
        notificationsActives: (m['notifications_actives'] ?? 1) == 1,
        themeMode: (m['theme_mode'] as String?) ?? 'system',
        onboardingDone: (m['onboarding_done'] ?? 0) == 1,
        devise: (m['devise'] as String?) ?? '€',
        modeSoleil: (m['mode_soleil'] ?? 0) == 1,
        modeGants: (m['mode_gants'] ?? 0) == 1,
      );

  Reglages copyWith({
    bool? gamificationActive,
    int? toleranceStreakJours,
    String? heureRappelMatin,
    String? heureRappelMidi,
    String? heureRappelSoir,
    bool? notificationsActives,
    String? themeMode,
    bool? onboardingDone,
    String? devise,
    bool? modeSoleil,
    bool? modeGants,
  }) => Reglages(
        id: id,
        gamificationActive: gamificationActive ?? this.gamificationActive,
        toleranceStreakJours: toleranceStreakJours ?? this.toleranceStreakJours,
        heureRappelMatin: heureRappelMatin ?? this.heureRappelMatin,
        heureRappelMidi: heureRappelMidi ?? this.heureRappelMidi,
        heureRappelSoir: heureRappelSoir ?? this.heureRappelSoir,
        notificationsActives: notificationsActives ?? this.notificationsActives,
        themeMode: themeMode ?? this.themeMode,
        onboardingDone: onboardingDone ?? this.onboardingDone,
        devise: devise ?? this.devise,
        modeSoleil: modeSoleil ?? this.modeSoleil,
        modeGants: modeGants ?? this.modeGants,
      );
}
