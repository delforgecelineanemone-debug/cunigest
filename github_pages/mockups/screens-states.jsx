// screens-states.jsx — Nouveaux écrans post-audit :
// • Splash propre (palette corrigée)
// • Onboarding condensé 2 pages
// • Cheptel aplati (Lapins direct + chips Lots/Cages)
// • États système (loading skeleton, error retry, empty)
// • Lapin form avec banner brouillon
// • Verrouiller (ex-Logout)

// ─── Splash propre — couleur primary V3 corrigée ─────────────────
function ScreenSplash({ onNav }) {
  const { t, s } = useTheme();
  return (
    <div style={{
      width: '100%', height: '100%', position: 'relative',
      background: `linear-gradient(135deg, ${t.primary} 0%, ${t.primaryDarkVar || '#0A6B4D'} 50%, ${tint(t.primary, 0.9)} 100%)`,
      display: 'flex', flexDirection: 'column',
      alignItems: 'center', justifyContent: 'center',
      color: '#fff',
    }}>
      <StatusBar fg="#fff" />

      {/* Logo */}
      <div style={{
        width: 130, height: 130, borderRadius: 35,
        background: 'rgba(255,255,255,0.2)',
        boxShadow: '0 8px 24px rgba(0,0,0,0.2)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontSize: 64,
      }}>🐇</div>

      <div style={{
        fontSize: 38, fontWeight: 800, letterSpacing: 3,
        marginTop: 28, color: '#fff',
      }}>CuniGest</div>

      <div style={{
        fontSize: 13, marginTop: 6, opacity: 0.78,
        letterSpacing: 0.5,
      }}>V3 — Gestion cunicole pro</div>

      {/* Loader */}
      <div style={{
        marginTop: 60,
        width: 26, height: 26,
        border: '2.5px solid rgba(255,255,255,0.3)',
        borderTopColor: '#fff',
        borderRadius: '50%',
        animation: 'cu-spin 0.9s linear infinite',
      }} />

      <div style={{
        marginTop: 16, fontSize: 12, opacity: 0.78,
        padding: '0 32px', textAlign: 'center',
      }}>Chargement des données…</div>

      {/* Footer */}
      <div style={{
        position: 'absolute', bottom: 32, left: 0, right: 0,
        textAlign: 'center', fontSize: 10.5, opacity: 0.6,
        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
      }}>
        <SyncDot status="ok" />
        Offline-first · Données chiffrées localement
      </div>

      <style>{`@keyframes cu-spin { to { transform: rotate(360deg); } }`}</style>
    </div>
  );
}

