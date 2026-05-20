// screens-misc.jsx — Alertes / Rapports / Stock / Réglages (V3)

// ─── Alertes du jour ──────────────────────────────────────────
function ScreenAlertes({ onNav }) {
  const { t, s, dark } = useTheme();
  const [filter, setFilter] = React.useState('all');
  const [done, setDone] = React.useState({ water: true });

  const NotifRow = ({ icon, iconBg, iconColor, title, sub, time, urgent, doneCheck, action, left }) => {
    const Ico = I[icon];
    return (
      <div style={{
        background: t.bgCard,
        borderRadius: 12,
        border: `0.5px solid ${t.border}`,
        borderLeft: left ? `3px solid ${left}` : `0.5px solid ${t.border}`,
        padding: '12px 14px',
        display: 'flex', gap: 12, alignItems: 'flex-start',
        opacity: doneCheck ? 0.55 : 1,
      }}>
        <div style={{
          width: 36, height: 36, borderRadius: 10, background: iconBg,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          flexShrink: 0, position: 'relative',
        }}>
          <Ico size={18} color={iconColor} stroke={1.9} />
          {doneCheck && (
            <div style={{
              position: 'absolute', right: -3, bottom: -3, width: 15, height: 15,
              borderRadius: 99, background: t.success, border: `1.5px solid ${t.bgCard}`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <I.check size={10} color="#fff" stroke={3} />
            </div>
          )}
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{
            fontSize: 13, fontWeight: 700, color: urgent ? t.danger : t.ink,
            textDecoration: doneCheck ? 'line-through' : 'none',
          }}>{title}</div>
          <div style={{ fontSize: 11.5, color: t.muted, lineHeight: 1.4, marginTop: 2 }}>{sub}</div>
          {(time || action) && (
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10, marginTop: 8 }}>
              <span style={{ fontSize: 10.5, color: t.muted }}>{time}</span>
              {action}
            </div>
          )}
        </div>
      </div>
    );
  };

  return (
    <div style={{ background: t.bg, minHeight: '100%', paddingBottom: 100 }}>
      {/* Dark header */}
      <div style={{
        background: dark ? '#000' : '#1A1F1B', color: '#fff',
        paddingTop: 47,
      }}>
        <StatusBar fg="#fff" />
        <div style={{ padding: '6px 4px', display: 'flex', alignItems: 'center' }}>
          <button onClick={() => onNav?.('accueil')} style={{
            border: 0, background: 'transparent', width: 40, height: 40,
            cursor: 'pointer', color: '#fff', borderRadius: 99,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}><I.back size={22} color="#fff" stroke={2} /></button>
          <div style={{ flex: 1 }} />
          <AppBarAction icon="filter" />
        </div>
        <div style={{ padding: '0 18px 16px' }}>
          <div style={{ fontSize: 22, fontWeight: 800 }}>{s.sectionAlertes}</div>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 6 }}>
            <span style={{ fontSize: 12, opacity: 0.65 }}>Mardi 6 mai 2025</span>
            <span style={{
              background: t.warning, color: '#fff', borderRadius: 99,
              padding: '4px 10px', fontSize: 11, fontWeight: 700,
            }}>5 {s.unread || 'non lues'}</span>
          </div>
          {/* Filters */}
          <div style={{ marginLeft: -2, marginRight: -2, display: 'flex', gap: 6, marginTop: 16, overflowX: 'auto', paddingBottom: 4 }}>
            {[
              { id: 'all', label: 'Toutes', count: 9 },
              { id: 'urgent', label: '🔴 Urgentes', count: 2 },
              { id: 'routine', label: 'Routine' },
              { id: 'farming', label: 'Élevage' },
              { id: 'stock', label: 'Stock' },
            ].map(f => {
              const active = f.id === filter;
              return (
                <button key={f.id} onClick={() => setFilter(f.id)} style={{
                  background: active ? t.primary : 'rgba(255,255,255,0.1)',
                  border: 0, borderRadius: 99, padding: '6px 12px',
                  fontSize: 11.5, fontWeight: 600, color: '#fff',
                  cursor: 'pointer', whiteSpace: 'nowrap', fontFamily: 'inherit',
                }}>
                  {f.label}{f.count != null && <span style={{ opacity: 0.7, marginLeft: 4 }}>· {f.count}</span>}
                </button>
              );
            })}
          </div>
        </div>
      </div>

      {/* Urgent */}
      <SectionHeader label="URGENT — à traiter maintenant" />
      <div style={{ padding: '0 16px', display: 'flex', flexDirection: 'column', gap: 8 }}>
        <NotifRow icon="warning" iconBg={t.danger} iconColor="#fff" left={t.danger} urgent
          title="Alerte stock aliment bas"
          sub="42 kg restants — seuil minimum 50 kg. Commandez rapidement."
          time="Stock · Il y a 2h"
          action={<Button kind="filled" color={t.accent.feed} size="sm" onClick={() => onNav?.('stock')}>Commander</Button>}
        />
        <NotifRow icon="pets" iconBg={t.danger} iconColor="#fff" left={t.danger} urgent
          title="Mortalité anormale détectée"
          sub="3 décès en 5 jours dans le Lot L02. Inspection vétérinaire recommandée."
          time="Élevage · Ce matin"
        />
      </div>

      <SectionHeader label="ROUTINE DU MATIN" />
      <div style={{ padding: '0 16px', display: 'flex', flexDirection: 'column', gap: 8 }}>
        <NotifRow icon="water" iconBg={tint(t.info, 0.16)} iconColor={t.info} left={t.success}
          title="Vérifier les abreuvoirs ✓" sub="Terminé à 06h45" doneCheck={done.water}
        />
        <NotifRow icon="eye" iconBg={tint(t.info, 0.16)} iconColor={t.info} left={t.success}
          title="Tour d'observation du comportement"
          sub="Passez devant chaque cage — poil ébouriffé, diarrhée, isolement"
          time="Routine · 06h45"
          action={<Button kind="tonal" color={t.success} size="sm">Marquer fait</Button>}
        />
        <NotifRow icon="plant" iconBg={tint(t.primary, 0.16)} iconColor={t.primary} left={t.success}
          title="Aération du bâtiment"
          sub="Ouvrir les fenêtres. L'ammoniaque cause des maladies respiratoires."
          time="Routine · 07h15"
          action={<Button kind="tonal" color={t.success} size="sm">Marquer fait</Button>}
        />
        <NotifRow icon="trash" iconBg={tint(t.danger, 0.14)} iconColor={t.danger} left={t.success}
          title="Vérifier les lapins morts"
          sub="Retirer immédiatement tout cadavre détecté."
          time="Routine · 07h00"
          action={<Button kind="tonal" color={t.success} size="sm">Marquer fait</Button>}
        />
      </div>

      <SectionHeader label="ÉLEVAGE — STADES" />
      <div style={{ padding: '0 16px', display: 'flex', flexDirection: 'column', gap: 8 }}>
        <NotifRow icon="clock" iconBg={tint(t.accent.repro, 0.14)} iconColor={t.accent.repro} left={t.accent.repro}
          title="Contrôle mamelles — Lot F02"
          sub="Mise bas J+4 · 3 mères allaitantes"
          time="Aujourd'hui"
        />
        <NotifRow icon="scale" iconBg={tint(t.info, 0.14)} iconColor={t.info} left={t.accent.repro}
          title="Pesée lapereaux — Lot F02"
          sub="J+7 · Objectif >80g par lapereau"
          time="Dans 3 jours"
        />
        <NotifRow icon="syringe" iconBg={tint(t.accent.tools, 0.14)} iconColor={t.accent.tools} left={t.accent.repro}
          title="Vaccination VHD — Lot L03"
          sub="Rappel annuel · 18 lapins concernés"
          time="Dans 5 jours"
        />
      </div>

      <div style={{ height: 32 }} />
      <BottomNav active="accueil" onChange={onNav} />
    </div>
  );
}

