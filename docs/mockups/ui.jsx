// ui.jsx — UI atoms & molecules V3 (CuniUI Field-Premium)
// Material 3 patterns matching the Flutter implementation.

// ─── Icons (Material Symbols path data, outlined) ────────────────
function Icon({ size = 22, color = 'currentColor', stroke = 1.7, children, viewBox = '0 0 24 24' }) {
  return (
    <svg width={size} height={size} viewBox={viewBox} fill="none" aria-hidden="true"
         strokeWidth={stroke} strokeLinecap="round" strokeLinejoin="round"
         stroke={color}>
      {children}
    </svg>
  );
}

const _stroke = (d, p) => <path d={d} stroke={p?.color || 'currentColor'} strokeWidth={p?.stroke || 1.7} strokeLinecap="round" strokeLinejoin="round" fill="none"/>;

const I = {
  // Nav primary
  home: (p) => <Icon {...p}>{_stroke('M3 11l9-7 9 7v9a1 1 0 0 1-1 1h-5v-7h-6v7H4a1 1 0 0 1-1-1v-9z', p)}</Icon>,
  pets: (p) => <Icon {...p}>{_stroke('M5 11.5c0-2 1-3.5 2-3.5 1.4 0 2 2 2 4M19 11.5c0-2-1-3.5-2-3.5-1.4 0-2 2-2 4M3.5 14c.4-2 2-3 4-3M20.5 14c-.4-2-2-3-4-3M12 13c4 0 6.5 2.4 6.5 5.5S15.5 22 12 22s-6.5-.4-6.5-3.5S8 13 12 13z', p)}</Icon>,
  heart: (p) => <Icon {...p}>{_stroke('M12 6.2a4 4 0 0 1 8 0c0 5.5-8 11.8-8 11.8S4 11.7 4 6.2a4 4 0 0 1 8 0z', p)}</Icon>,
  heartFill: (p) => <Icon {...p}><path d="M12 6.2a4 4 0 0 1 8 0c0 5.5-8 11.8-8 11.8S4 11.7 4 6.2a4 4 0 0 1 8 0z" fill={p?.color || 'currentColor'}/></Icon>,
  checklist: (p) => <Icon {...p}>{_stroke('M3 5l2 2 4-4M3 12l2 2 4-4M3 19l2 2 4-4M13 6h8M13 13h8M13 20h8', p)}</Icon>,
  apps: (p) => <Icon {...p}>{_stroke('M3.5 3.5h6v6h-6zM14.5 3.5h6v6h-6zM3.5 14.5h6v6h-6zM14.5 14.5h6v6h-6z', p)}</Icon>,
  // Cheptel sub-tabs
  groups: (p) => <Icon {...p}>{_stroke('M9 12a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM17 13a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5zM3 19c.5-3 3-5 6-5s5.5 2 6 5M14 14c2 0 5 1 6 4', p)}</Icon>,
  grid: (p) => <Icon {...p}>{_stroke('M3.5 3.5h7v7h-7zM13.5 3.5h7v7h-7zM3.5 13.5h7v7h-7zM13.5 13.5h7v7h-7z', p)}</Icon>,
  // Common
  bell: (p) => <Icon {...p}>{_stroke('M6 8a6 6 0 1 1 12 0c0 7 3 8 3 8H3s3-1 3-8M10 21a2 2 0 0 0 4 0', p)}</Icon>,
  back: (p) => <Icon {...p}>{_stroke('M15 5l-7 7 7 7', p)}</Icon>,
  chevron: (p) => <Icon {...p}>{_stroke('M9 5l7 7-7 7', p)}</Icon>,
  chevronUp: (p) => <Icon {...p}>{_stroke('M5 15l7-7 7 7', p)}</Icon>,
  plus: (p) => <Icon {...p}>{_stroke('M12 5v14M5 12h14', { ...p, stroke: (p?.stroke || 2) })}</Icon>,
  check: (p) => <Icon {...p}>{_stroke('M5 12.5l4.5 4.5L19 7', { ...p, stroke: (p?.stroke || 2.2) })}</Icon>,
  close: (p) => <Icon {...p}>{_stroke('M6 6l12 12M6 18L18 6', { ...p, stroke: (p?.stroke || 2) })}</Icon>,
  search: (p) => <Icon {...p}>{_stroke('M11 18a7 7 0 1 1 0-14 7 7 0 0 1 0 14zM20 20l-3.5-3.5', p)}</Icon>,
  // Domain
  egg: (p) => <Icon {...p}>{_stroke('M12 3c-4 0-6 5-6 9.5C6 16.4 8.7 20 12 20s6-3.6 6-7.5C18 8 16 3 12 3z', p)}</Icon>,
  child: (p) => <Icon {...p}>{_stroke('M12 6a2 2 0 1 1 0-4 2 2 0 0 1 0 4zM9 12.5l3-3 3 3M9 12.5L8 22M15 12.5L16 22M12 9.5V14', p)}</Icon>,
  scale: (p) => <Icon {...p}>{_stroke('M4 7h16l-2 12a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L4 7zM9 7V5a3 3 0 0 1 6 0v2', p)}</Icon>,
  syringe: (p) => <Icon {...p}>{_stroke('M14 4l6 6M16 6l-9 9M11 11l-5 5-2-1 1-2 5-5M7 17l-3 3', p)}</Icon>,
  medical: (p) => <Icon {...p}>{_stroke('M12 3l8 4v6c0 4.5-3.5 7.5-8 8-4.5-.5-8-3.5-8-8V7l8-4zM12 9v6M9 12h6', p)}</Icon>,
  pkg: (p) => <Icon {...p}>{_stroke('M3 7l9-4 9 4v10l-9 4-9-4V7zM12 3v18M3 7l9 4 9-4', p)}</Icon>,
  euro: (p) => <Icon {...p}>{_stroke('M17 6.5A6 6 0 0 0 7 12a6 6 0 0 0 10 5.5M4 10h8M4 14h8', p)}</Icon>,
  money: (p) => <Icon {...p}>{_stroke('M3 6h18v13H3zM12 16.5a3 3 0 1 0 0-6 3 3 0 0 0 0 6z', p)}</Icon>,
  wallet: (p) => <Icon {...p}>{_stroke('M3 7a2 2 0 0 1 2-2h13a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7zM16 13h3', p)}</Icon>,
  cart: (p) => <Icon {...p}>{_stroke('M4 5h2l2 11h10l2-7H7M9 20a1 1 0 1 1 0-2 1 1 0 0 1 0 2zM17 20a1 1 0 1 1 0-2 1 1 0 0 1 0 2z', p)}</Icon>,
  pdf: (p) => <Icon {...p}>{_stroke('M6 3h8l5 5v13a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1zM14 3v5h5M9 14h6M9 17h6M9 11h3', p)}</Icon>,
  download: (p) => <Icon {...p}>{_stroke('M12 4v12m0 0l-4-4m4 4l4-4M5 20h14', p)}</Icon>,
  share: (p) => <Icon {...p}>{_stroke('M4 12v7a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-7M16 6l-4-4-4 4M12 2v14', p)}</Icon>,
  calc: (p) => <Icon {...p}>{_stroke('M5 3h14a1 1 0 0 1 1 1v17a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1zM7 7h10v3H7zM8 14h.01M12 14h.01M16 14h.01M8 18h.01M12 18h.01M16 18h.01', p)}</Icon>,
  qr: (p) => <Icon {...p}>{_stroke('M3.5 3.5h6v6h-6zM3.5 14.5h6v6h-6zM14.5 3.5h6v6h-6zM14.5 14.5h.5M19.5 19.5h.5M14.5 17.5h.5M17.5 14.5h.5M14.5 14.5h.5', p)}</Icon>,
  cloud: (p) => <Icon {...p}>{_stroke('M7 18h11a4 4 0 0 0 0-8 5 5 0 0 0-9.7-1.3A4 4 0 0 0 7 18z', p)}</Icon>,
  cloudSync: (p) => <Icon {...p}>{_stroke('M7 18h11a4 4 0 0 0 0-8 5 5 0 0 0-9.7-1.3A4 4 0 0 0 7 18zM10 14l2 2 2-2M12 12v4', p)}</Icon>,
  settings: (p) => <Icon {...p}>{_stroke('M12 9.5a2.5 2.5 0 1 0 0 5 2.5 2.5 0 0 0 0-5zM19.4 13.5l1.6 1-2 3.5-1.9-.5a8 8 0 0 1-1.6 1L15 20.5h-4l-.5-2a8 8 0 0 1-1.6-1L7 18l-2-3.5 1.6-1a8 8 0 0 1 0-2L5 9.5 7 6l1.9.5a8 8 0 0 1 1.6-1L11 3.5h4l.5 2a8 8 0 0 1 1.6 1L19 6l2 3.5-1.6 1a8 8 0 0 1 0 2z', p)}</Icon>,
  people: (p) => <Icon {...p}>{_stroke('M9 12a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zM17 13a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM3 20c0-3.3 2.7-6 6-6s6 2.7 6 6M15 14c2.8 0 5 2.2 5 5', p)}</Icon>,
  eco: (p) => <Icon {...p}>{_stroke('M5 19c0-7 5-12 14-12-1 7-5 12-12 12-1.5 0-2-1 0 0z M5 19c2-3 4-5 7-7', p)}</Icon>,
  trophy: (p) => <Icon {...p}>{_stroke('M7 4h10v6a5 5 0 0 1-10 0V4zM7 7H4v2a3 3 0 0 0 3 3M17 7h3v2a3 3 0 0 1-3 3M10 15h4M12 15v3M9 18h6', p)}</Icon>,
  fire: (p) => <Icon {...p}>{_stroke('M12 22c-4 0-6.5-3-6.5-6.5 0-2 1.5-4 2.5-5 .5 1 1.5 1.5 2.5 1-1-3 0-5.5 2.5-8 1 4 6 6 6 12 0 3.5-3 6.5-7 6.5z', p)}</Icon>,
  calendar: (p) => <Icon {...p}>{_stroke('M3.5 5h17v15h-17zM3.5 10h17M8 3v4M16 3v4', p)}</Icon>,
  alarm: (p) => <Icon {...p}>{_stroke('M12 21a8 8 0 1 0 0-16 8 8 0 0 0 0 16zM12 9v4l3 2M4 5l3-3M20 5l-3-3', p)}</Icon>,
  warning: (p) => <Icon {...p}>{_stroke('M12 4l10 17H2L12 4zM12 10v5M12 18v.5', p)}</Icon>,
  inv: (p) => <Icon {...p}>{_stroke('M4 8l8 4 8-4M4 8v9l8 4 8-4V8M4 8l8-4 8 4M12 12v9', p)}</Icon>,
  cage: (p) => <Icon {...p}>{_stroke('M4 5h16v14H4zM4 12h16M9 5v14M15 5v14', p)}</Icon>,
  lock: (p) => <Icon {...p}>{_stroke('M5 11h14v10H5zM8 11V7a4 4 0 0 1 8 0v4', p)}</Icon>,
  eye: (p) => <Icon {...p}>{_stroke('M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12zM12 9.5a2.5 2.5 0 1 0 0 5 2.5 2.5 0 0 0 0-5z', p)}</Icon>,
  eyeOff: (p) => <Icon {...p}>{_stroke('M3 3l18 18M10.5 6.2a8 8 0 0 1 11.5 5.8 14 14 0 0 1-3 4M14 14a3 3 0 0 1-4-4M2 12s4-7 10-7c1.4 0 2.7.3 3.8.7', p)}</Icon>,
  pin: (p) => <Icon {...p}>{_stroke('M12 22s7-7 7-13a7 7 0 0 0-14 0c0 6 7 13 7 13zM12 11.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z', p)}</Icon>,
  chart: (p) => <Icon {...p}>{_stroke('M4 4v16h16M8 16v-5M12 16V8M16 16v-7', p)}</Icon>,
  water: (p) => <Icon {...p}>{_stroke('M12 3s7 8 7 13a7 7 0 0 1-14 0c0-5 7-13 7-13z', p)}</Icon>,
  plant: (p) => <Icon {...p}>{_stroke('M12 21V11M12 11C12 7 8 5 5 5c0 4 3 6 7 6zM12 11c0-4 4-6 7-6 0 4-3 6-7 6z', p)}</Icon>,
  edit: (p) => <Icon {...p}>{_stroke('M4 20h4l11-11-4-4L4 16v4z', p)}</Icon>,
  logout: (p) => <Icon {...p}>{_stroke('M9 5H5a1 1 0 0 0-1 1v12a1 1 0 0 0 1 1h4M16 8l4 4-4 4M9 12h11', p)}</Icon>,
  trash: (p) => <Icon {...p}>{_stroke('M4 7h16M9 7V4h6v3M6 7l1 13a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-13', p)}</Icon>,
  globe: (p) => <Icon {...p}>{_stroke('M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18', p)}</Icon>,
  clock: (p) => <Icon {...p}>{_stroke('M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 7v5l3.5 2', p)}</Icon>,
  arrowUp: (p) => <Icon {...p}>{_stroke('M12 19V5M5 12l7-7 7 7', p)}</Icon>,
  arrowDown: (p) => <Icon {...p}>{_stroke('M12 5v14M19 12l-7 7-7-7', p)}</Icon>,
  filter: (p) => <Icon {...p}>{_stroke('M4 5h16l-6 8v6l-4-2v-4z', p)}</Icon>,
  more: (p) => <Icon {...p}><circle cx="5" cy="12" r="1.5" fill={p?.color||'currentColor'}/><circle cx="12" cy="12" r="1.5" fill={p?.color||'currentColor'}/><circle cx="19" cy="12" r="1.5" fill={p?.color||'currentColor'}/></Icon>,
  sun: (p) => <Icon {...p}>{_stroke('M12 5V3M12 21v-2M5 12H3M21 12h-2M5.6 5.6L4.2 4.2M19.8 19.8l-1.4-1.4M5.6 18.4l-1.4 1.4M19.8 4.2l-1.4 1.4M12 17a5 5 0 1 0 0-10 5 5 0 0 0 0 10z', p)}</Icon>,
};

