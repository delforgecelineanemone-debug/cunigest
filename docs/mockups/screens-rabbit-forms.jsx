// screens-forms.jsx — Saisie saillie + Saisie vente (forms V3)

// ─── Saisie d'une saillie ─────────────────────────────────────
function ScreenMatingForm({ onNav }) {
  const { t, s, dark } = useTheme();
  const [male, setMale] = React.useState('max');
  const [result, setResult] = React.useState('reussie');

  return (
    <div style={{ background: t.bg, minHeight: '100%', paddingBottom: 100 }}>
      <AppBar title={s.nouvelleSaillie} subtitle={s.recordMating || 'Enregistrer la saillie'}
        color={t.accent.repro}
        onBack={() => onNav?.('lapin')}
      />

      {/* Progress 3 steps */}
      <div style={{ background: t.accent.repro, padding: '0 16px 16px' }}>
        <div style={{ display: 'flex', gap: 6 }}>
          <span style={{ flex: 1, height: 4, background: '#fff', borderRadius: 99 }} />
          <span style={{ flex: 1, height: 4, background: '#fff', borderRadius: 99 }} />
          <span style={{ flex: 1, height: 4, background: 'rgba(255,255,255,0.35)', borderRadius: 99 }} />
        </div>
      </div>

      {/* Femelle */}
      <SectionHeader label={s.femelle} />
      <div style={{ padding: '0 16px' }}>
        <div style={{
          background: t.bgCard, borderRadius: 14, padding: '12px 14px',
          border: `2px solid ${t.accent.repro}`,
          display: 'flex', alignItems: 'center', gap: 12,
        }}>
          <Avatar bg={tint(t.primary, 0.14)} color={t.primary} size={42} square
            icon={<I.pets size={20} color={t.primary} stroke={1.9} />} />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 14, fontWeight: 600, color: t.ink }}>♀ Bella · #L-0042</div>
            <div style={{ fontSize: 11, color: t.muted, marginTop: 1 }}>Néo-Zélandaise · 14 mois · 3.2 kg</div>
          </div>
          <div style={{
            width: 22, height: 22, borderRadius: 99, background: t.accent.repro,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <I.check size={13} color="#fff" stroke={3} />
          </div>
        </div>
      </div>

      {/* Mâle */}
      <SectionHeader label={s.male} action={
        <a style={{ fontSize: 12, color: t.accent.repro, fontWeight: 600, cursor: 'pointer' }}>{s.changer} →</a>
      } />
      <div style={{ padding: '0 16px', display: 'flex', flexDirection: 'column', gap: 8 }}>
        {[
          { id: 'max', name: '♂ Buck Max · #L-0018', sub: 'Néo-Zélandaise · 18 mois · Père habituel', meta: 'GMQ 38 g/j · 12 portées réussies' },
          { id: 'rex', name: '♂ Buck Rex · #L-0031', sub: 'Californienne · 12 mois · Disponible', meta: 'GMQ 35 g/j · 3 portées' },
        ].map(m => {
          const active = male === m.id;
          return (
            <div key={m.id} onClick={() => setMale(m.id)} style={{
              background: t.bgCard, borderRadius: 14, padding: '12px 14px',
              border: active ? `2px solid ${t.accent.repro}` : `0.5px solid ${t.border}`,
              display: 'flex', alignItems: 'center', gap: 12, cursor: 'pointer',
            }}>
              <Avatar bg={tint(t.accent.tools, 0.14)} color={t.accent.tools} size={42} square
                icon={<I.pets size={20} color={t.accent.tools} stroke={1.9} />} />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 14, fontWeight: 600, color: t.ink }}>{m.name}</div>
                <div style={{ fontSize: 11, color: t.muted, marginTop: 1 }}>{m.sub}</div>
                <div style={{ fontSize: 10.5, color: t.accent.tools, marginTop: 3, fontWeight: 600 }}>{m.meta}</div>
              </div>
              <div style={{
                width: 22, height: 22, borderRadius: 99,
                background: active ? t.accent.repro : 'transparent',
                border: active ? 'none' : `1.5px solid ${t.border}`,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                flexShrink: 0,
              }}>
                {active && <I.check size={13} color="#fff" stroke={3} />}
              </div>
            </div>
          );
        })}
      </div>

      {/* Consanguinité — feature spécifique V3 */}
      <div style={{ padding: '12px 16px 0' }}>
        <AlertBanner level="success" icon="check"
          message="Aucun lien de consanguinité détecté entre Bella et Buck Max."
        />
      </div>

      {/* Dates */}
      <SectionHeader label={s.dates} />
      <div style={{ padding: '0 16px' }}>
        <Card pad={false}>
          <div style={{ display: 'flex', alignItems: 'center', padding: '14px 14px' }}>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 11, color: t.muted }}>{s.dateSaillie}</div>
              <div style={{ fontSize: 14.5, color: t.ink, fontWeight: 600, marginTop: 2 }}>06 mai 2025</div>
            </div>
            <I.calendar size={20} color={t.muted} stroke={1.8} />
          </div>
        </Card>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8, marginTop: 8 }}>
          {[
            { label: s.miseBasPrevue, value: '6 juin 2025', meta: `${s.calculeAuto} · J+31` },
            { label: s.sevragePrevu, value: '4 juil. 2025', meta: `${s.calculeAuto} · J+28` },
          ].map((card, i) => (
            <div key={i} style={{
              background: tint(t.accent.repro, dark ? 0.20 : 0.10),
              border: `0.5px solid ${tint(t.accent.repro, 0.30)}`,
              borderRadius: 12, padding: 12,
            }}>
              <div style={{ fontSize: 10.5, color: t.accent.repro, opacity: 0.9, fontWeight: 600 }}>{card.label}</div>
              <div style={{ fontSize: 15, fontWeight: 700, color: dark ? t.accent.repro : t.accentRepro, marginTop: 4, fontFeatureSettings: '"tnum"' }}>{card.value}</div>
              <div style={{ fontSize: 10, color: t.accent.repro, opacity: 0.75, marginTop: 4 }}>{card.meta}</div>
            </div>
          ))}
        </div>
      </div>

      {/* Result */}
      <SectionHeader label={s.resultat} />
      <div style={{ padding: '0 16px' }}>
        <Segmented color={t.accent.repro}
          value={result} onChange={setResult}
          options={[
            { value: 'reussie', label: s.reussie },
            { value: 'douteuse', label: s.douteuse },
            { value: 'echouee', label: s.echouee },
          ]}
        />
      </div>

      {/* Info banner */}
      <div style={{ padding: '16px 16px 0' }}>
        <div style={{
          background: tint(t.accent.repro, 0.10),
          border: `0.5px solid ${tint(t.accent.repro, 0.30)}`,
          borderLeft: `3px solid ${t.accent.repro}`,
          borderRadius: 12, padding: '12px 14px',
          display: 'flex', gap: 10, alignItems: 'flex-start',
        }}>
          <div style={{
            width: 22, height: 22, borderRadius: 99, background: t.accent.repro,
            display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, marginTop: 1,
          }}>
            <span style={{ color: '#fff', fontSize: 13, fontWeight: 800 }}>i</span>
          </div>
          <div style={{ fontSize: 12, color: t.ink, lineHeight: 1.5 }}>
            <b>Notifications programmées automatiquement</b><br/>
            • Rappel mise bas 6 juin · Contrôle mamelles J+4, J+10, J+20<br/>
            • Pesée lapereaux J+7 · Sevrage J+28
          </div>
        </div>
      </div>

      <SectionHeader label={s.observations} />
      <div style={{ padding: '0 16px' }}>
        <div style={{
          background: t.bgRaised, border: `0.5px solid ${t.border}`,
          borderRadius: 12, padding: '12px 14px', minHeight: 70,
          fontSize: 12.5, color: t.muted, fontStyle: 'italic',
        }}>Ajouter une observation...</div>
      </div>

      <div style={{ padding: '20px 16px', display: 'flex', gap: 8 }}>
        <Button kind="outlined" onClick={() => onNav?.('lapin')} style={{ flex: 1 }}>{s.annuler}</Button>
        <Button kind="filled" color={t.accent.repro} style={{ flex: 2 }}
          icon={<I.check size={16} color="#fff" stroke={2.4} />}>{s.enregistrer}</Button>
      </div>

      <BottomNav active="repro" onChange={onNav} />
    </div>
  );
}

