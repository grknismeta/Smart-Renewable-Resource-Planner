// suitability.jsx — Kurulabilir alanlar overlay sistemi
// Vektör polygon overlay: choropleth + uygun yeşil + yasaklı kırmızı, single-tip mode

const { useState: useS, useMemo: useM, useRef: useR, useEffect: useE } = React;

// ============================================================================
// Suitability data — Türkiye il/ilçe + yasaklı/uygun polygon mock'ları
// ============================================================================

// Per-tip her bölgenin verim skoru (0-100). Gerçek backend province_analysis taklidi.
// Renkler choropleth fill için; daha yüksek = daha doygun yeşil
const PROVINCE_SCORES = {
  // [name, x, y, w, h, scoreSolar, scoreWind, scoreHydro]
  konya:    { name: 'Konya', cx: 540, cy: 395, scoreSolar: 92, scoreWind: 41, scoreHydro: 18 },
  ankara:   { name: 'Ankara', cx: 430, cy: 320, scoreSolar: 68, scoreWind: 52, scoreHydro: 30 },
  antalya:  { name: 'Antalya', cx: 360, cy: 410, scoreSolar: 88, scoreWind: 58, scoreHydro: 45 },
  izmir:    { name: 'İzmir', cx: 220, cy: 380, scoreSolar: 78, scoreWind: 86, scoreHydro: 25 },
  balikesir:{ name: 'Balıkesir', cx: 270, cy: 320, scoreSolar: 70, scoreWind: 89, scoreHydro: 32 },
  istanbul: { name: 'İstanbul', cx: 290, cy: 270, scoreSolar: 48, scoreWind: 71, scoreHydro: 28 },
  kayseri:  { name: 'Kayseri', cx: 600, cy: 350, scoreSolar: 81, scoreWind: 49, scoreHydro: 38 },
  sivas:    { name: 'Sivas', cx: 720, cy: 320, scoreSolar: 64, scoreWind: 56, scoreHydro: 52 },
  erzurum:  { name: 'Erzurum', cx: 800, cy: 380, scoreSolar: 56, scoreWind: 67, scoreHydro: 78 },
  artvin:   { name: 'Artvin', cx: 820, cy: 290, scoreSolar: 38, scoreWind: 42, scoreHydro: 95 },
  trabzon:  { name: 'Trabzon', cx: 760, cy: 280, scoreSolar: 32, scoreWind: 38, scoreHydro: 88 },
  adana:    { name: 'Adana', cx: 580, cy: 430, scoreSolar: 84, scoreWind: 48, scoreHydro: 42 },
  diyarbakir:{ name: 'Diyarbakır', cx: 760, cy: 420, scoreSolar: 86, scoreWind: 38, scoreHydro: 48 },
  samsun:   { name: 'Samsun', cx: 620, cy: 270, scoreSolar: 42, scoreWind: 58, scoreHydro: 56 },
  bursa:    { name: 'Bursa', cx: 320, cy: 290, scoreSolar: 58, scoreWind: 65, scoreHydro: 35 },
};

// Yasaklı bölgeler — kırmızı polygon overlay
const RESTRICTED_ZONES = [
  { id: 'r1', kind: 'Askeri Bölge', authority: 'Genelkurmay', d: 'M 380 290 L 460 285 L 470 320 L 395 330 Z', forTypes: ['solar','wind','hydro'] },
  { id: 'r2', kind: 'Milli Park', authority: 'Çevre Bakanlığı', d: 'M 600 285 C 640 280, 680 295, 690 320 C 685 345, 640 350, 605 340 C 590 320, 595 300, 600 285 Z', forTypes: ['solar','hydro'] },
  { id: 'r3', kind: 'Yerleşim Yeri', authority: 'Belediye', d: 'M 270 250 C 310 245, 320 270, 305 285 C 280 295, 260 285, 260 270 C 260 258, 265 252, 270 250 Z', forTypes: ['wind'] },
  { id: 'r4', kind: 'Su Havzası', authority: 'DSİ', d: 'M 760 415 C 790 410, 815 425, 810 445 C 800 460, 770 465, 745 450 C 740 435, 745 420, 760 415 Z', forTypes: ['solar'] },
  { id: 'r5', kind: 'Otoyol Koridor', authority: 'KGM', d: 'M 320 380 L 720 365 L 730 378 L 325 395 Z', forTypes: ['solar','hydro'], thin: true },
  { id: 'r6', kind: 'Orman', authority: 'Orman GM', d: 'M 700 270 C 740 260, 780 270, 790 290 C 785 305, 750 312, 720 305 C 700 295, 695 280, 700 270 Z', forTypes: ['solar'] },
];

