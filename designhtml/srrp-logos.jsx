// srrp-logos.jsx — Logo concepts for SRRP (Smart Renewable Resource Planner)
// Six mark directions, wordmarks, lockups, small-scale, and in-app context.

const SOLAR = '#F59E0B';
const SOLAR_HI = '#FBBF24';
const WIND = '#3B82F6';
const WIND_HI = '#60A5FA';
const HYDRO = '#06B6D4';
const HYDRO_HI = '#22D3EE';
const TEAL = '#14B8A6';
const TEAL_HI = '#2DD4BF';

// ============================================================
// MARK 01 — Aperture / Trefoil
// Three blade-petals (solar/wind/hydro) rotating around a teal hub.
// Reads as: turbine, sunburst, compass, aperture.
// ============================================================
const MarkAperture = ({ size = 96, mono = false, color = TEAL }) => {
  const colors = mono ? [color, color, color] : [SOLAR, WIND, HYDRO];
  const blade = "M0 -44 C 16 -32 18 -18 0 -10 C -18 -18 -16 -32 0 -44 Z";
  return (
    <svg viewBox="-50 -50 100 100" width={size} height={size} style={{ display: 'block' }}>
      <defs>
        {colors.map((c, i) => (
          <linearGradient key={i} id={`ap-g${i}-${size}-${mono ? 'm' : 'c'}`} x1="0" y1="-1" x2="0" y2="0.3">
            <stop offset="0" stopColor={c} stopOpacity="1"/>
            <stop offset="1" stopColor={c} stopOpacity="0.75"/>
          </linearGradient>
        ))}
      </defs>
      {[0, 120, 240].map((rot, i) => (
        <g key={i} transform={`rotate(${rot})`}>
          <path d={blade} fill={`url(#ap-g${i}-${size}-${mono ? 'm' : 'c'})`}/>
        </g>
      ))}
      <circle r="8" fill={mono ? color : TEAL}/>
      <circle r="3" fill="#fff" opacity="0.95"/>
    </svg>
  );
};

// ============================================================
// MARK 02 — Node
// Single teal hub with three diagonal stems ending in solar/wind/hydro dots.
// Reads as: power-grid node, network, a planning workspace.
// ============================================================
const MarkNode = ({ size = 96, mono = false, color = TEAL }) => {
  const a = mono ? color : SOLAR;
  const b = mono ? color : WIND;
  const c = mono ? color : HYDRO;
  return (
    <svg viewBox="-50 -50 100 100" width={size} height={size} style={{ display: 'block' }}>
      <g stroke={mono ? color : TEAL} strokeWidth="3.5" strokeLinecap="round" fill="none">
        <line x1="0" y1="0" x2="30" y2="-30"/>
        <line x1="0" y1="0" x2="-30" y2="-30"/>
        <line x1="0" y1="0" x2="0" y2="38"/>
      </g>
      <circle r="10" fill={mono ? color : TEAL}/>
      <circle r="4.5" fill="#0B0E14"/>
      <circle cx="30" cy="-30" r="7" fill={a}/>
      <circle cx="-30" cy="-30" r="7" fill={b}/>
      <circle cx="0" cy="38" r="7" fill={c}/>
    </svg>
  );
};

