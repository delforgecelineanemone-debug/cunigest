// ──────────────────────────────────────────────────────────────
// Validators — Helpers centralisés de validation métier
// ──────────────────────────────────────────────────────────────
// Bornes réalistes pour un élevage cunicole pro, anti-saisies
// absurdes (négatifs, valeurs aberrantes, unités confondues).
//
// Tous renvoient String? compatible TextFormField.validator :
//   - null  : la valeur est valide
//   - String: message d'erreur affiché sous le champ
//
// Convention : les champs OPTIONNELS sont validés UNIQUEMENT
// quand l'utilisateur a saisi quelque chose. Les champs
// OBLIGATOIRES doivent être combinés avec Validators.requis().
// ──────────────────────────────────────────────────────────────

class Validators {
  Validators._();

  // ── Constantes métier (bornes réalistes élevage) ──
  static const double poidsMaxLapinKg = 12.0; // race géante max
  static const double poidsMinLapinKg = 0.01; // 10 g (lapereau nouveau-né)
  static const double poidsMaxLotKg = 5000.0; // 5 tonnes (lot industriel)
  static const double prixMax = 100000000.0; // 100 M (FCFA / €) — gros lot
  static const int delaiAttenteMaxJours = 120; // 4 mois = max pratique
  static const int nombreMaxPortee = 30; // record absolu ≈ 24
  static const int quantiteMaxStock = 100000; // 100 t aliment

  // ──────────────────────────────────────────────────────────
  // Champs obligatoires (string)
  // ──────────────────────────────────────────────────────────
  static String? requis(String? v, {String message = 'Champ obligatoire'}) {
    if (v == null || v.trim().isEmpty) return message;
    return null;
  }

  static String? choixRequis<T>(T? v, {String message = 'Choix obligatoire'}) {
    if (v == null) return message;
    if (v is String && v.trim().isEmpty) return message;
    return null;
  }

  // ──────────────────────────────────────────────────────────
  // Helpers numériques (parsing tolérant : virgule OU point)
  // ──────────────────────────────────────────────────────────
  static double? _parseDouble(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return double.tryParse(v.trim().replaceAll(',', '.'));
  }

  static int? _parseInt(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return int.tryParse(v.trim());
  }

  // ──────────────────────────────────────────────────────────
  // Poids lapin individuel (kg) — optionnel
  // ──────────────────────────────────────────────────────────
  /// Bornes : 0.01 kg (10 g lapereau) à 12 kg (race géante).
  /// Refuse négatifs, zéro, et valeurs aberrantes.
  static String? poidsLapin(String? v, {bool requisField = false}) {
    if (v == null || v.trim().isEmpty) {
      return requisField ? 'Poids obligatoire' : null;
    }
    final p = _parseDouble(v);
    if (p == null) return 'Nombre invalide';
    if (p <= 0) return 'Doit être supérieur à 0';
    if (p < poidsMinLapinKg) return 'Poids trop faible (min 10 g)';
    if (p > poidsMaxLapinKg) {
      return 'Poids irréaliste (max ${poidsMaxLapinKg.toInt()} kg)';
    }
    return null;
  }

  // ──────────────────────────────────────────────────────────
  // Poids lot / portée (kg) — total
  // ──────────────────────────────────────────────────────────
  static String? poidsLot(String? v, {bool requisField = false}) {
    if (v == null || v.trim().isEmpty) {
      return requisField ? 'Poids obligatoire' : null;
    }
    final p = _parseDouble(v);
    if (p == null) return 'Nombre invalide';
    if (p <= 0) return 'Doit être supérieur à 0';
    if (p > poidsMaxLotKg) return 'Poids trop élevé';
    return null;
  }

  // ──────────────────────────────────────────────────────────
  // Prix / Montant (devise neutre — FCFA ou €)
  // ──────────────────────────────────────────────────────────
  /// Refuse négatifs et zéro (un prix doit être > 0).
  /// Accepte les centimes (décimales).
  static String? prix(String? v, {bool requisField = true}) {
    if (v == null || v.trim().isEmpty) {
      return requisField ? 'Prix obligatoire' : null;
    }
    final p = _parseDouble(v);
    if (p == null) return 'Montant invalide';
    if (p <= 0) return 'Doit être supérieur à 0';
    if (p > prixMax) return 'Montant trop élevé';
    return null;
  }

  /// Variante : prix peut être 0 (cadeau, échange) mais pas négatif.
  static String? prixOuZero(String? v, {bool requisField = false}) {
    if (v == null || v.trim().isEmpty) {
      return requisField ? 'Montant obligatoire' : null;
    }
    final p = _parseDouble(v);
    if (p == null) return 'Montant invalide';
    if (p < 0) return 'Ne peut pas être négatif';
    if (p > prixMax) return 'Montant trop élevé';
    return null;
  }

  // ──────────────────────────────────────────────────────────
  // Délai d'attente médicament (jours)
  // ──────────────────────────────────────────────────────────
  /// 0 = pas de délai. Max 120 j (au-delà, animal sort du marché).
  static String? delaiAttenteJours(String? v, {bool requisField = false}) {
    if (v == null || v.trim().isEmpty) {
      return requisField ? 'Délai obligatoire' : null;
    }
    final n = _parseInt(v);
    if (n == null) return 'Nombre entier invalide';
    if (n < 0) return 'Ne peut pas être négatif';
    if (n > delaiAttenteMaxJours) {
      return 'Délai irréaliste (max $delaiAttenteMaxJours jours)';
    }
    return null;
  }

