// screens-repro-taches.jsx — Reproduction list + Routine/Tâches + Plus grid + Login

// ─── Reproduction list (saillies) ────────────────────────────
function ScreenRepro({ onNav }) {
  const { t, s, dark } = useTheme();
  const [filter, setFilter] = React.useState('tous');
  const filters = [
    { id: 'tous', label: 'Tous' },
    { id: 'en_attente', label: s.enAttente },
    { id: 'mise_bas', label: s.miseBas },
    { id: 'sevrage', label: s.sevrage },
    { id: 'termine', label: s.terminees },
    { id: 'echec', label: s.echecs },
  ];

  const saillies = [
    {
      mere: 'Bella · #L-0042', pere: 'Buck Max · #L-0018',
      dateSaillie: '6 mai 2025', dateMiseBas: '6 juin 2025',
      jours: 3, statut: 'en_attente', urgent: true,
    },
    {
      mere: 'Stella · #L-0024', pere: 'Buck Max · #L-0018',
      dateSaillie: '12 avr. 2025', dateMiseBas: '13 mai 2025',
      jours: -2, statut: 'en_attente', urgent: false,
    },
    {
      mere: 'Lola · #L-0089', pere: 'Buck Rex · #L-0031',
      dateSaillie: '2 avr. 2025', dateMiseBas: '3 mai 2025',
      statut: 'mise_bas', nes: 9, vivants: 8,
    },
    {
      mere: 'Juno · #L-0067', pere: 'Buck Max · #L-0018',
      dateSaillie: '15 mars 2025', dateMiseBas: '15 avr. 2025',
      statut: 'sevrage', nes: 11, vivants: 10, sevres: 9,
    },
    {
      mere: 'Mira · #L-0033', pere: 'Buck Rex · #L-0031',
      dateSaillie: '5 fév. 2025', dateMiseBas: '8 mars 2025',
      statut: 'termine', nes: 8, vivants: 8, sevres: 7,
    },
  ];

  const statutMeta = {
    en_attente: { color: t.warning, emoji: '⏳', label: s.enAttente },
    mise_bas: { color: t.accent.tools, emoji: '🐣', label: s.miseBas },
    sevrage: { color: t.accent.repro, emoji: '🍼', label: s.sevrage },
    termine: { color: t.success, emoji: '✅', label: s.terminees.replace('s', '') },
    echec: { color: t.danger, emoji: '✗', label: 'Échec' },
  };

  const list = filter === 'tous' ? saillies : saillies.filter(x => x.statut === filter);

  return (
    <div style={{ background: t.bg, minHeight: '100%', paddingBottom: 100 }}>
      <AppBar title={s.repro}
        actions={<AppBarAction icon="chart" />}
      />

      {/* Mini KPIs */}
      <div style={{ padding: '14px 16px 0', display: 'flex', gap: 8 }}>
        <MiniKpi label={s.enAttente} count={2} color={t.warning} />
        <MiniKpi label={s.miseBas} count={1} color={t.accent.tools} />
        <MiniKpi label={s.sevrage} count={1} color={t.accent.repro} />
      </div>

      {/* Filters */}
      <div style={{ paddingLeft: 16, marginTop: 14 }}>
        <div style={{ display: 'flex', gap: 6, overflowX: 'auto', paddingRight: 16, paddingBottom: 4 }}>
          {filters.map(f => (
            <ChipFilter key={f.id} label={f.label} selected={filter === f.id}
              color={t.accent.repro} onClick={() => setFilter(f.id)}
            />
          ))}
        </div>
      </div>

      {/* List */}
      <div style={{ padding: '8px 16px 0', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {list.map((s_, i) => {
          const meta = statutMeta[s_.statut];
          const accent = s_.urgent ? t.warning : meta.color;
          return (
            <div key={i} style={{
              background: t.bgCard,
              border: dark ? 'none' : `0.5px solid ${t.border}`,
              boxShadow: dark ? 'none' : t.shadow,
              borderRadius: 14, overflow: 'hidden',
              position: 'relative',
            }}>
              <div style={{ display: 'flex' }}>
                <div style={{ width: 4, background: accent, flexShrink: 0 }} />
                <div style={{ flex: 1, padding: '12px 14px' }}>
                  {/* Header: parents + badge */}
                  <div style={{ display: 'flex', alignItems: 'flex-start', gap: 8 }}>
                    <I.heartFill size={14} color={t.accent.repro} />
                    <span style={{ flex: 1, fontSize: 13, fontWeight: 600, color: t.ink, lineHeight: 1.3 }}>
                      ♀ {s_.mere}  ×  ♂ {s_.pere}
                    </span>
                    <Badge color={meta.color}>{meta.emoji} {meta.label}</Badge>
                  </div>

                  <div style={{ height: 1, background: t.borderSoft, margin: '10px 0' }} />

                  {/* Dates */}
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                    <DateChip icon="calendar" label="Saillie" date={s_.dateSaillie} />
                    {s_.dateMiseBas && (
                      <DateChip icon="child" label="Mise bas" date={s_.dateMiseBas} highlight={s_.urgent} />
                    )}
                  </div>

                  {/* Countdown */}
                  {s_.jours != null && s_.statut === 'en_attente' && (
                    <div style={{ marginTop: 8 }}>
                      <CountdownBar jours={s_.jours} />
                    </div>
                  )}

                  {/* Birth results */}
                  {s_.nes != null && (
                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 8 }}>
                      <PillStat icon="egg" label="Nés" val={s_.nes} />
                      {s_.vivants != null && <PillStat icon="pets" label="Vivants" val={s_.vivants} />}
                      {s_.sevres != null && <PillStat icon="scale" label="Sevrés" val={s_.sevres} />}
                    </div>
                  )}
                </div>
              </div>
            </div>
          );
        })}
      </div>

      <FAB icon="plus" label={s.saillie} color={t.accent.repro} onClick={() => onNav?.('mating')} />
      <div style={{ height: 32 }} />
      <BottomNav active="repro" onChange={onNav} />
    </div>
  );
}