// ─── Phone frame (iPhone-14 bezel + iOS status bar) ──────────────
function PhoneFrame({ width = 390, height = 844, dark, statusFg, children, label }) {
  const bezel = '#0a0a0a';
  const { t } = useTheme() || { t: makeTheme(!!dark) };
  return (
    <div data-screen-label={label} style={{
      width: width + 16, height: height + 16, padding: 8, borderRadius: 52,
      background: bezel, position: 'relative',
      boxShadow: '0 30px 60px rgba(0,0,0,0.18), 0 0 0 1px rgba(0,0,0,0.18)',
      fontFamily: 'Inter, -apple-system, system-ui, sans-serif',
      WebkitFontSmoothing: 'antialiased', flexShrink: 0,
    }}>
      <div style={{
        width, height, borderRadius: 44, overflow: 'hidden',
        background: t.bg, position: 'relative',
      }}>
        {children}
        <StatusBar fg={statusFg || (dark ? '#fff' : '#0a0a0a')} />
        {/* Dynamic Island */}
        <div style={{
          position: 'absolute', top: 9, left: '50%', transform: 'translateX(-50%)',
          width: 116, height: 30, borderRadius: 24, background: '#000', zIndex: 91,
        }} />
        {/* Home indicator */}
        <div style={{
          position: 'absolute', left: 0, right: 0, bottom: 8,
          display: 'flex', justifyContent: 'center', pointerEvents: 'none', zIndex: 100,
        }}>
          <div style={{
            width: 134, height: 5, borderRadius: 4,
            background: dark ? 'rgba(255,255,255,0.55)' : 'rgba(0,0,0,0.32)',
          }} />
        </div>
      </div>
    </div>
  );
}

