// shared.jsx — icons, map background, common bits
const { useState, useEffect, useRef, useMemo } = React;

// ---- Resource type config ----
const TYPES = {
  solar: { id: 'solar', label: 'Güneş Paneli', shortLabel: 'Güneş', color: 'var(--solar)', glow: 'var(--solar-glow)', glowShadow: 'var(--glow-solar)' },
  wind:  { id: 'wind',  label: 'Rüzgar Türbini', shortLabel: 'Rüzgar', color: 'var(--wind)',  glow: 'var(--wind-glow)', glowShadow: 'var(--glow-wind)' },
  hydro: { id: 'hydro', label: 'Hidroelektrik', shortLabel: 'HES', color: 'var(--hydro)', glow: 'var(--hydro-glow)', glowShadow: 'var(--glow-hydro)' },
};

// ---- Icons (matched to Material visual weight in the existing app) ----
const Icon = ({ name, size = 16, color = 'currentColor', strokeWidth = 1.8 }) => {
  const props = { width: size, height: size, viewBox: '0 0 24 24', fill: 'none', stroke: color, strokeWidth, strokeLinecap: 'round', strokeLinejoin: 'round' };
  switch (name) {
    case 'sun':    return <svg {...props}><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"/></svg>;
    case 'wind':   return <svg {...props}><path d="M9.59 4.59A2 2 0 1 1 11 8H2"/><path d="M17.73 4.27A2.5 2.5 0 1 1 19.5 8.5H2"/><path d="M14.83 14.83A2 2 0 1 0 13.41 18H2"/></svg>;
    case 'water':  return <svg {...props}><path d="M12 2.5s6 7.5 6 12.5a6 6 0 0 1-12 0c0-5 6-12.5 6-12.5z"/></svg>;
    case 'pin':    return <svg {...props}><path d="M12 22s7-7.5 7-13a7 7 0 0 0-14 0c0 5.5 7 13 7 13z"/><circle cx="12" cy="9" r="2.5"/></svg>;
    case 'plus':   return <svg {...props}><path d="M12 5v14M5 12h14"/></svg>;
    case 'check':  return <svg {...props}><path d="M20 6L9 17l-5-5"/></svg>;
    case 'x':      return <svg {...props}><path d="M18 6 6 18M6 6l12 12"/></svg>;
    case 'edit':   return <svg {...props}><path d="M12 20h9"/><path d="M16.5 3.5a2.121 2.121 0 1 1 3 3L7 19l-4 1 1-4z"/></svg>;
    case 'trash':  return <svg {...props}><path d="M3 6h18M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6M10 11v6M14 11v6"/></svg>;
    case 'chevR':  return <svg {...props}><path d="M9 18l6-6-6-6"/></svg>;
    case 'chevL':  return <svg {...props}><path d="M15 18l-6-6 6-6"/></svg>;
    case 'chevD':  return <svg {...props}><path d="M6 9l6 6 6-6"/></svg>;
    case 'chevU':  return <svg {...props}><path d="M18 15l-6-6-6 6"/></svg>;
    case 'arrowR': return <svg {...props}><path d="M5 12h14M13 5l7 7-7 7"/></svg>;
    case 'search': return <svg {...props}><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg>;
    case 'layers': return <svg {...props}><path d="M12 2 2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/></svg>;
    case 'info':   return <svg {...props}><circle cx="12" cy="12" r="10"/><path d="M12 16v-4M12 8h.01"/></svg>;
    case 'check2': return <svg {...props}><circle cx="12" cy="12" r="10"/><path d="M8 12l3 3 5-6"/></svg>;
    case 'warn':   return <svg {...props}><path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><path d="M12 9v4M12 17h.01"/></svg>;
    case 'gear':   return <svg {...props}><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09a1.65 1.65 0 0 0-1-1.51 1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09a1.65 1.65 0 0 0 1.51-1 1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33h0a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51h0a1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82v0a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>;
    case 'mw':     return <svg {...props}><path d="M13 2 3 14h7l-1 8 10-12h-7l1-8z"/></svg>;
    case 'roi':    return <svg {...props}><path d="M3 3v18h18"/><path d="M7 14l4-4 4 4 5-5"/></svg>;
    case 'cal':    return <svg {...props}><rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><path d="M16 2v4M8 2v4M3 10h18"/></svg>;
    case 'temp':   return <svg {...props}><path d="M14 14.76V3.5a2.5 2.5 0 1 0-5 0v11.26a4 4 0 1 0 5 0z"/></svg>;
    case 'eq':     return <svg {...props}><rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18M9 21V9"/></svg>;
    case 'ext':    return <svg {...props}><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><path d="M15 3h6v6M10 14L21 3"/></svg>;
    case 'drag':   return <svg {...props}><circle cx="9" cy="6" r="1.4"/><circle cx="9" cy="12" r="1.4"/><circle cx="9" cy="18" r="1.4"/><circle cx="15" cy="6" r="1.4"/><circle cx="15" cy="12" r="1.4"/><circle cx="15" cy="18" r="1.4"/></svg>;
    case 'eye':    return <svg {...props}><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>;
    case 'play':   return <svg {...props}><polygon points="5 3 19 12 5 21 5 3"/></svg>;
    case 'list':   return <svg {...props}><path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"/></svg>;
    case 'grid':   return <svg {...props}><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/></svg>;
    case 'filter': return <svg {...props}><polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3"/></svg>;
    case 'globe':  return <svg {...props}><circle cx="12" cy="12" r="10"/><path d="M2 12h20M12 2a15.3 15.3 0 0 1 0 20M12 2a15.3 15.3 0 0 0 0 20"/></svg>;
    case 'spark':  return <svg {...props}><path d="M12 2v4M12 18v4M5 12H1M23 12h-4M6 6l-3-3M21 21l-3-3M6 18l-3 3M21 3l-3 3"/></svg>;
    case 'finance':return <svg {...props}><path d="M12 1v22M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>;
    case 'panel':  return <svg {...props}><rect x="2" y="4" width="20" height="14" rx="1"/><path d="M2 10h20M2 16h20M9 4v14M15 4v14"/></svg>;
    default: return null;
  }
};