function DateChip({ icon, label, date, highlight }) {
  const { t } = useTheme();
  const Ico = I[icon];
  const color = highlight ? t.warning : t.muted;
  const bg = highlight ? tint(t.warning, 0.10) : t.bgRaised;
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 4,
      padding: '4px 8px', borderRadius: 8, background: bg,
      border: highlight ? `0.5px solid ${tint(t.warning, 0.35)}` : 'none',
      fontSize: 11, color, fontWeight: highlight ? 600 : 500,
    }}>
      <Ico size={12} color={color} stroke={1.9} />
      {label} · {date}
    </span>
  );
}

function CountdownBar({ jours }) {
  const { t } = useTheme();
  const retard = jours < 0;
  const color = retard ? t.danger : jours <= 3 ? t.warning : t.success;
  const label = retard
    ? `En retard de ${-jours} jour${-jours > 1 ? 's' : ''}`
    : `${jours} jour${jours > 1 ? 's' : ''} avant la mise bas`;
  const Ico = retard ? I.warning : I.clock;
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      padding: '5px 10px', borderRadius: 8,
      background: tint(color, 0.10),
      border: `0.5px solid ${tint(color, 0.30)}`,
    }}>
      <Ico size={13} color={color} stroke={2} />
      <span style={{ fontSize: 11.5, color, fontWeight: 600 }}>{label}</span>
    </div>
  );
}

function PillStat({ icon, label, val }) {
  const { t } = useTheme();
  const Ico = I[icon];
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 4,
      padding: '3px 8px', borderRadius: 8, background: t.bgRaised,
      fontSize: 11, color: t.muted,
    }}>
      <Ico size={12} color={t.muted} stroke={1.9} />
      {label} <b style={{ color: t.ink, fontWeight: 700 }}>{val}</b>
    </span>
  );
}

