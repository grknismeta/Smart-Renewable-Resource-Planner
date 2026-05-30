// markers.jsx — 5 marker style variations placed on a map backdrop

const MarkerArtboard = ({ title, subtitle, children, width = 720, height = 460 }) => (
  <div style={{ position: 'relative', width, height, borderRadius: 14, overflow: 'hidden', border: '1px solid var(--border)' }}>
    <MapBackdrop />
    {/* Top label strip */}
    <div style={{ position: 'absolute', left: 14, top: 12, zIndex: 5 }}>
      <div style={{ font: '600 13px/1.2 var(--font)', color: 'var(--text)', letterSpacing: '-.01em' }}>{title}</div>
      <div style={{ font: '500 11.5px/1.4 var(--font)', color: 'var(--text-3)', marginTop: 3 }}>{subtitle}</div>
    </div>
    {/* tiny zoom widget for context */}
    <div style={{ position: 'absolute', right: 12, top: 12, zIndex: 5, display: 'flex', flexDirection: 'column', background: 'rgba(20,24,34,.85)', border: '1px solid var(--border)', borderRadius: 10, overflow: 'hidden' }}>
      <button style={{ background: 'transparent', border: 'none', color: 'var(--text-2)', padding: '6px 8px', borderBottom: '1px solid var(--border-2)', cursor: 'pointer' }}>+</button>
      <button style={{ background: 'transparent', border: 'none', color: 'var(--text-2)', padding: '6px 8px', cursor: 'pointer' }}>–</button>
    </div>
    {/* scale bar */}
    <div style={{ position: 'absolute', left: 14, bottom: 12, zIndex: 5, display: 'flex', alignItems: 'center', gap: 8 }}>
      <div style={{ width: 60, height: 3, background: 'rgba(255,255,255,.5)' }}/>
      <div style={{ font: '500 10px/1 var(--font-mono)', color: 'var(--text-3)' }}>50 km</div>
    </div>
    {children}
  </div>
);

// Position helper — % coords
const posMap = (pin, mode) => {
  // hand-tuned positions across 720x460 backdrop based on lat/lng
  const map = {
    1: { x: 0.50, y: 0.69 },  // Konya
    2: { x: 0.30, y: 0.40 },  // Bandırma
    3: { x: 0.86, y: 0.36 },  // Artvin
    4: { x: 0.45, y: 0.82 },  // Antalya
    5: { x: 0.18, y: 0.55 },  // İzmir
  };
  return map[pin.id] || { x: 0.5, y: 0.5 };
};

// ---- 1) Teardrop classic ----
const TeardropMarker = ({ pin, selected, onClick }) => {
  const c = TYPES[pin.type].color;
  return (
    <div onClick={onClick} style={{ position: 'relative', cursor: 'pointer', transform: selected ? 'scale(1.15)' : 'scale(1)', transformOrigin: 'bottom center', transition: 'transform .2s' }}>
      <svg width="28" height="40" viewBox="0 0 28 40">
        <defs>
          <filter id={`tdShadow-${pin.id}`} x="-50%" y="-50%" width="200%" height="200%">
            <feDropShadow dx="0" dy="2" stdDeviation="2" floodOpacity="0.5"/>
          </filter>
        </defs>
        <path filter={`url(#tdShadow-${pin.id})`} d="M 14 0 C 5 0, 0 7, 0 14 C 0 25, 14 40, 14 40 C 14 40, 28 25, 28 14 C 28 7, 23 0, 14 0 Z" fill={c} stroke="rgba(0,0,0,.4)" strokeWidth=".5"/>
        <circle cx="14" cy="14" r="6" fill="rgba(0,0,0,.25)"/>
      </svg>
      <div style={{ position: 'absolute', left: 14, top: 14, transform: 'translate(-50%, -50%)', color: 'white', display: 'flex' }}>
        <TypeIcon type={pin.type} size={11} color="white"/>
      </div>
    </div>
  );
};

