// app.jsx — Main canvas V3.1 (audit-driven) :
// • Nouveaux écrans : Splash, Onboarding condensé, États (loading/error/empty), Lapin form brouillon
// • Cheptel aplati (Lapins direct, chips Lots/Cages)
// • Tweaks étendus : Mode gants + Mode soleil
// • Logout renommé "Verrouiller"

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "dark": false,
  "lang": "fr",
  "density": "regular",
  "currency": "FCFA",
  "gants": false,
  "soleil": false
}/*EDITMODE-END*/;

const SCREENS = {
  // Démarrage
  splash: { Comp: () => <ScreenSplash />, fg: 'white' },
  onboarding: { Comp: () => <ScreenOnboardingCompact />, fg: 'auto' },
  login: { Comp: () => <ScreenLogin />, fg: 'auto' },
  // Tabs — Accueil 3 variations
  accueil: { Comp: () => <AccueilV1 />, fg: 'white' },
  accueilV2: { Comp: () => <AccueilV2 />, fg: 'auto' },
  accueilV3: { Comp: () => <AccueilV3 />, fg: 'auto' },
  // Cheptel aplati par défaut
  cheptel: { Comp: () => <ScreenCheptelFlat />, fg: 'white' },
  'cheptel-lots': { Comp: () => <ScreenCheptel initialTab="lots" />, fg: 'white' },
  'cheptel-cages': { Comp: () => <ScreenCheptel initialTab="cages" />, fg: 'white' },
  // Autres tabs
  repro: { Comp: () => <ScreenRepro />, fg: 'white' },
  taches: { Comp: () => <ScreenTaches />, fg: 'white' },
  plus: { Comp: () => <ScreenPlus />, fg: 'white' },
  // Détails & forms
  lapin: { Comp: () => <ScreenLapinDetail />, fg: 'white' },
  'lapin-form': { Comp: () => <ScreenLapinFormDraft />, fg: 'white' },
  mating: { Comp: () => <ScreenMatingForm />, fg: 'white' },
  sale: { Comp: () => <ScreenSaleForm />, fg: 'white' },
  // États système
  'state-loading': { Comp: () => <ScreenStateLoading />, fg: 'white' },
  'state-error': { Comp: () => <ScreenStateError />, fg: 'white' },
  'state-empty': { Comp: () => <ScreenStateEmpty />, fg: 'white' },
  // Supports
  alertes: { Comp: () => <ScreenAlertes />, fg: 'white' },
  reports: { Comp: () => <ScreenReports />, fg: 'white' },
  stock: { Comp: () => <ScreenStock />, fg: 'white' },
  reglages: { Comp: () => <ScreenReglages />, fg: 'auto' },
};

const TAB_TO_SCREEN = {
  accueil: 'accueil',
  cheptel: 'cheptel',
  repro: 'repro',
  taches: 'taches',
  plus: 'plus',
};

function PhoneWithNav({ initial, label, dark }) {
  const [screen, setScreen] = React.useState(initial);
  const cur = SCREENS[screen] || SCREENS[initial];
  const handleNav = (target) => {
    const next = TAB_TO_SCREEN[target] || target;
    if (SCREENS[next]) setScreen(next);
  };
  const statusFg = cur.fg === 'white' ? '#fff' : (dark ? '#fff' : '#0a0a0a');
  const ScreenComp = cur?.Comp;
  return (
    <PhoneFrame dark={dark} statusFg={statusFg} label={label}>
      {ScreenComp ? React.cloneElement(ScreenComp(), { onNav: handleNav }) : null}
    </PhoneFrame>
  );
}