function StatusBar({ fg = '#0a0a0a' }) {
  return (
    <div style={{
      position: 'absolute', top: 0, left: 0, right: 0, height: 47,
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '0 28px', zIndex: 90, pointerEvents: 'none',
      fontFamily: '-apple-system, "SF Pro", system-ui',
    }}>
      <span style={{ fontSize: 15, fontWeight: 600, color: fg }}>9:41</span>
      <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
        <svg width="17" height="11" viewBox="0 0 17 11">
          <rect x="0" y="6" width="3" height="5" rx="0.5" fill={fg}/>
          <rect x="4.5" y="4" width="3" height="7" rx="0.5" fill={fg}/>
          <rect x="9" y="2" width="3" height="9" rx="0.5" fill={fg}/>
          <rect x="13.5" y="0" width="3" height="11" rx="0.5" fill={fg}/>
        </svg>
        <svg width="15" height="11" viewBox="0 0 17 11">
          <circle cx="8.5" cy="9" r="1.2" fill={fg}/>
          <path d="M8.5 2a8 8 0 0 1 5.7 2.4l1-1A9.5 9.5 0 0 0 8.5.5 9.5 9.5 0 0 0 1.8 3.4l1 1A8 8 0 0 1 8.5 2zM8.5 5.5a4.5 4.5 0 0 1 3.2 1.3l1-1A6 6 0 0 0 8.5 4a6 6 0 0 0-4.2 1.7l1 1a4.5 4.5 0 0 1 3.2-1.2z" fill={fg}/>
        </svg>
        <svg width="24" height="11" viewBox="0 0 24 11">
          <rect x="0.5" y="0.5" width="21" height="10" rx="2.5" fill="none" stroke={fg} strokeOpacity="0.4"/>
          <rect x="2" y="2" width="16" height="7" rx="1.5" fill={fg}/>
          <rect x="22.5" y="3.5" width="1.2" height="4" rx="0.4" fill={fg} fillOpacity="0.4"/>
        </svg>
      </div>
    </div>
  );
}