// ---- 2) Chip / token with capacity ----
const ChipMarker = ({ pin, selected, onClick }) => {
  const c = TYPES[pin.type].color;
  return (
    <div onClick={onClick} style={{
      cursor: 'pointer',
      display: 'inline-flex', alignItems: 'center', gap: 6,
      padding: '5px 9px 5px 6px',
      background: 'rgba(20,24,34,.92)',
      backdropFilter: 'blur(8px)',
      border: `1.5px solid ${c}`,
      borderRadius: 999,
      boxShadow: selected ? `0 0 0 4px ${c}33, 0 6px 20px rgba(0,0,0,.5)` : '0 4px 12px rgba(0,0,0,.45)',
      transform: selected ? 'scale(1.08)' : 'scale(1)',
      transition: 'all .2s',
      whiteSpace: 'nowrap'
    }}>
      <div style={{ width: 18, height: 18, borderRadius: '50%', background: c, display: 'grid', placeItems: 'center' }}>
        <TypeIcon type={pin.type} size={11} color="rgba(0,0,0,.65)"/>
      </div>
      <span style={{ font: '700 11px/1 var(--font)', color: 'white', letterSpacing: '-.01em' }} className="tnum">{pin.capacityMw.toFixed(1)}</span>
      <span style={{ font: '500 9px/1 var(--font)', color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '.05em' }}>MW</span>
    </div>
  );
};

// ---- 3) Ring/Halo — capacity factor outer ring ----
const RingMarker = ({ pin, selected, onClick }) => {
  const c = TYPES[pin.type].color;
  // mock capacity factor
  const cf = pin.capacityFactor || (pin.type === 'solar' ? 0.22 : pin.type === 'wind' ? 0.34 : 0.55);
  const radius = 17;
  const circ = 2 * Math.PI * radius;
  const dash = circ * cf;
  return (
    <div onClick={onClick} style={{ position: 'relative', cursor: 'pointer', transform: selected ? 'scale(1.12)' : 'scale(1)', transition: 'transform .2s' }}>
      <svg width="44" height="44" viewBox="0 0 44 44">
        {/* outer track */}
        <circle cx="22" cy="22" r={radius} fill="none" stroke="rgba(255,255,255,.18)" strokeWidth="3"/>
        {/* progress */}
        <circle cx="22" cy="22" r={radius} fill="none" stroke={c} strokeWidth="3" strokeLinecap="round"
                strokeDasharray={`${dash} ${circ}`} transform="rotate(-90 22 22)"/>
        {/* inner disc */}
        <circle cx="22" cy="22" r="12" fill="rgba(20,24,34,.95)" stroke="rgba(255,255,255,.08)"/>
      </svg>
      <div style={{ position: 'absolute', inset: 0, display: 'grid', placeItems: 'center' }}>
        <TypeIcon type={pin.type} size={14} color={c}/>
      </div>
      {selected && (
        <div style={{ position: 'absolute', top: -22, left: '50%', transform: 'translateX(-50%)',
          font: '700 10px/1 var(--font-mono)', color: c, background: 'rgba(20,24,34,.92)',
          padding: '3px 6px', borderRadius: 4, border: `1px solid ${c}66`, whiteSpace: 'nowrap'
        }}>
          {(cf*100).toFixed(0)}% CF
        </div>
      )}
    </div>
  );
};

// ---- 4) 3D extruded — height by capacity ----
const ExtrudedMarker = ({ pin, selected, onClick }) => {
  const c = TYPES[pin.type].color;
  // map capacity to height
  const h = Math.min(70, 16 + pin.capacityMw * 1.1);
  return (
    <div onClick={onClick} style={{ position: 'relative', cursor: 'pointer', transformStyle: 'preserve-3d', transition: 'all .2s' }}>
      {/* base shadow */}
      <div style={{ position: 'absolute', left: '50%', bottom: -2, transform: 'translateX(-50%)', width: 30, height: 8, background: 'radial-gradient(ellipse at center, rgba(0,0,0,.7), transparent 70%)' }}/>
      {/* extrusion: pseudo-3D using gradient */}
      <div style={{
        width: 22, height: h,
        background: `linear-gradient(180deg, ${c} 0%, ${c} 60%, color-mix(in srgb, ${c} 60%, black) 100%)`,
        borderRadius: '6px 6px 2px 2px',
        boxShadow: selected ? `0 0 0 2px white, 0 0 30px ${c}` : `0 6px 20px ${c}55`,
        transform: 'skewY(-8deg)',
        position: 'relative',
        border: `1px solid color-mix(in srgb, ${c} 70%, white 10%)`
      }}>
        {/* top face */}
        <div style={{ position: 'absolute', top: -6, left: -1, right: -1, height: 8,
          background: `color-mix(in srgb, ${c} 80%, white 25%)`,
          borderRadius: '6px 6px 0 0',
          transform: 'skewX(-30deg) translateX(3px)',
          transformOrigin: 'bottom left',
          opacity: 0.9
        }}/>
        {/* icon on side */}
        <div style={{ position: 'absolute', top: 6, left: '50%', transform: 'translateX(-50%) skewY(8deg)' }}>
          <TypeIcon type={pin.type} size={11} color="rgba(0,0,0,.55)"/>
        </div>
      </div>
      {/* capacity label */}
      <div style={{ position: 'absolute', top: -16, left: '50%', transform: 'translateX(-50%)',
        font: '700 10px/1 var(--font-mono)', color: 'white', whiteSpace: 'nowrap',
        textShadow: '0 1px 2px rgba(0,0,0,.7)'
      }}>{pin.capacityMw.toFixed(1)}<span style={{ color: c, marginLeft: 2 }}>MW</span></div>
    </div>
  );
};