// Uygun yeşil bölgeler — soft green overlay (ST_Buffer'lı suitability)
const SUITABLE_ZONES = {
  solar: [
    { d: 'M 480 380 L 580 375 L 595 420 L 490 425 Z' }, // Konya GES kuşağı
    { d: 'M 540 420 C 600 415, 660 430, 650 460 C 590 470, 530 460, 525 440 Z' },
    { d: 'M 760 410 L 830 405 L 835 445 L 770 450 Z' },
  ],
  wind: [
    { d: 'M 200 320 C 250 310, 290 320, 295 350 C 270 365, 220 360, 200 340 Z' }, // Çeşme/Balıkesir RES kuşağı
    { d: 'M 250 300 L 320 290 L 330 320 L 260 330 Z' },
    { d: 'M 800 370 C 840 365, 870 375, 870 395 C 840 405, 805 395, 800 380 Z' },
  ],
  hydro: [
    { d: 'M 760 280 L 830 285 L 840 320 L 770 325 Z' }, // Doğu Karadeniz
    { d: 'M 700 320 C 740 315, 780 325, 785 350 C 760 360, 720 355, 705 340 Z' },
  ],
};

// Akarsu çizgileri (HES için)
const RIVER_LINES = [
  { d: 'M 720 270 Q 750 290, 770 320 T 810 380', name: 'Çoruh' },
  { d: 'M 600 300 Q 640 330, 670 360 T 720 410', name: 'Kızılırmak' },
  { d: 'M 480 350 Q 520 380, 540 410 T 580 460', name: 'Sakarya' },
];

// HES aday noktaları (debi × düşü skoru en yüksek)
const HYDRO_CANDIDATES = [
  { x: 770, y: 305, score: 95, head: 145, flow: 32 },
  { x: 800, y: 340, score: 88, head: 110, flow: 28 },
  { x: 730, y: 280, score: 82, head: 95, flow: 24 },
  { x: 695, y: 365, score: 76, head: 78, flow: 19 },
  { x: 545, y: 425, score: 71, head: 65, flow: 16 },
];

// Skor → renk (RdYlGn-ish)
const scoreToColor = (score, alpha = 0.5) => {
  // 0 = red, 50 = yellow, 100 = green
  if (score < 50) {
    const t = score / 50;
    const r = 220, g = Math.round(60 + 160 * t), b = 60;
    return `rgba(${r},${g},${b},${alpha})`;
  } else {
    const t = (score - 50) / 50;
    const r = Math.round(220 - 180 * t), g = Math.round(220 - 40 * t), b = Math.round(60 + 40 * t);
    return `rgba(${r},${g},${b},${alpha})`;
  }
};