// ─── Saisie d'une vente ───────────────────────────────────────
function ScreenSaleForm({ onNav }) {
  const { t, s, dark, money } = useTheme();
  const [lot, setLot] = React.useState('L01');
  const [type, setType] = React.useState('poidsVif');
  const [client, setClient] = React.useState('mbarga');

  return (
    <div style={{ background: t.bg, minHeight: '100%', paddingBottom: 100 }}>
      <AppBar title={s.nouvelleVente} subtitle="Enregistrer la vente"
        color={t.accent.finance}
        onBack={() => onNav?.('plus')}
      />

      <div style={{ background: t.accent.finance, padding: '0 16px 16px' }}>
        <div style={{ display: 'flex', gap: 6 }}>
          <span style={{ flex: 1, height: 4, background: '#fff', borderRadius: 99 }} />
          <span style={{ flex: 1, height: 4, background: 'rgba(255,255,255,0.35)', borderRadius: 99 }} />
          <span style={{ flex: 1, height: 4, background: 'rgba(255,255,255,0.35)', borderRadius: 99 }} />
        </div>
      </div>

      {/* Lot */}
      <SectionHeader label={s.lotAVendre} />
      <div style={{ padding: '0 16px', display: 'flex', flexDirection: 'column', gap: 8 }}>
        {[
          { id: 'L01', code: 'L01', count: 22, sub: 'Poids moy. 1.8 kg · Prêt à vendre', kind: 'vente', disabled: false },
          { id: 'L03', code: 'L03', count: 38, sub: 'Poids moy. 0.92 kg', kind: 'engraissement', disabled: false },
          { id: 'F02', code: 'F02', count: 12, sub: 'En maternité — non disponible', kind: 'maternite', disabled: true },
        ].map(l => {
          const active = lot === l.id;
          return (
            <div key={l.id} onClick={() => !l.disabled && setLot(l.id)} style={{
              background: t.bgCard, borderRadius: 14, padding: '12px 14px',
              border: `0.5px solid ${active ? t.accent.finance : t.border}`,
              borderLeft: `${active ? 4 : 0.5}px solid ${active ? t.accent.finance : t.border}`,
              opacity: l.disabled ? 0.45 : 1,
              display: 'flex', alignItems: 'center', gap: 12,
              cursor: l.disabled ? 'not-allowed' : 'pointer',
            }}>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 14, fontWeight: 700, color: t.ink }}>
                  Lot {l.code} <span style={{ fontSize: 12, color: t.muted, fontWeight: 500 }}>· {l.count} lapins</span>
                </div>
                <div style={{ fontSize: 11.5, color: t.muted, marginTop: 2 }}>{l.sub}</div>
              </div>
              <Badge color={l.kind === 'vente' ? t.accent.finance : l.kind === 'engraissement' ? t.primary : t.accent.repro}>
                {lotBadgeLabel(l.kind, s)}
              </Badge>
            </div>
          );
        })}
      </div>

      {/* Type */}
      <SectionHeader label={s.typeVente} />
      <div style={{ padding: '0 16px' }}>
        <Segmented color={t.accent.finance}
          value={type} onChange={setType}
          options={[
            { value: 'poidsVif', label: `${s.poidsVif} 🐰` },
            { value: 'carcasse', label: `${s.carcasse} 🥩` },
          ]}
        />
      </div>

      {/* Qty & price */}
      <SectionHeader label={s.quantitePrix} />
      <div style={{ padding: '0 16px' }}>
        <Card pad={false}>
          <div style={{ padding: '12px 14px', borderBottom: `0.5px solid ${t.borderSoft}`, display: 'flex' }}>
            <span style={{ flex: 1, fontSize: 12.5, color: t.muted }}>{s.poidsTotal} (kg)</span>
            <span style={{ fontSize: 15, fontWeight: 700, color: t.ink, fontFeatureSettings: '"tnum"' }}>22.5 kg</span>
          </div>
          <div style={{ padding: '12px 14px', borderBottom: `0.5px solid ${t.borderSoft}`, display: 'flex' }}>
            <span style={{ flex: 1, fontSize: 12.5, color: t.muted }}>{s.prixUnitaire} / kg</span>
            <span style={{ fontSize: 15, fontWeight: 700, color: t.ink, fontFeatureSettings: '"tnum"' }}>{money(2500)}</span>
          </div>
          <div style={{
            padding: '16px 14px', display: 'flex', alignItems: 'baseline',
            background: tint(t.accent.finance, dark ? 0.20 : 0.10),
          }}>
            <span style={{ flex: 1, fontSize: 12.5, color: t.accent.finance, fontWeight: 700 }}>{s.montantTotal}</span>
            <span style={{ fontSize: 24, fontWeight: 800, color: t.accent.finance, fontFeatureSettings: '"tnum"' }}>{money(56250)}</span>
          </div>
        </Card>
      </div>

      {/* Client */}
      <SectionHeader label={s.client} />
      <div style={{ padding: '0 16px' }}>
        <div style={{
          background: t.bgRaised, border: `0.5px solid ${t.border}`,
          borderRadius: 12, padding: '10px 12px',
          display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8,
        }}>
          <I.search size={16} color={t.muted} stroke={1.8} />
          <span style={{ flex: 1, fontSize: 12, color: t.muted, fontStyle: 'italic' }}>{s.rechercherClient}</span>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {[
            { id: 'mbarga', name: 'Boucher Mbarga', sub: 'Revendeur · Yaoundé', kind: 'boucher' },
            { id: 'lapin', name: 'Restaurant Le Lapin d\u2019Or', sub: 'Restaurant · Douala', kind: 'restaurant' },
          ].map(c => {
            const active = client === c.id;
            return (
              <div key={c.id} onClick={() => setClient(c.id)} style={{
                background: t.bgCard, borderRadius: 12, padding: '10px 12px',
                border: active ? `2px solid ${t.accent.finance}` : `0.5px solid ${t.border}`,
                display: 'flex', alignItems: 'center', gap: 12, cursor: 'pointer',
              }}>
                <Avatar initials={c.name[0]} bg={tint(t.accent.finance, 0.14)}
                  color={t.accent.finance} size={36} />
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 13, fontWeight: 600, color: t.ink }}>{c.name}</div>
                  <div style={{ fontSize: 11, color: t.muted }}>{c.sub}</div>
                </div>
              </div>
            );
          })}
          <div style={{
            background: 'transparent', borderRadius: 12, padding: '12px',
            border: `1.2px dashed ${t.border}`,
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
            color: t.muted, cursor: 'pointer',
          }}>
            <I.plus size={16} color={t.muted} stroke={2} />
            <span style={{ fontSize: 13, fontWeight: 600 }}>Nouveau client</span>
          </div>
        </div>
      </div>

      <div style={{ padding: '20px 16px', display: 'flex', gap: 8 }}>
        <Button kind="outlined" onClick={() => onNav?.('plus')} style={{ flex: 1 }}>{s.annuler}</Button>
        <Button kind="filled" color={t.accent.finance} style={{ flex: 2 }}
          icon={<I.check size={16} color="#fff" stroke={2.4} />}>{s.enregistrer}</Button>
      </div>

      <BottomNav active="plus" onChange={onNav} />
    </div>
  );
}

Object.assign(window, { ScreenMatingForm, ScreenSaleForm });
