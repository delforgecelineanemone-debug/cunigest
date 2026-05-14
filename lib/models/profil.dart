// ──────────────────────────────────────────────────────────────
// Modèle de données : Profil Éleveur (Gamification)
// ──────────────────────────────────────────────────────────────
// Stocke les données de gamification de l'éleveur :
// - Streak (jours consécutifs avec routines complétées)
// - Score total cumulé
// - Niveau de l'éleveur
// - Badges débloqués
//
// Objectif : motiver l'éleveur à maintenir ses routines
// ──────────────────────────────────────────────────────────────

/// Profil de l'éleveur avec données de gamification
class ProfilEleveur {
  final int? id;
  int streakActuel;          // Nombre de jours consécutifs
  int meilleurStreak;        // Record personnel
  int scoreTotal;            // Score cumulé (total de tous les jours)
  int scoreAujourdhui;       // Score du jour actuel
  int niveau;                // Niveau de l'éleveur (1 à 50)
  String? derniereActivite;  // Date de la dernière activité
  final String dateCreation;

  ProfilEleveur({
    this.id,
    this.streakActuel = 0,
    this.meilleurStreak = 0,
    this.scoreTotal = 0,
    this.scoreAujourdhui = 0,
    this.niveau = 1,
    this.derniereActivite,
    String? dateCreation,
  }) : dateCreation = dateCreation ?? DateTime.now().toIso8601String().substring(0, 10);

  /// Convertit en Map pour la base de données
  Map<String, dynamic> toMap() => {
        'id': id,
        'streak_actuel': streakActuel,
        'meilleur_streak': meilleurStreak,
        'score_total': scoreTotal,
        'score_aujourdhui': scoreAujourdhui,
        'niveau': niveau,
        'derniere_activite': derniereActivite,
        'date_creation': dateCreation,
      };

  /// Crée un ProfilEleveur depuis une Map
  factory ProfilEleveur.fromMap(Map<String, dynamic> m) => ProfilEleveur(
        id: m['id'],
        streakActuel: m['streak_actuel'] ?? 0,
        meilleurStreak: m['meilleur_streak'] ?? 0,
        scoreTotal: m['score_total'] ?? 0,
        scoreAujourdhui: m['score_aujourdhui'] ?? 0,
        niveau: m['niveau'] ?? 1,
        derniereActivite: m['derniere_activite'],
        dateCreation: m['date_creation'],
      );

  /// Emoji du niveau selon la progression
  String get niveauIcon {
    if (niveau >= 40) return '👑';
    if (niveau >= 30) return '🏆';
    if (niveau >= 20) return '⭐';
    if (niveau >= 10) return '🌟';
    if (niveau >= 5) return '🌱';
    return '🥚';
  }

  /// Titre du niveau
  String get niveauTitre {
    if (niveau >= 40) return 'Maître Cuniculteur';
    if (niveau >= 30) return 'Expert';
    if (niveau >= 20) return 'Confirmé';
    if (niveau >= 10) return 'Intermédiaire';
    if (niveau >= 5) return 'Apprenti';
    return 'Débutant';
  }

  /// Calcule le niveau à partir du score total
  /// Chaque niveau requiert 500 points de plus que le précédent
  static int calculerNiveau(int scoreTotal) {
    int niveau = 1;
    int seuilProchain = 500;
    int scoreCumule = 0;
    while (scoreCumule + seuilProchain <= scoreTotal && niveau < 50) {
      scoreCumule += seuilProchain;
      niveau++;
      seuilProchain = 500 * niveau;
    }
    return niveau;
  }

  /// Points nécessaires pour le prochain niveau
  int get pointsProchainNiveau => 500 * niveau;

  /// Points accumulés dans le niveau actuel
  int get pointsDansNiveau {
    int scoreCumule = 0;
    for (int n = 1; n < niveau; n++) {
      scoreCumule += 500 * n;
    }
    return scoreTotal - scoreCumule;
  }

  /// Progression vers le prochain niveau (0.0 à 1.0)
  double get progressionNiveau {
    final total = pointsProchainNiveau;
    if (total <= 0) return 1.0;
    return (pointsDansNiveau / total).clamp(0.0, 1.0);
  }

  /// Emoji du streak
  String get streakIcon {
    if (streakActuel >= 30) return '🔥🔥🔥';
    if (streakActuel >= 14) return '🔥🔥';
    if (streakActuel >= 7) return '🔥';
    if (streakActuel >= 3) return '✨';
    return '💫';
  }
}

/// Badge déblocable par l'éleveur
class BadgeEleveur {
  final int? id;
  final String code;           // Identifiant unique du badge
  final String nom;            // Nom affiché
  final String description;    // Comment le débloquer
  final String icone;          // Emoji du badge
  final String? dateObtenu;    // null = pas encore obtenu

  const BadgeEleveur({
    this.id,
    required this.code,
    required this.nom,
    required this.description,
    required this.icone,
    this.dateObtenu,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'nom': nom,
        'description': description,
        'icone': icone,
        'date_obtenu': dateObtenu,
      };

  factory BadgeEleveur.fromMap(Map<String, dynamic> m) => BadgeEleveur(
        id: m['id'],
        code: m['code'],
        nom: m['nom'],
        description: m['description'],
        icone: m['icone'],
        dateObtenu: m['date_obtenu'],
      );

  bool get estObtenu => dateObtenu != null;

  /// Liste de tous les badges disponibles dans l'application
  static const List<BadgeEleveur> tousLesBadges = [
    BadgeEleveur(code: 'premier_pas', nom: 'Premier Pas', description: 'Compléter sa première routine quotidienne', icone: '🌱'),
    BadgeEleveur(code: 'semaine_parfaite', nom: 'Semaine Parfaite', description: '7 jours de streak consécutifs', icone: '🔥'),
    BadgeEleveur(code: 'mois_parfait', nom: 'Mois Parfait', description: '30 jours de streak consécutifs', icone: '🏆'),
    BadgeEleveur(code: 'eleveur_attentif', nom: 'Éleveur Attentif', description: '10 palpations enregistrées', icone: '👀'),
    BadgeEleveur(code: 'sage_femme', nom: 'Sage-Femme', description: '10 mises bas enregistrées', icone: '🐣'),
    BadgeEleveur(code: 'docteur', nom: 'Docteur', description: '20 soins enregistrés', icone: '💊'),
    BadgeEleveur(code: 'commercial', nom: 'Commercial', description: '10 ventes effectuées', icone: '💰'),
    BadgeEleveur(code: 'gestionnaire', nom: 'Gestionnaire', description: 'Stock toujours au-dessus du seuil pendant 30 jours', icone: '📦'),
    BadgeEleveur(code: 'centurion', nom: 'Centurion', description: 'Atteindre 100 jours de streak', icone: '💎'),
    BadgeEleveur(code: 'premier_lapin', nom: 'Premier Lapin', description: 'Enregistrer son premier lapin', icone: '🐇'),
  ];
}