// ─── AppBar (Material 3 style — colored primary by default) ─────
function AppBar({
  title, subtitle, leading, actions, color, onBack,
  syncStatus, // 'ok' | 'pending' | 'error' | undefined
  flat = false, // when true, no colored bg (transparent on bg)
}) {
  const { t } = useTheme();
  const bg = flat ? 'transparent' : (color || t.primary);
  const fg = flat ? t.ink : '#fff';
  const fgMuted = flat ? t.muted : 'rgba(255,255,255,0.78)';
  return (
    <div style={{
      background: bg, color: fg,
      paddingTop: 47, // status bar
      padding: '47px 4px 0',
      boxShadow: flat ? 'none' : '0 1px 0 rgba(0,0,0,0.04)',
    }}>
      <div style={{
        display: 'flex', alignItems: 'center', gap: 4, minHeight: 56, padding: '6px 8px',
      }}>
        {(onBack || leading) && (
          <button onClick={onBack} style={{
            border: 0, background: 'transparent', cursor: 'pointer',
            width: 40, height: 40, borderRadius: 99, color: fg,
            display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 0,
          }}>
            {leading || <I.back size={22} color={fg} stroke={2} />}
          </button>
        )}
        <div style={{ flex: 1, minWidth: 0, padding: onBack || leading ? 0 : '0 8px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{ fontSize: 17, fontWeight: 600, color: fg, letterSpacing: -0.1 }}>{title}</span>
            {syncStatus && <SyncDot status={syncStatus} fg={fg} />}
          </div>
          {subtitle && (
            <div style={{ fontSize: 11.5, color: fgMuted, marginTop: 1 }}>{subtitle}</div>
          )}
        </div>
        {actions && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 2 }}>{actions}</div>
        )}
      </div>
    </div>
  );
}

function AppBarAction({ icon, onClick, badge, color = '#fff', tooltip, label }) {
  const Ico = typeof icon === 'string' ? I[icon] : null;
  const themeCtx = useTheme();
  const d = themeCtx?.d;
  const sz = d && d.touchMin === 56 ? 48 : 40;
  const isz = d ? d.iconSize : 22;
  return (
    <button onClick={onClick} title={tooltip} aria-label={label || tooltip} style={{
      border: 0, background: 'transparent', cursor: 'pointer',
      width: sz, height: sz, borderRadius: 99, position: 'relative',
      display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 0,
      color,
    }}>
      {Ico ? <Ico size={isz} color={color} stroke={1.9} /> : icon}
      {badge && (
        <span style={{
          position: 'absolute', top: 6, right: 6,
          minWidth: 16, height: 16, padding: '0 4px',
          background: '#E24B4A', color: '#fff', fontSize: 9.5, fontWeight: 700,
          borderRadius: 99, display: 'flex', alignItems: 'center', justifyContent: 'center',
          border: `1.5px solid ${color === '#fff' ? '#0F8C66' : '#fff'}`,
        }}>{badge}</span>
      )}
    </button>
  );
}

function SyncDot({ status, fg = '#fff' }) {
  const color = { ok: '#52C77F', pending: '#FFC265', error: '#FF6B6A' }[status];
  return (
    <span style={{
      width: 8, height: 8, borderRadius: 99, background: color,
      boxShadow: '0 0 0 1.5px rgba(255,255,255,0.4)',
      flexShrink: 0, display: 'inline-block',
    }} />
  );
}

