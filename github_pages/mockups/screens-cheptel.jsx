// screens-cheptel.jsx — Onglet Cheptel (Lapins / Lots / Cages) + détail

// Sticky 3-tab header at top of the Cheptel hub.
function CheptelTabBar({ active, onChange }) {
  const { t, s } = useTheme();
  const tabs = [
    { id: 'lapins', label: s.lapins, icon: 'pets' },
    { id: 'lots', label: s.lots, icon: 'groups' },
    { id: 'cages', label: s.cages, icon: 'grid' },
  ];
  return (
    <div style={{
      background: t.bgCard,
      borderBottom: `0.5px solid ${t.border}`,
      padding: '4px 16px',
      display: 'flex',
    }}>
      {tabs.map(tab => {
        const isActive = active === tab.id;
        const Ico = I[tab.icon];
        return (
          <button key={tab.id} onClick={() => onChange?.(tab.id)} style={{
            flex: 1, border: 0, background: 'transparent', cursor: 'pointer',
            padding: '12px 8px', fontFamily: 'inherit',
            borderBottom: `2.5px solid ${isActive ? t.primary : 'transparent'}`,
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
            color: isActive ? t.primary : t.muted,
            fontSize: 13, fontWeight: isActive ? 700 : 500,
          }}>
            <Ico size={18} color={isActive ? t.primary : t.muted} stroke={1.8} />
            {tab.label}
          </button>
        );
      })}
    </div>
  );
}

// ─── Cheptel Hub — Lapins list ────────────────────────────────
function CheptelLapins({ onNav }) {
  const { t, s, dark } = useTheme();
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
    { name: 'Charlie', code: '#L-0156', race: 'Géant des Flandres', sexe: 'M', weight: 4.6, age: 22, statut: 'vendu' },
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100%' }}>
      {/* Search */}
      <div style={{ padding: '12px 16px 8px' }}>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 8,
          background: t.bgRaised, border: `0.5px solid ${t.border}`,
          borderRadius: 12, padding: '10px 12px',
        }}>
          <I.search size={18} color={t.muted} stroke={1.8} />
          <span style={{ fontSize: 13, color: t.muted, flex: 1 }}>Rechercher un lapin · code, nom, race...</span>
          <I.qr size={18} color={t.muted} stroke={1.8} />
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
    </div>
  );
}