// ============================================================
// MARK 03 — Horizon Pin
// Map pin silhouette enclosing a horizon line + rising sun.
// Reads as: where renewable resources live on the map.
// ============================================================
const MarkPin = ({ size = 96, mono = false, color = TEAL }) => {
  return (
    <svg viewBox="0 0 100 100" width={size} height={size} style={{ display: 'block' }}>
      <defs>
        <clipPath id={`pin-clip-${size}-${mono ? 'm' : 'c'}`}>
          <path d="M50 6 C 27 6, 12 22, 12 44 C 12 70, 50 94, 50 94 C 50 94, 88 70, 88 44 C 88 22, 73 6, 50 6 Z"/>
        </clipPath>
      </defs>
      <g clipPath={`url(#pin-clip-${size}-${mono ? 'm' : 'c'})`}>
        <rect x="0" y="0" width="100" height="56" fill={mono ? 'rgba(255,255,255,0.06)' : 'rgba(245,158,11,0.10)'}/>
        <rect x="0" y="56" width="100" height="44" fill={mono ? 'rgba(255,255,255,0.10)' : 'rgba(6,182,212,0.10)'}/>
        {/* horizon */}
        <line x1="0" y1="56" x2="100" y2="56" stroke={mono ? color : SOLAR} strokeWidth="2.5"/>
        {/* sun */}
        <circle cx="50" cy="56" r="8" fill={mono ? color : SOLAR}/>
        {/* wind sweep */}
        <path d="M22 38 Q 36 32 50 38" stroke={mono ? color : WIND} strokeWidth="2.2" fill="none" strokeLinecap="round" opacity="0.9"/>
        <path d="M50 38 Q 64 32 78 38" stroke={mono ? color : WIND} strokeWidth="2.2" fill="none" strokeLinecap="round" opacity="0.9"/>
        {/* hydro waves */}
        <path d="M16 72 Q 28 66 40 72 T 64 72 T 88 72" stroke={mono ? color : HYDRO} strokeWidth="2.2" fill="none" strokeLinecap="round"/>
      </g>
      <path d="M50 6 C 27 6, 12 22, 12 44 C 12 70, 50 94, 50 94 C 50 94, 88 70, 88 44 C 88 22, 73 6, 50 6 Z"
            fill="none" stroke={mono ? color : TEAL} strokeWidth="3.5"/>
    </svg>
  );
};

// ============================================================
// MARK 04 — Topo Arcs
// Three nested sunrise arcs sitting on a horizon — atlas-like.
// Reads as: layered potential, contour map, planning depth.
// ============================================================
const MarkTopo = ({ size = 96, mono = false, color = TEAL }) => {
  const a = mono ? color : SOLAR;
  const b = mono ? color : WIND;
  const c = mono ? color : HYDRO;
  return (
    <svg viewBox="-50 -32 100 64" width={size} height={size * 0.64} style={{ display: 'block' }}>
      <path d="M -38 14 A 38 38 0 0 1 38 14" stroke={a} strokeWidth="4.5" fill="none" strokeLinecap="round"/>
      <path d="M -26 14 A 26 26 0 0 1 26 14" stroke={b} strokeWidth="4.5" fill="none" strokeLinecap="round"/>
      <path d="M -14 14 A 14 14 0 0 1 14 14" stroke={c} strokeWidth="4.5" fill="none" strokeLinecap="round"/>
      <line x1="-46" y1="14" x2="46" y2="14" stroke={mono ? color : TEAL} strokeWidth="2" strokeLinecap="round"/>
      <circle cx="0" cy="14" r="3.5" fill={mono ? color : TEAL}/>
    </svg>
  );
};

