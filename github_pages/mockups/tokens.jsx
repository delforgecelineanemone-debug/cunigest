// tokens.jsx — Design tokens V3 alignés sur CuColors (cunicole_app)

// ── Palette officielle V3 « Field-Premium » (lib/ui/tokens/colors.dart) ──
const Cu = {
  // Brand
  primary: '#0F8C66',
  primarySoft: '#E6F4EE',
  primaryDarkVar: '#3DBE93',

  // Accents modules
  accentRepro: '#7C5CDB',
  accentReproDark: '#A48FE8',
  accentHealth: '#E24B4A',
  accentHealthDark: '#FF6B6A',
  accentFeed: '#D85A30',
  accentFeedDark: '#FF8A5C',
  accentFinance: '#B47416',
  accentFinanceDark: '#E1A24E',
  accentTools: '#1565C0',
  accentToolsDark: '#5B9BE8',
  accentAdmin: '#546E7A',

  // Surfaces light
  bgLight: '#FAF9F5',
  cardLight: '#FFFFFF',
  raisedLight: '#F2F0E9',
  navBgLight: '#FFFFFF',

  // Surfaces dark
  bgDark: '#0F1411',
  cardDark: '#1A211D',
  raisedDark: '#222B26',
  navBgDark: '#1A211D',

  // Texte light
  textPrimaryLight: '#1A1F1B',
  textSecondaryLight: '#5C6660',
  textDisabledLight: '#9AA29D',

  // Texte dark
  textPrimaryDark: '#F1EFE8',
  textSecondaryDark: '#A8B0AB',
  textDisabledDark: '#5C6660',

  // Bordures
  borderLight: '#E5E3DC',
  borderDark: '#2A332E',

  // États sémantiques
  success: '#2D9B5A',
  successDark: '#52C77F',
  warning: '#E8A02C',
  warningDark: '#FFC265',
  danger: '#D63B3A',
  dangerDark: '#FF6B6A',
  info: '#1565C0',
  infoDark: '#5B9BE8',

  // Statuts lapin
  statutActif: '#0F8C66',
  statutVendu: '#1565C0',
  statutMort: '#757575',
  statutSevrage: '#EF6C00',
  statutQuarantaine: '#B45309',

  // Statuts cage
  cageVide: '#9E9E9E',
  cageOccupee: '#1976D2',
  cageGestante: '#EC407A',
  cageAllaitement: '#AD1457',
  cageSevrage: '#EF6C00',
  cageQuarantaine: '#B45309',
  cageDesinfection: '#7B1FA2',
  cageMaintenance: '#424242',
};

// ── Theme ────────────────────────────────────────────────────
function makeTheme(dark) {
  if (!dark) {
    return {
      ...Cu,
      bg: Cu.bgLight,
      bgCard: Cu.cardLight,
      bgRaised: Cu.raisedLight,
      bgNav: Cu.navBgLight,
      ink: Cu.textPrimaryLight,
      inkSoft: Cu.textSecondaryLight,
      muted: Cu.textSecondaryLight,
      disabled: Cu.textDisabledLight,
      border: Cu.borderLight,
      borderSoft: '#EFEDE7',
      shadow: '0 1px 2px rgba(0,0,0,0.04), 0 2px 6px rgba(0,0,0,0.05)',
      // accents — mode clair: valeurs nominales
      accent: {
        primary: Cu.primary, primarySoft: Cu.primarySoft,
        repro: Cu.accentRepro, health: Cu.accentHealth,
        feed: Cu.accentFeed, finance: Cu.accentFinance,
        tools: Cu.accentTools, admin: Cu.accentAdmin,
        success: Cu.success, warning: Cu.warning, danger: Cu.danger, info: Cu.info,
      },
    };
  }
  return {
    ...Cu,
    bg: Cu.bgDark,
    bgCard: Cu.cardDark,
    bgRaised: Cu.raisedDark,
    bgNav: Cu.navBgDark,
    ink: Cu.textPrimaryDark,
    inkSoft: Cu.textSecondaryDark,
    muted: Cu.textSecondaryDark,
    disabled: Cu.textDisabledDark,
    border: Cu.borderDark,
    borderSoft: '#23292B',
    shadow: 'none',
    accent: {
      primary: Cu.primaryDarkVar, primarySoft: 'rgba(15,140,102,0.18)',
      repro: Cu.accentReproDark, health: Cu.accentHealthDark,
      feed: Cu.accentFeedDark, finance: Cu.accentFinanceDark,
      tools: Cu.accentToolsDark, admin: Cu.accentAdmin,
      success: Cu.successDark, warning: Cu.warningDark, danger: Cu.dangerDark, info: Cu.infoDark,
    },
  };
}