// ─── Tâches / Routine — système anti-paresse ───────────────────
function ScreenTaches({ onNav }) {
  const { t, s, dark } = useTheme();
  const [done, setDone] = React.useState({ 1: true, 2: true });
  const taches = [
    { id: 1, cat: '🌅', titre: 'Vérifier les abreuvoirs', desc: 'Routine matin · 06h30', priorite: 'critique', points: 30, heure: '06h30' },
    { id: 2, cat: '👁', titre: "Tour d'observation", desc: 'Poil ébouriffé, diarrhée, isolement', priorite: 'critique', points: 30, heure: '06h45' },
    { id: 3, cat: '🌬', titre: 'Aération du bâtiment', desc: 'Ammoniaque = maladies respiratoires', priorite: 'important', points: 20, heure: '07h15' },
    { id: 4, cat: '🍃', titre: 'Distribution aliments', desc: 'Granulés + foin · tous les lots', priorite: 'important', points: 20, heure: '08h00' },
    { id: 5, cat: '🧹', titre: 'Nettoyage cages B', desc: 'Cycle J+3 · 3 cages', priorite: 'important', points: 20, heure: '14h00' },
    { id: 6, cat: '🐰', titre: 'Contrôle mamelles F02', desc: 'J+4 mise bas · 3 mères', priorite: 'critique', points: 30, heure: '17h00' },
  ];

  const totalPoints = taches.reduce((a, t) => a + t.points, 0);
  const scoreActuel = taches.filter(t => done[t.id]).reduce((a, t) => a + t.points, 0);
  const nbDone = taches.filter(t => done[t.id]).length;
  const progress = scoreActuel / totalPoints;

  const toggle = (id) => setDone(d => ({ ...d, [id]: !d[id] }));

  const motivation = progress >= 1 ? s.parfait :
    progress >= 0.75 ? '💪 Encore un petit effort, c\u2019est presque fini !' :
    progress >= 0.5 ? s.bonneProg :
    progress >= 0.25 ? s.cParti : s.nouvelleJournee;

  const prioriteColor = (p) => ({ critique: t.danger, important: t.warning, normal: t.success }[p]);
  const prioriteLabel = (p) => ({ critique: '🔴 Critique', important: '🟠 Important', normal: '🟢 Normal' }[p]);

  return (
    <div style={{ background: t.bg, minHeight: '100%', paddingBottom: 100 }}>
      <AppBar title={'📋 ' + s.maRoutine}
        actions={
          <>
            <AppBarAction icon="calendar" />
            <AppBarAction icon="trophy" />
            <AppBarAction icon="plus" />
          </>
        }
      />

      <div style={{ padding: '14px 16px', display: 'flex', flexDirection: 'column', gap: 12 }}>
        {/* Streak */}
        <StreakBanner streak={7} record={23} level={3} levelTitle="Éleveur sérieux" levelIcon="🌾" />

        {/* Progress card */}
        <Card raised>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
            <span style={{ fontSize: 14, fontWeight: 700, color: t.ink }}>{nbDone} / {taches.length} tâches</span>
            <span style={{
              fontSize: 14, fontWeight: 700,
              color: progress >= 1 ? t.success : t.primary,
              fontFeatureSettings: '"tnum"',
            }}>{scoreActuel} / {totalPoints} pts</span>
          </div>
          <ProgressBar value={scoreActuel} max={totalPoints} color={progress >= 1 ? t.success : t.primary} height={12} />
          <div style={{ display: 'flex', alignItems: 'center', gap: 5, marginTop: 8, fontSize: 11, color: t.muted }}>
            <I.arrowUp size={12} color={t.muted} stroke={1.8} />
            <span>Niveau 4 dans 120 points</span>
          </div>
        </Card>

        {/* Motivation banner */}
        <div style={{
          padding: '12px 14px', borderRadius: 12,
          background: tint(progress >= 1 ? t.success : t.primary, 0.10),
          border: `0.5px solid ${tint(progress >= 1 ? t.success : t.primary, 0.30)}`,
          textAlign: 'center',
          fontSize: 13, fontWeight: 600,
          color: progress >= 1 ? t.success : t.primary,
        }}>
          {motivation}
        </div>

        {/* Tâches list */}
        <div>
          <div style={{ fontSize: 11, fontWeight: 700, color: t.muted, textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: 10 }}>
            {s.tachesDuJour}
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            {taches.map(tt => {
              const isFait = done[tt.id];
              const prio = prioriteColor(tt.priorite);
              return (
                <div key={tt.id} onClick={() => toggle(tt.id)} style={{
                  background: isFait ? tint(t.success, 0.06) : t.bgCard,
                  border: dark ? 'none' : `0.5px solid ${t.border}`,
                  borderRadius: 12, padding: '12px 14px',
                  display: 'flex', alignItems: 'center', gap: 12,
                  cursor: 'pointer',
                }}>
                  <div style={{
                    width: 32, height: 32, borderRadius: 99,
                    background: isFait ? t.success : 'transparent',
                    border: `2px solid ${isFait ? t.success : prio}`,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    flexShrink: 0,
                  }}>
                    {isFait && <I.check size={16} color="#fff" stroke={3} />}
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{
                      fontSize: 13.5, fontWeight: 600, color: isFait ? t.muted : t.ink,
                      textDecoration: isFait ? 'line-through' : 'none',
                    }}>{tt.cat} {tt.titre}</div>
                    <div style={{ fontSize: 11, color: t.muted, marginTop: 2 }}>{tt.desc}</div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 6 }}>
                      <span style={{
                        padding: '1px 7px', borderRadius: 4,
                        background: tint(prio, 0.12), color: prio,
                        fontSize: 9.5, fontWeight: 600,
                      }}>{prioriteLabel(tt.priorite)}</span>
                      <span style={{
                        fontSize: 10.5, fontWeight: isFait ? 700 : 500,
                        color: isFait ? t.success : t.muted,
                      }}>+{tt.points} pts</span>
                    </div>
                  </div>
                  <span style={{ fontSize: 10.5, color: t.muted, fontFeatureSettings: '"tnum"' }}>{tt.heure}</span>
                </div>
              );
            })}
          </div>
        </div>

        {/* Badges */}
        <div>
          <div style={{ fontSize: 11, fontWeight: 700, color: t.muted, textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: 10 }}>
            {s.badgesDebloques}
          </div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
            {[
              { i: '🔥', n: 'Semaine parfaite' },
              { i: '🐰', n: 'Premier sevrage' },
              { i: '💉', n: 'Vétérinaire' },
              { i: '💰', n: 'Première vente' },
              { i: '🌅', n: 'Lève-tôt' },
            ].map((b, i) => (
              <span key={i} style={{
                display: 'inline-flex', alignItems: 'center', gap: 4,
                padding: '6px 10px', borderRadius: 10,
                background: tint(t.warning, 0.10),
                border: `0.5px solid ${tint(t.warning, 0.30)}`,
                fontSize: 12, fontWeight: 600, color: t.ink,
              }}>
                <span>{b.i}</span>
                <span>{b.n}</span>
              </span>
            ))}
          </div>
        </div>
      </div>

      <div style={{ height: 32 }} />
      <BottomNav active="taches" onChange={onNav} />
    </div>
  );
}