// ============================================================
// MARK 05 — Power S Monogram
// Bold geometric S formed from a continuous teal stroke, with a
// notched lightning cut — single-letter monogram.
// ============================================================
const MarkSBolt = ({ size = 96, mono = false, color = TEAL }) => {
  return (
    <svg viewBox="0 0 100 100" width={size} height={size} style={{ display: 'block' }}>
      <defs>
        <linearGradient id={`sb-${size}-${mono ? 'm' : 'c'}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={mono ? color : TEAL_HI}/>
          <stop offset="1" stopColor={mono ? color : TEAL}/>
        </linearGradient>
      </defs>
      {/* Outer rounded square frame */}
      <rect x="6" y="6" width="88" height="88" rx="22" fill="none" stroke={`url(#sb-${size}-${mono ? 'm' : 'c'})`} strokeWidth="3" opacity="0.35"/>
      {/* S path */}
      <path
        d="M 72 28 H 40 A 12 12 0 0 0 40 52 H 60 A 12 12 0 0 1 60 76 H 28"
        fill="none"
        stroke={`url(#sb-${size}-${mono ? 'm' : 'c'})`}
        strokeWidth="11"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      {/* accent dot — solar */}
      {!mono && <circle cx="72" cy="28" r="5" fill={SOLAR}/>}
    </svg>
  );
};

// ============================================================
// MARK 06 — Layered Diamond
// Three rotated squares stacked in solar/wind/hydro, forming a diamond
// "stack of plans". Brutalist, technical, scenario-planner vibe.
// ============================================================
const MarkStack = ({ size = 96, mono = false, color = TEAL }) => {
  const a = mono ? color : SOLAR;
  const b = mono ? color : WIND;
  const c = mono ? color : HYDRO;
  return (
    <svg viewBox="-50 -50 100 100" width={size} height={size} style={{ display: 'block' }}>
      <g transform="rotate(45)">
        <rect x="-38" y="-38" width="76" height="76" rx="6" fill="none" stroke={a} strokeWidth="3.5" opacity={mono ? 0.4 : 1}/>
        <rect x="-26" y="-26" width="52" height="52" rx="5" fill="none" stroke={b} strokeWidth="3.5" opacity={mono ? 0.7 : 1}/>
        <rect x="-14" y="-14" width="28" height="28" rx="4" fill={mono ? color : c} opacity={mono ? 1 : 0.9}/>
      </g>
    </svg>
  );
};

// ============================================================
// Wordmark — SRRP
// JetBrains Mono allcaps with a tracked-out, technical feel.
// One letter optionally swapped for a glyph.
// ============================================================
const Wordmark = ({ size = 36, color = '#fff', letterSpacing = 0.04, weight = 700, mono = true }) => (
  <div style={{
    font: `${weight} ${size}px/1 ${mono ? '"JetBrains Mono", ui-monospace, monospace' : '"Inter", system-ui, sans-serif'}`,
    color,
    letterSpacing: `${letterSpacing}em`,
    display: 'inline-block',
    fontFeatureSettings: '"ss01"'
  }}>SRRP</div>
);

const Tagline = ({ size = 11, color = 'rgba(255,255,255,0.5)' }) => (
  <div style={{
    font: `500 ${size}px/1 "Inter", system-ui, sans-serif`,
    color,
    letterSpacing: '0.18em',
    textTransform: 'uppercase'
  }}>Smart Renewable Resource Planner</div>
);

// ============================================================
// Helpers
// ============================================================
const MARKS = [
  { id: 'aperture', name: 'Aperture', Comp: MarkAperture, blurb: 'Üç enerji türü tek bir hub etrafında dönen kanatlar olarak. Türbin + güneş ışını + pusula okuması.' },
  { id: 'node',     name: 'Node',     Comp: MarkNode,     blurb: 'Üç renkli uç noktasıyla bir şebeke düğümü. Minimal, teknik, planlama aracı diline yakın.' },
  { id: 'pin',      name: 'Horizon Pin', Comp: MarkPin,   blurb: 'Harita pini içinde ufuk çizgisi + güneş + rüzgar + dalga. SRRP\'nin harita-merkezli karakterini yansıtır.' },
  { id: 'topo',     name: 'Topo',     Comp: MarkTopo,     blurb: 'Üç katmanlı yay — kontur haritası / gün doğumu. Atlas hissi, "Living Atlas" yönüyle akraba.' },
  { id: 'sbolt',    name: 'S-Mark',   Comp: MarkSBolt,    blurb: 'Tek harf monogram — yuvarlatılmış kare içinde sürekli S. Köşe ucundan bir solar nokta.' },
  { id: 'stack',    name: 'Stack',    Comp: MarkStack,    blurb: 'Eşmerkezli üç döndürülmüş kare — "katmanlı senaryo" metaforu. Sert, brutalist, mühendislik dili.' },
];

const ArtboardBase = ({ children, bg = '#1E232F', width, height, pad = 0 }) => (
  <div style={{ width, height, background: bg, padding: pad, display: 'grid', placeItems: 'center', position: 'relative' }}>
    {children}
  </div>
);

// ============================================================
// Card: Mark only on dark
// ============================================================
const MarkCardDark = ({ Comp, name, blurb }) => (
  <ArtboardBase width={340} height={340} bg="#161A24">
    <div style={{
      position: 'absolute', top: 16, left: 18, right: 18,
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      font: '600 10px/1 "JetBrains Mono", monospace', color: 'rgba(255,255,255,0.4)',
      letterSpacing: '0.14em', textTransform: 'uppercase'
    }}>
      <span>{name}</span>
      <span>· DARK</span>
    </div>
    <Comp size={140}/>
    <div style={{
      position: 'absolute', bottom: 16, left: 18, right: 18,
      font: '400 11px/1.45 "Inter", system-ui, sans-serif', color: 'rgba(255,255,255,0.45)',
    }}>{blurb}</div>
  </ArtboardBase>
);

const MarkCardLight = ({ Comp, name, blurb, mono = false, color }) => (
  <ArtboardBase width={340} height={340} bg="#F5F2ED">
    <div style={{
      position: 'absolute', top: 16, left: 18, right: 18,
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      font: '600 10px/1 "JetBrains Mono", monospace', color: 'rgba(0,0,0,0.35)',
      letterSpacing: '0.14em', textTransform: 'uppercase'
    }}>
      <span>{name}</span>
      <span>· {mono ? 'MONO' : 'LIGHT'}</span>
    </div>
    <Comp size={140} mono={mono} color={color || '#0B0E14'}/>
    <div style={{
      position: 'absolute', bottom: 16, left: 18, right: 18,
      font: '400 11px/1.45 "Inter", system-ui, sans-serif', color: 'rgba(0,0,0,0.5)',
    }}>{blurb}</div>
  </ArtboardBase>
);

// ============================================================
// Lockup card — mark + wordmark + tagline
// ============================================================
const LockupCard = ({ Comp, name, orientation = 'horizontal' }) => (
  <ArtboardBase width={560} height={240} bg="#1E232F">
    <div style={{
      position: 'absolute', top: 14, left: 18, right: 18,
      font: '600 10px/1 "JetBrains Mono", monospace', color: 'rgba(255,255,255,0.4)',
      letterSpacing: '0.14em', textTransform: 'uppercase'
    }}>{name} · LOCKUP · {orientation === 'horizontal' ? 'YATAY' : 'DİKEY'}</div>
    {orientation === 'horizontal' ? (
      <div style={{ display: 'flex', alignItems: 'center', gap: 22 }}>
        <Comp size={80}/>
        <div style={{ width: 1, height: 56, background: 'rgba(255,255,255,0.12)' }}/>
        <div>
          <Wordmark size={36}/>
          <div style={{ height: 8 }}/>
          <Tagline/>
        </div>
      </div>
    ) : (
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 16 }}>
        <Comp size={92}/>
        <Wordmark size={32}/>
        <Tagline size={10}/>
      </div>
    )}
  </ArtboardBase>
);