// ─── Rapports ─────────────────────────────────────────────────
function ScreenReports({ onNav }) {
  const { t, s, money, moneyCompact } = useTheme();
  const [period, setPeriod] = React.useState('month');

  return (
    <div style={{ background: t.bg, minHeight: '100%', paddingBottom: 100 }}>
      <AppBar title="Rapports & statistiques"
        color={t.primaryDarkVar || '#0F6E56'}
        onBack={() => onNav?.('plus')}
        actions={<AppBarAction icon="download" />}
      />

      {/* Period selector */}
      <div style={{ background: t.primaryDarkVar || '#0F6E56', padding: '0 16px 16px' }}>
        <div style={{
          display: 'flex', gap: 3, background: 'rgba(255,255,255,0.1)',
          borderRadius: 99, padding: 3,
        }}>
          {[
            { v: 'week', l: 'Semaine' },
            { v: 'month', l: 'Mois' },
            { v: 'quarter', l: 'Trimestre' },
            { v: 'year', l: 'Année' },
          ].map(p => (
            <button key={p.v} onClick={() => setPeriod(p.v)} style={{
              flex: 1, border: 0, background: period === p.v ? '#fff' : 'transparent',
              color: period === p.v ? t.primaryDarkVar || '#0F6E56' : '#fff',
              borderRadius: 99, padding: '8px 0', fontSize: 12, fontWeight: 700,
              cursor: 'pointer', fontFamily: 'inherit',
            }}>{p.l}</button>
          ))}
        </div>
      </div>

      {/* 3 colored report cards */}
      <div style={{ padding: '14px 16px 0', display: 'flex', flexDirection: 'column', gap: 12 }}>
        {[
          {
            bg: t.primary, icon: 'pets', title: 'Production',
            stats: [{ v: '184', l: 'lapins' }, { v: '6', l: 'portées' }, { v: '89%', l: 'sevrage' }],
            chart: <BarChart data={[0.18, 0.32, 0.48, 0.65, 0.81, 0.92]} color="#fff" height={42} />,
          },
          {
            bg: t.accent.finance, icon: 'euro', title: 'Financier',
            stats: [{ v: moneyCompact(1245000), l: 'recettes' }, { v: moneyCompact(312000), l: 'dépenses' }, { v: moneyCompact(933000), l: 'bénéfice ↑' }],
            chart: <LineChart data={[20, 25, 28, 30, 35, 47]} color="#fff" height={36} />,
          },
          {
            bg: t.accent.health, icon: 'medical', title: 'Santé',
            stats: [{ v: '12', l: 'vaccins' }, { v: '3', l: 'traitements' }, { v: '5', l: 'décès' }],
          },
        ].map((r, i) => {
          const Ico = I[r.icon];
          return (
            <div key={i} style={{
              background: r.bg, color: '#fff', borderRadius: 18, padding: 16,
              position: 'relative', overflow: 'hidden',
              boxShadow: `0 8px 18px ${tint(r.bg, 0.35)}`,
            }}>
              <div style={{ position: 'absolute', right: -10, top: -10, opacity: 0.15 }}>
                <Ico size={130} color="#fff" stroke={1.2} />
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14 }}>
                <div style={{
                  width: 36, height: 36, borderRadius: 10,
                  background: 'rgba(255,255,255,0.22)',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                }}>
                  <Ico size={20} color="#fff" stroke={1.9} />
                </div>
                <span style={{ fontSize: 15, fontWeight: 700 }}>Rapport {r.title}</span>
              </div>
              <div style={{ display: 'flex', gap: 12, marginBottom: r.chart ? 12 : 4 }}>
                {r.stats.map((s_, j) => (
                  <div key={j} style={{ flex: 1 }}>
                    <div style={{ fontSize: 18, fontWeight: 800, fontFeatureSettings: '"tnum"' }}>{s_.v}</div>
                    <div style={{ fontSize: 10.5, opacity: 0.85 }}>{s_.l}</div>
                  </div>
                ))}
              </div>
              {r.chart}
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 12 }}>
                <span style={{ fontSize: 11, opacity: 0.8 }}>Ce mois</span>
                <span style={{ fontSize: 12.5, fontWeight: 700 }}>Voir détails →</span>
              </div>
            </div>
          );
        })}
      </div>

      <SectionHeader label="Évolution du cheptel — 6 mois" />
      <div style={{ padding: '0 16px' }}>
        <Card raised>
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 10 }}>
            <span style={{ fontSize: 22, fontWeight: 800, color: t.ink, fontFeatureSettings: '"tnum"' }}>184</span>
            <Badge color={t.success}>+44 sur 6 mois</Badge>
          </div>
          <LineChart data={[140, 152, 161, 168, 175, 184]} color={t.primary} fill highlight height={90} />
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 6, fontSize: 9.5, color: t.muted }}>
            {['Déc','Jan','Fév','Mar','Avr','Mai'].map(l => <span key={l}>{l}</span>)}
          </div>
        </Card>
      </div>

      <SectionHeader label="Top clients ce mois" />
      <div style={{ padding: '0 16px' }}>
        <Card pad={false}>
          {[
            { rank: '🥇', name: 'Boucher Mbarga', sub: '12 lapins', amount: 540000 },
            { rank: '🥈', name: 'Restaurant Le Lapin d\u2019Or', sub: '8 lapins', amount: 360000 },
            { rank: '🥉', name: 'Ferme Kotto', sub: '6 lapins', amount: 240000 },
          ].map((c, i, arr) => (
            <div key={i} style={{
              display: 'flex', alignItems: 'center', gap: 12,
              padding: '12px 14px',
              borderBottom: i < arr.length - 1 ? `0.5px solid ${t.borderSoft}` : 'none',
            }}>
              <span style={{ fontSize: 20 }}>{c.rank}</span>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 13, fontWeight: 600, color: t.ink }}>{c.name}</div>
                <div style={{ fontSize: 11, color: t.muted, marginTop: 1 }}>{c.sub}</div>
              </div>
              <span style={{ fontSize: 13.5, fontWeight: 700, color: t.accent.finance, fontFeatureSettings: '"tnum"' }}>{moneyCompact(c.amount)}</span>
            </div>
          ))}
        </Card>
      </div>

      <div style={{ padding: '20px 16px', display: 'flex', gap: 8 }}>
        <Button kind="outlined" full icon={<I.pdf size={15} color={t.ink} stroke={1.8} />}>PDF</Button>
        <Button kind="outlined" full icon={<I.download size={15} color={t.ink} stroke={1.8} />}>CSV</Button>
        <Button kind="outlined" full icon={<I.share size={15} color={t.ink} stroke={1.8} />}>Partager</Button>
      </div>

      <BottomNav active="plus" onChange={onNav} />
    </div>
  );
}

