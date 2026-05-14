// Référentiel métier cunicole — données de référence pour l'élevage du lapin.
// Utilisé pour les autocomplètes : races, couleurs, médicaments.
// Toutes les listes sont const pour ne pas allouer en build.

class CunicoleRef {
  CunicoleRef._();

  // ── Races ──────────────────────────────────────────────────────────────
  // Hybrides commerciaux (sélectionnés pour la production de viande)
  static const List<String> racesHybrides = [
    'Hyla',
    'Hycole',
    'ZIKA',
    'Hyplus',
    'Félix',
    'Lory',
    'Grimaud Frères',
    'ELCO',
  ];

  // Races pures — charpente / viande
  static const List<String> racesPures = [
    'Néo-Zélandais',
    'Californien',
    'Rex',
    'Fauve de Bourgogne',
    'Géant des Flandres',
    'Blanc de Termonde',
    'Blanc de Bouscat',
    'Géant Papillon',
    'Argenté de Champagne',
    'Bélier français',
    'Bélier anglais',
    'Papillon français',
    'Nain hollandais',
    'Angora français',
    'Angora anglais',
    'Chinchilla',
    'Havane',
    'Satin',
    'Perle de Halle',
    'Lapin de Garenne',
    'Autre',
  ];

  static List<String> get races => [...racesHybrides, ...racesPures];

  // ── Couleurs ────────────────────────────────────────────────────────────
  static const List<String> couleurs = [
    'Blanc',
    'Blanc cassé',
    'Gris agouti',
    'Gris argenté',
    'Gris perle',
    'Noir',
    'Brun',
    'Fauve',
    'Bleu',
    'Beige',
    'Isabelle',
    'Lilas',
    'Tricolore',
    'Bicolore blanc-brun',
    'Bicolore blanc-noir',
    'Marbré',
    'Tacheté',
    'Argenté',
    'Rex (velours)',
    'Havane',
    'Autre',
  ];

  // ── Médicaments & produits vétérinaires ──────────────────────────────────
  // Classés par famille thérapeutique pour faciliter la recherche
  static const List<String> medicamentsAntibiotiques = [
    'Baytril (enrofloxacine)',
    'Enroxil (enrofloxacine)',
    'Draxxin (tulathromycine)',
    'Tiamuline',
    'Lincomycine',
    'Furaltadone',
    'Néomycine',
    'Ampicilline',
    'Trimétoprime-sulfaméthoxazole',
  ];

  static const List<String> medicamentsAntiparasitaires = [
    'Ivermectine',
    'Fenbendazole',
    'Toltrazuril (anticoccidien)',
    'Sulfadiméthoxine (anticoccidien)',
    'Moxidectine',
  ];

  static const List<String> medicamentsVaccins = [
    'Nobivac Myxo-RHD (myxomatose + VHD1)',
    'Myxoherpevax (myxomatose)',
    'Dercunimix (myxomatose + VHD1)',
    'Filavac VHD K C+V (VHD1 + VHD2)',
    'Eravac (VHD2)',
    'Cunipravac VHD (VHD1)',
  ];

  static const List<String> medicamentsAntiInflammatoires = [
    'Finadyne (flunixine méglumine)',
    'Metacam (méloxicam)',
    'Robenacoxib',
    'Dexaméthasone',
  ];

  static const List<String> medicamentsVitamines = [
    'Vit E + Sélénium',
    'Vit A + D3 + E',
    'Catosal (vit B12 + phosphore)',
    'Vitamine C',
    'Complexe B',
  ];

  static const List<String> medicamentsDivers = [
    'Probiotiques',
    'Électrolytes oraux',
    'Charbon actif',
    'Huile de paraffine',
    'Ocytocine',
    'Calcium injectable',
    'Désinfectant (Virkon S)',
  ];

  /// Liste complète des produits pour l'autocomplete "produit utilisé"
  static List<String> get medicaments => [
    ...medicamentsVaccins,
    ...medicamentsAntibiotiques,
    ...medicamentsAntiparasitaires,
    ...medicamentsAntiInflammatoires,
    ...medicamentsVitamines,
    ...medicamentsDivers,
  ];
}