// ─── Bottom Nav (Material 3 NavigationBar — 5 tabs V3) ──────────
function BottomNav({ active, onChange }) {
  const { t, s } = useTheme();
  const tabs = [
    { id: 'accueil', label: s.tabAccueil, icon: 'home', color: t.primary },
    { id: 'cheptel', label: s.tabCheptel, icon: 'pets', color: t.primary },
    { id: 'repro', label: s.tabRepro, icon: 'heart', activeIcon: 'heartFill', color: t.accentRepro },
    { id: 'taches', label: s.tabTaches, icon: 'checklist', color: t.primary },
    { id: 'plus', label: s.tabPlus, icon: 'apps', color: t.primary },
  ];
  return (
    <div style={{
      position: 'absolute', bottom: 0, left: 0, right: 0,
      background: t.bgNav, borderTop: `0.5px solid ${t.border}`,
      paddingBottom: 22, zIndex: 50,
      boxShadow: '0 -3px 12px rgba(0,0,0,0.06)',
    }}>
      <div style={{ display: 'flex', height: 64 }}>
        {tabs.map(tab => {
          const isActive = tab.id === active;
          const iconKey = isActive && tab.activeIcon ? tab.activeIcon : tab.icon;
          const Ico = I[iconKey];
          const color = isActive ? tab.color : t.muted;
          return (
            <button key={tab.id} onClick={() => onChange?.(tab.id)} style={{
              flex: 1, border: 0, background: 'transparent', cursor: 'pointer',
              display: 'flex', flexDirection: 'column', alignItems: 'center',
              justifyContent: 'center', gap: 3, padding: 0,
              fontFamily: 'inherit',
            }}>
              {/* Active indicator pill */}
              <div style={{
                position: 'relative',
                width: 56, height: 28, borderRadius: 14,
                background: isActive ? tint(tab.color, 0.18) : 'transparent',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                transition: 'background 0.18s',
              }}>
                <Ico size={22} color={color} stroke={isActive ? 2 : 1.7} />
              </div>
              <span style={{
                fontSize: 10.5, fontWeight: isActive ? 700 : 500,
                color, letterSpacing: 0.1,
              }}>{tab.label}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
}

// ─── Card / Section ────────────────────────────────────────────
function Card({ children, style, pad = true, border, raised }) {
  const { t, d } = useTheme();
  return (
    <div style={{
      background: t.bgCard,
      borderRadius: d.radius,
      border: border === false ? 'none' : `0.5px solid ${t.border}`,
      boxShadow: raised ? t.shadow : 'none',
      padding: pad ? d.lg + 'px' : 0,
      ...style,
    }}>{children}</div>
  );
}

function SectionHeader({ label, action, style }) {
  const { t, d } = useTheme();
  return (
    <div style={{
      display: 'flex', alignItems: 'baseline', justifyContent: 'space-between',
      padding: `${d.md}px ${d.pageH}px ${d.sm}px`, ...style,
    }}>
      <span style={{
        fontSize: 11, fontWeight: 700, color: t.muted,
        textTransform: 'uppercase', letterSpacing: '0.08em',
      }}>{label}</span>
      {action}
    </div>
  );
}

// ─── Badge ─────────────────────────────────────────────────────
function Badge({ color, children, soft = true, icon }) {
  const { t, dark } = useTheme();
  const bg = soft ? tint(color, dark ? 0.22 : 0.12) : color;
  const fg = soft ? color : '#fff';
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 4,
      padding: '3px 9px', borderRadius: 99,
      background: bg, color: fg,
      fontSize: 10.5, fontWeight: 600, letterSpacing: 0.1, whiteSpace: 'nowrap',
    }}>
      {icon}{children}
    </span>
  );
}

// ─── KPI Card (CuKpiCard) — icon top-left + value + label + delta ─
function KpiCard({ label, value, icon, color, delta, deltaGood = true, onClick }) {
  const { t, d, dark } = useTheme();
  const Ico = typeof icon === 'string' ? I[icon] : null;
  const deltaIsPos = delta?.startsWith('+') || (delta && !delta.startsWith('-'));
  const isGood = deltaGood ? deltaIsPos : !deltaIsPos;
  const deltaColor = isGood ? t.success : t.danger;

  return (
    <div onClick={onClick} style={{
      background: t.bgCard, borderRadius: d.radius,
      border: dark ? 'none' : `0.5px solid ${t.border}`,
      boxShadow: dark ? 'none' : t.shadow,
      padding: d.lg, cursor: onClick ? 'pointer' : 'default',
      display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
      minHeight: 100,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{
          width: 32, height: 32, borderRadius: 8,
          background: tint(color, 0.14),
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          {Ico && <Ico size={16} color={color} stroke={1.9} />}
        </div>
        {delta && (
          <span style={{
            padding: '2px 6px', borderRadius: 99,
            background: tint(deltaColor, 0.14),
            color: deltaColor, fontSize: 11, fontWeight: 700,
          }}>{delta}</span>
        )}
      </div>
      <div style={{ marginTop: d.sm }}>
        <div style={{
          fontSize: 22, fontWeight: 800, color: t.ink, lineHeight: 1.05,
          fontFeatureSettings: '"tnum"',
        }}>{value}</div>
        <div style={{
          fontSize: 11, color: t.muted, marginTop: 2,
          overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
        }}>{label}</div>
      </div>
    </div>
  );
}

// ─── Mini KPI (Reproduction screen pattern: tinted count + label) ─
function MiniKpi({ label, count, color }) {
  const { t, d, dark } = useTheme();
  return (
    <div style={{
      padding: `${d.md}px`, borderRadius: d.radius,
      background: tint(color, dark ? 0.22 : 0.10),
      display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2,
    }}>
      <span style={{ fontSize: 22, fontWeight: 700, color, lineHeight: 1, fontFeatureSettings: '"tnum"' }}>{count}</span>
      <span style={{ fontSize: 11, color, fontWeight: 500, opacity: 0.85 }}>{label}</span>
    </div>
  );
}

// ─── Chip Filter ───────────────────────────────────────────────
function ChipFilter({ label, selected, color, onClick, count }) {
  const { t, dark } = useTheme();
  const c = color || t.primary;
  return (
    <button onClick={onClick} style={{
      border: 0, padding: '7px 12px', borderRadius: 99,
      background: selected ? c : (dark ? t.bgRaised : '#fff'),
      color: selected ? '#fff' : t.ink,
      fontSize: 12, fontWeight: 600, cursor: 'pointer',
      whiteSpace: 'nowrap', fontFamily: 'inherit',
      boxShadow: selected ? 'none' : `0 0 0 0.5px ${t.border}`,
      display: 'inline-flex', alignItems: 'center', gap: 5,
    }}>
      {label}
      {count != null && (
        <span style={{ opacity: 0.65, fontSize: 11 }}>· {count}</span>
      )}
    </button>
  );
}

// ─── Alert banner (CuAlertBanner) ──────────────────────────────
function AlertBanner({ message, level = 'warning', icon, actionLabel, onAction }) {
  const { t } = useTheme();
  const color = { warning: t.warning, danger: t.danger, info: t.info, success: t.success }[level] || t.warning;
  const Ico = typeof icon === 'string' ? I[icon] : null;
  return (
    <div style={{
      background: tint(color, 0.10),
      border: `0.5px solid ${tint(color, 0.35)}`,
      borderLeft: `3px solid ${color}`,
      borderRadius: 12, padding: '10px 12px',
      display: 'flex', alignItems: 'center', gap: 10,
    }}>
      {Ico && <Ico size={20} color={color} stroke={1.9} />}
      <span style={{ flex: 1, fontSize: 12.5, color: t.ink, fontWeight: 500, lineHeight: 1.35 }}>{message}</span>
      {actionLabel && (
        <button onClick={onAction} style={{
          border: 0, background: 'transparent', color, fontWeight: 700,
          fontSize: 12.5, cursor: 'pointer', padding: '4px 6px', fontFamily: 'inherit',
        }}>{actionLabel}</button>
      )}
    </div>
  );
}

// ─── Button ────────────────────────────────────────────────────
function Button({ kind = 'filled', color, children, icon, full, size = 'md', onClick, style, disabled, label, tooltip }) {
  const { t, d, gants } = useTheme();
  const c = color || t.primary;
  const styles = {
    filled: { background: c, color: '#fff', border: '0' },
    tonal: { background: tint(c, 0.16), color: c, border: '0' },
    outlined: { background: 'transparent', color: c, border: `1px solid ${t.border}` },
    text: { background: 'transparent', color: c, border: '0' },
  }[kind];
  // Mode gants : tailles ↑ systematiquement (min 56dp partout).
  const sizes = gants ? {
    sm: { padding: '12px 16px', fontSize: 14, minHeight: 48 },
    md: { padding: '16px 22px', fontSize: 16, minHeight: 56 },
    lg: { padding: '18px 26px', fontSize: 17, minHeight: 60 },
  }[size] : {
    sm: { padding: '8px 12px', fontSize: 12, minHeight: 36 },
    md: { padding: '12px 18px', fontSize: 14, minHeight: 48 },
    lg: { padding: '14px 22px', fontSize: 15, minHeight: 52 },
  }[size];
  return (
    <button onClick={onClick} disabled={disabled} title={tooltip} aria-label={label || tooltip} style={{
      ...styles, ...sizes, borderRadius: 12, fontWeight: 600,
      display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 8,
      width: full ? '100%' : 'auto',
      cursor: disabled ? 'not-allowed' : 'pointer', opacity: disabled ? 0.5 : 1,
      fontFamily: 'inherit', whiteSpace: 'nowrap', ...style,
    }}>
      {icon}{children}
    </button>
  );
}

// ─── SkeletonRow / SkeletonBlock — placeholders animated ──────────────
function SkeletonBlock({ width = '100%', height = 14, radius = 4, style }) {
  const { t } = useTheme();
  return (
    <div style={{
      width, height, borderRadius: radius,
      background: `linear-gradient(90deg, ${t.bgRaised} 25%, ${tint(t.muted, 0.08)} 50%, ${t.bgRaised} 75%)`,
      backgroundSize: '200% 100%',
      animation: 'cu-shimmer 1.4s ease-in-out infinite',
      ...style,
    }} />
  );
}

// Inject shimmer keyframes once.
if (typeof document !== 'undefined' && !document.getElementById('cu-shimmer-style')) {
  const s = document.createElement('style');
  s.id = 'cu-shimmer-style';
  s.textContent = '@keyframes cu-shimmer { 0%{background-position:200% 0} 100%{background-position:-200% 0} }';
  document.head.appendChild(s);
}

function SkeletonListRow() {
  const { t } = useTheme();
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12,
      padding: '12px 14px',
      background: t.bgCard, borderRadius: 12,
      border: `0.5px solid ${t.border}`,
    }}>
      <SkeletonBlock width={42} height={42} radius={8} />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 6 }}>
        <SkeletonBlock width={120} height={14} />
        <SkeletonBlock width={180} height={11} />
      </div>
      <SkeletonBlock width={56} height={22} radius={99} />
    </div>
  );
}