// ============================================================================
// SuitabilityOverlay — main map layer (SVG)
// ============================================================================
const SuitabilityOverlay = ({ activeType, threshold, showRestricted = true, showSuitable = true, showChoropleth = true, zoom = 'province' /* province | district | polygon */, mode = 'desktop' }) => {
  if (!activeType) return null;
  const scoreKey = `score${activeType[0].toUpperCase()}${activeType.slice(1)}`;

  return (
    <svg viewBox="0 0 1000 600" preserveAspectRatio="xMidYMid slice"
         style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', pointerEvents: 'none' }}>
      <defs>
        <pattern id="hatch-restrict" width="6" height="6" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">
          <line x1="0" y1="0" x2="0" y2="6" stroke="rgba(255,80,80,.55)" strokeWidth="2"/>
        </pattern>
        <radialGradient id="cand-glow" cx="50%" cy="50%" r="50%">
          <stop offset="0%" stopColor="#10B981" stopOpacity="0.7"/>
          <stop offset="60%" stopColor="#10B981" stopOpacity="0.2"/>
          <stop offset="100%" stopColor="#10B981" stopOpacity="0"/>
        </radialGradient>
      </defs>

      {/* LAYER 1: Choropleth (province scores) */}
      {showChoropleth && zoom === 'province' && Object.values(PROVINCE_SCORES).map(p => {
        const score = p[scoreKey];
        if (score < threshold) return null;
        // approximate province as ellipse, sized by score
        const r = 38 + score * 0.18;
        return (
          <g key={p.name}>
            <ellipse cx={p.cx} cy={p.cy} rx={r} ry={r * 0.62}
                     fill={scoreToColor(score, 0.32)} stroke={scoreToColor(score, 0.55)} strokeWidth="0.8"/>
          </g>
        );
      })}

      {/* LAYER 1b: District-level (when zoom = district) — denser, smaller cells */}
      {showChoropleth && zoom === 'district' && Object.values(PROVINCE_SCORES).map(p => {
        const baseScore = p[scoreKey];
        // simulate 6-12 districts per province with varying scores
        const districts = Array.from({length: 7}).map((_, i) => ({
          dx: p.cx + (Math.cos(i * 0.9) * 26),
          dy: p.cy + (Math.sin(i * 0.9) * 18),
          s: Math.max(0, Math.min(100, baseScore + (Math.sin(i * 2.3) * 18))),
        }));
        return districts.map((d, i) => {
          if (d.s < threshold) return null;
          return <ellipse key={`${p.name}-${i}`} cx={d.dx} cy={d.dy} rx="14" ry="10"
                          fill={scoreToColor(d.s, 0.34)} stroke={scoreToColor(d.s, 0.5)} strokeWidth="0.5"/>;
        });
      })}

      {/* LAYER 2: Suitable zones (soft green) */}
      {showSuitable && SUITABLE_ZONES[activeType]?.map((z, i) => (
        <path key={i} d={z.d} fill="rgba(16,185,129,.22)" stroke="rgba(16,185,129,.55)" strokeWidth="1.2" strokeDasharray="4 3"/>
      ))}

      {/* LAYER 2b: HES özel — akarsular + adaylar */}
      {activeType === 'hydro' && (
        <g>
          {RIVER_LINES.map((r, i) => (
            <g key={i}>
              <path d={r.d} fill="none" stroke="#06B6D4" strokeWidth="3" strokeOpacity="0.7" strokeLinecap="round"/>
              <path d={r.d} fill="none" stroke="#67E8F9" strokeWidth="1.2" strokeOpacity="0.95" strokeLinecap="round"/>
              {/* flow direction arrows */}
              {[0.25, 0.55, 0.85].map((t, j) => {
                // approximate point along path — use sample points
                const pts = r.d.match(/[\d.]+/g).map(Number);
                const x = pts[0] + (pts[pts.length - 2] - pts[0]) * t;
                const y = pts[1] + (pts[pts.length - 1] - pts[1]) * t;
                return <path key={j} d={`M ${x} ${y} l -5 -2 l 0 4 z`} fill="#67E8F9" opacity="0.9"/>;
              })}
            </g>
          ))}
          {HYDRO_CANDIDATES.filter(c => c.score >= threshold).map((c, i) => (
            <g key={i}>
              <circle cx={c.x} cy={c.y} r="22" fill="url(#cand-glow)"/>
              <circle cx={c.x} cy={c.y} r="6" fill="#10B981" stroke="white" strokeWidth="1.5"/>
              <text x={c.x} y={c.y + 1.5} textAnchor="middle" fill="white" fontSize="7" fontWeight="700" fontFamily="JetBrains Mono">{c.score}</text>
            </g>
          ))}
        </g>
      )}

      {/* LAYER 3: Restricted zones (red hatch + outline) */}
      {showRestricted && RESTRICTED_ZONES.filter(z => z.forTypes.includes(activeType)).map(z => (
        <g key={z.id}>
          <path d={z.d} fill="url(#hatch-restrict)" stroke="rgba(239,68,68,.85)" strokeWidth="1.2"/>
          <path d={z.d} fill="rgba(239,68,68,.10)" pointerEvents="all"/>
        </g>
      ))}
    </svg>
  );
};