// ─── Plus — grille de modules ───────────────────────────────
function ScreenPlus({ onNav }) {
  const { t, s, dark } = useTheme();

  const sections = [
    {
      label: s.elevage, icon: 'pets',
      tiles: [
        { icon: 'grid', label: s.cages, sub: 'Bâtiments & clapiers', color: t.primary, target: 'cheptel-cages' },
        { icon: 'groups', label: s.lots, sub: 'GMQ & IC', color: t.primary, target: 'cheptel-lots' },
        { icon: 'inv', label: s.alimentation, sub: 'Stocks & nourriture', color: t.accent.feed, target: 'stock' },
        { icon: 'chart', label: s.statsRepro, sub: 'Fertilité & prolificité', color: t.accent.repro },
        { icon: 'checklist', label: s.maRoutine, sub: 'Checklist quotidienne', color: t.primary, target: 'taches' },
        { icon: 'calendar', label: s.calendrier, sub: 'Tâches du mois', color: t.primary },
      ],
    },
    {
      label: s.finances, icon: 'euro',
      tiles: [
        { icon: 'cart', label: s.ventes, sub: 'Ventes & revenus', color: t.accent.finance, target: 'sale' },
        { icon: 'wallet', label: s.depenses, sub: 'Charges & coûts', color: t.accent.finance },
        { icon: 'pdf', label: s.rapportsPdf, sub: 'Mensuel & annuel', color: t.accent.finance, target: 'reports' },
        { icon: 'download', label: s.exportCsv, sub: 'Lapins, ventes, soins…', color: t.accent.finance },
      ],
    },
    {
      label: s.outils, icon: 'calc',
      tiles: [
        { icon: 'calc', label: s.calculatrices, sub: 'Ration, prix, croissance', color: t.accent.tools },
        { icon: 'qr', label: s.scannerQr, sub: 'Lapin ou cage', color: t.accent.tools },
      ],
    },
    {
      label: s.administration, icon: 'cloudSync',
      tiles: [
        { icon: 'cloudSync', label: s.sauvegardeCloud, sub: 'Sync automatique', color: t.accent.admin },
        { icon: 'people', label: s.utilisateurs, sub: 'Gestion des comptes', color: t.accent.admin },
        { icon: 'settings', label: s.reglages, sub: 'Préférences & profil', color: t.accent.admin },
      ],
    },
  ];

  return (
    <div style={{ background: t.bg, minHeight: '100%', paddingBottom: 100 }}>
      <AppBar title={s.plus} />
      <div style={{ padding: '16px' }}>
        {sections.map((sec, i) => {
          const SecIco = I[sec.icon];
          return (
            <div key={i} style={{ marginBottom: 22 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 12 }}>
                <SecIco size={14} color={t.muted} stroke={1.8} />
                <span style={{ fontSize: 11, fontWeight: 700, color: t.muted, textTransform: 'uppercase', letterSpacing: '0.11em' }}>{sec.label}</span>
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
                {sec.tiles.map((tile, j) => {
                  const Ico = I[tile.icon];
                  return (
                    <div key={j} onClick={() => tile.target && onNav?.(tile.target)} style={{
                      background: t.bgCard, borderRadius: 14, padding: 16,
                      border: dark ? 'none' : `0.5px solid ${t.border}`,
                      boxShadow: dark ? 'none' : t.shadow,
                      cursor: 'pointer',
                      display: 'flex', flexDirection: 'column', alignItems: 'center',
                      gap: 8, minHeight: 124, justifyContent: 'center', textAlign: 'center',
                    }}>
                      <div style={{
                        width: 50, height: 50, borderRadius: 12,
                        background: tint(tile.color, 0.14),
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                      }}>
                        <Ico size={26} color={tile.color} stroke={1.9} />
                      </div>
                      <div>
                        <div style={{ fontSize: 13, fontWeight: 700, color: t.ink }}>{tile.label}</div>
                        <div style={{ fontSize: 10.5, color: t.muted, marginTop: 2, lineHeight: 1.3 }}>{tile.sub}</div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          );
        })}

        {/* Footer */}
        <div style={{ textAlign: 'center', padding: '16px 0', fontSize: 10.5, color: t.muted, lineHeight: 1.6 }}>
          CuniGest v3.0 · Flutter<br />
          Développé pour les cuniculteurs d&apos;Afrique
        </div>
      </div>

      <BottomNav active="plus" onChange={onNav} />
    </div>
  );
}

// ─── Login (password screen — V2.6 actual implementation) ────
function ScreenLogin({ onNav }) {
  const { t, s, dark } = useTheme();
  const [showPw, setShowPw] = React.useState(false);
  const [pw, setPw] = React.useState('');

  return (
    <div style={{
      background: t.bg, minHeight: '100%', position: 'relative',
      paddingTop: 47, padding: '47px 24px 24px',
      display: 'flex', flexDirection: 'column',
    }}>
      <StatusBar fg={t.ink} />

      <div style={{ height: 40 }} />

      {/* Mascot */}
      <div style={{ textAlign: 'center', fontSize: 64, lineHeight: 1 }}>🐇</div>
      <div style={{ height: 8 }} />
      <div style={{
        textAlign: 'center', fontSize: 30, fontWeight: 800, color: t.ink,
        letterSpacing: -0.5,
      }}>CuniGest</div>
      <div style={{
        textAlign: 'center', fontSize: 12.5, color: t.muted, marginTop: 6,
      }}>{s.gerezVotreFerme}</div>

      <div style={{ height: 32 }} />

      {/* User info */}
      <div style={{
        textAlign: 'center', fontSize: 18, fontWeight: 600, color: t.ink,
      }}>{s.bonjour} Jean-Marie</div>
      <div style={{
        textAlign: 'center', fontSize: 13, color: t.muted, marginTop: 4,
      }}>jm.nkomo@ferme-lapinverde.cm</div>

      <div style={{ height: 32 }} />

      {/* Password input */}
      <div style={{
        display: 'flex', alignItems: 'center',
        background: t.bgRaised, border: `0.5px solid ${t.border}`,
        borderRadius: 12, padding: '0 12px', minHeight: 56,
      }}>
        <I.lock size={20} color={t.muted} stroke={1.8} />
        <input
          type={showPw ? 'text' : 'password'}
          value={pw} onChange={(e) => setPw(e.target.value)}
          placeholder={s.motDePasse}
          style={{
            flex: 1, border: 0, background: 'transparent', outline: 'none',
            padding: '14px 12px', fontFamily: 'inherit', fontSize: 14,
            color: t.ink, letterSpacing: showPw ? 'normal' : '0.2em',
          }}
        />
        <button onClick={() => setShowPw(v => !v)} style={{
          background: 'transparent', border: 0, padding: 4, cursor: 'pointer',
        }}>
          {showPw ? <I.eyeOff size={20} color={t.muted} stroke={1.8} /> : <I.eye size={20} color={t.muted} stroke={1.8} />}
        </button>
      </div>

      <div style={{ height: 20 }} />

      <Button kind="filled" full size="lg" color={t.primary}
        onClick={() => onNav?.('accueil')}
        icon={<I.eye size={18} color="#fff" stroke={2} />}
      >{s.entrer}</Button>

      <div style={{ height: 24 }} />

      <div style={{ textAlign: 'center' }}>
        <a style={{ fontSize: 13, color: t.primary, fontWeight: 600, cursor: 'pointer' }}>
          {s.motDePasseOublie}
        </a>
      </div>

      <div style={{ flex: 1 }} />

      {/* Footer sync status */}
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
        fontSize: 11, color: t.muted, marginBottom: 20,
      }}>
        <SyncDot status="ok" />
        <span>Données sauvegardées · {s.synchronise} il y a 2h</span>
      </div>
    </div>
  );
}

Object.assign(window, { ScreenRepro, ScreenTaches, ScreenPlus, ScreenLogin });
