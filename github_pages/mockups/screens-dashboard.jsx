// screens-dashboard.jsx — Accueil V3 — 3 variations

function useAccueilData() {
  const { t, s } = useTheme();
  return {
    user: 'Jean-Marie',
    streak: 7, record: 23, level: 3, levelTitle: 'Éleveur sérieux', levelIcon: '🌾',
    syncStatus: 'pending',
    alertesCount: 5,
    kpis: {
      lapinsActifs: 184, naissancesMois: 12,
      recettesMois: 1_245_000, // FCFA
      lotsEnCours: 12,
      rappels7j: 3,
      stocksCritiques: 2,
    },
    lots: [
      { id: 'F02', code: 'F02', name: 'Maternité — Cohorte mai', sub: 'Mise bas J+4 · 3 mères', kind: 'maternite', count: 12, accent: t.accent.repro },
      { id: 'L03', code: 'L03', name: 'Engraissement S5', sub: 'Poids moy. 0.92 kg · Prêt dans 2 sem.', kind: 'engraissement', count: 38, accent: t.primary },
      { id: 'L01', code: 'L01', name: 'À vendre — Boucher Mbarga', sub: 'Poids moy. 1.8 kg', kind: 'vente', count: 22, accent: t.accent.finance },
    ],
    composition: { values: [82, 59, 43], colors: [t.primary, t.accent.repro, t.accent.finance] },
    growth: [0.18, 0.32, 0.48, 0.65, 0.81, 0.92],
  };
}

const lotBadgeLabel = (kind, s) => ({ engraissement: s.engraissement, maternite: s.maternite, vente: s.toSell || 'À vendre' })[kind] || kind;