// ─── Stock / Alimentation ─────────────────────────────────────
function ScreenStock({ onNav }) {
  const { t, s, dark } = useTheme();

  const StockCard = ({ title, value, max, unit, threshold, status, expiry }) => {
    const ratio = value / max;
    const color = status === 'red' ? t.danger : status === 'amber' ? t.warning : t.success;
    return (
      <div style={{
        background: t.bgCard, borderRadius: 14, padding: 14,
        border: dark ? 'none' : `0.5px solid ${t.border}`,
        boxShadow: dark ? 'none' : t.shadow,
        borderLeft: `4px solid ${color}`,
      }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 10, marginBottom: 10 }}>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 13.5, fontWeight: 700, color: t.ink }}>{title}</div>
            {expiry && <div style={{ fontSize: 10.5, color: t.muted, marginTop: 2 }}>{expiry}</div>}
          </div>
          {status === 'red' ? <Button kind="filled" color={t.accent.feed} size="sm">Commander</Button>
            : status === 'amber' ? <Button kind="tonal" color={t.warning} size="sm">Commander</Button>
            : <button style={{ background: 'transparent', border: 0, padding: 4, cursor: 'pointer' }}>
                <I.edit size={16} color={t.muted} stroke={1.8} />
              </button>}
        </div>
        <ProgressBar value={value} max={max} color={color} height={8} />
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8, fontSize: 11.5, color }}>
          <span style={{ fontWeight: 700, fontFeatureSettings: '"tnum"' }}>{value} {unit} restants</span>
          <span style={{ color: t.muted }}>Seuil: {threshold} {unit}</span>
        </div>
      </div>
    );
  };

  return (
    <div style={{ background: t.bg, minHeight: '100%', paddingBottom: 100, position: 'relative' }}>
      <AppBar title="Stock & Alimentation" subtitle="Gestion des aliments et médicaments"
        color={t.accent.feed}
        onBack={() => onNav?.('plus')}
        actions={
          <AppBarAction icon="plus"
            color="#fff"
          />
        }
      />

      {/* Alert banner */}
      <div style={{ padding: '14px 16px 0' }}>
        <AlertBanner level="danger" icon="warning"
          message="2 articles en dessous du seuil minimum"
          actionLabel="Voir"
        />
      </div>

      <SectionHeader label="Aliments" />
      <div style={{ padding: '0 16px', display: 'flex', flexDirection: 'column', gap: 8 }}>
        <StockCard title="Granulés lapins" value={42} max={100} unit="kg" threshold={50} status="red" />
        <StockCard title="Foin de qualité" value={85} max={100} unit="kg" threshold={20} status="green" />
        <StockCard title="Complément minéral" value={3} max={10} unit="kg" threshold={5} status="amber" />
      </div>

      <SectionHeader label="Médicaments" />
      <div style={{ padding: '0 16px', display: 'flex', flexDirection: 'column', gap: 8 }}>
        <StockCard title="Vaccin VHD" value={12} max={20} unit="doses" threshold={5} status="green" expiry="Exp: Déc 2025" />
        <StockCard title="Antiparasitaire Ivermectine" value={1} max={10} unit="dose" threshold={3} status="red" expiry="Exp: Juin 2025" />
      </div>

      <SectionHeader label="Équipements" />
      <div style={{ padding: '0 16px' }}>
        <Card pad={false}>
          {[
            { name: 'Cage maternité B-07', sub: 'Vérifiée il y a 3 jours', statut: 'Bon état', color: t.success },
            { name: 'Balance électronique', sub: 'Dernier contrôle: il y a 18 jours', statut: 'À vérifier', color: t.warning },
            { name: 'Pulvérisateur désinfection', sub: 'En atelier — retour 12 mai', statut: 'En réparation', color: t.danger },
          ].map((e, i, arr) => (
            <div key={i} style={{
              display: 'flex', alignItems: 'center', gap: 12,
              padding: '12px 14px',
              borderBottom: i < arr.length - 1 ? `0.5px solid ${t.borderSoft}` : 'none',
            }}>
              <div style={{
                width: 36, height: 36, borderRadius: 9, background: t.bgRaised,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <I.pkg size={18} color={t.muted} stroke={1.8} />
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 13, fontWeight: 600, color: t.ink }}>{e.name}</div>
                <div style={{ fontSize: 10.5, color: t.muted, marginTop: 1 }}>{e.sub}</div>
              </div>
              <Badge color={e.color}>{e.statut}</Badge>
            </div>
          ))}
        </Card>
      </div>

      <FAB icon="plus" label="Ajouter" color={t.accent.feed} />
      <div style={{ height: 32 }} />
      <BottomNav active="plus" onChange={onNav} />
    </div>
  );
}