function SkeletonList({ count = 6 }) {
  return (
    <div style={{ padding: '0 16px', display: 'flex', flexDirection: 'column', gap: 8 }}>
      {Array.from({ length: count }).map((_, i) => <SkeletonListRow key={i} />)}
    </div>
  );
}

// ─── ErrorState (CuErrorState générique) ────────────────────────
function ErrorState({ title = 'Impossible de charger', message = 'Vérifie ta connexion ou réessaye.', onRetry, color }) {
  const { t } = useTheme();
  const c = color || t.danger;
  return (
    <div style={{ padding: '48px 32px', textAlign: 'center', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <div style={{
        width: 80, height: 80, borderRadius: '50%',
        background: tint(c, 0.10),
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        marginBottom: 16,
      }}>
        <I.warning size={40} color={c} stroke={1.8} />
      </div>
      <div style={{ fontSize: 16, fontWeight: 700, color: t.ink }}>{title}</div>
      <div style={{ fontSize: 12.5, color: t.muted, marginTop: 6, maxWidth: 280, lineHeight: 1.5 }}>{message}</div>
      {onRetry && (
        <div style={{ marginTop: 20 }}>
          <Button kind="filled" onClick={onRetry} icon={<I.cloudSync size={16} color="#fff" stroke={2} />}>
            Réessayer
          </Button>
        </div>
      )}
    </div>
  );
}

// ─── EmptyState (CuEmptyState générique) ────────────────────────
function EmptyState({ icon = 'pets', title, hint, actionLabel, onAction, color }) {
  const { t } = useTheme();
  const c = color || t.primary;
  const Ico = typeof icon === 'string' ? I[icon] : null;
  return (
    <div style={{ padding: '48px 32px', textAlign: 'center', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <div style={{
        width: 88, height: 88, borderRadius: '50%',
        background: tint(c, 0.10),
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        marginBottom: 18,
      }}>
        {Ico && <Ico size={44} color={c} stroke={1.5} />}
      </div>
      <div style={{ fontSize: 17, fontWeight: 700, color: t.ink }}>{title}</div>
      {hint && <div style={{ fontSize: 12.5, color: t.muted, marginTop: 6, maxWidth: 280, lineHeight: 1.5 }}>{hint}</div>}
      {actionLabel && onAction && (
        <div style={{ marginTop: 22 }}>
          <Button kind="filled" color={c} onClick={onAction} icon={<I.plus size={16} color="#fff" stroke={2.2} />}>
            {actionLabel}
          </Button>
        </div>
      )}
    </div>
  );
}

// ─── DraftBanner — brouillon restauré ────────────────────────────
function DraftBanner({ onRestore, onDismiss, label = "Un brouillon non sauvegardé a été récupéré." }) {
  const { t } = useTheme();
  return (
    <div style={{
      background: tint(t.info, 0.10),
      border: `0.5px solid ${tint(t.info, 0.35)}`,
      borderLeft: `3px solid ${t.info}`,
      borderRadius: 12, padding: '10px 12px',
      display: 'flex', alignItems: 'center', gap: 10,
    }}>
      <I.cloud size={18} color={t.info} stroke={1.9} />
      <span style={{ flex: 1, fontSize: 12.5, color: t.ink, fontWeight: 500 }}>{label}</span>
      <button onClick={onDismiss} style={{
        border: 0, background: 'transparent', color: t.muted, fontSize: 12,
        fontWeight: 600, cursor: 'pointer', padding: '4px 6px', fontFamily: 'inherit',
      }}>Ignorer</button>
      <button onClick={onRestore} style={{
        border: 0, background: t.info, color: '#fff', borderRadius: 8,
        padding: '6px 12px', fontSize: 12, fontWeight: 700,
        cursor: 'pointer', fontFamily: 'inherit',
      }}>Restaurer</button>
    </div>
  );
}

// ─── FAB (extended floating action button) ─────────────────────
function FAB({ icon, label, color, onClick, style, extended = true }) {
  const { t } = useTheme();
  const c = color || t.primary;
  const Ico = typeof icon === 'string' ? I[icon] : null;
  return (
    <button onClick={onClick} style={{
      position: 'absolute', right: 16, bottom: 88,
      background: c, color: '#fff', border: 0, cursor: 'pointer',
      borderRadius: extended ? 18 : 28,
      padding: extended ? '14px 18px' : 0,
      width: extended ? 'auto' : 56, height: extended ? 'auto' : 56,
      minHeight: 56,
      display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
      boxShadow: `0 6px 18px ${tint(c, 0.45)}`,
      fontFamily: 'inherit', fontSize: 14, fontWeight: 700,
      zIndex: 49, ...style,
    }}>
      {Ico && <Ico size={22} color="#fff" stroke={2.2} />}
      {extended && label}
    </button>
  );
}

// ─── Segmented (Material 3-ish) ────────────────────────────────
function Segmented({ options, value, onChange, color }) {
  const { t } = useTheme();
  const c = color || t.primary;
  return (
    <div style={{
      display: 'flex', background: 'transparent',
      borderRadius: 99, padding: 2,
      border: `1px solid ${t.border}`,
    }}>
      {options.map(opt => {
        const active = opt.value === value;
        return (
          <button key={opt.value} onClick={() => onChange?.(opt.value)} style={{
            flex: 1, border: 0,
            background: active ? tint(c, 0.16) : 'transparent',
            color: active ? c : t.muted,
            padding: '9px 6px', borderRadius: 99,
            fontWeight: 600, fontSize: 12,
            cursor: 'pointer', fontFamily: 'inherit',
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 5,
          }}>
            {active && <I.check size={14} color={c} stroke={2.4} />}
            {opt.label}
          </button>
        );
      })}
    </div>
  );
}

// ─── List row + Avatar + InfoRow ───────────────────────────────
function Avatar({ initials, bg, color = '#fff', size = 40, icon, square }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: square ? 8 : '50%',
      background: bg, color, fontWeight: 700,
      fontSize: size * 0.4,
      display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
    }}>
      {icon || initials}
    </div>
  );
}

function InfoRow({ label, value, valueColor, isLast }) {
  const { t } = useTheme();
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '12px 14px',
      borderBottom: isLast ? 'none' : `0.5px solid ${t.borderSoft}`,
      fontSize: 13,
    }}>
      <span style={{ color: t.muted }}>{label}</span>
      <span style={{ color: valueColor || t.ink, fontWeight: 500, textAlign: 'right' }}>{value}</span>
    </div>
  );
}