// ============================================================
// Favicon strip — mark at 16/24/32/48/64
// ============================================================
const FaviconStrip = ({ Comp, name }) => (
  <ArtboardBase width={520} height={180} bg="#161A24">
    <div style={{
      position: 'absolute', top: 14, left: 18, right: 18,
      font: '600 10px/1 "JetBrains Mono", monospace', color: 'rgba(255,255,255,0.4)',
      letterSpacing: '0.14em', textTransform: 'uppercase'
    }}>{name} · KÜÇÜK ÖLÇEKLER</div>
    <div style={{ display: 'flex', alignItems: 'flex-end', gap: 36 }}>
      {[16, 24, 32, 48, 64].map(s => (
        <div key={s} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10 }}>
          <Comp size={s}/>
          <div style={{ font: '500 10px/1 "JetBrains Mono", monospace', color: 'rgba(255,255,255,0.4)' }}>{s}px</div>
        </div>
      ))}
    </div>
  </ArtboardBase>
);

// ============================================================
// In-app context — top bar of the SRRP app
// ============================================================
const AppHeaderContext = ({ Comp, name }) => (
  <ArtboardBase width={900} height={220} bg="#0F1218">
    <div style={{
      position: 'absolute', top: 14, left: 18, right: 18,
      font: '600 10px/1 "JetBrains Mono", monospace', color: 'rgba(255,255,255,0.4)',
      letterSpacing: '0.14em', textTransform: 'uppercase'
    }}>{name} · UYGULAMA BAĞLAMI</div>

    {/* App top bar */}
    <div style={{
      position: 'absolute', top: 52, left: 0, right: 0, height: 56,
      background: '#1E232F', borderTop: '1px solid rgba(255,255,255,0.06)', borderBottom: '1px solid rgba(255,255,255,0.06)',
      display: 'flex', alignItems: 'center', padding: '0 20px', gap: 14
    }}>
      <Comp size={28}/>
      <Wordmark size={17}/>
      <div style={{ width: 1, height: 22, background: 'rgba(255,255,255,0.10)', marginLeft: 4 }}/>
      <div style={{ font: '500 12.5px/1 "Inter", system-ui', color: 'rgba(255,255,255,0.72)' }}>Türkiye 2030 Yenilenebilir</div>
      <div style={{ flex: 1 }}/>
      <div style={{
        font: '500 11.5px/1 "Inter", system-ui', color: 'rgba(255,255,255,0.5)',
        padding: '6px 10px', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 8
      }}>14 saha · 285 MW</div>
      <div style={{ width: 28, height: 28, borderRadius: '50%', background: 'linear-gradient(135deg,#2DD4BF,#0EA5A4)' }}/>
    </div>

    {/* Sidebar avatar context */}
    <div style={{
      position: 'absolute', bottom: 18, left: 20, right: 20,
      display: 'flex', alignItems: 'center', gap: 14,
      font: '400 11.5px/1.4 "Inter", system-ui', color: 'rgba(255,255,255,0.5)'
    }}>
      <Comp size={20}/>
      <span>Top-bar @ 28px · Sidebar avatar @ 20px · Login splash @ 96px+</span>
    </div>
  </ArtboardBase>
);