// ─── Réglages / Profil ────────────────────────────────────────
function ScreenReglages({ onNav }) {
  const { t, s, dark } = useTheme();

  const Row = ({ icon, label, value, danger, isLast, onClick }) => {
    const Ico = I[icon];
    return (
      <div onClick={onClick} style={{
        display: 'flex', alignItems: 'center', gap: 12,
        padding: '12px 14px',
        borderBottom: isLast ? 'none' : `0.5px solid ${t.borderSoft}`,
        cursor: onClick ? 'pointer' : 'default',
      }}>
        <div style={{
          width: 34, height: 34, borderRadius: 9,
          background: danger ? tint(t.danger, 0.14) : t.bgRaised,
          display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
        }}>
          <Ico size={17} color={danger ? t.danger : t.muted} stroke={1.8} />
        </div>
        <span style={{ flex: 1, fontSize: 13.5, color: danger ? t.danger : t.ink, fontWeight: 500 }}>{label}</span>
        {value && <span style={{ fontSize: 12, color: t.muted }}>{value}</span>}
        <I.chevron size={14} color={t.muted} stroke={1.6} />
      </div>
    );
  };

  return (
    <div style={{ background: t.bg, minHeight: '100%', paddingBottom: 100 }}>
      <AppBar title={s.reglages} flat onBack={() => onNav?.('plus')} />

      {/* Profile */}
      <div style={{ padding: '8px 16px 16px' }}>
        <div style={{
          background: t.bgCard, borderRadius: 16, padding: 16,
          border: `0.5px solid ${t.border}`,
          display: 'flex', alignItems: 'center', gap: 14,
        }}>
          <Avatar initials="JM" bg={t.primary} size={56} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 16, fontWeight: 700, color: t.ink }}>Jean-Marie Nkomo</div>
            <div style={{ fontSize: 11.5, color: t.muted, marginTop: 2 }}>Propriétaire · Ferme Lapinverde</div>
            <a style={{ fontSize: 11.5, color: t.primary, fontWeight: 600, cursor: 'pointer', marginTop: 6, display: 'inline-block' }}>
              Modifier le profil →
            </a>
          </div>
        </div>
      </div>

      {/* Farm card */}
      <div style={{ padding: '0 16px' }}>
        <Card>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 14 }}>
            <div style={{
              width: 40, height: 40, borderRadius: 10,
              background: tint(t.primary, 0.14),
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <I.home size={20} color={t.primary} stroke={1.9} />
            </div>
            <div>
              <div style={{ fontSize: 14.5, fontWeight: 700, color: t.ink }}>Ferme Lapinverde</div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 11.5, color: t.muted, marginTop: 2 }}>
                <I.pin size={11} color={t.muted} stroke={1.8} />
                <span>Yaoundé, Cameroun</span>
                <span>·</span>
                <span>Depuis mars 2023</span>
              </div>
            </div>
          </div>
          <div style={{ display: 'flex', gap: 12, paddingTop: 12, borderTop: `0.5px solid ${t.borderSoft}` }}>
            {[
              { v: '184', l: 'lapins' },
              { v: '3', l: 'ouvriers' },
              { v: '12', l: 'lots' },
            ].map((m, i) => (
              <div key={i} style={{ flex: 1, textAlign: 'center' }}>
                <div style={{ fontSize: 19, fontWeight: 800, color: t.ink, fontFeatureSettings: '"tnum"' }}>{m.v}</div>
                <div style={{ fontSize: 10.5, color: t.muted, marginTop: 1 }}>{m.l}</div>
              </div>
            ))}
          </div>
        </Card>
      </div>

      {/* Sync */}
      <SectionHeader label="Sauvegarde cloud" />
      <div style={{ padding: '0 16px' }}>
        <div style={{
          background: tint(t.success, 0.10),
          border: `0.5px solid ${tint(t.success, 0.30)}`,
          borderLeft: `3px solid ${t.success}`,
          borderRadius: 12, padding: '12px 14px',
          display: 'flex', alignItems: 'center', gap: 12,
        }}>
          <div style={{
            width: 36, height: 36, borderRadius: 10, background: tint(t.success, 0.16),
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <I.cloudSync size={20} color={t.success} stroke={1.9} />
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 13, fontWeight: 700, color: t.ink }}>Données synchronisées</div>
            <div style={{ fontSize: 11, color: t.muted, marginTop: 1 }}>Dernière synchro · aujourd'hui 09h15</div>
          </div>
          <SyncDot status="ok" />
        </div>
      </div>

      {/* Team */}
      <SectionHeader label="Équipe" />
      <div style={{ padding: '0 16px' }}>
        <Card pad={false}>
          {[
            { i: 'PK', name: 'Paul Kamga', sub: 'Ouvrier', bg: tint(t.primary, 0.14), color: t.primary },
            { i: 'SM', name: 'Sarah Manga', sub: 'Ouvrière', bg: tint(t.accent.tools, 0.14), color: t.accent.tools },
          ].map((m, i) => (
            <div key={i} style={{
              display: 'flex', alignItems: 'center', gap: 12,
              padding: '12px 14px', borderBottom: `0.5px solid ${t.borderSoft}`,
            }}>
              <Avatar initials={m.i} bg={m.bg} color={m.color} size={36} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 13.5, fontWeight: 600, color: t.ink }}>{m.name}</div>
                <div style={{ fontSize: 10.5, color: t.muted, marginTop: 1 }}>{m.sub}</div>
              </div>
              <Badge color={t.success} icon={<span style={{ width: 5, height: 5, background: t.success, borderRadius: 99 }} />}>actif</Badge>
            </div>
          ))}
          <div style={{
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
            padding: '12px 14px', color: t.primary, fontSize: 13, fontWeight: 700,
            cursor: 'pointer',
          }}>
            <I.qr size={15} color={t.primary} stroke={2} />
            <span>Inviter un ouvrier · QR code</span>
          </div>
        </Card>
      </div>

      {/* Préférences */}
      <SectionHeader label="Préférences" />
      <div style={{ padding: '0 16px' }}>
        <Card pad={false}>
          <Row icon="globe" label="Langue" value="Français" />
          <Row icon="euro" label="Devise" value="FCFA" />
          <Row icon="sun" label="Thème" value="Auto (système)" />
          <Row icon="bell" label="Notifications" value="Activées" />
          <Row icon="clock" label="Heure routine matin" value="06h30" />
          <Row icon="scale" label="Unités de poids" value="Kilogrammes" />
          <Row icon="lock" label="Sécurité" value="PIN activé" isLast />
        </Card>
      </div>

      {/* Données */}
      <SectionHeader label="Données" />
      <div style={{ padding: '0 16px' }}>
        <Card pad={false}>
          <Row icon="download" label="Exporter toutes les données" />
          <Row icon="cloud" label="Sauvegarde locale chiffrée" />
          <Row icon="trash" label="Effacer le cache local" danger isLast />
        </Card>
      </div>

      <div style={{ padding: '20px 16px 0', textAlign: 'center', fontSize: 10.5, color: t.muted, lineHeight: 1.6 }}>
        CuniGest v3.0 · Flutter · SQLCipher AES-256<br/>
        Développé pour les cuniculteurs d&apos;Afrique
      </div>

      <BottomNav active="plus" onChange={onNav} />
    </div>
  );
}

Object.assign(window, { ScreenAlertes, ScreenReports, ScreenStock, ScreenReglages });