// ─── Charts ───────────────────────────────────────────────────
function BarChart({ data, color, max, height = 80, labels }) {
  const { t } = useTheme();
  const m = max || Math.max(...data) * 1.1;
  return (
    <div style={{ display: 'flex', alignItems: 'flex-end', gap: 6, height, padding: '0 2px' }}>
      {data.map((v, i) => {
        const ratio = v / m;
        return (
          <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, height: '100%' }}>
            <div style={{ flex: 1, width: '100%', display: 'flex', alignItems: 'flex-end' }}>
              <div style={{
                width: '100%', height: `${ratio * 100}%`,
                background: color || t.primary,
                opacity: 0.45 + ratio * 0.55, borderRadius: 4,
                minHeight: 3,
              }} />
            </div>
            {labels && <span style={{ fontSize: 9.5, color: t.muted, fontWeight: 500 }}>{labels[i]}</span>}
          </div>
        );
      })}
    </div>
  );
}

function LineChart({ data, color, height = 90, fill, highlight }) {
  const { t } = useTheme();
  const w = 280;
  const max = Math.max(...data) * 1.1 || 1;
  const min = 0;
  const pts = data.map((v, i) => {
    const x = (i / (data.length - 1)) * w;
    const y = height - ((v - min) / (max - min)) * (height - 12) - 6;
    return [x, y];
  });
  const path = pts.map(([x, y], i) => (i === 0 ? `M${x},${y}` : `L${x},${y}`)).join(' ');
  const area = `${path} L${w},${height} L0,${height} Z`;
  return (
    <svg viewBox={`0 0 ${w} ${height}`} width="100%" height={height} preserveAspectRatio="none">
      {fill && <path d={area} fill={color || t.primary} fillOpacity={0.14} />}
      <path d={path} fill="none" stroke={color || t.primary} strokeWidth={2.2} strokeLinecap="round" strokeLinejoin="round" />
      {pts.map(([x, y], i) => {
        const isLast = highlight && i === pts.length - 1;
        return (
          <circle key={i} cx={x} cy={y} r={isLast ? 5 : 2.4}
            fill={isLast ? color || t.primary : t.bgCard}
            stroke={color || t.primary} strokeWidth={isLast ? 0 : 2}
          />
        );
      })}
    </svg>
  );
}