// ---- 5) Sparkline marker — weekly trend ----
const SparkMarker = ({ pin, selected, onClick }) => {
  const c = TYPES[pin.type].color;
  const weekly = (pin.monthly || [1,2,3,4,5,4,3]).slice(0, 7).map((m, i) => m * (0.8 + Math.sin(i)*0.15));
  return (
    <div onClick={onClick} style={{ cursor: 'pointer', transform: selected ? 'scale(1.06)' : 'scale(1)', transition: 'transform .2s' }}>
      <div style={{
        background: 'rgba(20,24,34,.92)',
        border: `1px solid ${c}88`,
        borderRadius: 10,
        padding: '5px 8px',
        boxShadow: selected ? `0 0 0 3px ${c}33, 0 8px 24px rgba(0,0,0,.5)` : '0 4px 14px rgba(0,0,0,.45)',
        backdropFilter: 'blur(8px)',
        display: 'flex', alignItems: 'center', gap: 7
      }}>
        <div style={{ width: 22, height: 22, borderRadius: 6, background: `${c}22`, display: 'grid', placeItems: 'center' }}>
          <TypeIcon type={pin.type} size={12} color={c}/>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}>
          <Sparkline data={weekly} color={c} width={48} height={14}/>
          <span style={{ font: '700 10px/1 var(--font-mono)', color: 'white' }}>{pin.capacityMw.toFixed(1)}MW</span>
        </div>
      </div>
      {/* anchor stem */}
      <div style={{ width: 2, height: 8, background: c, marginLeft: 14, opacity: 0.7 }}/>
      <div style={{ width: 6, height: 6, borderRadius: '50%', background: c, marginLeft: 12, marginTop: -3, boxShadow: `0 0 8px ${c}` }}/>
    </div>
  );
};

// ---- 6) Pulse dot (hover-reveal) ----
const PulseDot = ({ pin, selected, hovered, onClick, onHover }) => {
  const c = TYPES[pin.type].color;
  return (
    <div onClick={onClick} onMouseEnter={() => onHover?.(pin.id)} onMouseLeave={() => onHover?.(null)} style={{ position: 'relative', cursor: 'pointer' }}>
      {/* pulse ring */}
      {selected && (
        <div style={{
          position: 'absolute', left: '50%', top: '50%',
          width: 16, height: 16, transform: 'translate(-50%, -50%)',
          borderRadius: '50%', background: c,
          opacity: 0.4,
          animation: 'srrp-pulse 1.6s ease-out infinite',
        }}/>
      )}
      <div style={{
        width: 14, height: 14, borderRadius: '50%',
        background: c,
        border: '2px solid white',
        boxShadow: `0 0 0 1px rgba(0,0,0,.5), 0 4px 8px rgba(0,0,0,.5), 0 0 12px ${c}`,
        position: 'relative', zIndex: 2,
        transform: hovered || selected ? 'scale(1.3)' : 'scale(1)',
        transition: 'transform .2s'
      }}/>
      {hovered && (
        <div style={{
          position: 'absolute', left: 18, top: -8, zIndex: 10,
          background: 'rgba(20,24,34,.96)', backdropFilter: 'blur(10px)',
          border: '1px solid var(--border)', borderRadius: 10,
          padding: '8px 10px', minWidth: 160,
          boxShadow: '0 12px 32px rgba(0,0,0,.5)',
          font: '500 12px/1.4 var(--font)'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 4 }}>
            <TypeIcon type={pin.type} size={12} color={c}/>
            <span style={{ color: 'var(--text)', fontWeight: 600 }}>{pin.name}</span>
          </div>
          <div style={{ color: 'var(--text-3)', fontSize: 11 }}>{pin.district} / {pin.city}</div>
          <div style={{ display: 'flex', gap: 12, marginTop: 6 }}>
            <div><div style={{ color: 'var(--text-3)', fontSize: 9, textTransform: 'uppercase' }}>Kapasite</div><div style={{ color: 'white', fontWeight: 700 }}>{pin.capacityMw} <span style={{color: 'var(--text-3)', fontWeight: 500, fontSize: 10}}>MW</span></div></div>
            <div><div style={{ color: 'var(--text-3)', fontSize: 9, textTransform: 'uppercase' }}>Yıllık</div><div style={{ color: 'white', fontWeight: 700 }} className="tnum">{(pin.annualKwh/1e6).toFixed(1)}<span style={{color: 'var(--text-3)', fontWeight: 500, fontSize: 10}}> GWh</span></div></div>
          </div>
        </div>
      )}
    </div>
  );
};