// ============================================================================
// Suitability HUD — top-right control panel
// ============================================================================
const SuitabilityControls = ({ activeType, onTypeChange, threshold, onThreshold, layers, onLayer, timeSimOn = false, onTimeSim, compact = false, onClose }) => (
  <div style={{
    background: 'rgba(20,24,34,.96)', backdropFilter: 'blur(16px)',
    border: '1px solid var(--border)', borderRadius: 12,
    boxShadow: '0 12px 32px rgba(0,0,0,.45)',
    width: compact ? 240 : 280, padding: 14
  }}>
    {/* header */}
    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12 }}>
      <Icon name="layers" size={13} color="var(--accent)"/>
      <span style={{ font: '600 12px/1 var(--font)', color: 'var(--text)', textTransform: 'uppercase', letterSpacing: '.06em' }}>Kurulabilir Alanlar</span>
      {onClose && <button onClick={onClose} style={{ marginLeft: 'auto', background: 'transparent', border: 'none', cursor: 'pointer', padding: 2 }}><Icon name="x" size={12} color="var(--text-3)"/></button>}
    </div>

    {/* type selector */}
    <div style={{ marginBottom: 12 }}>
      <div className="label" style={{ marginBottom: 6 }}>Santral tipi</div>
      <div className="seg" style={{ width: '100%' }}>
        {Object.values(TYPES).map(t => (
          <button key={t.id} onClick={() => onTypeChange(t.id)}
                  className={activeType === t.id ? 'on' : ''}
                  style={{ flex: 1, color: activeType === t.id ? t.color : 'var(--text-3)', borderColor: activeType === t.id ? `${t.color}66` : undefined }}>
            <TypeIcon type={t.id} size={11} color={activeType === t.id ? t.color : 'var(--text-3)'}/>
            {t.shortLabel}
          </button>
        ))}
      </div>
    </div>

    {/* threshold slider */}
    <div style={{ marginBottom: 14 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
        <span className="label">Min. verim skoru</span>
        <span className="tnum" style={{ font: '700 13px/1 var(--font-mono)', color: scoreToColor(threshold, 1).replace('0.5','1') }}>{threshold}</span>
      </div>
      <div style={{ position: 'relative', height: 10 }}>
        {/* gradient track */}
        <div style={{ position: 'absolute', inset: 0, top: 3, height: 4, borderRadius: 2,
          background: 'linear-gradient(90deg, #DC2626 0%, #F59E0B 50%, #10B981 100%)', opacity: 0.5 }}/>
        {/* active portion (above threshold = bright) */}
        <div style={{ position: 'absolute', left: `${threshold}%`, right: 0, top: 3, height: 4, borderRadius: 2,
          background: 'linear-gradient(90deg, #F59E0B, #10B981)', opacity: 1 }}/>
        {/* knob */}
        <div style={{ position: 'absolute', left: `${threshold}%`, top: 0, transform: 'translateX(-50%)',
          width: 14, height: 14, borderRadius: '50%', background: 'white',
          boxShadow: '0 2px 6px rgba(0,0,0,.4), 0 0 0 2px ' + scoreToColor(threshold, 0.7) }}/>
        {/* hidden range */}
        <input type="range" min="0" max="100" step="5" value={threshold} onChange={e => onThreshold(+e.target.value)}
               style={{ position: 'absolute', inset: 0, opacity: 0, cursor: 'pointer', width: '100%', margin: 0 }}/>
      </div>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 6, font: '500 9.5px/1 var(--font)', color: 'var(--text-3)' }}>
        <span>0 · Düşük</span><span>50</span><span>100 · Yüksek</span>
      </div>
    </div>

    {/* layer toggles */}
    <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
      <div className="label" style={{ marginBottom: 2 }}>Katmanlar</div>
      {[
        { k: 'choropleth', l: 'Verim haritası', sw: 'rgba(16,185,129,.5)', icon: <div style={{ width: 12, height: 12, borderRadius: 3, background: 'linear-gradient(135deg, #10B981, #F59E0B, #DC2626)', opacity: 0.6 }}/> },
        { k: 'suitable',   l: 'Uygun bölgeler', sw: '#10B981', icon: <div style={{ width: 12, height: 12, borderRadius: 3, background: 'rgba(16,185,129,.3)', border: '1px dashed #10B981' }}/> },
        { k: 'restricted', l: 'Yasaklı bölgeler', sw: '#EF4444', icon: <div style={{ width: 12, height: 12, borderRadius: 3, background: 'repeating-linear-gradient(45deg, rgba(239,68,68,.6) 0 2px, transparent 2px 4px)' }}/> },
      ].map(o => (
        <label key={o.k} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 8px', borderRadius: 8, background: layers[o.k] ? 'rgba(255,255,255,.04)' : 'transparent', cursor: 'pointer' }}>
          {o.icon}
          <span style={{ flex: 1, font: '500 12px/1 var(--font)', color: layers[o.k] ? 'var(--text)' : 'var(--text-3)' }}>{o.l}</span>
          <div style={{ width: 26, height: 14, borderRadius: 8, background: layers[o.k] ? 'var(--accent)' : 'rgba(255,255,255,.12)', position: 'relative', transition: 'all .15s' }}>
            <div style={{ position: 'absolute', top: 1, left: layers[o.k] ? 13 : 1, width: 12, height: 12, borderRadius: '50%', background: 'white', transition: 'left .15s' }}/>
          </div>
          <input type="checkbox" checked={layers[o.k]} onChange={e => onLayer(o.k, e.target.checked)} style={{ display: 'none' }}/>
        </label>
      ))}
    </div>

    {/* ZAMAN SİMÜLASYONU — bottom-anchored map overlay toggle */}
    {onTimeSim && (
      <>
        <div style={{ height: 1, background: 'var(--border-2)', margin: '12px -2px 10px' }}/>
        <div className="label" style={{ marginBottom: 6 }}>Harita üzerinde</div>
        <button onClick={() => onTimeSim(!timeSimOn)}
          style={{
            width: '100%', textAlign: 'left',
            padding: '9px 10px', borderRadius: 9,
            background: timeSimOn ? 'rgba(20,184,166,.12)' : 'rgba(255,255,255,.04)',
            border: `1px solid ${timeSimOn ? 'rgba(20,184,166,.55)' : 'var(--border)'}`,
            display: 'flex', alignItems: 'center', gap: 9, cursor: 'pointer',
            transition: 'background .15s, border-color .15s'
          }}>
          <div style={{
            width: 28, height: 28, borderRadius: 7, flexShrink: 0,
            background: timeSimOn ? 'rgba(20,184,166,.20)' : 'rgba(255,255,255,.04)',
            border: `1px solid ${timeSimOn ? 'rgba(20,184,166,.45)' : 'var(--border)'}`,
            display: 'grid', placeItems: 'center'
          }}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={timeSimOn ? 'var(--accent)' : 'var(--text-2)'} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>
            </svg>
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ font: '600 12px/1.2 var(--font)', color: timeSimOn ? 'var(--text)' : 'var(--text-2)' }}>Zaman Simülasyonu</div>
            <div style={{ font: '500 10px/1.3 var(--font)', color: 'var(--text-3)', marginTop: 2 }}>Saat · Gün · Yıl üzerinde portföyü canlı izle</div>
          </div>
          <div style={{ width: 26, height: 14, borderRadius: 8, background: timeSimOn ? 'var(--accent)' : 'rgba(255,255,255,.12)', position: 'relative', transition: 'background .15s', flexShrink: 0 }}>
            <div style={{ position: 'absolute', top: 1, left: timeSimOn ? 13 : 1, width: 12, height: 12, borderRadius: '50%', background: 'white', transition: 'left .15s' }}/>
          </div>
        </button>
      </>
    )}
  </div>
);