function Donut({ values, colors, size = 120, thickness = 18, centerLabel, centerSub }) {
  const { t } = useTheme();
  const total = values.reduce((a, b) => a + b, 0);
  const r = (size - thickness) / 2;
  const c = 2 * Math.PI * r;
  let offset = 0;
  return (
    <div style={{ position: 'relative', width: size, height: size, flexShrink: 0 }}>
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ transform: 'rotate(-90deg)' }}>
        <circle cx={size/2} cy={size/2} r={r} fill="none" stroke={t.bgRaised} strokeWidth={thickness}/>
        {values.map((v, i) => {
          const len = (v / total) * c;
          const dashOff = -offset;
          offset += len;
          return (
            <circle key={i} cx={size/2} cy={size/2} r={r} fill="none"
              stroke={colors[i]} strokeWidth={thickness}
              strokeDasharray={`${len} ${c - len}`}
              strokeDashoffset={dashOff}
            />
          );
        })}
      </svg>
      <div style={{
        position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column',
        alignItems: 'center', justifyContent: 'center', textAlign: 'center',
      }}>
        <span style={{ fontSize: 22, fontWeight: 800, color: t.ink, lineHeight: 1, fontFeatureSettings: '"tnum"' }}>{centerLabel}</span>
        <span style={{ fontSize: 10.5, color: t.muted, marginTop: 3 }}>{centerSub}</span>
      </div>
    </div>
  );
}

function ProgressBar({ value, max, color, height = 8, rounded = true }) {
  const { t } = useTheme();
  const pct = Math.min(100, (value / max) * 100);
  return (
    <div style={{ height, background: t.bgRaised, borderRadius: rounded ? 99 : 4, overflow: 'hidden' }}>
      <div style={{ width: pct + '%', height: '100%', background: color || t.primary, borderRadius: rounded ? 99 : 4 }} />
    </div>
  );
}

// ─── StreakBanner (dashboard + routine pattern) ────────────────
function StreakBanner({ streak, record, level, levelTitle, levelIcon, onTap }) {
  const { t, s } = useTheme();
  return (
    <div onClick={onTap} style={{
      background: `linear-gradient(135deg, ${t.primary} 0%, ${tint(t.primary, 0.7)} 100%)`,
      borderRadius: 16, padding: 16, color: '#fff',
      boxShadow: `0 6px 16px ${tint(t.primary, 0.35)}`,
      display: 'flex', alignItems: 'center', gap: 12, cursor: onTap ? 'pointer' : 'default',
    }}>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
          <span style={{ fontSize: 24 }}>🔥</span>
          <span style={{ fontSize: 26, fontWeight: 800, lineHeight: 1, fontFeatureSettings: '"tnum"' }}>{streak}</span>
          <span style={{ fontSize: 15, fontWeight: 600 }}>{s.jours}{streak > 1 ? 's' : ''}</span>
        </div>
        {record != null && (
          <div style={{ fontSize: 11.5, opacity: 0.78, marginTop: 3 }}>
            {s.record} · {record} {s.jours}{record > 1 ? 's' : ''}
          </div>
        )}
      </div>
      <div style={{
        padding: '10px 14px', borderRadius: 12,
        background: 'rgba(255,255,255,0.2)',
        display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 1,
      }}>
        <span style={{ fontSize: 22, lineHeight: 1 }}>{levelIcon || '🌱'}</span>
        <span style={{ fontSize: 11, fontWeight: 700 }}>{s.niveau} {level || 1}</span>
        {levelTitle && <span style={{ fontSize: 9, opacity: 0.85 }}>{levelTitle}</span>}
      </div>
    </div>
  );
}

// ─── Lapin tile (cheptel list row) ─────────────────────────────
function LapinTile({ name, code, race, sexe, weight, age, statut, lotKind, onTap }) {
  const { t, s } = useTheme();
  const statutMeta = {
    actif: { color: t.statutActif, label: s.actif },
    vendu: { color: t.statutVendu, label: s.vendu },
    mort: { color: t.statutMort, label: s.mort },
    sevrage: { color: t.statutSevrage, label: 'Sevrage' },
    quarantaine: { color: t.statutQuarantaine, label: s.quarantaine },
  }[statut] || { color: t.muted, label: statut };
  return (
    <div onClick={onTap} style={{
      display: 'flex', alignItems: 'center', gap: 12,
      padding: '12px 14px',
      background: t.bgCard,
      borderRadius: 12,
      border: `0.5px solid ${t.border}`,
      cursor: onTap ? 'pointer' : 'default',
    }}>
      <Avatar
        bg={tint(statutMeta.color, 0.14)} color={statutMeta.color}
        size={42} square
        icon={<I.pets size={20} color={statutMeta.color} stroke={1.9} />}
      />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <span style={{ fontSize: 14, fontWeight: 600, color: t.ink }}>{name}</span>
          <span style={{ fontSize: 11, color: t.muted }}>· {code}</span>
        </div>
        <div style={{ fontSize: 11.5, color: t.muted, marginTop: 2, display: 'flex', gap: 6 }}>
          <span>{sexe === 'F' ? '♀' : '♂'} {race}</span>
          {weight && <span>· {weight} kg</span>}
          {age && <span>· {age} {s.mois}</span>}
        </div>
      </div>
      <Badge color={statutMeta.color}>{statutMeta.label}</Badge>
    </div>
  );
}

Object.assign(window, {
  I, Icon, PhoneFrame, StatusBar,
  AppBar, AppBarAction, SyncDot, BottomNav,
  Card, SectionHeader,
  Badge, KpiCard, MiniKpi, ChipFilter, AlertBanner,
  Button, FAB, Segmented,
  Avatar, InfoRow, LapinTile,
  BarChart, LineChart, Donut, ProgressBar,
  StreakBanner,
  SkeletonBlock, SkeletonListRow, SkeletonList,
  ErrorState, EmptyState, DraftBanner,
});