// ─── Cheptel Hub — Lots list ──────────────────────────────────
function CheptelLots({ onNav }) {
  const { t, s, dark } = useTheme();
  const lots = [
    {
      code: 'F02', name: 'Maternité — Cohorte mai',
      count: 12, kind: 'maternite', accent: t.accent.repro,
      created: '5 avril 2025',
      stage: 'J+4 après mise bas',
      kpis: [{ l: 'Mères', v: '3' }, { l: 'Lapereaux', v: '47' }, { l: 'Vivants', v: '42' }],
    },
    {
      code: 'L03', name: 'Engraissement — Semaine 5',
      count: 38, kind: 'engraissement', accent: t.primary,
      created: '12 mars 2025',
      stage: 'Prêt dans 2 semaines',
      kpis: [{ l: 'Poids moy.', v: '0.92 kg' }, { l: 'GMQ', v: '32 g/j' }, { l: 'IC', v: '3.4' }],
    },
    {
      code: 'L01', name: 'À vendre — Mbarga',
      count: 22, kind: 'vente', accent: t.accent.finance,
      created: '1 février 2025',
      stage: 'Disponible',
      kpis: [{ l: 'Poids moy.', v: '1.8 kg' }, { l: 'Prix prévu', v: '56k FCFA' }, { l: 'Marge', v: '+24%' }],
    },
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100%' }}>
      <div style={{ padding: '12px 16px 8px', display: 'flex', alignItems: 'center', gap: 8 }}>
        <MiniKpi label="En cours" count={12} color={t.primary} />
        <MiniKpi label="Maternité" count={3} color={t.accent.repro} />
        <MiniKpi label="À vendre" count={2} color={t.accent.finance} />
      </div>

      <div style={{ padding: '4px 16px', display: 'flex', flexDirection: 'column', gap: 10, paddingBottom: 80 }}>
        {lots.map(lot => (
          <div key={lot.code} onClick={() => onNav?.('lapin')} style={{
            background: t.bgCard, borderRadius: 14,
            border: dark ? 'none' : `0.5px solid ${t.border}`,
            boxShadow: dark ? 'none' : t.shadow,
            overflow: 'hidden', position: 'relative', cursor: 'pointer',
          }}>
            <div style={{ height: 4, background: lot.accent }} />
            <div style={{ padding: '12px 14px' }}>
              <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 10 }}>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
                    <span style={{ fontSize: 15, fontWeight: 700, color: t.ink }}>{lot.code}</span>
                    <span style={{ fontSize: 11, color: t.muted }}>· {lot.count} lapins</span>
                  </div>
                  <div style={{ fontSize: 12.5, color: t.ink, marginTop: 2 }}>{lot.name}</div>
                  <div style={{ fontSize: 11, color: lot.accent, fontWeight: 600, marginTop: 4 }}>{lot.stage}</div>
                </div>
                <Badge color={lot.accent}>{lotBadgeLabel(lot.kind, s)}</Badge>
              </div>
              {/* KPI strip */}
              <div style={{
                display: 'flex', marginTop: 12, padding: '10px 0 0',
                borderTop: `0.5px solid ${t.borderSoft}`,
              }}>
                {lot.kpis.map((k, i) => (
                  <div key={i} style={{ flex: 1, textAlign: 'center' }}>
                    <div style={{ fontSize: 14, fontWeight: 700, color: t.ink, fontFeatureSettings: '"tnum"' }}>{k.v}</div>
                    <div style={{ fontSize: 10, color: t.muted, marginTop: 1 }}>{k.l}</div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        ))}
      </div>

      <FAB icon="plus" label="Lot" color={t.primary} />
    </div>
  );
}

// ─── Cheptel Hub — Cages grid ─────────────────────────────────
function CheptelCages() {
  const { t, s, dark } = useTheme();
  const cageStatuts = [
    { id: 'occupee', label: s.occupee, color: t.cageOccupee },
    { id: 'gestante', label: s.gestante, color: t.cageGestante },
    { id: 'allaitement', label: s.allaitement, color: t.cageAllaitement },
    { id: 'sevrage', label: s.sevrage || 'Sevrage', color: t.cageSevrage },
    { id: 'vide', label: s.vide, color: t.cageVide },
    { id: 'desinfection', label: s.desinfection, color: t.cageDesinfection },
  ];
  const cages = [
    { code: 'A-01', statut: 'occupee', occupants: 1 },
    { code: 'A-02', statut: 'occupee', occupants: 1 },
    { code: 'A-03', statut: 'gestante', occupants: 1 },
    { code: 'A-04', statut: 'gestante', occupants: 1 },
    { code: 'A-05', statut: 'vide', occupants: 0 },
    { code: 'A-06', statut: 'desinfection', occupants: 0 },
    { code: 'B-01', statut: 'allaitement', occupants: 7 },
    { code: 'B-02', statut: 'allaitement', occupants: 9 },
    { code: 'B-03', statut: 'allaitement', occupants: 8 },
    { code: 'B-04', statut: 'sevrage', occupants: 6 },
    { code: 'B-05', statut: 'sevrage', occupants: 7 },
    { code: 'B-06', statut: 'sevrage', occupants: 5 },
    { code: 'C-01', statut: 'occupee', occupants: 4 },
    { code: 'C-02', statut: 'occupee', occupants: 4 },
    { code: 'C-03', statut: 'vide', occupants: 0 },
    { code: 'C-04', statut: 'vide', occupants: 0 },
  ];

  return (
    <div style={{ paddingBottom: 80 }}>
      {/* Building selector + segmented */}
      <div style={{ padding: '12px 16px 8px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
          <div>
            <div style={{ fontSize: 11, color: t.muted, fontWeight: 600 }}>BÂTIMENT</div>
            <div style={{ fontSize: 15, fontWeight: 700, color: t.ink, marginTop: 1 }}>Bâtiment principal · 3 clapiers</div>
          </div>
          <button style={{
            background: t.bgRaised, border: `0.5px solid ${t.border}`,
            borderRadius: 99, padding: '6px 12px', fontSize: 12,
            display: 'inline-flex', alignItems: 'center', gap: 4,
            color: t.ink, fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit',
          }}>
            <I.filter size={14} color={t.muted} stroke={1.8} /> Filtres
          </button>
        </div>
        {/* Legend */}
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
          {cageStatuts.map(st => (
            <div key={st.id} style={{
              display: 'inline-flex', alignItems: 'center', gap: 5,
              fontSize: 10.5, color: t.muted,
              padding: '3px 8px', background: t.bgRaised, borderRadius: 99,
            }}>
              <span style={{ width: 8, height: 8, borderRadius: 99, background: st.color }} />
              {st.label}
            </div>
          ))}
        </div>
      </div>

      {/* Clapier A */}
      {['A', 'B', 'C'].map(zone => (
        <div key={zone} style={{ padding: '14px 16px 0' }}>
          <div style={{ fontSize: 11, fontWeight: 700, color: t.muted, textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: 8 }}>
            Clapier {zone} · {cages.filter(c => c.code.startsWith(zone + '-')).length} cages
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8 }}>
            {cages.filter(c => c.code.startsWith(zone + '-')).map(cage => {
              const meta = cageStatuts.find(m => m.id === cage.statut) || { color: t.muted, label: cage.statut };
              return (
                <div key={cage.code} style={{
                  aspectRatio: '1.1',
                  background: tint(meta.color, 0.10),
                  border: `0.5px solid ${tint(meta.color, 0.30)}`,
                  borderLeft: `3px solid ${meta.color}`,
                  borderRadius: 12, padding: 10,
                  display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
                  cursor: 'pointer',
                }}>
                  <div style={{ fontSize: 13, fontWeight: 700, color: t.ink }}>{cage.code}</div>
                  <div>
                    <div style={{ fontSize: 10, color: meta.color, fontWeight: 600 }}>{meta.label}</div>
                    {cage.occupants > 0 && (
                      <div style={{ fontSize: 10, color: t.muted, marginTop: 2, display: 'flex', alignItems: 'center', gap: 3 }}>
                        <I.pets size={11} color={t.muted} stroke={1.8} /> {cage.occupants}
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      ))}
    </div>
  );
}

// ─── Cheptel hub container ────────────────────────────────────
function ScreenCheptel({ onNav, initialTab = 'lapins' }) {
  const { t, s } = useTheme();
  const [tab, setTab] = React.useState(initialTab);

  return (
    <div style={{ background: t.bg, minHeight: '100%', paddingBottom: 100, display: 'flex', flexDirection: 'column' }}>
      <AppBar title={s.tabCheptel}
        actions={
          <>
            <AppBarAction icon="qr" />
            <AppBarAction icon="more" />
          </>
        }
      />
      <CheptelTabBar active={tab} onChange={setTab} />
      <div style={{ flex: 1, overflow: 'auto', position: 'relative' }}>
        {tab === 'lapins' && <CheptelLapins onNav={onNav} />}
        {tab === 'lots' && <CheptelLots onNav={onNav} />}
        {tab === 'cages' && <CheptelCages />}
      </div>
      <BottomNav active="cheptel" onChange={onNav} />
    </div>
  );
}

// ─── Fiche Lapin — détail (refonte V3) ────────────────────────
function ScreenLapinDetail({ onNav }) {
  const { t, s, dark } = useTheme();
  const weightData = [0.18, 0.6, 1.3, 1.9, 2.6, 3.2];
  const events = [
    { dot: t.info, icon: 'child', title: 'Mise bas — 47 lapereaux', sub: '42 vivants · 5 morts-nés', date: '2 mai 2025' },
    { dot: t.accent.repro, icon: 'heart', title: 'Saillie avec Buck Max', sub: 'Réussie · Gestation 31 j', date: '1 avril 2025' },
    { dot: t.accent.tools, icon: 'syringe', title: 'Vaccination VHD', sub: '0.5 ml · Rappel dans 6 mois', date: '10 avril 2025' },
    { dot: t.accent.finance, icon: 'scale', title: 'Pesée — 3.2 kg', sub: '+0.1 kg depuis dernière pesée', date: '5 mai 2025' },
    { dot: t.muted, icon: 'eye', title: 'Contrôle mamelles — normal', sub: 'Aucune anomalie', date: '6 mai 2025' },
  ];

  return (
    <div style={{ background: t.bg, minHeight: '100%', paddingBottom: 100 }}>
      {/* Header coloré — primary */}
      <div style={{
        background: t.primary, color: '#fff',
        paddingTop: 47, position: 'relative', overflow: 'hidden',
      }}>
        <StatusBar fg="#fff" />
        <div style={{ position: 'absolute', top: 40, right: -10, opacity: 0.15 }}>
          <I.pets size={130} color="#fff" stroke={1.2} />
        </div>
        {/* AppBar actions */}
        <div style={{ display: 'flex', alignItems: 'center', padding: '6px 4px' }}>
          <button onClick={() => onNav?.('cheptel')} style={{
            border: 0, background: 'transparent', width: 40, height: 40,
            borderRadius: 99, cursor: 'pointer', color: '#fff',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}><I.back size={22} color="#fff" stroke={2} /></button>
          <div style={{ flex: 1 }} />
          <AppBarAction icon="qr" />
          <AppBarAction icon="edit" />
          <AppBarAction icon="more" />
        </div>
        {/* Identity */}
        <div style={{ padding: '0 18px 22px' }}>
          <div style={{ fontSize: 11, opacity: 0.78 }}>{s.ficheLapin} · #L-0042</div>
          <div style={{ fontSize: 26, fontWeight: 800, marginTop: 2, letterSpacing: -0.5 }}>Lapine Bella</div>
          <div style={{ fontSize: 12.5, opacity: 0.88, marginTop: 2 }}>Néo-Zélandaise Blanche · ♀ · 14 mois</div>
          <div style={{ marginTop: 14, display: 'flex', gap: 6 }}>
            <span style={{
              display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 11, fontWeight: 600,
              background: 'rgba(255,255,255,0.2)', borderRadius: 99, padding: '5px 11px',
            }}>
              <span style={{ width: 7, height: 7, background: '#FFD15C', borderRadius: 99 }} />
              {s.actif} — En production
            </span>
            <span style={{
              display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 11, fontWeight: 600,
              background: 'rgba(255,255,255,0.2)', borderRadius: 99, padding: '5px 11px',
            }}>
              <I.grid size={12} color="#fff" stroke={2} /> Cage B-07
            </span>
          </div>
        </div>
      </div>

      {/* 3 KPI cards floating */}
      <div style={{
        padding: '0 16px', marginTop: -14,
        display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8,
      }}>
        {[
          { l: s.poidsActuel, v: '3.2', u: 'kg', c: t.primary },
          { l: s.portees, v: '6', u: 'total', c: t.accent.repro },
          { l: s.age, v: '14', u: s.mois, c: t.accent.tools },
        ].map((k, i) => (
          <div key={i} style={{
            background: t.bgCard, borderRadius: 12, padding: 12,
            border: dark ? 'none' : `0.5px solid ${t.border}`,
            boxShadow: dark ? 'none' : t.shadow,
          }}>
            <div style={{ fontSize: 10, color: t.muted, fontWeight: 500 }}>{k.l}</div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 3, marginTop: 4 }}>
              <span style={{ fontSize: 20, fontWeight: 800, color: k.c, fontFeatureSettings: '"tnum"' }}>{k.v}</span>
              <span style={{ fontSize: 10, color: t.muted }}>{k.u}</span>
            </div>
          </div>
        ))}
      </div>

      <SectionHeader label={s.info} />
      <div style={{ padding: '0 16px' }}>
        <Card pad={false}>
          <InfoRow label={s.naissance} value="12 mars 2024" />
          <InfoRow label={s.cage} value="Cage B-07 · Maternité" />
          <InfoRow label={s.lot} value="F02 — Maternité" />
          <InfoRow label={s.maleRepro} value="#L-0018 · Buck Max" />
          <InfoRow label={s.prochaineSaillie} value="16 mai 2025" valueColor={t.primary} />
          <InfoRow label={s.dernierVaccin} value="VHD · 10 avril 2025" isLast />
        </Card>
      </div>

      <SectionHeader label={s.courbePoids} />
      <div style={{ padding: '0 16px' }}>
        <Card raised>
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 10 }}>
            <div>
              <div style={{ fontSize: 20, fontWeight: 800, color: t.ink, fontFeatureSettings: '"tnum"' }}>3.2 <span style={{ fontSize: 11, color: t.muted, fontWeight: 500 }}>kg actuel</span></div>
              <div style={{ fontSize: 10.5, color: t.muted, marginTop: 2 }}>GMQ 32 g/j sur 6 sem.</div>
            </div>
            <Badge color={t.success} icon={<I.arrowUp size={11} color={t.success} stroke={2.4} />}>+0.1 kg</Badge>
          </div>
          <LineChart data={weightData} color={t.primary} fill highlight height={100} />
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 6, fontSize: 9.5, color: t.muted }}>
            {['Nais.','S4','S8','S12','S20','Auj.'].map(l => <span key={l}>{l}</span>)}
          </div>
        </Card>
      </div>

      <SectionHeader label={s.historique} />
      <div style={{ padding: '0 16px' }}>
        <Card>
          {events.map((e, i) => {
            const Ico = I[e.icon];
            const isLast = i === events.length - 1;
            return (
              <div key={i} style={{ display: 'flex', gap: 12, position: 'relative' }}>
                <div style={{
                  flexShrink: 0, position: 'relative', width: 28,
                  display: 'flex', flexDirection: 'column', alignItems: 'center', paddingTop: 2,
                }}>
                  <div style={{
                    width: 28, height: 28, borderRadius: 99,
                    background: tint(e.dot, 0.16),
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    zIndex: 1,
                  }}>
                    <Ico size={14} color={e.dot} stroke={2} />
                  </div>
                  {!isLast && <span style={{ flex: 1, width: 1.5, background: t.borderSoft, marginTop: 2 }} />}
                </div>
                <div style={{ flex: 1, paddingBottom: isLast ? 0 : 14 }}>
                  <div style={{ fontSize: 13, fontWeight: 600, color: t.ink }}>{e.title}</div>
                  <div style={{ fontSize: 11.5, color: t.muted, marginTop: 2 }}>{e.sub}</div>
                  <div style={{ fontSize: 10, color: t.muted, marginTop: 3 }}>{e.date}</div>
                </div>
              </div>
            );
          })}
        </Card>
      </div>

      <SectionHeader label="Actions" />
      <div style={{ padding: '0 16px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
        <Button kind="filled" full color={t.accent.repro} onClick={() => onNav?.('mating')}
          icon={<I.plus size={16} color="#fff" stroke={2.2} />}>{s.saillie}</Button>
        <Button kind="outlined" full icon={<I.plus size={16} color={t.ink} stroke={2.2} />}>{s.pesee}</Button>
        <Button kind="outlined" full icon={<I.plus size={16} color={t.ink} stroke={2.2} />}>{s.traitement}</Button>
        <Button kind="outlined" full icon={<I.plus size={16} color={t.ink} stroke={2.2} />}>{s.evenement}</Button>
      </div>

      <div style={{ height: 32 }} />
      <BottomNav active="cheptel" onChange={onNav} />
    </div>
  );
}

Object.assign(window, { CheptelTabBar, CheptelLapins, CheptelLots, CheptelCages, ScreenCheptel, ScreenLapinDetail });
