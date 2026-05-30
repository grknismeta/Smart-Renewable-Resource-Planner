// srrp-scene.jsx — SRRP scene-logo composition
// Single illustrative scene combining all four renewable elements:
//   sun (top-center) · solar panel (under sun) · wind turbine (left, rotating)
//   · HES concrete dam (right) · water waves (bottom)

const C = {
  sun: '#F59E0B',
  sunHi: '#FBBF24',
  panelDark: '#1E3A8A',
  panelMid: '#2563EB',
  panelGrid: '#60A5FA',
  panelFrame: '#3B82F6',
  panelStand: '#6B7280',
  turbine: '#E8ECF2',
  turbineDark: '#9CA3AF',
  dam: '#B8BFCC',
  damMid: '#8B93A5',
  damLines: '#5C6473',
  water: '#06B6D4',
  waterHi: '#22D3EE',
  teal: '#14B8A6',
};

// ============================================================
// SceneLogo — the central composition
// frame: 'none' | 'circle' | 'rounded' | 'hex' | 'shield'
// palette: 'color' | 'mono-teal' | 'mono-dark' | 'mono-light'
// ============================================================
const SceneLogo = ({
  size = 320,
  frame = 'none',
  palette = 'color',
  bg = 'transparent',
  animated = true,
  simplified = false,
  uid = Math.random().toString(36).slice(2, 8),
}) => {
  const W = 280, H = 240;
  const ratio = H / W;

  // palette resolution
  const isMono = palette !== 'color';
  const monoColor = palette === 'mono-light' ? '#F5F2ED' : palette === 'mono-dark' ? '#0B0E14' : C.teal;
  const col = (k) => isMono ? monoColor : C[k];

  // turbine center
  const TX = 52, TY = 102;
  // dam left edge
  const DX = 195;
  // panel center
  const PX = 140, PY = 155;

  const blade = (rot) => (
    <g transform={`rotate(${rot} ${TX} ${TY})`}>
      <path
        d={`M ${TX} ${TY} C ${TX + 2.6} ${TY - 12}, ${TX + 3.4} ${TY - 24}, ${TX + 1.8} ${TY - 36} L ${TX - 1.4} ${TY - 38} C ${TX - 2.8} ${TY - 24}, ${TX - 2} ${TY - 12}, ${TX} ${TY} Z`}
        fill={col('turbine')}
        stroke={isMono ? 'none' : 'rgba(0,0,0,0.15)'}
        strokeWidth="0.4"
      />
    </g>
  );

  const sunRays = [0, 45, 90, 135, 180, 225, 270, 315].map(deg => {
    const rad = (deg * Math.PI) / 180;
    return (
      <line
        key={deg}
        x1={140 + Math.cos(rad) * 30}
        y1={52 + Math.sin(rad) * 30}
        x2={140 + Math.cos(rad) * 39}
        y2={52 + Math.sin(rad) * 39}
        stroke={col('sun')}
        strokeWidth="3.2"
        strokeLinecap="round"
      />
    );
  });

  // frame path
  let framePath = null;
  let clipPath = null;
  const frameStroke = isMono ? monoColor : C.teal;
  if (frame === 'circle') {
    framePath = <circle cx={W/2} cy={H/2} r={H/2 - 4} fill={bg !== 'transparent' ? bg : 'none'} stroke={frameStroke} strokeWidth="3"/>;
    clipPath = <clipPath id={`clip-${uid}`}><circle cx={W/2} cy={H/2} r={H/2 - 4}/></clipPath>;
  } else if (frame === 'rounded') {
    framePath = <rect x="4" y="4" width={W-8} height={H-8} rx="32" ry="32" fill={bg !== 'transparent' ? bg : 'none'} stroke={frameStroke} strokeWidth="3"/>;
    clipPath = <clipPath id={`clip-${uid}`}><rect x="4" y="4" width={W-8} height={H-8} rx="32" ry="32"/></clipPath>;
  } else if (frame === 'hex') {
    const cx = W/2, cy = H/2, r = H/2 - 6;
    const pts = [0, 60, 120, 180, 240, 300].map(deg => {
      const rad = ((deg - 30) * Math.PI) / 180;
      return `${cx + Math.cos(rad) * r},${cy + Math.sin(rad) * r}`;
    }).join(' ');
    framePath = <polygon points={pts} fill={bg !== 'transparent' ? bg : 'none'} stroke={frameStroke} strokeWidth="3"/>;
    clipPath = <clipPath id={`clip-${uid}`}><polygon points={pts}/></clipPath>;
  } else if (frame === 'shield') {
    const path = `M ${W/2} 8 L ${W-20} 28 L ${W-20} ${H*0.55} Q ${W-20} ${H-20}, ${W/2} ${H-8} Q 20 ${H-20}, 20 ${H*0.55} L 20 28 Z`;
    framePath = <path d={path} fill={bg !== 'transparent' ? bg : 'none'} stroke={frameStroke} strokeWidth="3"/>;
    clipPath = <clipPath id={`clip-${uid}`}><path d={path}/></clipPath>;
  }

  const innerContent = (
    <g>
      {/* sun glow */}
      {!isMono && (
        <circle cx="140" cy="52" r="58" fill={`url(#sun-glow-${uid})`}/>
      )}

      {/* SUN */}
      <circle cx="140" cy="52" r="20" fill={col('sun')}/>
      {!isMono && <circle cx="140" cy="52" r="20" fill={`url(#sun-shade-${uid})`}/>}
      {sunRays}

      {/* WIND TURBINE - left */}
      {/* tower */}
      <path d={`M ${TX-2} ${TY} L ${TX+2} ${TY} L ${TX+5} 184 L ${TX-5} 184 Z`} fill={col('turbineDark')}/>
      {/* base pad */}
      <ellipse cx={TX} cy="184" rx="9" ry="2.5" fill={isMono ? monoColor : 'rgba(0,0,0,0.4)'} opacity={isMono ? 0.4 : 1}/>
      {/* blades — rotating */}
      <g>
        {animated && (
          <animateTransform
            attributeName="transform"
            type="rotate"
            from={`0 ${TX} ${TY}`}
            to={`360 ${TX} ${TY}`}
            dur="9s"
            repeatCount="indefinite"
          />
        )}
        {blade(0)}
        {blade(120)}
        {blade(240)}
      </g>
      {/* hub */}
      <circle cx={TX} cy={TY} r="4.5" fill={col('turbine')} stroke={isMono ? monoColor : 'rgba(0,0,0,0.2)'} strokeWidth="0.6"/>
      <circle cx={TX} cy={TY} r="1.8" fill={isMono ? 'rgba(0,0,0,0.3)' : 'rgba(0,0,0,0.4)'}/>

      {/* HES DAM - right */}
      <g>
        {/* dam body — arched top */}
        <path d={`M ${DX} 92 Q ${DX+27} 86, ${DX+55} 98 L ${DX+55} 184 L ${DX} 184 Z`} fill={col('dam')}/>
        {/* dam shading - subtle gradient feel */}
        {!isMono && (
          <path d={`M ${DX} 92 Q ${DX+27} 86, ${DX+55} 98 L ${DX+55} 184 L ${DX} 184 Z`} fill={`url(#dam-shade-${uid})`}/>
        )}
        {/* horizontal construction bands */}
        <line x1={DX+2} y1="110" x2={DX+54} y2="112" stroke={col('damLines')} strokeWidth="0.8" opacity="0.7"/>
        <line x1={DX+1} y1="132" x2={DX+55} y2="133" stroke={col('damLines')} strokeWidth="0.8" opacity="0.7"/>
        <line x1={DX} y1="156" x2={DX+55} y2="156" stroke={col('damLines')} strokeWidth="0.8" opacity="0.7"/>
        {/* spillway gates */}
        {[0, 1, 2].map(i => (
          <rect key={i} x={DX + 6 + i*15} y="113" width="9" height="16" fill={col('damLines')} opacity="0.55" rx="1"/>
        ))}
        {/* water cascade */}
        {[0, 1, 2].map(i => (
          <path
            key={i}
            d={`M ${DX + 10.5 + i*15} 129 Q ${DX + 9.5 + i*15} 155, ${DX + 11 + i*15} 180`}
            stroke={col('water')}
            strokeWidth="2"
            fill="none"
            strokeLinecap="round"
            opacity="0.75"
          />
        ))}
      </g>

      {/* SOLAR PANEL - center */}
      <g>
        {/* stand */}
        <line x1={PX} y1={PY+15} x2={PX-2} y2={PY+34} stroke={col('panelStand')} strokeWidth="2.5" strokeLinecap="round"/>
        <line x1={PX-7} y1={PY+34} x2={PX+5} y2={PY+34} stroke={col('panelStand')} strokeWidth="2.2" strokeLinecap="round"/>
        {/* panel in 3D perspective using a polygon (trapezoid) */}
        <g>
          <polygon
            points={`${PX-32},${PY-10} ${PX+34},${PY-14} ${PX+30},${PY+14} ${PX-30},${PY+12}`}
            fill={isMono ? monoColor : `url(#panel-grad-${uid})`}
            stroke={col('panelFrame')}
            strokeWidth="1.4"
            strokeLinejoin="round"
          />
          {/* grid - 3 columns (perspective-adjusted by simple lerp) */}
          {!simplified && [-0.6, -0.3, 0, 0.3, 0.6].map((t, i) => {
            const xTop = PX + t * 33;
            const xBot = PX + t * 30;
            const yTop = PY - 12 - t * 2;
            const yBot = PY + 13 - t * 1;
            return <line key={i} x1={xTop} y1={yTop} x2={xBot} y2={yBot} stroke={col('panelGrid')} strokeWidth="0.7" opacity="0.55"/>;
          })}
          {/* grid horizontal */}
          {!simplified && (
            <>
              <line x1={PX-31} y1={PY-2} x2={PX+32} y2={PY-4} stroke={col('panelGrid')} strokeWidth="0.7" opacity="0.55"/>
              <line x1={PX-30.5} y1={PY+6} x2={PX+31} y2={PY+5} stroke={col('panelGrid')} strokeWidth="0.7" opacity="0.55"/>
            </>
          )}
          {/* sun-catching highlight band */}
          {!isMono && (
            <polygon
              points={`${PX-32},${PY-10} ${PX+34},${PY-14} ${PX+33},${PY-11} ${PX-31.5},${PY-7}`}
              fill="white"
              opacity="0.35"
            />
          )}
        </g>
      </g>

      {/* WATER WAVES - bottom */}
      <g>
        {animated && (
          <animateTransform
            attributeName="transform"
            type="translate"
            values="0 0; -10 0; 0 0"
            dur="5s"
            repeatCount="indefinite"
          />
        )}
        {[195, 205, 215, 224].map((y, i) => (
          <path
            key={y}
            d={`M -30 ${y} Q -10 ${y-3}, 10 ${y} T 50 ${y} T 90 ${y} T 130 ${y} T 170 ${y} T 210 ${y} T 250 ${y} T 290 ${y} T 330 ${y}`}
            stroke={col('water')}
            strokeWidth={i < 2 ? 2 : 1.6}
            fill="none"
            strokeLinecap="round"
            opacity={[1, 0.72, 0.48, 0.28][i]}
          />
        ))}
      </g>
    </g>
  );

  return (
    <svg viewBox={`0 0 ${W} ${H}`} width={size} height={size * ratio} style={{ display: 'block', overflow: 'visible' }}>
      <defs>
        <radialGradient id={`sun-glow-${uid}`}>
          <stop offset="0" stopColor={C.sunHi} stopOpacity="0.55"/>
          <stop offset="0.5" stopColor={C.sun} stopOpacity="0.2"/>
          <stop offset="1" stopColor={C.sun} stopOpacity="0"/>
        </radialGradient>
        <radialGradient id={`sun-shade-${uid}`} cx="0.4" cy="0.35">
          <stop offset="0" stopColor="#FEF3C7" stopOpacity="0.55"/>
          <stop offset="1" stopColor={C.sun} stopOpacity="0"/>
        </radialGradient>
        <linearGradient id={`panel-grad-${uid}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={C.panelMid}/>
          <stop offset="1" stopColor={C.panelDark}/>
        </linearGradient>
        <linearGradient id={`dam-shade-${uid}`} x1="0" y1="0" x2="1" y2="0">
          <stop offset="0" stopColor="rgba(0,0,0,0)"/>
          <stop offset="1" stopColor="rgba(0,0,0,0.35)"/>
        </linearGradient>
        {clipPath}
      </defs>

      {framePath}
      {clipPath ? <g clipPath={`url(#clip-${uid})`}>{innerContent}</g> : innerContent}
    </svg>
  );
};

// ============================================================
// Wordmark
// ============================================================
const Wordmark = ({ size = 36, color = '#fff', spacing = 0.06, weight = 700, mono = true }) => (
  <div style={{
    font: `${weight} ${size}px/1 ${mono ? '"JetBrains Mono", ui-monospace, monospace' : '"Inter", system-ui, sans-serif'}`,
    color,
    letterSpacing: `${spacing}em`,
    display: 'inline-block',
  }}>SRRP</div>
);

const Tagline = ({ size = 11, color = 'rgba(255,255,255,0.55)' }) => (
  <div style={{
    font: `500 ${size}px/1 "Inter", system-ui, sans-serif`,
    color,
    letterSpacing: '0.18em',
    textTransform: 'uppercase'
  }}>Smart Renewable Resource Planner</div>
);

// ============================================================
// Cards
// ============================================================
const Pad = ({ children, w, h, bg = '#161A24', label, sub }) => (
  <div style={{ width: w, height: h, background: bg, display: 'grid', placeItems: 'center', position: 'relative', overflow: 'hidden' }}>
    {label && (
      <div style={{
        position: 'absolute', top: 14, left: 18, right: 18,
        display: 'flex', justifyContent: 'space-between',
        font: '600 10px/1 "JetBrains Mono", monospace',
        color: 'rgba(255,255,255,0.42)', letterSpacing: '0.14em', textTransform: 'uppercase'
      }}>
        <span>{label}</span>
        {sub && <span>· {sub}</span>}
      </div>
    )}
    {children}
  </div>
);

const PadLight = ({ children, w, h, label, sub }) => (
  <div style={{ width: w, height: h, background: '#F5F2ED', display: 'grid', placeItems: 'center', position: 'relative', overflow: 'hidden' }}>
    {label && (
      <div style={{
        position: 'absolute', top: 14, left: 18, right: 18,
        display: 'flex', justifyContent: 'space-between',
        font: '600 10px/1 "JetBrains Mono", monospace',
        color: 'rgba(0,0,0,0.4)', letterSpacing: '0.14em', textTransform: 'uppercase'
      }}>
        <span>{label}</span>
        {sub && <span>· {sub}</span>}
      </div>
    )}
    {children}
  </div>
);

// ============================================================
// App
// ============================================================
const App = () => (
  <DesignCanvas
    title="SRRP — Sahne Logosu"
    subtitle="Tek kompozisyon: güneş · panel · rüzgar gülü · HES · su. Önce tam gösterim, sonra çerçeveleme + ölçek varyantları.">

    {/* 00 — Hero — full display */}
    <DCSection id="hero" title="00 · Tam Gösterim">
      <DCArtboard id="hero-scene" label="Sahne · büyük gösterim · animasyonlu" width={760} height={580}>
        <Pad w={760} h={580} bg="#0F1218">
          <div style={{
            position: 'absolute', inset: 0,
            background: 'radial-gradient(ellipse 60% 50% at 50% 35%, rgba(245,158,11,0.08), transparent 60%), radial-gradient(ellipse 70% 60% at 50% 95%, rgba(6,182,212,0.08), transparent 60%)'
          }}/>
          <div style={{ position: 'relative' }}>
            <SceneLogo size={560} animated/>
          </div>
          <div style={{
            position: 'absolute', bottom: 22, left: 28, right: 28,
            display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end'
          }}>
            <div>
              <Wordmark size={22}/>
              <div style={{ height: 6 }}/>
              <Tagline size={9.5}/>
            </div>
            <div style={{ font: '500 10px/1.4 "JetBrains Mono", monospace', color: 'rgba(255,255,255,0.4)', textAlign: 'right', letterSpacing: '0.06em' }}>
              <div>SUN · WIND · SOLAR · HYDRO</div>
              <div style={{ marginTop: 4 }}>animated · 280×240 viewBox</div>
            </div>
          </div>
        </Pad>
      </DCArtboard>
    </DCSection>

    {/* 01 — Element callouts */}
    <DCSection id="callouts" title="01 · Element Sözlüğü">
      <DCArtboard id="callouts" label="Her elemanın rolü" width={760} height={420}>
        <Pad w={760} h={420} bg="#11141C">
          <SceneLogo size={360} animated/>
          {/* annotations */}
          {[
            { label: 'GÜNEŞ', sub: 'üst-orta · sıcaklık merkezi', color: C.sun, x: '50%', y: '15%', anchor: 'top' },
            { label: 'RÜZGAR GÜLÜ', sub: 'sol · dönen 3 kanat', color: C.turbine, x: '12%', y: '38%', anchor: 'left' },
            { label: 'GÜNEŞ PANELİ', sub: 'orta · 3D perspektif', color: C.panelFrame, x: '50%', y: '70%', anchor: 'right' },
            { label: 'HES', sub: 'sağ · beton baraj + savak', color: C.dam, x: '88%', y: '42%', anchor: 'right' },
            { label: 'SU', sub: 'taban · 4 katmanlı dalga', color: C.water, x: '50%', y: '90%', anchor: 'bottom' },
          ].map((a, i) => (
            <div key={i} style={{
              position: 'absolute', left: a.x, top: a.y, transform: 'translate(-50%, -50%)',
              padding: '5px 10px',
              border: `1px solid ${a.color}66`, borderRadius: 6,
              background: 'rgba(11,14,20,0.85)', backdropFilter: 'blur(4px)',
              font: '600 10px/1.3 "JetBrains Mono", monospace', color: '#fff', letterSpacing: '0.08em',
              whiteSpace: 'nowrap'
            }}>
              <div style={{ color: a.color }}>{a.label}</div>
              <div style={{ font: '400 9px/1.2 "Inter", system-ui', color: 'rgba(255,255,255,0.55)', letterSpacing: '0.04em', marginTop: 2 }}>{a.sub}</div>
            </div>
          ))}
        </Pad>
      </DCArtboard>
    </DCSection>

    {/* 02 — Frame variants */}
    <DCSection id="frames" title="02 · Çerçeveleme Varyantları">
      {[
        { id: 'none', label: 'Çerçevesiz', sub: 'serbest' },
        { id: 'circle', label: 'Daire', sub: 'rozet' },
        { id: 'rounded', label: 'Yuvarlatılmış kare', sub: 'app icon' },
        { id: 'hex', label: 'Altıgen', sub: 'teknik' },
        { id: 'shield', label: 'Kalkan', sub: 'kurumsal' },
      ].map(f => (
        <DCArtboard key={f.id} id={`frame-${f.id}`} label={f.label} width={340} height={340}>
          <Pad w={340} h={340} label={f.label} sub={f.sub}>
            <SceneLogo size={240} frame={f.id} animated/>
          </Pad>
        </DCArtboard>
      ))}
    </DCSection>

    {/* 03 — Palette variants */}
    <DCSection id="palette" title="03 · Renk Paletleri">
      <DCArtboard id="p-color" label="Tam renk" width={340} height={340}>
        <Pad w={340} h={340} label="Renkli" sub="varsayılan">
          <SceneLogo size={240} animated/>
        </Pad>
      </DCArtboard>
      <DCArtboard id="p-mono-teal" label="Mono · teal" width={340} height={340}>
        <Pad w={340} h={340} label="Mono Teal" sub="dark">
          <SceneLogo size={240} palette="mono-teal" animated/>
        </Pad>
      </DCArtboard>
      <DCArtboard id="p-mono-light" label="Mono · light" width={340} height={340}>
        <Pad w={340} h={340} label="Mono Light" sub="dark bg">
          <SceneLogo size={240} palette="mono-light" animated/>
        </Pad>
      </DCArtboard>
      <DCArtboard id="p-mono-dark" label="Mono · dark on light" width={340} height={340}>
        <PadLight w={340} h={340} label="Mono Dark" sub="light bg">
          <SceneLogo size={240} palette="mono-dark" animated/>
        </PadLight>
      </DCArtboard>
      <DCArtboard id="p-color-light" label="Renkli · light bg" width={340} height={340}>
        <PadLight w={340} h={340} label="Renkli" sub="light bg">
          <SceneLogo size={240} animated/>
        </PadLight>
      </DCArtboard>
      <DCArtboard id="p-circle-color" label="Renkli · daire · dolu" width={340} height={340}>
        <Pad w={340} h={340} label="Daire" sub="solid bg">
          <SceneLogo size={240} frame="circle" bg="#11141C" animated/>
        </Pad>
      </DCArtboard>
    </DCSection>

    {/* 04 — Lockups */}
    <DCSection id="lockups" title="04 · Lockup (mark + wordmark + tagline)">
      <DCArtboard id="lockup-h" label="Yatay · scene + SRRP" width={680} height={240}>
        <Pad w={680} h={240}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 28 }}>
            <SceneLogo size={150} animated/>
            <div style={{ width: 1, height: 70, background: 'rgba(255,255,255,0.12)' }}/>
            <div>
              <Wordmark size={44}/>
              <div style={{ height: 10 }}/>
              <Tagline size={11}/>
            </div>
          </div>
        </Pad>
      </DCArtboard>
      <DCArtboard id="lockup-v" label="Dikey · scene üstte" width={460} height={420}>
        <Pad w={460} h={420}>
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 22 }}>
            <SceneLogo size={220} animated/>
            <Wordmark size={36}/>
            <Tagline size={10.5}/>
          </div>
        </Pad>
      </DCArtboard>
      <DCArtboard id="lockup-circle" label="Yatay · daire rozet + SRRP" width={680} height={240}>
        <Pad w={680} h={240}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 28 }}>
            <SceneLogo size={150} frame="circle" bg="#11141C" animated/>
            <div style={{ width: 1, height: 70, background: 'rgba(255,255,255,0.12)' }}/>
            <div>
              <Wordmark size={44}/>
              <div style={{ height: 10 }}/>
              <Tagline size={11}/>
            </div>
          </div>
        </Pad>
      </DCArtboard>
      <DCArtboard id="lockup-rounded" label="Yatay · app-icon + SRRP" width={680} height={240}>
        <Pad w={680} h={240}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 28 }}>
            <SceneLogo size={150} frame="rounded" bg="#11141C" animated/>
            <div style={{ width: 1, height: 70, background: 'rgba(255,255,255,0.12)' }}/>
            <div>
              <Wordmark size={44}/>
              <div style={{ height: 10 }}/>
              <Tagline size={11}/>
            </div>
          </div>
        </Pad>
      </DCArtboard>
    </DCSection>

    {/* 05 — Scale extraction */}
    <DCSection id="scale" title="05 · Ölçek · Logoya İndirgeme">
      <DCArtboard id="scale-strip" label="64→160 — tam sahne küçükken nasıl?" width={760} height={260}>
        <Pad w={760} h={260} label="Çerçevesiz" sub="küçükte detay kaybı">
          <div style={{ display: 'flex', alignItems: 'flex-end', gap: 28 }}>
            {[160, 120, 96, 72, 64, 48].map(s => (
              <div key={s} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10 }}>
                <SceneLogo size={s} animated={false} simplified={s < 96}/>
                <div style={{ font: '500 10px/1 "JetBrains Mono", monospace', color: 'rgba(255,255,255,0.4)' }}>{s}px</div>
              </div>
            ))}
          </div>
        </Pad>
      </DCArtboard>
      <DCArtboard id="scale-circle" label="64→160 — daire çerçeve" width={760} height={260}>
        <Pad w={760} h={260} label="Daire" sub="rozet">
          <div style={{ display: 'flex', alignItems: 'flex-end', gap: 28 }}>
            {[160, 120, 96, 72, 64, 48].map(s => (
              <div key={s} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10 }}>
                <SceneLogo size={s} frame="circle" bg="#11141C" animated={false} simplified={s < 96}/>
                <div style={{ font: '500 10px/1 "JetBrains Mono", monospace', color: 'rgba(255,255,255,0.4)' }}>{s}px</div>
              </div>
            ))}
          </div>
        </Pad>
      </DCArtboard>
      <DCArtboard id="scale-rounded" label="64→160 — app icon (yuvarlatılmış)" width={760} height={260}>
        <Pad w={760} h={260} label="App Icon" sub="rounded">
          <div style={{ display: 'flex', alignItems: 'flex-end', gap: 28 }}>
            {[160, 120, 96, 72, 64, 48].map(s => (
              <div key={s} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10 }}>
                <SceneLogo size={s} frame="rounded" bg="#11141C" animated={false} simplified={s < 96}/>
                <div style={{ font: '500 10px/1 "JetBrains Mono", monospace', color: 'rgba(255,255,255,0.4)' }}>{s}px</div>
              </div>
            ))}
          </div>
        </Pad>
      </DCArtboard>
    </DCSection>

    {/* 06 — In context */}
    <DCSection id="context" title="06 · Uygulamada">
      <DCArtboard id="ctx-topbar" label="Uygulama top-bar'ı" width={920} height={140}>
        <Pad w={920} h={140} bg="#0F1218">
          <div style={{
            position: 'absolute', top: 40, left: 0, right: 0, height: 60,
            background: '#1E232F', borderTop: '1px solid rgba(255,255,255,0.06)', borderBottom: '1px solid rgba(255,255,255,0.06)',
            display: 'flex', alignItems: 'center', padding: '0 22px', gap: 14
          }}>
            <SceneLogo size={42} animated/>
            <Wordmark size={18}/>
            <div style={{ width: 1, height: 22, background: 'rgba(255,255,255,0.10)', marginLeft: 4 }}/>
            <div style={{ font: '500 12.5px/1 "Inter", system-ui', color: 'rgba(255,255,255,0.72)' }}>Türkiye 2030 Yenilenebilir</div>
            <div style={{ flex: 1 }}/>
            <div style={{
              font: '500 11.5px/1 "Inter", system-ui', color: 'rgba(255,255,255,0.5)',
              padding: '6px 10px', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 8
            }}>14 saha · 285 MW</div>
            <div style={{ width: 28, height: 28, borderRadius: '50%', background: 'linear-gradient(135deg,#2DD4BF,#0EA5A4)' }}/>
          </div>
        </Pad>
      </DCArtboard>
      <DCArtboard id="ctx-splash" label="Login / splash" width={460} height={460}>
        <Pad w={460} h={460} bg="#0F1218">
          <div style={{
            position: 'absolute', inset: 0,
            background: 'radial-gradient(ellipse 60% 50% at 50% 40%, rgba(245,158,11,0.10), transparent 60%), radial-gradient(ellipse 70% 60% at 50% 95%, rgba(6,182,212,0.10), transparent 60%)'
          }}/>
          <div style={{ position: 'relative', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 20 }}>
            <SceneLogo size={240} animated/>
            <Wordmark size={40}/>
            <Tagline size={11}/>
            <div style={{ height: 10 }}/>
            <button style={{
              padding: '11px 22px', borderRadius: 10, border: 'none',
              background: 'linear-gradient(180deg, #2DD4BF, #0EA5A4)',
              color: '#06201E', font: '600 13px/1 "Inter", system-ui', cursor: 'pointer'
            }}>Giriş yap</button>
          </div>
        </Pad>
      </DCArtboard>
      <DCArtboard id="ctx-favicon" label="Tarayıcı sekmesi" width={460} height={140}>
        <Pad w={460} h={140} bg="#2A2F3A">
          <div style={{
            position: 'absolute', top: 36, left: 30, right: 30, height: 32,
            background: '#1E232F', borderRadius: '10px 10px 0 0',
            display: 'flex', alignItems: 'center', padding: '0 12px', gap: 8,
            border: '1px solid rgba(255,255,255,0.06)'
          }}>
            <SceneLogo size={16} frame="rounded" bg="#0F1218" animated={false} simplified/>
            <span style={{ font: '500 12px/1 "Inter", system-ui', color: 'rgba(255,255,255,0.75)' }}>SRRP — Türkiye 2030 Yenilenebilir</span>
            <div style={{ flex: 1 }}/>
            <span style={{ font: '500 14px/1 "Inter", system-ui', color: 'rgba(255,255,255,0.4)' }}>×</span>
          </div>
          <div style={{
            position: 'absolute', bottom: 18, left: 30,
            font: '400 10px/1 "JetBrains Mono", monospace', color: 'rgba(255,255,255,0.45)'
          }}>favicon @ 16px · uses simplified mode</div>
        </Pad>
      </DCArtboard>
    </DCSection>

    {/* 07 — Notes */}
    <DCSection id="notes" title="07 · Not">
      <DCArtboard id="next" label="Sonraki adım" width={680} height={260}>
        <div style={{ width: 680, height: 260, padding: 32, background: '#11141C', color: '#E8EAEE', font: '400 14px/1.55 "Inter", system-ui' }}>
          <div style={{ font: '700 22px/1.2 "Inter", system-ui', letterSpacing: '-0.02em', marginBottom: 14 }}>Seçimini söyle, finale çekelim</div>
          <ul style={{ color: '#9BA1AE', margin: 0, paddingLeft: 18, lineHeight: 1.7 }}>
            <li>Hangi <b style={{ color: '#fff' }}>çerçeveleme</b>? (çerçevesiz / daire / yuvarlatılmış kare / altıgen / kalkan)</li>
            <li>Hangi <b style={{ color: '#fff' }}>palet</b>? (renkli / mono teal / mono light / mono dark)</li>
            <li><b style={{ color: '#fff' }}>Animasyon</b> kalsın mı (rüzgar gülü dönüyor + su akıyor) yoksa statik mi?</li>
            <li>Küçük ölçekte (16–32px) <b style={{ color: '#fff' }}>basitleştirilmiş</b> bir varyant otomatik ürettim — onu da kullanırız.</li>
          </ul>
          <div style={{ marginTop: 16, font: '500 11px/1.5 "JetBrains Mono", monospace', color: 'rgba(20,184,166,0.85)', letterSpacing: '0.04em' }}>
            → SEÇ: "Daire · renkli · animasyonlu" gibi yaz, finalize edelim.
          </div>
        </div>
      </DCArtboard>
    </DCSection>

  </DesignCanvas>
);

ReactDOM.createRoot(document.getElementById('root')).render(<App/>);