  // ──────────────────────────────────────────────────────────
  // Nombre de lapereaux (nés / vivants / morts / sevrés)
  // ──────────────────────────────────────────────────────────
  /// Borne max 30 (record absolu portée ≈ 24).
  static String? nombreLapinsPortee(String? v, {bool requisField = false}) {
    if (v == null || v.trim().isEmpty) {
      return requisField ? 'Nombre obligatoire' : null;
    }
    final n = _parseInt(v);
    if (n == null) return 'Nombre entier invalide';
    if (n < 0) return 'Ne peut pas être négatif';
    if (n > nombreMaxPortee) {
      return 'Nombre irréaliste (max $nombreMaxPortee)';
    }
    return null;
  }

  // ──────────────────────────────────────────────────────────
  // Quantité stock (kg, litres, unités)
  // ──────────────────────────────────────────────────────────
  static String? quantiteStock(String? v, {bool requisField = true}) {
    if (v == null || v.trim().isEmpty) {
      return requisField ? 'Quantité obligatoire' : null;
    }
    final q = _parseDouble(v);
    if (q == null) return 'Quantité invalide';
    if (q <= 0) return 'Doit être supérieure à 0';
    if (q > quantiteMaxStock) return 'Quantité trop élevée';
    return null;
  }

  // ──────────────────────────────────────────────────────────
  // Quantité entière (nombre d'animaux dans lot, vente, etc.)
  // ──────────────────────────────────────────────────────────
  static String? quantiteEntiere(String? v, {
    bool requisField = true,
    int min = 1,
    int max = 10000,
  }) {
    if (v == null || v.trim().isEmpty) {
      return requisField ? 'Quantité obligatoire' : null;
    }
    final n = _parseInt(v);
    if (n == null) return 'Nombre entier invalide';
    if (n < min) return 'Doit être ≥ $min';
    if (n > max) return 'Quantité trop élevée';
    return null;
  }

  // ──────────────────────────────────────────────────────────
  // Pourcentage (0-100)
  // ──────────────────────────────────────────────────────────
  static String? pourcentage(String? v, {bool requisField = false}) {
    if (v == null || v.trim().isEmpty) {
      return requisField ? 'Pourcentage obligatoire' : null;
    }
    final p = _parseDouble(v);
    if (p == null) return 'Nombre invalide';
    if (p < 0 || p > 100) return 'Doit être entre 0 et 100';
    return null;
  }

  // ──────────────────────────────────────────────────────────
  // Date ISO (YYYY-MM-DD) — pas dans le futur
  // ──────────────────────────────────────────────────────────
  static String? dateIsoPassee(String? v, {bool requisField = false}) {
    if (v == null || v.trim().isEmpty) {
      return requisField ? 'Date obligatoire' : null;
    }
    final d = DateTime.tryParse(v);
    if (d == null) return 'Date invalide';
    if (d.isAfter(DateTime.now())) return 'Ne peut pas être dans le futur';
    return null;
  }

  /// Vérifie que date2 (ex: mise-bas réelle) est >= date1 (ex: saillie).
  /// Renvoie message si incohérent, null sinon. À utiliser hors validator
  /// (cross-field) avant submit.
  static String? dateApres({
    required String? date1Iso,
    required String? date2Iso,
    String label1 = 'date 1',
    String label2 = 'date 2',
  }) {
    if (date1Iso == null || date2Iso == null) return null;
    final d1 = DateTime.tryParse(date1Iso);
    final d2 = DateTime.tryParse(date2Iso);
    if (d1 == null || d2 == null) return null;
    if (d2.isBefore(d1)) {
      return 'La $label2 doit être après la $label1';
    }
    return null;
  }

  // ──────────────────────────────────────────────────────────
  // Cohérence portée : vivants <= nés
  // ──────────────────────────────────────────────────────────
  static String? coherenceNaissances({int? nes, int? vivants, int? morts}) {
    if (nes == null) return null;
    if (vivants != null && vivants > nes) {
      return 'Vivants ($vivants) ne peut pas dépasser nés ($nes)';
    }
    if (morts != null && morts > nes) {
      return 'Morts ($morts) ne peut pas dépasser nés ($nes)';
    }
    if (vivants != null && morts != null && (vivants + morts) > nes) {
      return 'Vivants + morts (${vivants + morts}) > nés ($nes)';
    }
    return null;
  }

  // ──────────────────────────────────────────────────────────
  // Normalisation de chaînes (anti-doublons casse)
  // ──────────────────────────────────────────────────────────
  /// Normalise une chaîne libre (race, couleur, type) pour éviter les
  /// doublons "Blanc" / "blanc" / "BLANC" / " Blanc " dans la base.
  /// Renvoie `null` si la chaîne est vide après trim.
  ///
  /// Stratégie : trim + lowercase + capitalize première lettre.
  /// Exemples : "  BLANC " → "Blanc" ; "néo-zélandais" → "Néo-zélandais".
  static String? normaliserNom(String? v) {
    if (v == null) return null;
    final trimmed = v.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }

  // ──────────────────────────────────────────────────────────
  // Combinateur — applique plusieurs validators
  // ──────────────────────────────────────────────────────────
  /// Renvoie le premier message d'erreur ; null si tous OK.
  static String? Function(String?) compose(
    List<String? Function(String?)> validators,
  ) {
    return (v) {
      for (final validator in validators) {
        final result = validator(v);
        if (result != null) return result;
      }
      return null;
    };
  }
}