const TypeIcon = ({ type, size = 16, color }) => {
  const map = { solar: 'sun', wind: 'wind', hydro: 'water' };
  return <Icon name={map[type] || 'pin'} size={size} color={color || TYPES[type]?.color} />;
};

// ---- Map background ----
// vector-style faux Türkiye coastline + city dots, just for context
const MapBackdrop = ({ children, simulatedZoom = 6, showGrid = true }) => {
  return (
    <div className="map-bg" style={{ position: 'absolute', inset: 0 }}>
      {/* abstract turkey-ish landmass */}
      <svg viewBox="0 0 1000 600" preserveAspectRatio="xMidYMid slice" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', opacity: 0.55 }}>
        <defs>
          <linearGradient id="land" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0" stopColor="#1d2532"/>
            <stop offset="1" stopColor="#161B26"/>
          </linearGradient>
        </defs>
        {/* coast outline */}
        <path d="M40 280 C 80 220, 160 200, 230 220 C 300 200, 380 230, 470 210 C 560 200, 640 220, 730 200 C 820 200, 900 230, 970 270 C 990 320, 950 360, 880 380 C 800 410, 700 410, 600 400 C 500 410, 400 400, 320 410 C 240 405, 160 390, 90 360 C 50 340, 30 310, 40 280 Z" fill="url(#land)" stroke="rgba(255,255,255,.08)" strokeWidth="1"/>
        {/* faint roads */}
        <g stroke="rgba(255,255,255,.05)" strokeWidth="1" fill="none">
          <path d="M 100 320 Q 280 300, 460 330 T 880 320"/>
          <path d="M 150 260 Q 350 280, 540 270 T 920 290"/>
          <path d="M 240 380 Q 420 360, 620 380 T 880 360"/>
        </g>
        {/* district dots */}
        <g fill="rgba(255,255,255,.12)">
          {Array.from({length: 90}).map((_, i) => {
            const x = 80 + (i * 73) % 880;
            const y = 240 + ((i*131) % 160);
            return <circle key={i} cx={x} cy={y} r="1.5"/>;
          })}
        </g>
        {/* major city labels (faint) */}
        <g fill="rgba(255,255,255,.18)" fontSize="10" fontFamily="Inter, sans-serif">
          <text x="270" y="280">İstanbul</text>
          <text x="430" y="320">Ankara</text>
          <text x="220" y="380">İzmir</text>
          <text x="600" y="350">Kayseri</text>
          <text x="800" y="380">Erzurum</text>
          <text x="540" y="395">Konya</text>
          <text x="720" y="320">Sivas</text>
        </g>
      </svg>
      {children}
    </div>
  );
};