// ─── Onboarding condensé — 2 pages au lieu de 5 ──────────────────
function ScreenOnboardingCompact({ onNav }) {
  const { t, s, dark } = useTheme();
  const [page, setPage] = React.useState(0);

  return (
    <div style={{ background: t.bg, minHeight: '100%', display: 'flex', flexDirection: 'column' }}>
      <StatusBar fg={dark ? '#fff' : '#0a0a0a'} />

      <div style={{ paddingTop: 50, flex: 1, display: 'flex', flexDirection: 'column' }}>
        {page === 0 && (
          <div style={{ flex: 1, padding: '20px 24px', display: 'flex', flexDirection: 'column' }}>
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
              <div style={{
                width: 160, height: 160, borderRadius: '50%',
                background: `radial-gradient(circle, ${tint(t.primary, 0.18)}, ${tint(t.primary, 0.04)})`,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: 88, marginBottom: 32,
              }}>🐇</div>
              <div style={{ fontSize: 26, fontWeight: 800, color: t.ink, textAlign: 'center', letterSpacing: -0.5 }}>
                Bienvenue sur<br/>CuniGest
              </div>
              <div style={{ fontSize: 14, color: t.muted, textAlign: 'center', marginTop: 16, lineHeight: 1.5, maxWidth: 280 }}>
                Ton élevage de lapins, organisé.<br/>
                Cheptel, repro, santé, ventes — au même endroit.
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginTop: 40, width: '100%' }}>
                {[
                  { ico: 'cloud', label: 'Marche sans internet', sub: 'Saisie offline, sync auto en wifi' },
                  { ico: 'lock', label: 'Données chiffrées sur ton tél.', sub: 'SQLCipher AES-256' },
                  { ico: 'people', label: 'Multi-ouvriers', sub: 'Partage par QR code' },
                ].map((feat, i) => {
                  const Ico = I[feat.ico];
                  return (
                    <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                      <div style={{
                        width: 36, height: 36, borderRadius: 9,
                        background: tint(t.primary, 0.12),
                        display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
                      }}>
                        <Ico size={18} color={t.primary} stroke={1.9} />
                      </div>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ fontSize: 13, fontWeight: 600, color: t.ink }}>{feat.label}</div>
                        <div style={{ fontSize: 11, color: t.muted, marginTop: 1 }}>{feat.sub}</div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>
        )}

        {page === 1 && (
          <div style={{ flex: 1, padding: '20px 24px', display: 'flex', flexDirection: 'column' }}>
            <div style={{ flex: 1, overflowY: 'auto' }}>
              <div style={{ textAlign: 'center', marginBottom: 24 }}>
                <div style={{
                  width: 90, height: 90, borderRadius: '50%',
                  background: tint(t.primary, 0.12), margin: '8px auto 18px',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                }}>
                  <I.people size={42} color={t.primary} stroke={1.7} />
                </div>
                <div style={{ fontSize: 22, fontWeight: 800, color: t.ink, letterSpacing: -0.3 }}>
                  Crée ton compte
                </div>
                <div style={{ fontSize: 12.5, color: t.muted, marginTop: 6, lineHeight: 1.5 }}>
                  Sauvegarde auto · sync entre tous tes appareils
                </div>
              </div>

              {/* Google */}
              <button style={{
                width: '100%', padding: '14px 16px',
                background: '#fff', border: `1px solid ${t.border}`, borderRadius: 12,
                fontSize: 14, fontWeight: 600, color: '#0a0a0a',
                display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10,
                cursor: 'pointer', fontFamily: 'inherit',
                boxShadow: '0 1px 2px rgba(0,0,0,0.08)',
                minHeight: 52,
              }}>
                <svg width="20" height="20" viewBox="0 0 18 18">
                  <path fill="#4285F4" d="M17.64 9.2c0-.64-.06-1.25-.16-1.84H9v3.49h4.84a4.14 4.14 0 0 1-1.79 2.72v2.27h2.9c1.7-1.56 2.69-3.86 2.69-6.64z"/>
                  <path fill="#34A853" d="M9 18c2.43 0 4.47-.8 5.96-2.18l-2.9-2.27c-.8.54-1.83.86-3.06.86-2.35 0-4.34-1.59-5.05-3.72H.96v2.34A9 9 0 0 0 9 18z"/>
                  <path fill="#FBBC05" d="M3.95 10.7a5.4 5.4 0 0 1 0-3.4V4.96H.96a9 9 0 0 0 0 8.08l2.99-2.34z"/>
                  <path fill="#EA4335" d="M9 3.58c1.32 0 2.5.45 3.44 1.34l2.58-2.58A9 9 0 0 0 .96 4.96L3.95 7.3C4.66 5.17 6.65 3.58 9 3.58z"/>
                </svg>
                Continuer avec Google
              </button>

              <div style={{ display: 'flex', alignItems: 'center', gap: 12, margin: '20px 0' }}>
                <div style={{ flex: 1, height: 1, background: t.border }} />
                <span style={{ fontSize: 11, color: t.muted, fontWeight: 600 }}>OU EMAIL</span>
                <div style={{ flex: 1, height: 1, background: t.border }} />
              </div>

              {/* Email fields */}
              {[
                { label: 'Ton nom', placeholder: 'Jean-Marie Nkomo', icon: 'people' },
                { label: 'Email', placeholder: 'jm@ferme.cm', icon: 'globe', err: null },
                { label: 'Mot de passe (6 car. min.)', placeholder: '••••••••', icon: 'lock', secure: true },
              ].map((f, i) => {
                const Ico = I[f.icon];
                return (
                  <div key={i} style={{ marginBottom: 12 }}>
                    <div style={{ fontSize: 11, color: t.muted, marginBottom: 6, fontWeight: 600 }}>{f.label}</div>
                    <div style={{
                      display: 'flex', alignItems: 'center', gap: 8,
                      padding: '0 12px', background: t.bgRaised,
                      border: `1px solid ${t.border}`, borderRadius: 10, minHeight: 48,
                    }}>
                      <Ico size={18} color={t.muted} stroke={1.8} />
                      <span style={{ flex: 1, fontSize: 13.5, color: t.muted }}>{f.placeholder}</span>
                    </div>
                  </div>
                );
              })}

              {/* Info banner */}
              <div style={{
                background: tint(t.info, 0.08),
                border: `0.5px solid ${tint(t.info, 0.25)}`,
                borderRadius: 10, padding: '10px 12px',
                display: 'flex', alignItems: 'flex-start', gap: 8, marginTop: 16,
              }}>
                <I.cloud size={16} color={t.info} stroke={1.9} />
                <span style={{ fontSize: 11.5, color: t.info, lineHeight: 1.4 }}>
                  L'app fonctionne sans internet. La sauvegarde cloud se fait quand tu as du réseau.
                </span>
              </div>

              {/* Skip */}
              <button style={{
                background: 'transparent', border: 0, color: t.muted,
                fontSize: 12.5, fontWeight: 600, cursor: 'pointer',
                fontFamily: 'inherit', padding: '14px 8px', marginTop: 8,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                gap: 6, width: '100%',
              }}>
                <I.cloud size={14} color={t.muted} stroke={1.8} />
                Démarrer sans compte cloud
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Bottom bar — page dots + buttons */}
      <div style={{ padding: '0 24px 24px' }}>
        {/* Page indicators */}
        <div style={{ display: 'flex', justifyContent: 'center', gap: 6, marginBottom: 14 }}>
          {[0, 1].map(i => (
            <div key={i} style={{
              width: i === page ? 24 : 8, height: 8, borderRadius: 99,
              background: i === page ? t.primary : tint(t.primary, 0.25),
              transition: 'width 0.2s',
            }} />
          ))}
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          {page === 1 && (
            <button onClick={() => setPage(0)} style={{
              background: 'transparent', border: 0, color: t.muted,
              fontSize: 13, fontWeight: 600, cursor: 'pointer',
              fontFamily: 'inherit', padding: '14px 12px',
            }}>← Retour</button>
          )}
          <div style={{ flex: 1 }} />
          <Button kind="filled" size="lg" color={t.primary}
            onClick={() => page === 0 ? setPage(1) : onNav?.('accueil')}
            icon={page === 1 ? <I.check size={18} color="#fff" stroke={2.2} /> : <I.chevron size={18} color="#fff" stroke={2.2} />}
          >
            {page === 0 ? 'Suivant' : 'Commencer'}
          </Button>
        </div>
      </div>
    </div>
  );
}

// ─── États système : Loading / Error / Empty ─────────────────────
function ScreenStateLoading({ onNav }) {
  const { t, s } = useTheme();
  return (
    <div style={{ background: t.bg, minHeight: '100%', paddingBottom: 100 }}>
      <AppBar title={s.tabCheptel} actions={<><AppBarAction icon="qr" tooltip="Scanner un QR" label="Scanner QR" /><AppBarAction icon="more" tooltip="Plus d'options" label="Menu" /></>} />
      {/* Tab bar mock */}
      <div style={{ background: t.bgCard, borderBottom: `0.5px solid ${t.border}`, padding: '4px 16px', display: 'flex' }}>
        {[s.lapins, s.lots, s.cages].map((lbl, i) => (
          <div key={i} style={{
            flex: 1, padding: '12px 8px', textAlign: 'center',
            borderBottom: `2.5px solid ${i === 0 ? t.primary : 'transparent'}`,
            color: i === 0 ? t.primary : t.muted,
            fontSize: 13, fontWeight: i === 0 ? 700 : 500,
          }}>{lbl}</div>
        ))}
      </div>

      {/* Search skeleton */}
      <div style={{ padding: '12px 16px 8px' }}>
        <SkeletonBlock height={42} radius={12} />
      </div>

      {/* Filter chips skeleton */}
      <div style={{ padding: '0 16px 12px', display: 'flex', gap: 6 }}>
        {[64, 76, 80, 90, 70].map((w, i) => (
          <SkeletonBlock key={i} width={w} height={30} radius={99} />
        ))}
      </div>

      {/* Skeleton rows */}
      <SkeletonList count={6} />

      <BottomNav active="cheptel" onChange={onNav} />
    </div>
  );
}

function ScreenStateError({ onNav }) {
  const { t, s } = useTheme();
  return (
    <div style={{ background: t.bg, minHeight: '100%', paddingBottom: 100 }}>
      <AppBar title={s.tabCheptel} syncStatus="error" actions={<><AppBarAction icon="qr" tooltip="Scanner un QR" /><AppBarAction icon="more" tooltip="Menu" /></>} />
      {/* Tab bar */}
      <div style={{ background: t.bgCard, borderBottom: `0.5px solid ${t.border}`, padding: '4px 16px', display: 'flex' }}>
        {[s.lapins, s.lots, s.cages].map((lbl, i) => (
          <div key={i} style={{
            flex: 1, padding: '12px 8px', textAlign: 'center',
            borderBottom: `2.5px solid ${i === 0 ? t.primary : 'transparent'}`,
            color: i === 0 ? t.primary : t.muted,
            fontSize: 13, fontWeight: i === 0 ? 700 : 500,
          }}>{lbl}</div>
        ))}
      </div>

      {/* Sync error banner */}
      <div style={{ padding: '12px 16px 0' }}>
        <AlertBanner level="danger" icon="warning"
          message="Synchronisation impossible — tes saisies restent locales."
          actionLabel="Réessayer"
        />
      </div>

      <ErrorState
        title="Impossible de charger la liste"
        message="Vérifie ta connexion ou recharge depuis le serveur."
        onRetry={() => onNav?.('cheptel')}
      />

      <BottomNav active="cheptel" onChange={onNav} />
    </div>
  );
}

function ScreenStateEmpty({ onNav }) {
  const { t, s } = useTheme();
  return (
    <div style={{ background: t.bg, minHeight: '100%', paddingBottom: 100 }}>
      <AppBar title={s.tabCheptel} actions={<><AppBarAction icon="qr" tooltip="Scanner un QR" /><AppBarAction icon="more" tooltip="Menu" /></>} />
      <div style={{ background: t.bgCard, borderBottom: `0.5px solid ${t.border}`, padding: '4px 16px', display: 'flex' }}>
        {[s.lapins, s.lots, s.cages].map((lbl, i) => (
          <div key={i} style={{
            flex: 1, padding: '12px 8px', textAlign: 'center',
            borderBottom: `2.5px solid ${i === 0 ? t.primary : 'transparent'}`,
            color: i === 0 ? t.primary : t.muted,
            fontSize: 13, fontWeight: i === 0 ? 700 : 500,
          }}>{lbl}</div>
        ))}
      </div>

      <EmptyState
        icon="pets"
        title="Aucun lapin dans cet élevage"
        hint="Ajoute ton premier lapin pour commencer le suivi cheptel."
        actionLabel="Ajouter un lapin"
        onAction={() => onNav?.('lapin-form')}
        color={t.primary}
      />

      <BottomNav active="cheptel" onChange={onNav} />
    </div>
  );
}

// ─── Cheptel APLATI — Lapins direct, chips Lots/Cages ─────────────
function ScreenCheptelFlat({ onNav }) {
  const { t, s, d, dark, gants } = useTheme();
  const [filter, setFilter] = React.useState('tous');
  const filters = [
    { id: 'tous', label: 'Tous', count: 184 },
    { id: 'actif', label: s.actif, count: 162 },
    { id: 'sevrage', label: 'Sevrage', count: 14 },
    { id: 'quarantaine', label: s.quarantaine, count: 3 },
    { id: 'vendu', label: s.vendu, count: 5 },
  ];
  const lapins = [
    { name: 'Bella', code: '#L-0042', race: 'Néo-Zélandaise', sexe: 'F', weight: 3.2, age: 14, statut: 'actif' },
    { name: 'Buck Max', code: '#L-0018', race: 'Néo-Zélandaise', sexe: 'M', weight: 3.8, age: 18, statut: 'actif' },
    { name: 'Stella', code: '#L-0024', race: 'Californienne', sexe: 'F', weight: 2.9, age: 11, statut: 'actif' },
    { name: 'Lapereau #07', code: '#L-0204', race: 'NZ × Cal', sexe: 'M', weight: 0.95, age: 1.5, statut: 'sevrage' },
    { name: 'Buck Rex', code: '#L-0031', race: 'Californienne', sexe: 'M', weight: 3.5, age: 12, statut: 'actif' },
    { name: 'Lola', code: '#L-0089', race: 'Néo-Zélandaise', sexe: 'F', weight: 3.1, age: 10, statut: 'quarantaine' },
  ];

  return (
    <div style={{ background: t.bg, minHeight: '100%', paddingBottom: 100, position: 'relative' }}>
      <AppBar title={s.tabCheptel} subtitle={`${lapins.length} lapins · 12 lots · 24 cages`}
        actions={
          <>
            <AppBarAction icon="qr" tooltip="Scanner un QR" label="Scanner QR" />
            <AppBarAction icon="filter" tooltip="Filtres avancés" label="Filtrer" />
          </>
        }
      />

      {/* Quick-access chips for Lots / Cages — remplace les sous-onglets */}
      <div style={{ padding: '12px 16px 0', display: 'flex', gap: 8 }}>
        <button onClick={() => onNav?.('cheptel-lots')} style={{
          flex: 1, background: t.bgCard, border: `0.5px solid ${t.border}`,
          borderRadius: 12, padding: '12px 14px', cursor: 'pointer',
          display: 'flex', alignItems: 'center', gap: 10,
          fontFamily: 'inherit', minHeight: gants ? 56 : 48,
        }}>
          <div style={{ width: 32, height: 32, borderRadius: 8, background: tint(t.primary, 0.14), display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <I.groups size={18} color={t.primary} stroke={1.9} />
          </div>
          <div style={{ flex: 1, minWidth: 0, textAlign: 'left' }}>
            <div style={{ fontSize: 12.5, fontWeight: 700, color: t.ink }}>Lots</div>
            <div style={{ fontSize: 10.5, color: t.muted }}>12 actifs</div>
          </div>
          <I.chevron size={14} color={t.muted} stroke={1.8} />
        </button>
        <button onClick={() => onNav?.('cheptel-cages')} style={{
          flex: 1, background: t.bgCard, border: `0.5px solid ${t.border}`,
          borderRadius: 12, padding: '12px 14px', cursor: 'pointer',
          display: 'flex', alignItems: 'center', gap: 10,
          fontFamily: 'inherit', minHeight: gants ? 56 : 48,
        }}>
          <div style={{ width: 32, height: 32, borderRadius: 8, background: tint(t.accent.tools, 0.14), display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <I.grid size={18} color={t.accent.tools} stroke={1.9} />
          </div>
          <div style={{ flex: 1, minWidth: 0, textAlign: 'left' }}>
            <div style={{ fontSize: 12.5, fontWeight: 700, color: t.ink }}>Cages</div>
            <div style={{ fontSize: 10.5, color: t.muted }}>24 / 18 occ.</div>
          </div>
          <I.chevron size={14} color={t.muted} stroke={1.8} />
        </button>
      </div>

      {/* Search */}
      <div style={{ padding: '12px 16px 8px' }}>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 8,
          background: t.bgRaised, border: `0.5px solid ${t.border}`,
          borderRadius: 12, padding: '10px 12px',
          minHeight: gants ? 56 : 48,
        }}>
          <I.search size={18} color={t.muted} stroke={1.8} />
          <span style={{ fontSize: 13, color: t.muted, flex: 1 }}>Rechercher · bague, nom, race...</span>
        </div>
      </div>

      {/* Filters */}
      <div style={{ paddingLeft: 16, marginBottom: 8 }}>
        <div style={{ display: 'flex', gap: 6, overflowX: 'auto', paddingRight: 16, paddingBottom: 4 }}>
          {filters.map(f => (
            <ChipFilter key={f.id} label={f.label} count={f.count}
              selected={filter === f.id} color={t.primary}
              onClick={() => setFilter(f.id)}
            />
          ))}
        </div>
      </div>

      {/* List */}
      <div style={{ padding: '0 16px', display: 'flex', flexDirection: 'column', gap: 8, paddingBottom: 80 }}>
        {lapins.map((l, i) => <LapinTile key={i} {...l} onTap={() => onNav?.('lapin')} />)}
      </div>

      <FAB icon="plus" label="Lapin" color={t.primary} />
      <BottomNav active="cheptel" onChange={onNav} />
    </div>
  );
}

// ─── Lapin form avec banner brouillon (intro screen) ─────────────
function ScreenLapinFormDraft({ onNav }) {
  const { t, s, dark } = useTheme();
  const [showDraft, setShowDraft] = React.useState(true);
  const [step, setStep] = React.useState(0);

  return (
    <div style={{ background: t.bg, minHeight: '100%', paddingBottom: 100 }}>
      <AppBar title="Nouveau lapin" subtitle="Étape 1 / 3 · Identité"
        color={t.primary} onBack={() => onNav?.('cheptel')}
      />

      {/* Step indicator */}
      <div style={{ background: t.primary, padding: '0 16px 16px' }}>
        <div style={{ display: 'flex', gap: 6 }}>
          <span style={{ flex: 1, height: 4, background: '#fff', borderRadius: 99 }} />
          <span style={{ flex: 1, height: 4, background: 'rgba(255,255,255,0.35)', borderRadius: 99 }} />
          <span style={{ flex: 1, height: 4, background: 'rgba(255,255,255,0.35)', borderRadius: 99 }} />
        </div>
      </div>

      {/* Brouillon restauré */}
      {showDraft && (
        <div style={{ padding: '14px 16px 0' }}>
          <DraftBanner
            label="Brouillon de saisie récupéré (il y a 2 min)."
            onRestore={() => setShowDraft(false)}
            onDismiss={() => setShowDraft(false)}
          />
        </div>
      )}

      {/* Photo + Bague */}
      <SectionHeader label="Identification" />
      <div style={{ padding: '0 16px', display: 'flex', gap: 12, alignItems: 'flex-start' }}>
        <button style={{
          width: 80, height: 80, borderRadius: 12,
          background: t.bgRaised, border: `1.5px dashed ${t.border}`,
          display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
          color: t.muted, gap: 4, cursor: 'pointer', fontFamily: 'inherit',
        }}>
          <I.pets size={26} color={t.muted} stroke={1.6} />
          <span style={{ fontSize: 10, fontWeight: 600 }}>Photo</span>
        </button>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 11, color: t.muted, marginBottom: 6, fontWeight: 600 }}>BAGUE *</div>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 8,
            background: t.bgRaised, border: `1px solid ${t.border}`,
            borderRadius: 10, padding: '0 12px', minHeight: 48,
          }}>
            <span style={{ flex: 1, fontSize: 14, fontWeight: 600, color: t.ink, fontFeatureSettings: '"tnum"' }}>L-0205</span>
            <button style={{
              background: 'transparent', border: 0, color: t.primary,
              fontSize: 11, fontWeight: 700, cursor: 'pointer',
              fontFamily: 'inherit', padding: '4px 8px',
            }} title="Régénérer la bague" aria-label="Régénérer la bague">↻ Auto</button>
          </div>
          <div style={{ fontSize: 10.5, color: t.muted, marginTop: 4 }}>Numéro unique requis</div>
        </div>
      </div>

      <SectionHeader label="Sexe *" />
      <div style={{ padding: '0 16px' }}>
        <Segmented value={null}
          options={[
            { value: 'M', label: '♂ Mâle' },
            { value: 'F', label: '♀ Femelle' },
          ]}
        />
        <div style={{ fontSize: 10.5, color: t.warning, marginTop: 6, display: 'flex', alignItems: 'center', gap: 4 }}>
          <I.warning size={12} color={t.warning} stroke={2} />
          Choix explicite obligatoire
        </div>
      </div>

      <SectionHeader label="Nom (optionnel)" />
      <div style={{ padding: '0 16px' }}>
        <div style={{
          background: t.bgRaised, border: `1px solid ${t.border}`,
          borderRadius: 10, padding: '0 12px', minHeight: 48,
          display: 'flex', alignItems: 'center',
        }}>
          <span style={{ fontSize: 14, color: t.muted, fontStyle: 'italic' }}>Bella</span>
        </div>
      </div>

      <SectionHeader label="Race & couleur" />
      <div style={{ padding: '0 16px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
        <div style={{
          background: t.bgRaised, border: `1px solid ${t.border}`,
          borderRadius: 10, padding: '0 12px', minHeight: 48,
          display: 'flex', alignItems: 'center', gap: 8,
        }}>
          <I.pets size={16} color={t.muted} stroke={1.8} />
          <span style={{ fontSize: 13, color: t.ink }}>Néo-Zélandaise</span>
        </div>
        <div style={{
          background: t.bgRaised, border: `1px solid ${t.border}`,
          borderRadius: 10, padding: '0 12px', minHeight: 48,
          display: 'flex', alignItems: 'center',
        }}>
          <span style={{ fontSize: 13, color: t.muted }}>Blanche</span>
        </div>
      </div>

      <SectionHeader label="Cage" />
      <div style={{ padding: '0 16px' }}>
        <button style={{
          width: '100%', background: t.bgRaised, border: `1px solid ${t.border}`,
          borderRadius: 10, padding: '12px', cursor: 'pointer',
          display: 'flex', alignItems: 'center', gap: 10, fontFamily: 'inherit',
          minHeight: 48, textAlign: 'left',
        }}>
          <I.grid size={18} color={t.muted} stroke={1.8} />
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 13, fontWeight: 600, color: t.ink }}>Bât A · Clapier 1 · C-04</div>
            <div style={{ fontSize: 10.5, color: t.muted, marginTop: 1 }}>Capacité 2/3 · libre</div>
          </div>
          <I.chevron size={14} color={t.muted} stroke={1.8} />
        </button>
      </div>

      {/* Actions */}
      <div style={{ padding: '24px 16px', display: 'flex', gap: 8 }}>
        <Button kind="outlined" onClick={() => onNav?.('cheptel')} style={{ flex: 1 }}>Annuler</Button>
        <Button kind="filled" color={t.primary} style={{ flex: 2 }}
          icon={<I.chevron size={16} color="#fff" stroke={2.4} />}>
          Suivant — Généalogie
        </Button>
      </div>

      <BottomNav active="cheptel" onChange={onNav} />
    </div>
  );
}

Object.assign(window, {
  ScreenSplash, ScreenOnboardingCompact,
  ScreenStateLoading, ScreenStateError, ScreenStateEmpty,
  ScreenCheptelFlat, ScreenLapinFormDraft,
});