// ─────────────────────────────────────────────────────────────
// V1 — Fidèle à l'implémentation Flutter actuelle
// AppBar primary + Header dégradé + KPIs 2x2 + Streak + Alertes + Lots + Donut
// ─────────────────────────────────────────────────────────────
function AccueilV1({ onNav }) {
  const { t, s, d, money, moneyCompact, dark } = useTheme();
  const data = useAccueilData();

  return (
    <div style={{ background: t.bg, minHeight: '100%', paddingBottom: 100 }}>
      <AppBar
        title="CuniGest"
        leading={<I.eco size={22} color="#fff" stroke={2} />}
        syncStatus={data.syncStatus}
        actions={
          <>
            <AppBarAction icon="qr" onClick={() => onNav?.('qr')} />
            <AppBarAction icon="bell" badge={data.alertesCount} onClick={() => onNav?.('alertes')} />
            <AppBarAction icon="settings" onClick={() => onNav?.('reglages')} />
          </>
        }
      />

      {/* Header degradient (welcome banner) */}
      <div style={{
        background: `linear-gradient(180deg, ${t.primary} 0%, ${dark ? t.bg : t.primarySoft} 100%)`,
        padding: '14px 16px 22px', color: '#fff',
        marginBottom: -12,
      }}>
        <div style={{ fontSize: 14, fontWeight: 500, opacity: 0.92 }}>{s.bonjour}, {data.user}</div>
        <div style={{ fontSize: 12, opacity: 0.78, marginTop: 2 }}>
          {new Date().toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' })}
        </div>
      </div>

      {/* KPI 2x2 (overlapping header) */}
      <div style={{ padding: '0 16px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, position: 'relative', zIndex: 1 }}>
        <KpiCard label={s.lapinsActifs} value={data.kpis.lapinsActifs}
          icon="pets" color={t.primary}
          delta={data.kpis.naissancesMois > 0 ? `+${data.kpis.naissancesMois}` : null}
          onClick={() => onNav?.('cheptel')}
        />
        <KpiCard label={s.recettesMois} value={moneyCompact(data.kpis.recettesMois)}
          icon="euro" color={t.accent.finance}
          onClick={() => onNav?.('ventes')}
        />
        <KpiCard label={s.rappelsSante} value={data.kpis.rappels7j}
          icon="medical" color={t.accent.health}
          delta={data.kpis.rappels7j > 0 ? '!' : null} deltaGood={false}
        />
        <KpiCard label={s.stocksCritiques} value={data.kpis.stocksCritiques}
          icon="inv" color={t.accent.feed}
          delta={data.kpis.stocksCritiques > 0 ? '!' : null} deltaGood={false}
          onClick={() => onNav?.('stock')}
        />
      </div>

      {/* Streak banner */}
      <div style={{ padding: '16px 16px 0' }}>
        <StreakBanner
          streak={data.streak} record={data.record}
          level={data.level} levelTitle={data.levelTitle} levelIcon={data.levelIcon}
          onTap={() => onNav?.('taches')}
        />
      </div>

      {/* Alertes */}
      <div style={{ padding: '12px 16px 0', display: 'flex', flexDirection: 'column', gap: 8 }}>
        <AlertBanner level="warning" icon="alarm" actionLabel={s.voir} onAction={() => onNav?.('alertes')}
          message={`${data.kpis.rappels7j} rappel(s) sanitaire(s) dans les 7 prochains jours`}
        />
        <AlertBanner level="danger" icon="inv"
          message={`${data.kpis.stocksCritiques} stock(s) en dessous du seuil minimum`}
        />
      </div>

      <SectionHeader label={s.lotsActifs} action={
        <a onClick={() => onNav?.('lots')} style={{ fontSize: 12, color: t.primary, fontWeight: 600, cursor: 'pointer' }}>{s.voirTout} →</a>
      } />
      <div style={{ padding: '0 16px', display: 'flex', flexDirection: 'column', gap: 8 }}>
        {data.lots.map(lot => (
          <div key={lot.id} onClick={() => onNav?.('lapin')} style={{
            background: t.bgCard, borderRadius: 14,
            border: dark ? 'none' : `0.5px solid ${t.border}`,
            boxShadow: dark ? 'none' : t.shadow,
            padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 12,
            cursor: 'pointer', position: 'relative', overflow: 'hidden',
          }}>
            <span style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: 4, background: lot.accent }} />
            <div style={{ paddingLeft: 4, flex: 1, minWidth: 0 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                <span style={{ fontSize: 13.5, fontWeight: 700, color: t.ink }}>{lot.code}</span>
                <span style={{ fontSize: 11, color: t.muted }}>· {lot.count} lapins</span>
              </div>
              <div style={{ fontSize: 12, color: t.ink, marginTop: 2, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{lot.name}</div>
              <div style={{ fontSize: 11, color: t.muted, marginTop: 2 }}>{lot.sub}</div>
            </div>
            <Badge color={lot.accent}>{lotBadgeLabel(lot.kind, s)}</Badge>
            <I.chevron size={16} color={t.muted} stroke={1.6} />
          </div>
        ))}
      </div>

      <SectionHeader label={s.repartitionCheptel} />
      <div style={{ padding: '0 16px' }}>
        <Card raised>
          <div style={{ display: 'flex', alignItems: 'center', gap: 18 }}>
            <Donut values={data.composition.values} colors={data.composition.colors}
              centerLabel={data.composition.values.reduce((a, b) => a + b, 0)}
              centerSub="lapins" />
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 9 }}>
              {[
                { label: s.engraissement, value: 82, color: t.primary },
                { label: s.maternite, value: 59, color: t.accent.repro },
                { label: 'À vendre', value: 43, color: t.accent.finance },
              ].map((row, i) => (
                <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <span style={{ width: 10, height: 10, background: row.color, borderRadius: 3 }} />
                  <span style={{ flex: 1, fontSize: 12.5, color: t.ink }}>{row.label}</span>
                  <span style={{ fontSize: 13.5, fontWeight: 700, color: t.ink, fontFeatureSettings: '"tnum"' }}>{row.value}</span>
                </div>
              ))}
            </div>
          </div>
        </Card>
      </div>

      <div style={{ height: 32 }} />
      <BottomNav active="accueil" onChange={onNav} />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// V2 — Editorial / Magazine
// Hero number gigantesque + composition strip + horizontal rail
// ─────────────────────────────────────────────────────────────
function AccueilV2({ onNav }) {
  const { t, s, dark, moneyCompact } = useTheme();
  const data = useAccueilData();

  return (
    <div style={{ background: t.bg, minHeight: '100%', paddingBottom: 100 }}>
      <AppBar flat title={s.appName}
        leading={<I.eco size={22} color={t.primary} stroke={2.2} />}
        syncStatus={data.syncStatus}
        actions={
          <>
            <AppBarAction icon="qr" color={t.ink} />
            <AppBarAction icon="bell" badge={data.alertesCount} color={t.ink} onClick={() => onNav?.('alertes')} />
            <AppBarAction icon="settings" color={t.ink} />
          </>
        }
      />

      <div style={{ padding: '8px 16px 4px' }}>
        <div style={{ fontSize: 12, color: t.muted, fontWeight: 500 }}>
          {s.bonjour}, {data.user} ·{' '}
          <span style={{ color: t.ink, fontWeight: 600 }}>
            {new Date().toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' })}
          </span>
        </div>
      </div>

      {/* HERO — total lapins gigantesque */}
      <div style={{ padding: '8px 16px 16px' }}>
        <div style={{ display: 'flex', alignItems: 'flex-end', gap: 10 }}>
          <span style={{ fontSize: 72, fontWeight: 800, color: t.ink, lineHeight: 0.9, letterSpacing: -3, fontFeatureSettings: '"tnum"' }}>184</span>
          <div style={{ paddingBottom: 8 }}>
            <div style={{ fontSize: 13, fontWeight: 600, color: t.muted }}>{s.lapinsActifs.toLowerCase()}</div>
            <Badge color={t.success}>+12 ce mois</Badge>
          </div>
        </div>
        {/* Composition strip */}
        <div style={{ marginTop: 14, display: 'flex', height: 10, borderRadius: 99, overflow: 'hidden', gap: 2 }}>
          <div style={{ flex: 82, background: t.primary }} />
          <div style={{ flex: 59, background: t.accent.repro }} />
          <div style={{ flex: 43, background: t.accent.finance }} />
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8, fontSize: 11, color: t.muted }}>
          <span><b style={{ color: t.primary }}>82</b> {s.engraissement.toLowerCase()}</span>
          <span><b style={{ color: t.accent.repro }}>59</b> {s.maternite.toLowerCase()}</span>
          <span><b style={{ color: t.accent.finance }}>43</b> à vendre</span>
        </div>
      </div>

      {/* Compact KPI row */}
      <div style={{ padding: '8px 16px', display: 'flex', gap: 8 }}>
        {[
          { label: s.recettesMois, value: moneyCompact(data.kpis.recettesMois), color: t.accent.finance },
          { label: s.rappelsSante, value: data.kpis.rappels7j, color: t.accent.health },
          { label: s.stocksCritiques, value: data.kpis.stocksCritiques, color: t.accent.feed },
        ].map((m, i) => (
          <div key={i} style={{
            flex: 1, padding: '12px', borderRadius: 14,
            background: t.bgRaised, border: `0.5px solid ${t.border}`,
          }}>
            <div style={{ fontSize: 10.5, color: t.muted, fontWeight: 500, lineHeight: 1.2 }}>{m.label}</div>
            <div style={{ fontSize: 20, fontWeight: 800, color: m.color, marginTop: 6, lineHeight: 1, fontFeatureSettings: '"tnum"' }}>{m.value}</div>
          </div>
        ))}
      </div>

      {/* Streak — inline compact variant */}
      <div style={{ padding: '10px 16px' }}>
        <div onClick={() => onNav?.('taches')} style={{
          background: t.bgCard, border: `0.5px solid ${t.border}`,
          borderLeft: `4px solid ${t.primary}`,
          borderRadius: 14, padding: '12px 14px',
          display: 'flex', alignItems: 'center', gap: 12, cursor: 'pointer',
        }}>
          <span style={{ fontSize: 26 }}>🔥</span>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 13, fontWeight: 700, color: t.ink }}>{data.streak} jours · {data.levelTitle}</div>
            <div style={{ fontSize: 11, color: t.muted, marginTop: 1 }}>{s.record} {data.record} · Niveau {data.level} {data.levelIcon}</div>
          </div>
          <I.chevron size={16} color={t.muted} stroke={1.6} />
        </div>
      </div>

      {/* Aujourd'hui — chips alertes */}
      <div style={{ padding: '6px 16px 0' }}>
        <div style={{ fontSize: 11, color: t.muted, fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: 8 }}>
          {s.sectionAlertes}
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          <AlertBanner level="danger" icon="warning"
            message="Stock aliment critique — 42 kg restants" actionLabel="Commander" />
          <AlertBanner level="warning" icon="alarm"
            message="Contrôle mamelles — Lot F02 · J+4" actionLabel={s.voir} />
          <AlertBanner level="info" icon="syringe"
            message="Vaccin VHD — Lot L03 dans 5 jours" />
        </div>
      </div>

      {/* Lots — horizontal rail */}
      <div style={{ paddingLeft: 16, marginTop: 18 }}>
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', paddingRight: 16, marginBottom: 10 }}>
          <span style={{ fontSize: 11, fontWeight: 700, color: t.muted, textTransform: 'uppercase', letterSpacing: '0.08em' }}>
            {s.lotsActifs} · {data.kpis.lotsEnCours}
          </span>
          <a style={{ fontSize: 12, color: t.primary, fontWeight: 600, cursor: 'pointer' }} onClick={() => onNav?.('lots')}>{s.voirTout} →</a>
        </div>
        <div style={{ display: 'flex', gap: 10, overflowX: 'auto', paddingRight: 16, paddingBottom: 8 }}>
          {data.lots.map(lot => (
            <div key={lot.id} onClick={() => onNav?.('lapin')} style={{
              width: 192, flexShrink: 0,
              background: t.bgCard, borderRadius: 14, padding: 14,
              border: `0.5px solid ${t.border}`,
              cursor: 'pointer', position: 'relative', overflow: 'hidden',
            }}>
              <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 3, background: lot.accent }} />
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 14 }}>
                <span style={{
                  width: 32, height: 32, borderRadius: 8, background: tint(lot.accent, 0.14),
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                }}>
                  {lot.kind === 'maternite' ? <I.heart size={16} color={lot.accent} stroke={1.9} /> :
                   lot.kind === 'vente' ? <I.cart size={16} color={lot.accent} stroke={1.9} /> :
                   <I.pets size={16} color={lot.accent} stroke={1.9} />}
                </span>
                <Badge color={lot.accent}>{lotBadgeLabel(lot.kind, s)}</Badge>
              </div>
              <div style={{ fontSize: 14, fontWeight: 700, color: t.ink }}>{lot.code}</div>
              <div style={{ fontSize: 11, color: t.muted, marginTop: 1 }}>{lot.count} lapins</div>
              <div style={{ fontSize: 11, color: t.ink, marginTop: 8, lineHeight: 1.3 }}>{lot.sub}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Growth chart */}
      <div style={{ padding: '12px 16px 16px' }}>
        <Card raised>
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 10 }}>
            <div>
              <div style={{ fontSize: 11, color: t.muted, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.08em' }}>Croissance 6 sem.</div>
              <div style={{ fontSize: 18, fontWeight: 800, color: t.ink, marginTop: 4 }}>0.92 <span style={{ fontSize: 11, color: t.muted, fontWeight: 500 }}>kg moy.</span></div>
            </div>
            <Badge color={t.success}>+0.11 kg</Badge>
          </div>
          <LineChart data={data.growth} color={t.primary} fill highlight height={80} />
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 6, fontSize: 9.5, color: t.muted }}>
            {['S1','S2','S3','S4','S5','S6'].map(l => <span key={l}>{l}</span>)}
          </div>
        </Card>
      </div>

      <BottomNav active="accueil" onChange={onNav} />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// V3 — Field-Ready / Action-First