// ---- Production sparkline (svg) ----
const Sparkline = ({ data, color, width = 60, height = 18, fill = true }) => {
  const max = Math.max(...data);
  const min = Math.min(...data);
  const range = max - min || 1;
  const step = width / (data.length - 1);
  const points = data.map((v, i) => [i * step, height - ((v - min) / range) * height]);
  const d = points.map((p, i) => `${i === 0 ? 'M' : 'L'} ${p[0].toFixed(1)} ${p[1].toFixed(1)}`).join(' ');
  const fillD = `${d} L ${width} ${height} L 0 ${height} Z`;
  return (
    <svg width={width} height={height} style={{ overflow: 'visible' }}>
      {fill && <path d={fillD} fill={color} opacity={0.18}/>}
      <path d={d} fill="none" stroke={color} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  );
};

// ---- Sample data ----
const SAMPLE_PINS = [
  { id: 1, type: 'solar', name: 'Konya Solar A', city: 'Konya', district: 'Karapınar', lat: 37.7167, lng: 33.5500, capacityMw: 12.5, annualKwh: 26800000, roi: 6.2, irradiance: 5.4, panelArea: 80000, equipment: 'Trina Vertex 660W', monthly: [1800,1900,2100,2400,2600,2900,3000,2950,2700,2300,1900,1750] },
  { id: 2, type: 'wind',  name: 'Bandırma RES-3', city: 'Balıkesir', district: 'Bandırma', lat: 40.3500, lng: 27.9667, capacityMw: 48.0, annualKwh: 142000000, roi: 8.1, windSpeed: 8.2, capacityFactor: 0.34, equipment: 'Vestas V150 4.5MW', monthly: [11000,11500,12200,12800,11400,10200,9800,10100,11700,13200,13900,13500] },
  { id: 3, type: 'hydro', name: 'Çoruh HES-7', city: 'Artvin', district: 'Yusufeli', lat: 40.8167, lng: 41.5333, capacityMw: 24.0, annualKwh: 95000000, roi: 9.4, flowRate: 32.5, headHeight: 145, equipment: 'Francis Tipi', monthly: [6500,6800,8200,11200,13600,12400,9700,7100,6300,7400,7900,8000] },
  { id: 4, type: 'solar', name: 'Antalya Korkuteli', city: 'Antalya', district: 'Korkuteli', lat: 37.0667, lng: 30.2000, capacityMw: 6.8, annualKwh: 14600000, roi: 5.8, irradiance: 5.7, panelArea: 42000, equipment: 'Jinko Tiger Pro', monthly: [950,1080,1240,1400,1580,1760,1810,1740,1530,1280,1050,920] },
  { id: 5, type: 'wind',  name: 'Çeşme Yel-2', city: 'İzmir', district: 'Çeşme', lat: 38.3167, lng: 26.3000, capacityMw: 18.5, annualKwh: 56400000, roi: 7.4, windSpeed: 7.6, capacityFactor: 0.31, equipment: 'Enercon E-138', monthly: [4400,4600,4900,5200,4500,4100,3900,4000,4700,5300,5500,5300] },
];

// ---- Monthly bars (svg) ----
const MonthlyBars = ({ data, color, width = 220, height = 56 }) => {
  const max = Math.max(...data) || 1;
  const months = ['O','Ş','M','N','M','H','T','A','E','E','K','A'];
  const bw = width / data.length;
  return (
    <svg width="100%" height={height + 14} viewBox={`0 0 ${width} ${height + 14}`} preserveAspectRatio="none" style={{ display: 'block' }}>
      {data.map((v, i) => {
        const h = (v / max) * height;
        return (
          <g key={i}>
            <rect x={i * bw + bw * 0.18} y={height - h} width={bw * 0.64} height={h} rx={1.5} fill={color} opacity={0.85}/>
            <text x={i * bw + bw / 2} y={height + 10} textAnchor="middle" fontSize="8" fill="#7B8190" fontFamily="Inter, system-ui">{months[i]}</text>
          </g>
        );
      })}
    </svg>
  );
};

// expose
Object.assign(window, { TYPES, Icon, TypeIcon, MapBackdrop, Sparkline, MonthlyBars, SAMPLE_PINS });