// Tinted helper: returns a softer background-tone of an accent color (matches
// the .withValues(alpha: 0.14) pattern used everywhere in the Flutter UI).
function tint(hex, alpha = 0.12) {
  const h = hex.replace('#', '');
  const v = h.length === 3 ? h.replace(/./g, (c) => c + c) : h;
  const r = parseInt(v.slice(0, 2), 16);
  const g = parseInt(v.slice(2, 4), 16);
  const b = parseInt(v.slice(4, 6), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

// ── Spacing (8-pt grid, identique à CuSpacing) ─────────────────
// V3 « Field-Premium » — mode gants force touchMin=56 (cible terrain),
// mode soleil applique +25% textScale (lisibilité plein soleil africain).
function makeDensity(d, { gants = false, soleil = false } = {}) {
  // Mode gants > density choice : impose toujours 56dp tactile minimum.
  const M = { compact: 0.85, regular: 1, comfy: 1.18 }[d] || 1;
  const r = (n) => Math.round(n * M);
  // Text scaler — boost typo de 25% en mode soleil pour lisibilité outdoor.
  // Clamp [1, 1.6] pour éviter casse layout.
  const textScale = soleil ? Math.min(1.6, Math.max(1, 1.25)) : 1;
  const touchMin = gants ? 56 : 48;
  return {
    M, scale: M, textScale, gants, soleil,
    xs: r(4), sm: r(8), md: r(12), lg: r(16), xl: r(24), x2l: r(32), x3l: r(48),
    pageH: r(16),
    rowH: gants ? 56 : Math.max(48, r(48)),
    touchMin,
    btnHeight: gants ? 56 : 48,
    iconSize: gants ? 28 : 22,
    radius: 12, radiusSm: 8, radiusLg: 16, radiusFull: 999,
  };
}

// ── Strings ────────────────────────────────────────────────────
const STR = {
  fr: {
    appName: 'CuniGest',
    // Nav onglets V3
    tabAccueil: 'Accueil', tabCheptel: 'Cheptel', tabRepro: 'Repro',
    tabTaches: 'Tâches', tabPlus: 'Plus',
    // Cheptel sub-tabs
    lapins: 'Lapins', lots: 'Lots', cages: 'Cages',
    // Dashboard
    lapinsActifs: 'Lapins actifs', recettesMois: 'Recettes / mois',
    lotsEnCours: 'Lots en cours', rappelsSante: 'Rappels santé (7j)',
    stocksCritiques: 'Stocks critiques', lotsActifs: 'Lots actifs',
    voirTout: 'Voir tout', repartitionCheptel: 'Répartition du cheptel',
    // Streak
    jours: 'jour', niveau: 'Nv.',
    record: 'Record',
    tachesDuJour: 'Tâches du jour',
    badgesDebloques: 'Badges débloqués',
    parfait: '🎉 Parfait ! Toutes les tâches sont faites !',
    bonneProg: '👍 Bonne progression, continuez !',
    cParti: '🌱 C\u2019est parti, bon début !',
    nouvelleJournee: '☀️ Nouvelle journée, nouvelles routines !',
    // Reproduction
    repro: 'Reproduction',
    enAttente: 'En attente', miseBas: 'Mise bas', sevrage: 'Sevrage',
    terminees: 'Terminées', echecs: 'Échecs',
    enregistrerSaillie: 'Enregistrer une saillie',
    saillie: 'Saillie',
    aucuneSaillie: 'Aucune saillie',
    accouplement: 'Enregistrez votre premier accouplement.',
    // Plus
    plus: 'Plus', elevage: 'Élevage', finances: 'Finances',
    outils: 'Outils', administration: 'Administration',
    alimentation: 'Alimentation', statsRepro: 'Stats repro',
    maRoutine: 'Ma Routine', calendrier: 'Calendrier',
    ventes: 'Ventes', depenses: 'Dépenses',
    rapportsPdf: 'Rapports PDF', exportCsv: 'Export CSV',
    calculatrices: 'Calculatrices', scannerQr: 'Scanner QR',
    sauvegardeCloud: 'Sauvegarde cloud',
    utilisateurs: 'Utilisateurs', reglages: 'Réglages',
    // Lapin
    ficheLapin: 'Fiche lapin',
    poidsActuel: 'Poids actuel', portees: 'Portées', age: 'Âge',
    mois: 'mois', naissance: 'Naissance', cage: 'Cage', lot: 'Lot',
    maleRepro: 'Mâle reproducteur', prochaineSaillie: 'Prochaine saillie',
    dernierVaccin: 'Dernier vaccin', courbePoids: 'Courbe de poids',
    historique: 'Historique',
    pesee: 'Pesée', traitement: 'Traitement', evenement: 'Événement',
    // Saillie form
    nouvelleSaillie: 'Nouvelle saillie',
    femelle: 'Femelle', male: 'Mâle', changer: 'Changer',
    dateSaillie: 'Date de la saillie',
    miseBasPrevue: 'Mise bas prévue', sevragePrevu: 'Sevrage prévu',
    calculeAuto: 'Calculé auto',
    resultat: 'Résultat',
    reussie: 'Réussie', douteuse: 'Douteuse', echouee: 'Échouée',
    observations: 'Observations (optionnel)',
    annuler: 'Annuler', enregistrer: 'Enregistrer',
    // Vente
    nouvelleVente: 'Nouvelle vente',
    lotAVendre: 'Lot à vendre', typeVente: 'Type de vente',
    poidsVif: 'Poids vif', carcasse: 'Carcasse',
    quantitePrix: 'Quantité et prix',
    poidsTotal: 'Poids total', prixUnitaire: 'Prix unitaire',
    montantTotal: 'Montant total',
    client: 'Client',
    rechercherClient: 'Rechercher ou créer un client...',
    // Login
    motDePasse: 'Mot de passe', entrer: 'Entrer',
    motDePasseOublie: 'Mot de passe oublié ?',
    bonjour: 'Bonjour',
    // Statuts
    actif: 'Actif', vendu: 'Vendu', mort: 'Mort', quarantaine: 'Quarantaine',
    engraissement: 'Engraissement', maternite: 'Maternité',
    // Cages
    bonEtat: 'Bon état', use: 'Usagée', reparation: 'En réparation',
    occupee: 'Occupée', vide: 'Vide', gestante: 'Gestante',
    allaitement: 'Allaitement', desinfection: 'Désinfection',
    // Misc
    sync: 'Sync', synchronise: 'Synchronisé', enAttenteSync: 'En attente',
    alertes: 'Alertes', voir: 'Voir',
    sectionAlertes: 'Alertes du jour',
    aucunCheptel: 'Aucun lapin enregistré',
    ajouterLapin: 'Ajouter un lapin',
    // Reglages / settings
    profil: 'Profil', langueLib: 'Langue',
    devise: 'Devise', mode: 'Mode',
    clair: 'Clair', sombre: 'Sombre',
    // Onboarding
    bienvenue: 'Bienvenue', gerezVotreFerme: 'Gérez votre ferme',
    continuer: 'Continuer',
    // dates
    aujourdhui: "Aujourd'hui",
    cuniculteur: 'Cuniculteur',
  },
  en: {
    appName: 'CuniGest',
    tabAccueil: 'Home', tabCheptel: 'Herd', tabRepro: 'Repro',
    tabTaches: 'Tasks', tabPlus: 'More',
    lapins: 'Rabbits', lots: 'Lots', cages: 'Cages',
    lapinsActifs: 'Active rabbits', recettesMois: 'Revenue / month',
    lotsEnCours: 'Active lots', rappelsSante: 'Health alerts (7d)',
    stocksCritiques: 'Critical stock', lotsActifs: 'Active lots',
    voirTout: 'See all', repartitionCheptel: 'Herd breakdown',
    jours: 'day', niveau: 'Lvl',
    record: 'Best',
    tachesDuJour: 'Today\u2019s tasks',
    badgesDebloques: 'Badges',
    parfait: '🎉 Perfect! All done today!',
    bonneProg: '👍 Good progress, keep going!',
    cParti: '🌱 Off to a good start!',
    nouvelleJournee: '☀️ New day, new routines!',
    repro: 'Breeding',
    enAttente: 'Pending', miseBas: 'Kindling', sevrage: 'Weaning',
    terminees: 'Done', echecs: 'Failed',
    enregistrerSaillie: 'Log a mating',
    saillie: 'Mating', aucuneSaillie: 'No matings',
    accouplement: 'Log your first mating.',
    plus: 'More', elevage: 'Farming', finances: 'Finance',
    outils: 'Tools', administration: 'Admin',
    alimentation: 'Feed', statsRepro: 'Repro stats',
    maRoutine: 'My routine', calendrier: 'Calendar',
    ventes: 'Sales', depenses: 'Expenses',
    rapportsPdf: 'PDF reports', exportCsv: 'CSV export',
    calculatrices: 'Calculators', scannerQr: 'QR scanner',
    sauvegardeCloud: 'Cloud backup',
    utilisateurs: 'Users', reglages: 'Settings',
    ficheLapin: 'Rabbit profile',
    poidsActuel: 'Current weight', portees: 'Litters', age: 'Age',
    mois: 'mo', naissance: 'Birth', cage: 'Cage', lot: 'Lot',
    maleRepro: 'Breeding male', prochaineSaillie: 'Next mating',
    dernierVaccin: 'Last vaccine', courbePoids: 'Weight curve',
    historique: 'History',
    pesee: 'Weighing', traitement: 'Treatment', evenement: 'Event',
    nouvelleSaillie: 'New mating',
    femelle: 'Female', male: 'Male', changer: 'Change',
    dateSaillie: 'Mating date',
    miseBasPrevue: 'Expected kindling', sevragePrevu: 'Expected weaning',
    calculeAuto: 'Auto', resultat: 'Result',
    reussie: 'Successful', douteuse: 'Doubtful', echouee: 'Failed',
    observations: 'Notes (optional)',
    annuler: 'Cancel', enregistrer: 'Save',
    nouvelleVente: 'New sale',
    lotAVendre: 'Lot to sell', typeVente: 'Sale type',
    poidsVif: 'Live weight', carcasse: 'Carcass',
    quantitePrix: 'Quantity & price',
    poidsTotal: 'Total weight', prixUnitaire: 'Unit price',
    montantTotal: 'Total amount',
    client: 'Customer',
    rechercherClient: 'Search or create a customer...',
    motDePasse: 'Password', entrer: 'Enter',
    motDePasseOublie: 'Forgot password?',
    bonjour: 'Hello',
    actif: 'Active', vendu: 'Sold', mort: 'Dead', quarantaine: 'Quarantine',
    engraissement: 'Fattening', maternite: 'Maternity',
    bonEtat: 'Good', use: 'Worn', reparation: 'Repair',
    occupee: 'Occupied', vide: 'Empty', gestante: 'Pregnant',
    allaitement: 'Nursing', desinfection: 'Disinfection',
    sync: 'Sync', synchronise: 'Synced', enAttenteSync: 'Pending',
    alertes: 'Alerts', voir: 'View',
    sectionAlertes: "Today\u2019s alerts",
    aucunCheptel: 'No rabbits yet',
    ajouterLapin: 'Add a rabbit',
    profil: 'Profile', langueLib: 'Language',
    devise: 'Currency', mode: 'Mode',
    clair: 'Light', sombre: 'Dark',
    bienvenue: 'Welcome', gerezVotreFerme: 'Manage your farm',
    continuer: 'Continue',
    aujourdhui: 'Today',
    cuniculteur: 'Farmer',
  },
};

const CURRENCIES = {
  FCFA: { sym: 'FCFA', after: true, format: (v) => v.toLocaleString('fr-FR') },
  '€': { sym: '€', after: true, format: (v) => v.toLocaleString('fr-FR') },
  '$': { sym: '$', after: false, format: (v) => v.toLocaleString('en-US') },
};

function formatMoney(v, code = 'FCFA') {
  const c = CURRENCIES[code] || CURRENCIES.FCFA;
  const num = c.format(v);
  return c.after ? `${num} ${c.sym}` : `${c.sym}${num}`;
}
function formatMoneyCompact(v, code = 'FCFA') {
  const c = CURRENCIES[code] || CURRENCIES.FCFA;
  let n;
  if (v >= 1_000_000) n = (v / 1_000_000).toFixed(1).replace('.0', '') + 'M';
  else if (v >= 1_000) n = (v / 1_000).toFixed(1).replace('.0', '') + 'k';
  else n = String(Math.round(v));
  return c.after ? `${n} ${c.sym}` : `${c.sym}${n}`;
}

// React context
const ThemeCtx = React.createContext(null);
function useTheme() { return React.useContext(ThemeCtx); }

function ThemeProvider({ dark, density, lang, currency, gants, soleil, children }) {
  // Mode soleil force light pour la lisibilité plein soleil (cf. main.dart:154).
  const effectiveDark = soleil ? false : !!dark;
  const value = React.useMemo(() => ({
    t: makeTheme(effectiveDark),
    d: makeDensity(density, { gants, soleil }),
    s: STR[lang] || STR.fr,
    dark: effectiveDark,
    gants: !!gants,
    soleil: !!soleil,
    lang,
    currency: currency || 'FCFA',
    money: (v) => formatMoney(v, currency || 'FCFA'),
    moneyCompact: (v) => formatMoneyCompact(v, currency || 'FCFA'),
  }), [effectiveDark, density, lang, currency, gants, soleil]);
  return <ThemeCtx.Provider value={value}>{children}</ThemeCtx.Provider>;
}

Object.assign(window, {
  Cu, makeTheme, makeDensity, tint, STR,
  formatMoney, formatMoneyCompact,
  ThemeCtx, ThemeProvider, useTheme,
});