// Gros boutons, contrastes forts, "plan du jour" outdoor-friendly
// ─────────────────────────────────────────────────────────────
function AccueilV3({ onNav }) {
  const { t, s, dark, moneyCompact } = useTheme();
  const data = useAccueilData();

  return (
    <div style={{ background: t.bg, minHeight: '100%', paddingBottom: 100 }}>
      <AppBar flat title={`${s.bonjour}, ${data.user}`}
        subtitle={new Date().toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' })}
        syncStatus={data.syncStatus}
        actions={
          <>
            <AppBarAction icon="qr" color={t.ink} />
            <AppBarAction icon="bell" badge={data.alertesCount} color={t.ink} onClick={() => onNav?.('alertes')} />
          </>
        }
      />

      {/* URGENT block — full-bleed danger */}
      <div style={{ padding: '8px 16px 0' }}>
        <div onClick={() => onNav?.('stock')} style={{
          background: t.danger, color: '#fff', borderRadius: 18,
          padding: '16px 18px', display: 'flex', alignItems: 'center', gap: 14,
          boxShadow: `0 8px 22px ${tint(t.danger, 0.45)}`, cursor: 'pointer',
        }}>
          <div style={{
            width: 50, height: 50, borderRadius: 14, background: 'rgba(255,255,255,0.22)',
            display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
          }}>
            <I.warning size={28} color="#fff" stroke={2.2} />
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 11, fontWeight: 700, opacity: 0.85, letterSpacing: '0.08em', textTransform: 'uppercase' }}>Urgent</div>
            <div style={{ fontSize: 16, fontWeight: 700, marginTop: 2 }}>Stock aliment critique</div>
            <div style={{ fontSize: 12, opacity: 0.9, marginTop: 2 }}>42 kg restants · seuil 50 kg</div>
          </div>
          <I.chevron size={20} color="#fff" stroke={2.2} />
        </div>
      </div>

      {/* Streak — proéminent */}
      <div style={{ padding: '12px 16px 0' }}>
        <StreakBanner streak={data.streak} record={data.record}
          level={data.level} levelTitle={data.levelTitle} levelIcon={data.levelIcon}
          onTap={() => onNav?.('taches')}
        />
      </div>

      {/* Plan du jour — 4 grands boutons tactiles */}
      <SectionHeader label="Plan d'aujourd'hui · 4 tâches" action={
        <a style={{ fontSize: 12, color: t.primary, fontWeight: 600, cursor: 'pointer' }} onClick={() => onNav?.('taches')}>{s.voirTout} →</a>
      } />
      <div style={{ padding: '0 16px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
        {[
          { title: 'Abreuvoirs', sub: '06h45', icon: 'water', color: t.info, done: true },
          { title: 'Mamelles F02', sub: '3 mères · J+4', icon: 'heart', color: t.accent.repro },
          { title: 'Nettoyage B', sub: 'J3 · 14h', icon: 'home', color: t.primary },
          { title: 'Aération', sub: '07h15', icon: 'plant', color: t.success },
        ].map((task, i) => {
          const Ico = I[task.icon];
          return (
            <div key={i} style={{
              background: task.done ? tint(t.success, 0.10) : t.bgCard,
              borderRadius: 16, padding: '14px',
              border: `0.5px solid ${task.done ? tint(t.success, 0.35) : t.border}`,
              minHeight: 92, display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
              cursor: 'pointer',
            }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <div style={{
                  width: 38, height: 38, borderRadius: 11, background: tint(task.color, 0.14),
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                }}>
                  <Ico size={22} color={task.color} stroke={2} />
                </div>
                {task.done && (
                  <div style={{
                    width: 24, height: 24, borderRadius: 99, background: t.success,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                  }}>
                    <I.check size={14} color="#fff" stroke={3} />
                  </div>
                )}
              </div>
              <div>
                <div style={{ fontSize: 14, fontWeight: 700, color: t.ink, textDecoration: task.done ? 'line-through' : 'none', opacity: task.done ? 0.6 : 1 }}>{task.title}</div>
                <div style={{ fontSize: 11, color: t.muted, marginTop: 2 }}>{task.sub}</div>
              </div>
            </div>
          );
        })}
      </div>

      {/* Big KPI tiles avec mini chart inline */}
      <SectionHeader label="Chiffres clés" />
      <div style={{ padding: '0 16px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
        <Card raised>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div>
              <div style={{ fontSize: 11, color: t.muted, fontWeight: 600 }}>{s.lapinsActifs}</div>
              <div style={{ fontSize: 30, fontWeight: 800, color: t.ink, marginTop: 4, lineHeight: 1, fontFeatureSettings: '"tnum"' }}>184</div>
            </div>
            <Badge color={t.success}>+12</Badge>
          </div>
          <div style={{ marginTop: 10 }}>
            <LineChart data={[140, 152, 161, 168, 175, 184]} color={t.primary} fill height={32} />
          </div>
        </Card>
        <Card raised>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div>
              <div style={{ fontSize: 11, color: t.muted, fontWeight: 600 }}>{s.recettesMois}</div>
              <div style={{ fontSize: 30, fontWeight: 800, color: t.accent.finance, marginTop: 4, lineHeight: 1, fontFeatureSettings: '"tnum"' }}>{moneyCompact(data.kpis.recettesMois)}</div>
            </div>
            <Badge color={t.success}>+18%</Badge>
          </div>
          <div style={{ marginTop: 10 }}>
            <BarChart data={[24, 32, 30, 38, 41, 47.5]} color={t.accent.finance} height={32} />
          </div>
        </Card>
      </div>

      {/* Lots compact list */}
      <SectionHeader label={s.lotsActifs} action={
        <a style={{ fontSize: 12, color: t.primary, fontWeight: 600, cursor: 'pointer' }} onClick={() => onNav?.('lots')}>{s.voirTout} →</a>
      } />
      <div style={{ padding: '0 16px' }}>
        <Card pad={false}>
          {data.lots.map((lot, i) => (
            <div key={lot.id} onClick={() => onNav?.('lapin')} style={{
              display: 'flex', alignItems: 'center', gap: 12,
              padding: '12px 14px',
              borderBottom: i < data.lots.length - 1 ? `0.5px solid ${t.borderSoft}` : 'none',
              cursor: 'pointer',
            }}>
              <span style={{ width: 10, height: 10, background: lot.accent, borderRadius: 99 }} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 13, fontWeight: 700, color: t.ink }}>{lot.code} <span style={{ color: t.muted, fontWeight: 500 }}>· {lot.count} lapins</span></div>
                <div style={{ fontSize: 11, color: t.muted, marginTop: 2, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{lot.sub}</div>
              </div>
              <Badge color={lot.accent}>{lotBadgeLabel(lot.kind, s)}</Badge>
            </div>
          ))}
        </Card>
      </div>

      <div style={{ height: 32 }} />
      <BottomNav active="accueil" onChange={onNav} />
    </div>
  );
}

Object.assign(window, { AccueilV1, AccueilV2, AccueilV3, useAccueilData, lotBadgeLabel });