// ============================================================
// App entry
// ============================================================
const App = () => (
  <DesignCanvas
    title="SRRP — Logo Keşfi"
    subtitle="6 yön · marks → lockup → küçük ölçek → uygulama bağlamı. Beğendiğin yön(ler)i söyle, finale çekelim.">

    {/* 00 — Notes */}
    <DCSection id="notes" title="00 · Notlar">
      <DCArtboard id="note" label="Brief & yaklaşım" width={900} height={420}>
        <div style={{ width: 900, height: 420, padding: 44, background: '#11141C', color: '#E8EAEE', font: '400 14.5px/1.6 "Inter", system-ui', display: 'flex', flexDirection: 'column', gap: 18 }}>
          <div style={{ font: '700 28px/1.2 "Inter", system-ui', letterSpacing: '-0.02em' }}>SRRP için logo keşfi</div>
          <div style={{ color: '#9BA1AE', maxWidth: 760 }}>
            <b style={{ color: '#fff' }}>SRRP — Smart Renewable Resource Planner</b>. Üç enerji türü (güneş · rüzgar · hidro) üzerinde senaryo planlama ve harita-merkezli analiz aracı. Dark UI, teknik, mühendislik diline yakın.
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 18, marginTop: 6 }}>
            <div style={{ borderLeft: `3px solid ${TEAL}`, paddingLeft: 14 }}>
              <div style={{ font: '700 11px/1 "JetBrains Mono", monospace', color: TEAL, letterSpacing: 2, marginBottom: 6 }}>HEDEF</div>
              <div style={{ color: '#C9CDD6', fontSize: 13, lineHeight: 1.5 }}>Üç enerji türünü tek mark içinde yansıtmak; küçük ölçekte (16–24px) okunabilir kalmak; mevcut accent teal'a yaslanmak.</div>
            </div>
            <div style={{ borderLeft: `3px solid ${SOLAR}`, paddingLeft: 14 }}>
              <div style={{ font: '700 11px/1 "JetBrains Mono", monospace', color: SOLAR, letterSpacing: 2, marginBottom: 6 }}>RENK</div>
              <div style={{ color: '#C9CDD6', fontSize: 13, lineHeight: 1.5 }}>Solar #F59E0B · Wind #3B82F6 · Hydro #06B6D4 · Accent #14B8A6. Her mark hem renkli hem mono kullanıma uygun.</div>
            </div>
            <div style={{ borderLeft: `3px solid ${WIND}`, paddingLeft: 14 }}>
              <div style={{ font: '700 11px/1 "JetBrains Mono", monospace', color: WIND, letterSpacing: 2, marginBottom: 6 }}>TİP</div>
              <div style={{ color: '#C9CDD6', fontSize: 13, lineHeight: 1.5 }}>Wordmark: JetBrains Mono allcaps, 4% letter-spacing. Tagline: Inter caps, 18% tracking. Hep yan yana çalışır.</div>
            </div>
          </div>
          <div style={{ marginTop: 'auto', font: '400 12px/1.5 "Inter", system-ui', color: '#6B7280' }}>
            Her artboard'u çift tıklayarak fullscreen yapabilirsin. Beğendiklerini söyle — finale çekip vector + favicon set hazırlarım.
          </div>
        </div>
      </DCArtboard>
    </DCSection>

    {/* 01 — Marks on dark */}
    <DCSection id="marks-dark" title="01 · İşaretler · Dark">
      {MARKS.map(m => (
        <DCArtboard key={m.id} id={`md-${m.id}`} label={m.name} width={340} height={340}>
          <MarkCardDark Comp={m.Comp} name={m.name} blurb={m.blurb}/>
        </DCArtboard>
      ))}
    </DCSection>

    {/* 02 — Marks on light */}
    <DCSection id="marks-light" title="02 · İşaretler · Light + Mono">
      {MARKS.map(m => (
        <DCArtboard key={m.id} id={`ml-${m.id}`} label={`${m.name} · light`} width={340} height={340}>
          <MarkCardLight Comp={m.Comp} name={m.name} blurb={m.blurb}/>
        </DCArtboard>
      ))}
      {MARKS.map(m => (
        <DCArtboard key={`mono-${m.id}`} id={`mm-${m.id}`} label={`${m.name} · mono`} width={340} height={340}>
          <MarkCardLight Comp={m.Comp} name={m.name} blurb={m.blurb} mono color="#0B0E14"/>
        </DCArtboard>
      ))}
    </DCSection>

    {/* 03 — Lockups */}
    <DCSection id="lockups" title="03 · Lockup'lar (mark + wordmark + tagline)">
      {MARKS.map(m => (
        <DCArtboard key={m.id} id={`lh-${m.id}`} label={`${m.name} · yatay`} width={560} height={240}>
          <LockupCard Comp={m.Comp} name={m.name} orientation="horizontal"/>
        </DCArtboard>
      ))}
    </DCSection>

    {/* 04 — Small scale */}
    <DCSection id="small" title="04 · Küçük ölçek okunabilirlik">
      {MARKS.map(m => (
        <DCArtboard key={m.id} id={`fav-${m.id}`} label={`${m.name} · 16→64px`} width={520} height={180}>
          <FaviconStrip Comp={m.Comp} name={m.name}/>
        </DCArtboard>
      ))}
    </DCSection>

    {/* 05 — In app */}
    <DCSection id="context" title="05 · Uygulama içinde (top-bar + sidebar)">
      {MARKS.map(m => (
        <DCArtboard key={m.id} id={`ctx-${m.id}`} label={`${m.name} · top-bar`} width={900} height={220}>
          <AppHeaderContext Comp={m.Comp} name={m.name}/>
        </DCArtboard>
      ))}
    </DCSection>

    {/* 06 — Pure wordmark study */}
    <DCSection id="wordmark" title="06 · Yalnız wordmark çalışmaları">
      <DCArtboard id="wm-mono-dark" label="JetBrains Mono · dark" width={520} height={220}>
        <ArtboardBase width={520} height={220} bg="#1E232F">
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14 }}>
            <Wordmark size={64} mono letterSpacing={0.06}/>
            <Tagline/>
          </div>
        </ArtboardBase>
      </DCArtboard>
      <DCArtboard id="wm-inter-dark" label="Inter Black · dark" width={520} height={220}>
        <ArtboardBase width={520} height={220} bg="#1E232F">
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14 }}>
            <Wordmark size={64} mono={false} weight={800} letterSpacing={-0.02}/>
            <Tagline/>
          </div>
        </ArtboardBase>
      </DCArtboard>
      <DCArtboard id="wm-mono-light" label="JetBrains Mono · light" width={520} height={220}>
        <ArtboardBase width={520} height={220} bg="#F5F2ED">
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14 }}>
            <Wordmark size={64} mono letterSpacing={0.06} color="#0B0E14"/>
            <Tagline color="rgba(0,0,0,0.5)"/>
          </div>
        </ArtboardBase>
      </DCArtboard>
      <DCArtboard id="wm-colored" label="Renkli harf vurgu" width={520} height={220}>
        <ArtboardBase width={520} height={220} bg="#1E232F">
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14 }}>
            <div style={{ font: '700 64px/1 "JetBrains Mono", monospace', letterSpacing: '0.06em' }}>
              <span style={{ color: SOLAR }}>S</span>
              <span style={{ color: WIND }}>R</span>
              <span style={{ color: HYDRO }}>R</span>
              <span style={{ color: TEAL }}>P</span>
            </div>
            <Tagline/>
          </div>
        </ArtboardBase>
      </DCArtboard>
    </DCSection>

  </DesignCanvas>
);

ReactDOM.createRoot(document.getElementById('root')).render(<App/>);