function App() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);

  return (
    <ThemeProvider
      dark={t.dark}
      density={t.density}
      lang={t.lang}
      currency={t.currency}
      gants={t.gants}
      soleil={t.soleil}
    >
      <div style={{
        background: t.dark ? '#0a0e0b' : '#f0eee9',
        minHeight: '100vh', minWidth: '100vw',
        color: t.dark ? '#e8e6df' : '#29261b',
      }}>
        <DesignCanvas
          title="CuniGest — Maquettes V3.1 (post-audit UX/UI)"
          subtitle="Audit appliqué : skeletons + erreur + empty génériques · Cheptel aplati · Onboarding 2 pages · Mode gants & soleil · Splash corrigé"
        >
          <DCSection
            id="boot"
            title="Démarrage"
            subtitle="Splash V3 (palette corrigée) → Onboarding condensé 2 pages → Login"
          >
            <DCArtboard id="splash" label="00 Splash · primary V3 corrigé" width={406} height={860}>
              <PhoneWithNav initial="splash" label="00 Splash" dark={t.dark} />
            </DCArtboard>
            <DCArtboard id="onb1" label="01 Onboarding · Bienvenue + Features" width={406} height={860}>
              <PhoneWithNav initial="onboarding" label="01 Onboarding" dark={t.dark} />
            </DCArtboard>
            <DCArtboard id="login" label="02 Login · mot de passe local" width={406} height={860}>
              <PhoneWithNav initial="login" label="02 Login" dark={t.dark} />
            </DCArtboard>
          </DCSection>

          <DCSection
            id="states"
            title="États système — extraits comme composants"
            subtitle="Skeleton (animé) · Error avec Retry · Empty avec CTA — désormais cohérents sur tous les écrans"
          >
            <DCArtboard id="state-loading" label="État · Loading (skeleton)" width={406} height={860}>
              <PhoneWithNav initial="state-loading" label="03 Loading" dark={t.dark} />
            </DCArtboard>
            <DCArtboard id="state-error" label="État · Error avec Retry" width={406} height={860}>
              <PhoneWithNav initial="state-error" label="04 Error" dark={t.dark} />
            </DCArtboard>
            <DCArtboard id="state-empty" label="État · Empty avec CTA" width={406} height={860}>
              <PhoneWithNav initial="state-empty" label="05 Empty" dark={t.dark} />
            </DCArtboard>
          </DCSection>

          <DCSection
            id="accueil"
            title="Accueil — 3 directions"
            subtitle="V1 fidèle au code · V2 editorial · V3 field-ready"
          >
            <DCArtboard id="acc-v1" label="V1 · Header dégradé classique" width={406} height={860}>
              <PhoneWithNav initial="accueil" label="06 Accueil V1" dark={t.dark} />
            </DCArtboard>
            <DCArtboard id="acc-v2" label="V2 · Editorial · hero number" width={406} height={860}>
              <PhoneWithNav initial="accueilV2" label="07 Accueil V2" dark={t.dark} />
            </DCArtboard>
            <DCArtboard id="acc-v3" label="V3 · Field-ready · plan du jour" width={406} height={860}>
              <PhoneWithNav initial="accueilV3" label="08 Accueil V3" dark={t.dark} />
            </DCArtboard>
          </DCSection>

          <DCSection
            id="onglets"
            title="Onglets principaux"
            subtitle="Cheptel APLATI · Lots · Cages · Repro · Tâches · Plus"
          >
            <DCArtboard id="cheptel" label="Cheptel · Lapins direct + chips Lots/Cages" width={406} height={860}>
              <PhoneWithNav initial="cheptel" label="09 Cheptel (aplati)" dark={t.dark} />
            </DCArtboard>
            <DCArtboard id="cheptel-lots" label="Cheptel · Lots (GMQ & IC)" width={406} height={860}>
              <PhoneWithNav initial="cheptel-lots" label="10 Lots" dark={t.dark} />
            </DCArtboard>
            <DCArtboard id="cheptel-cages" label="Cheptel · Cages" width={406} height={860}>
              <PhoneWithNav initial="cheptel-cages" label="11 Cages" dark={t.dark} />
            </DCArtboard>
            <DCArtboard id="repro" label="Reproduction · saillies + countdown" width={406} height={860}>
              <PhoneWithNav initial="repro" label="12 Reproduction" dark={t.dark} />
            </DCArtboard>
            <DCArtboard id="taches" label="Tâches · Streak + badges" width={406} height={860}>
              <PhoneWithNav initial="taches" label="13 Tâches" dark={t.dark} />
            </DCArtboard>
            <DCArtboard id="plus" label="Plus · modules" width={406} height={860}>
              <PhoneWithNav initial="plus" label="14 Plus" dark={t.dark} />
            </DCArtboard>
          </DCSection>

          <DCSection
            id="details"
            title="Détails & saisies"
            subtitle="Fiche lapin · Lapin form avec brouillon récupéré · Saillie · Vente"
          >
            <DCArtboard id="lapin" label="Fiche lapin · Bella #L-0042" width={406} height={860}>
              <PhoneWithNav initial="lapin" label="15 Fiche lapin" dark={t.dark} />
            </DCArtboard>
            <DCArtboard id="lapin-form" label="Lapin form · brouillon restauré" width={406} height={860}>
              <PhoneWithNav initial="lapin-form" label="16 Lapin form" dark={t.dark} />
            </DCArtboard>
            <DCArtboard id="mating" label="Saisie d'une saillie" width={406} height={860}>
              <PhoneWithNav initial="mating" label="17 Saillie" dark={t.dark} />
            </DCArtboard>
            <DCArtboard id="sale" label="Saisie d'une vente" width={406} height={860}>
              <PhoneWithNav initial="sale" label="18 Vente" dark={t.dark} />
            </DCArtboard>
          </DCSection>

          <DCSection
            id="support"
            title="Vues supports"
            subtitle="Alertes · Rapports · Stock · Réglages (Logout renommé Verrouiller)"
          >
            <DCArtboard id="alertes" label="Alertes du jour" width={406} height={860}>
              <PhoneWithNav initial="alertes" label="19 Alertes" dark={t.dark} />
            </DCArtboard>
            <DCArtboard id="reports" label="Rapports & statistiques" width={406} height={860}>
              <PhoneWithNav initial="reports" label="20 Rapports" dark={t.dark} />
            </DCArtboard>
            <DCArtboard id="stock" label="Stock & alimentation" width={406} height={860}>
              <PhoneWithNav initial="stock" label="21 Stock" dark={t.dark} />
            </DCArtboard>
            <DCArtboard id="reglages" label="Réglages · Verrouiller maintenant" width={406} height={860}>
              <PhoneWithNav initial="reglages" label="22 Réglages" dark={t.dark} />
            </DCArtboard>
          </DCSection>

          <DCPostIt x={50} y={120} color="#fef4a8">
            <b>Audit appliqué — V3.1</b><br/>
            ✅ Splash : palette V3 #0F8C66<br/>
            ✅ Skeleton + ErrorState + EmptyState génériques<br/>
            ✅ Cheptel aplati (4→3 taps vers fiche lapin)<br/>
            ✅ Onboarding : 5 → 2 pages<br/>
            ✅ Logout renommé "Verrouiller"<br/>
            ✅ Banner brouillon récupéré<br/>
            ✅ Tooltips a11y sur AppBar
          </DCPostIt>

          <DCPostIt x={50} y={340} color="#d6f1e0">
            <b>Tweaks → essayez !</b><br/>
            • <b>Mode gants</b> : tailles tactiles 56dp + icônes 28px<br/>
            • <b>Mode soleil</b> : texte +25% + force light theme<br/>
            • FR / EN · dark · densité · devise<br/>
            Tout s'applique en live sur les 22 écrans.
          </DCPostIt>
        </DesignCanvas>

        <TweaksPanel>
          <TweakSection label="Langue">
            <TweakRadio
              label="Locale"
              value={t.lang}
              options={[
                { value: 'fr', label: 'Français' },
                { value: 'en', label: 'English' },
              ]}
              onChange={(v) => setTweak('lang', v)}
            />
          </TweakSection>

          <TweakSection label="Modes terrain (V3)">
            <TweakToggle label="🧤 Mode gants (56dp)" value={t.gants} onChange={(v) => setTweak('gants', v)} />
            <TweakToggle label="☀️ Mode soleil (+25% typo)" value={t.soleil} onChange={(v) => setTweak('soleil', v)} />
          </TweakSection>

          <TweakSection label="Thème">
            <TweakToggle label="Mode sombre" value={t.dark} onChange={(v) => setTweak('dark', v)} />
          </TweakSection>

          <TweakSection label="Densité">
            <TweakRadio
              label="Espacement"
              value={t.density}
              options={[
                { value: 'compact', label: 'Compact' },
                { value: 'regular', label: 'Standard' },
                { value: 'comfy', label: 'Aéré' },
              ]}
              onChange={(v) => setTweak('density', v)}
            />
          </TweakSection>

          <TweakSection label="Devise">
            <TweakRadio
              label="Devise"
              value={t.currency}
              options={[
                { value: 'FCFA', label: 'FCFA' },
                { value: '€', label: '€' },
                { value: '$', label: '$' },
              ]}
              onChange={(v) => setTweak('currency', v)}
            />
          </TweakSection>
        </TweaksPanel>
      </div>
    </ThemeProvider>
  );
}

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<App />);