// ---- The five marker artboards ----
const MarkerVariant = ({ MarkerCmp, title, subtitle, label }) => {
  const [selected, setSelected] = useState(2);
  const [hovered, setHovered] = useState(null);
  return (
    <MarkerArtboard title={title} subtitle={subtitle}>
      {/* Variant chip */}
      <div style={{ position: 'absolute', right: 60, top: 14, zIndex: 5, display: 'flex', alignItems: 'center', gap: 6, background: 'rgba(20,24,34,.85)', border: '1px solid var(--border)', borderRadius: 999, padding: '4px 10px' }}>
        <div style={{ width: 6, height: 6, borderRadius: '50%', background: 'var(--accent)' }}/>
        <span style={{ font: '600 10px/1 var(--font)', color: 'var(--text)', letterSpacing: '.04em', textTransform: 'uppercase' }}>{label}</span>
      </div>
      {/* legend */}
      <div style={{ position: 'absolute', right: 60, bottom: 12, zIndex: 5, display: 'flex', gap: 8, background: 'rgba(20,24,34,.85)', border: '1px solid var(--border)', borderRadius: 999, padding: '5px 10px' }}>
        {Object.values(TYPES).map(t => (
          <div key={t.id} style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
            <div style={{ width: 8, height: 8, borderRadius: '50%', background: t.color }}/>
            <span style={{ font: '500 10px/1 var(--font)', color: 'var(--text-2)' }}>{t.shortLabel}</span>
          </div>
        ))}
      </div>
      {SAMPLE_PINS.map(pin => {
        const p = posMap(pin);
        return (
          <div key={pin.id} style={{ position: 'absolute', left: `${p.x*100}%`, top: `${p.y*100}%`, transform: 'translate(-50%, -100%)', zIndex: hovered === pin.id ? 20 : (selected === pin.id ? 15 : 10) }}>
            <MarkerCmp pin={pin} selected={selected === pin.id} hovered={hovered === pin.id} onClick={() => setSelected(pin.id)} onHover={setHovered}/>
          </div>
        );
      })}
    </MarkerArtboard>
  );
};

const MarkerVariantTeardrop  = () => <MarkerVariant MarkerCmp={TeardropMarker} label="V1 · Klasik"  title="Teardrop · Klasik Pin"          subtitle="Tanıdık konum sembolü, ikon merkezde. En düşük öğrenme eğrisi."/>;
const MarkerVariantChip      = () => <MarkerVariant MarkerCmp={ChipMarker}     label="V2 · Bilgili" title="Chip · Kapasite Çipi"          subtitle="MW değeri marker üzerinde, harita üzerinde anında okunur."/>;
const MarkerVariantRing      = () => <MarkerVariant MarkerCmp={RingMarker}     label="V3 · Veri"    title="Ring · Halka + Kapasite Faktörü" subtitle="Dış halka kapasite faktörünü (üretim verimini) gösterir."/>;
const MarkerVariantExtruded  = () => <MarkerVariant MarkerCmp={ExtrudedMarker} label="V4 · 3D"      title="Extruded · 3D Kapasite Sütunu"  subtitle="Yükseklik = kurulu güç (MW). Bölgesel hacmi tek bakışta gösterir."/>;
const MarkerVariantSpark     = () => <MarkerVariant MarkerCmp={SparkMarker}    label="V5 · Trend"   title="Spark · Mini Üretim Trendi"     subtitle="Haftalık üretim sparkline'ı her marker üzerinde. Anomali tespiti kolay."/>;
const MarkerVariantPulse     = () => <MarkerVariant MarkerCmp={PulseDot}       label="V6 · Minimal" title="Pulse · Minimal Nokta + Hover"  subtitle="Sade nokta, hover'da zengin tooltip. Çok pin olduğunda en az gürültü."/>;

Object.assign(window, {
  MarkerVariantTeardrop, MarkerVariantChip, MarkerVariantRing,
  MarkerVariantExtruded, MarkerVariantSpark, MarkerVariantPulse
});