// Compact mobile legend (sits above bottom sheet)
const MobileLegend = ({ activeType, threshold, onOpen }) => (
  <div onClick={onOpen} style={{
    background: 'rgba(20,24,34,.96)', backdropFilter: 'blur(16px)',
    border: '1px solid var(--border)', borderRadius: 12, padding: '8px 12px',
    boxShadow: '0 8px 20px rgba(0,0,0,.45)',
    display: 'flex', alignItems: 'center', gap: 10, cursor: 'pointer'
  }}>
    <TypeIcon type={activeType} size={14} color={TYPES[activeType].color}/>
    <span style={{ font: '600 11.5px/1 var(--font)', color: 'var(--text)' }}>{TYPES[activeType].shortLabel}</span>
    <div style={{ width: 1, height: 14, background: 'var(--border-2)' }}/>
    <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
      <span style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)' }}>Min</span>
      <span className="tnum" style={{ font: '700 11.5px/1 var(--font-mono)', color: scoreToColor(threshold, 1) }}>{threshold}</span>
    </div>
    <div style={{ flex: 1 }}/>
    <Icon name="chevU" size={11} color="var(--text-3)"/>
  </div>
);

// Restricted-zone tooltip
const RestrictedTooltip = ({ zone, x, y, type }) => (
  <div style={{
    position: 'absolute', left: x, top: y, transform: 'translate(-50%, calc(-100% - 12px))',
    background: 'rgba(20,24,34,.97)', backdropFilter: 'blur(14px)',
    border: '1px solid rgba(239,68,68,.55)', borderRadius: 10, padding: '10px 12px',
    width: 230, zIndex: 60, boxShadow: '0 16px 36px rgba(0,0,0,.5)'
  }}>
    <div style={{ position: 'absolute', left: '50%', bottom: -6, transform: 'translateX(-50%) rotate(45deg)', width: 10, height: 10, background: 'rgba(20,24,34,.97)', borderRight: '1px solid rgba(239,68,68,.55)', borderBottom: '1px solid rgba(239,68,68,.55)' }}/>
    <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 6 }}>
      <Icon name="warn" size={13} color="var(--danger)"/>
      <span style={{ font: '700 11px/1 var(--font)', color: 'var(--danger)', textTransform: 'uppercase', letterSpacing: '.06em' }}>Kurulamaz</span>
    </div>
    <div style={{ font: '600 13px/1.3 var(--font)', color: 'var(--text)' }}>{zone.kind}</div>
    <div style={{ font: '500 11px/1.4 var(--font)', color: 'var(--text-3)', marginTop: 4 }}>{TYPES[type].label} bu alana kurulamaz.</div>
    <div style={{ marginTop: 8, padding: '6px 8px', background: 'rgba(0,0,0,.30)', borderRadius: 6, font: '500 10.5px/1.3 var(--font)', color: 'var(--text-2)' }}>
      <span style={{ color: 'var(--text-3)' }}>Yetkili kurum:</span> {zone.authority}
    </div>
  </div>
);

Object.assign(window, {
  SuitabilityOverlay, SuitabilityControls, MobileLegend, RestrictedTooltip,
  RESTRICTED_ZONES, PROVINCE_SCORES, scoreToColor
});
