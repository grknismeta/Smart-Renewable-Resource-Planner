// map-time-sim.jsx — SRRP · Zaman Simülasyonu v2
// Spotify mantığı: kalıcı mini bar (temel kontroller her zaman) + tap-to-expand panel.
// Veri çözünürlüğü: 2024 öncesi GÜNLÜK, 2024 sonrası SAATLİK — timeline'da görsel ayrım.
// Variants: 'desktop' | 'tablet' | 'mobile'

const { useState: useS, useEffect: useE, useRef: useR, useMemo: useM, useId: useI } = React;

// ─── Constants ─────────────────────────────────────────────────────────────
const TC2 = { solar: '#F59E0B', wind: '#3B82F6', hydro: '#06B6D4' };
const TLbl = { solar: 'GES', wind: 'RES', hydro: 'HES' };
const NOW = new Date('2026-05-26T14:32:00');
const HOURLY_FROM = new Date('2024-01-01T00:00:00');
const OLDEST = new Date('2020-03-15T00:00:00'); // earliest commission across portfolio
const HOUR_MS = 3600 * 1000;
const DAY_MS = 86400 * 1000;

const MONTHS = ['Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'];
const fmtDate = (d) => `${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`;
const fmtHr = (d) => `${d.getHours().toString().padStart(2,'0')}:${d.getMinutes().toString().padStart(2,'0')}`;

// ─── Capacity-factor model ─────────────────────────────────────────────────
function cfPin(pin, d) {
  const hr = d.getHours() + d.getMinutes()/60;
  const doy = (d - new Date(d.getFullYear(), 0, 1)) / DAY_MS;
  const seasonal = Math.sin((doy/365 - 0.25) * Math.PI * 2); // -1 winter .. +1 summer
  const idVar = ((pin.id || 1) * 17) % 7 / 7 * 0.1 - 0.05;   // ±5% per-pin

  if (pin.type === 'solar') {
    if (hr < 5.5 || hr > 19.5) return 0;
    const arc = Math.sin(((hr - 5.5)/14) * Math.PI);
    return Math.max(0, arc * (0.78 + 0.20*seasonal + idVar));
  }
  if (pin.type === 'wind') {
    const diurnal = 0.55 + 0.30*Math.sin(hr*0.27 + 1.2) + 0.12*Math.cos(hr*0.42);
    return Math.max(0.10, diurnal * (0.95 - 0.18*seasonal) + idVar);
  }
  // hydro
  const month = d.getMonth();
  const spring = Math.exp(-((month - 3.5)**2)/5);   // peak Apr/May
  return Math.max(0.20, 0.45 + 0.30*spring + idVar);
}

function aggregateAt(pins, d) {
  const out = { solar: { mw: 0, cap: 0 }, wind: { mw: 0, cap: 0 }, hydro: { mw: 0, cap: 0 }, totalMw: 0, totalCap: 0 };
  for (const p of pins) {
    const cf = cfPin(p, d);
    const mw = p.capacityMw * cf;
    out[p.type].mw += mw;
    out[p.type].cap += p.capacityMw;
    out.totalMw += mw;
    out.totalCap += p.capacityMw;
  }
  return out;
}

// Snap a date to its native resolution
function snapToGranularity(d) {
  if (d >= HOURLY_FROM) {
    // snap to hour
    const r = new Date(d);
    r.setMinutes(0, 0, 0);
    return r;
  }
  // snap to day
  const r = new Date(d);
  r.setHours(0, 0, 0, 0);
  return r;
}
function isHourly(d) { return d >= HOURLY_FROM; }

// ─── Conditions (lightweight) ──────────────────────────────────────────────
function conditionsAt(d) {
  const hr = d.getHours() + d.getMinutes()/60;
  const doy = (d - new Date(d.getFullYear(), 0, 1)) / DAY_MS;
  const seasonal = Math.sin((doy/365 - 0.25) * Math.PI * 2);
  const night = hr < 6 || hr > 19;
  const temp = Math.round(14 + 13*seasonal + (night ? -3 : 4*Math.sin((hr-6)/13*Math.PI)));
  const icon = night ? 'moon' : (hr < 9 ? 'sun-rise' : hr > 17 ? 'sun-set' : seasonal > -0.2 ? 'sun' : 'cloud');
  const lbl = night ? 'Açık · gece' : seasonal > 0.3 ? 'Açık · ılık' : seasonal < -0.2 ? 'Soğuk' : 'Ilık';
  const wind = Math.round(8 + 6*Math.sin(hr*0.27 + 1.2));
  return { temp, icon, lbl, wind };
}

// ─── Icons ─────────────────────────────────────────────────────────────────
const IC = ({ n, s = 14, c = 'currentColor' }) => {
  const p = { width: s, height: s, viewBox: '0 0 24 24', fill: 'none', stroke: c, strokeWidth: 1.8, strokeLinecap: 'round', strokeLinejoin: 'round' };
  switch (n) {
    case 'sun': return <svg {...p}><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"/></svg>;
    case 'sun-rise': return <svg {...p}><path d="M17 18a5 5 0 0 0-10 0"/><path d="M2 18h20M12 2v6M5.6 8.6l1.4 1.4M16.6 8.6l-1.4 1.4M8 6l4-4 4 4"/></svg>;
    case 'sun-set': return <svg {...p}><path d="M17 18a5 5 0 0 0-10 0"/><path d="M2 18h20M12 9V3M5.6 8.6l1.4 1.4M16.6 8.6l-1.4 1.4M8 5l4 4 4-4"/></svg>;
    case 'moon': return <svg {...p}><path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/></svg>;
    case 'cloud': return <svg {...p}><path d="M18 18a4 4 0 0 0 0-8 6 6 0 0 0-11.6 1.5A3.5 3.5 0 1 0 7 18z"/></svg>;
    case 'wind': return <svg {...p}><path d="M17.7 7.7a2.5 2.5 0 1 1 1.8 4.3H2M9.6 4.6A2 2 0 1 1 11 8H2M12.6 19.4A2 2 0 1 0 14 16H2"/></svg>;
    case 'play': return <svg width={s} height={s} viewBox="0 0 12 12"><path d="M3 1.5 L10 6 L3 10.5 Z" fill={c}/></svg>;
    case 'pause': return <svg width={s} height={s} viewBox="0 0 12 12"><rect x="2.5" y="1.5" width="2.5" height="9" rx=".6" fill={c}/><rect x="7" y="1.5" width="2.5" height="9" rx=".6" fill={c}/></svg>;
    case 'rewind': return <svg width={s} height={s} viewBox="0 0 14 14"><rect x="1" y="2" width="1.5" height="10" rx=".5" fill={c}/><path d="M12 2 L4 7 L12 12 Z" fill={c}/></svg>;
    case 'now': return <svg {...p}><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>;
    case 'x': return <svg {...p}><path d="M18 6L6 18M6 6l12 12"/></svg>;
    case 'expand': return <svg {...p}><path d="M7 14l5-5 5 5"/></svg>;
    case 'collapse': return <svg {...p}><path d="M7 10l5 5 5-5"/></svg>;
    case 'live': return <svg {...p}><circle cx="12" cy="12" r="3" fill={c}/></svg>;
    case 'minimize': return <svg {...p}><path d="M5 12h14"/></svg>;
    default: return null;
  }
};

// ─── Live pulse dot ────────────────────────────────────────────────────────
const LiveDot = ({ size = 8, live = true }) => (
  <span style={{ position: 'relative', width: size, height: size, display: 'inline-block', flexShrink: 0 }}>
    <span style={{ position: 'absolute', inset: 0, borderRadius: '50%', background: live ? '#10B981' : 'var(--text-3)' }}/>
    {live && <span style={{ position: 'absolute', inset: 0, borderRadius: '50%', background: '#10B981', animation: 'mtsPulse 1.8s ease-out infinite' }}/>}
  </span>
);

// ─── Hook: simulation state ────────────────────────────────────────────────
function useTimeSim(pins) {
  const [date, setDate] = useS(NOW);
  const [playing, setPlaying] = useS(false);
  const [speed, setSpeed] = useS(8); // hours per real second

  const dateRef = useR(date); dateRef.current = date;
  const rafRef = useR(null);
  const lastT = useR(0);

  useE(() => {
    if (!playing) { lastT.current = 0; return; }
    const tick = (now) => {
      if (!lastT.current) lastT.current = now;
      const dt = (now - lastT.current) / 1000; lastT.current = now;
      const incMs = speed * HOUR_MS * dt;
      const next = new Date(dateRef.current.getTime() + incMs);
      if (next >= NOW) { setDate(NOW); setPlaying(false); return; }
      setDate(next);
      rafRef.current = requestAnimationFrame(tick);
    };
    rafRef.current = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(rafRef.current);
  }, [playing, speed]);

  const setDateSnapped = (d) => setDate(snapToGranularity(d < OLDEST ? OLDEST : d > NOW ? NOW : d));
  const agg = useM(() => aggregateAt(pins, date), [pins, date]);
  return { date, setDate: setDateSnapped, playing, setPlaying, speed, setSpeed, agg, hourly: isHourly(date) };
}

// ─── Preset chips ──────────────────────────────────────────────────────────
const PRESETS = [
  { id: 'now',  lbl: 'Şimdi',     d: () => NOW },
  { id: '1h',   lbl: '1 saat',    d: () => new Date(NOW - HOUR_MS) },
  { id: '6h',   lbl: '6 saat',    d: () => new Date(NOW - 6*HOUR_MS) },
  { id: '1g',   lbl: '1 gün',     d: () => new Date(NOW - DAY_MS) },
  { id: '1h_',  lbl: '1 hafta',   d: () => new Date(NOW - 7*DAY_MS) },
  { id: '1a',   lbl: '1 ay',      d: () => new Date(NOW - 30*DAY_MS) },
  { id: '1y',   lbl: '1 yıl',     d: () => new Date(NOW - 365*DAY_MS) },
  { id: '3y',   lbl: '3 yıl',     d: () => new Date(NOW - 3*365*DAY_MS) },
];
const presetActive = (id, d) => {
  const target = PRESETS.find(p => p.id === id)?.d();
  if (!target) return false;
  return Math.abs(d - target) < (isHourly(d) ? HOUR_MS/2 : DAY_MS/2);
};
const PresetChips = ({ date, setDate, scroll = true }) => (
  <div style={{ display: 'flex', gap: 5, overflowX: scroll ? 'auto' : 'visible', flexWrap: scroll ? 'nowrap' : 'wrap', paddingBottom: scroll ? 2 : 0 }} className="scroll">
    {PRESETS.map(p => {
      const on = presetActive(p.id, date);
      return (
        <button key={p.id} onClick={() => setDate(p.d())}
          style={{
            flexShrink: 0, padding: '5px 10px', borderRadius: 999,
            background: on ? 'rgba(20,184,166,.16)' : 'rgba(255,255,255,.04)',
            border: `1px solid ${on ? 'rgba(20,184,166,.55)' : 'var(--border)'}`,
            color: on ? 'var(--accent)' : 'var(--text-2)',
            font: `${on ? 600 : 500} 11px/1 var(--font)`, cursor: 'pointer', whiteSpace: 'nowrap',
          }}>{p.lbl}</button>
      );
    })}
  </div>
);

// ─── Speed segmented ───────────────────────────────────────────────────────
const SpeedSeg = ({ speed, setSpeed, compact }) => {
  const opts = [
    { v: 1,  lbl: '1×',  hint: '1sa/sn' },
    { v: 8,  lbl: '8×',  hint: '8sa/sn' },
    { v: 24, lbl: '1g',  hint: '1gün/sn' },
    { v: 168,lbl: '1h',  hint: '1hafta/sn' },
  ];
  return (
    <div className="seg" style={{ padding: 2 }}>
      {opts.map(o => (
        <button key={o.v} onClick={() => setSpeed(o.v)} className={speed === o.v ? 'on' : ''}
          title={o.hint}
          style={{ padding: compact ? '5px 7px' : '5px 9px', font: `${speed === o.v ? 700 : 500} 11px/1 var(--font-mono)`, minWidth: 26 }}>
          {o.lbl}
        </button>
      ))}
    </div>
  );
};

// ─── Play button ───────────────────────────────────────────────────────────
const PlayBtn = ({ playing, onClick, size = 36, accent = '#14B8A6', glow = true }) => (
  <button onClick={onClick} aria-label={playing ? 'Duraklat' : 'Oynat'}
    style={{
      width: size, height: size, borderRadius: size/2,
      background: accent, border: `1px solid ${accent}`, color: '#06201E',
      cursor: 'pointer', display: 'grid', placeItems: 'center',
      boxShadow: glow ? `0 0 0 4px ${accent}22, 0 4px 14px rgba(0,0,0,.4)` : 'none',
      transition: 'transform .1s, box-shadow .15s', flexShrink: 0,
    }}>
    <IC n={playing ? 'pause' : 'play'} s={size * 0.38} c="#06201E"/>
  </button>
);

// ─── Timeline (the centerpiece — shows daily/hourly resolution split) ─────
const Timeline = ({ date, setDate, setPlaying, height = 56, dense = false }) => {
  const W = 1000;
  const padL = 12, padR = 12;
  const trackW = W - padL - padR;
  const trackY = dense ? height * 0.40 : height * 0.46;
  const trackH = dense ? 10 : 14;
  const baseId = useI().replace(/:/g, '');

  // Time → x
  const TOTAL = NOW - OLDEST;
  const xFor = (d) => padL + ((d - OLDEST) / TOTAL) * trackW;
  const dateFromClient = (clientX, rect) => {
    const x = ((clientX - rect.left) / rect.width) * W;
    const t = Math.max(0, Math.min(1, (x - padL) / trackW));
    return new Date(OLDEST.getTime() + t * TOTAL);
  };

  // The hourly-boundary divider
  const dividerX = xFor(HOURLY_FROM);
  const playheadX = xFor(date);

  // Year ticks
  const years = [];
  for (let y = OLDEST.getFullYear() + 1; y <= NOW.getFullYear(); y++) {
    years.push({ d: new Date(y, 0, 1), lbl: y });
  }

  // Refs + drag
  const ref = useR();
  const drag = useR(false);
  const onDown = (e) => {
    setPlaying && setPlaying(false);
    drag.current = true;
    setDate(dateFromClient(e.clientX, ref.current.getBoundingClientRect()));
    e.preventDefault(); e.stopPropagation();
  };
  useE(() => {
    const mv = (e) => { if (drag.current) setDate(dateFromClient(e.clientX, ref.current.getBoundingClientRect())); };
    const up = () => { drag.current = false; };
    window.addEventListener('pointermove', mv); window.addEventListener('pointerup', up);
    return () => { window.removeEventListener('pointermove', mv); window.removeEventListener('pointerup', up); };
  });

  return (
    <div ref={ref} style={{ position: 'relative', userSelect: 'none' }} onPointerDown={onDown}>
      <svg viewBox={`0 0 ${W} ${height}`} style={{ width: '100%', height: 'auto', display: 'block', cursor: 'ew-resize', touchAction: 'none' }}>
        <defs>
          {/* Daily texture pattern */}
          <pattern id={`tex-${baseId}`} x="0" y="0" width="3" height="6" patternUnits="userSpaceOnUse">
            <rect width="3" height="6" fill="rgba(255,255,255,.04)"/>
            <rect width="1" height="6" fill="rgba(255,255,255,.10)"/>
          </pattern>
          {/* Hourly gradient (denser) */}
          <linearGradient id={`hr-${baseId}`} x1="0" x2="0" y1="0" y2="1">
            <stop offset="0" stopColor="#14B8A6" stopOpacity="0.55"/>
            <stop offset="1" stopColor="#14B8A6" stopOpacity="0.30"/>
          </linearGradient>
        </defs>

        {/* Pre-2024 (daily) portion */}
        <rect x={padL} y={trackY} width={dividerX - padL} height={trackH} rx={trackH/2} fill="rgba(255,255,255,.06)"/>
        <rect x={padL} y={trackY} width={dividerX - padL} height={trackH} rx={trackH/2} fill={`url(#tex-${baseId})`}/>

        {/* 2024+ (hourly) portion */}
        <rect x={dividerX} y={trackY} width={W - padR - dividerX} height={trackH} rx={trackH/2} fill={`url(#hr-${baseId})`}/>

        {/* Year ticks */}
        {years.map(y => (
          <g key={y.lbl}>
            <line x1={xFor(y.d)} x2={xFor(y.d)} y1={trackY + trackH + 2} y2={trackY + trackH + 5} stroke="rgba(255,255,255,.25)"/>
            <text x={xFor(y.d)} y={trackY + trackH + 16} textAnchor="middle" fontSize="9.5" fill="rgba(255,255,255,.5)" fontFamily="JetBrains Mono, monospace">{y.lbl}</text>
          </g>
        ))}

        {/* The 2024 divider (key visual) */}
        <line x1={dividerX} x2={dividerX} y1={trackY - 8} y2={trackY + trackH + 6} stroke="#14B8A6" strokeWidth="1.4" strokeDasharray="2 2" opacity="0.6"/>
        {!dense && (
          <>
            <text x={dividerX - 4} y={trackY - 11} textAnchor="end" fontSize="9" fill="rgba(255,255,255,.55)" fontFamily="JetBrains Mono, monospace" letterSpacing=".05em">GÜNLÜK</text>
            <text x={dividerX + 4} y={trackY - 11} textAnchor="start" fontSize="9" fill="#14B8A6" fontFamily="JetBrains Mono, monospace" letterSpacing=".05em" fontWeight="700">SAATLİK</text>
          </>
        )}

        {/* Now end marker */}
        <line x1={xFor(NOW)} x2={xFor(NOW)} y1={trackY - 4} y2={trackY + trackH + 4} stroke="rgba(255,255,255,.35)" strokeWidth="1.2"/>

        {/* Playhead */}
        <g>
          <line x1={playheadX} x2={playheadX} y1={trackY - 9} y2={trackY + trackH + 7} stroke="var(--accent)" strokeWidth="2"/>
          <circle cx={playheadX} cy={trackY + trackH/2} r="8.5" fill="var(--accent)" stroke="#06201E" strokeWidth="2"/>
          <circle cx={playheadX} cy={trackY + trackH/2} r="13" fill="var(--accent)" opacity="0.18"/>
        </g>
      </svg>
    </div>
  );
};

// ─── Type breakdown — compact vertical bar trio ────────────────────────────
const Breakdown = ({ agg, layout = 'row', compact = false }) => {
  const items = ['solar','wind','hydro'].map(t => {
    const cf = agg[t].cap ? agg[t].mw / agg[t].cap : 0;
    return { t, mw: agg[t].mw, cap: agg[t].cap, cf };
  });
  if (layout === 'rows') {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', gap: 7 }}>
        {items.map(i => (
          <div key={i.t} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{ font: '600 10px/1 var(--font-mono)', color: TC2[i.t], width: 26 }}>{TLbl[i.t]}</span>
            <div style={{ flex: 1, position: 'relative', height: 6, background: 'rgba(255,255,255,.06)', borderRadius: 3 }}>
              <div style={{ position: 'absolute', inset: 0, width: `${Math.min(100, i.cf*100)}%`, background: TC2[i.t], borderRadius: 3, boxShadow: `0 0 10px ${TC2[i.t]}66` }}/>
            </div>
            <span className="tnum" style={{ font: '700 12px/1 var(--font)', color: 'var(--text)', minWidth: 44, textAlign: 'right' }}>{i.mw.toFixed(0)} MW</span>
            <span className="tnum" style={{ font: '500 10px/1 var(--font-mono)', color: 'var(--text-3)', minWidth: 30, textAlign: 'right' }}>%{(i.cf*100).toFixed(0)}</span>
          </div>
        ))}
      </div>
    );
  }
  // row layout — 3 mini cards
  return (
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 7 }}>
      {items.map(i => (
        <div key={i.t} style={{ padding: '7px 8px', background: 'rgba(0,0,0,.25)', border: '1px solid var(--border-2)', borderRadius: 8 }}>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
            <span style={{ font: '600 9.5px/1 var(--font-mono)', color: TC2[i.t] }}>{TLbl[i.t]}</span>
            <span style={{ flex: 1 }}/>
            <span className="tnum" style={{ font: '500 9.5px/1 var(--font-mono)', color: 'var(--text-3)' }}>%{(i.cf*100).toFixed(0)}</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 3, marginTop: 4 }}>
            <span className="tnum" style={{ font: '700 15px/1 var(--font)', color: 'var(--text)', letterSpacing: '-.01em' }}>{i.mw.toFixed(0)}</span>
            <span style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)' }}>MW</span>
          </div>
          <div style={{ marginTop: 5, height: 4, background: 'rgba(255,255,255,.06)', borderRadius: 2 }}>
            <div style={{ width: `${Math.min(100, i.cf*100)}%`, height: '100%', background: TC2[i.t], borderRadius: 2 }}/>
          </div>
        </div>
      ))}
    </div>
  );
};

// ─── Mini bar (always visible — the "Spotify mini" surface) ───────────────
const MiniBar = ({ sim, onExpand, onClose, accent = '#14B8A6', variant = 'mobile' }) => {
  const { date, agg, playing, setPlaying, hourly } = sim;
  // Compact mode for desktop/tablet floating chip
  if (variant === 'web') {
    return (
      <div onClick={onExpand}
        style={{
          display: 'inline-flex', alignItems: 'center', gap: 9,
          padding: '6px 8px 6px 12px',
          background: 'rgba(20,24,34,.96)', backdropFilter: 'blur(16px)',
          border: '1px solid var(--border)', borderRadius: 999,
          boxShadow: '0 8px 24px rgba(0,0,0,.4), 0 0 0 1px rgba(20,184,166,.10)',
          cursor: 'pointer', color: 'var(--text)',
        }}>
        <LiveDot size={7}/>
        <span className="tnum" style={{ font: '600 11.5px/1 var(--font-mono)', color: 'var(--text)' }}>
          {hourly ? fmtHr(date) : ''} {hourly ? '·' : ''} {date.getDate()} {MONTHS[date.getMonth()]}
        </span>
        <span style={{ width: 1, height: 12, background: 'var(--border)' }}/>
        <span className="tnum" style={{ font: '700 13px/1 var(--font)', color: accent, letterSpacing: '-.02em' }}>{agg.totalMw.toFixed(0)}</span>
        <span style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)' }}>MW</span>
        <PlayBtn playing={playing} onClick={(e) => { e.stopPropagation(); setPlaying(p => !p); }} size={28} glow={false}/>
        {onClose && (
          <button onClick={(e) => { e.stopPropagation(); onClose(); }} aria-label="Kapat"
            style={{ width: 22, height: 22, borderRadius: 6, background: 'rgba(255,255,255,.05)', border: '1px solid var(--border)', color: 'var(--text-3)', cursor: 'pointer', display: 'grid', placeItems: 'center', marginLeft: 2 }}>
            <IC n="x" s={11}/>
          </button>
        )}
      </div>
    );
  }
  // mobile mini bar — pill, full-width, persistent
  return (
    <div onClick={onExpand}
      style={{
        display: 'flex', alignItems: 'center', gap: 9, width: '100%',
        padding: '7px 9px 7px 12px',
        background: 'rgba(20,24,34,.97)', backdropFilter: 'blur(16px)',
        border: '1px solid var(--border)', borderTop: '1px solid rgba(20,184,166,.30)',
        borderRadius: 14,
        boxShadow: '0 -6px 22px rgba(0,0,0,.5)',
        cursor: 'pointer', color: 'var(--text)',
      }}>
      <LiveDot size={8}/>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
          <span className="tnum" style={{ font: '700 14px/1 var(--font)', color: accent, letterSpacing: '-.02em' }}>{agg.totalMw.toFixed(0)}</span>
          <span style={{ font: '600 10px/1 var(--font)', color: 'var(--text-2)' }}>MW</span>
          <span className="tnum" style={{ font: '500 10px/1 var(--font-mono)', color: 'var(--text-3)', marginLeft: 2 }}>%{(agg.totalMw/agg.totalCap*100).toFixed(0)}</span>
          <span style={{ flex: 1 }}/>
          <span className="tnum" style={{ font: '500 10px/1 var(--font-mono)', color: 'var(--text-3)' }}>{hourly ? 'saatlik' : 'günlük'}</span>
        </div>
        <div className="tnum" style={{ font: '500 10.5px/1.3 var(--font-mono)', color: 'var(--text-3)', marginTop: 2, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
          {hourly ? `${fmtHr(date)} · ` : ''}{fmtDate(date)}
        </div>
      </div>
      <PlayBtn playing={playing} onClick={(e) => { e.stopPropagation(); setPlaying(p => !p); }} size={30} glow={false}/>
      <button onClick={(e) => { e.stopPropagation(); onExpand(); }} aria-label="Aç"
        style={{ width: 26, height: 26, borderRadius: 7, background: 'rgba(255,255,255,.05)', border: '1px solid var(--border)', color: 'var(--text-2)', cursor: 'pointer', display: 'grid', placeItems: 'center' }}>
        <IC n="expand" s={12}/>
      </button>
      {onClose && (
        <button onClick={(e) => { e.stopPropagation(); onClose(); }} aria-label="Kapat"
          style={{ width: 26, height: 26, borderRadius: 7, background: 'rgba(255,255,255,.05)', border: '1px solid var(--border)', color: 'var(--text-3)', cursor: 'pointer', display: 'grid', placeItems: 'center' }}>
          <IC n="x" s={12}/>
        </button>
      )}
    </div>
  );
};

// ─── Big readout block (used in expanded panels) ──────────────────────────
const BigReadout = ({ date, agg, hourly, accent = '#14B8A6', dense = false }) => {
  const cond = conditionsAt(date);
  return (
    <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12 }}>
      <div style={{ flex: 1 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>
          <LiveDot size={7} live={Math.abs(date - NOW) < HOUR_MS}/>
          <span style={{ font: '500 10px/1 var(--font-mono)', color: 'var(--text-3)', letterSpacing: '.06em' }}>
            ANLIK ÜRETİM · {hourly ? 'SAATLİK VERİ' : 'GÜNLÜK VERİ'}
          </span>
        </div>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginTop: 5 }}>
          <span className="tnum" style={{ font: `700 ${dense ? 30 : 38}px/1 var(--font)`, color: accent, letterSpacing: '-.025em' }}>{agg.totalMw.toFixed(0)}</span>
          <span style={{ font: `600 ${dense ? 13 : 14}px/1 var(--font)`, color: 'var(--text-2)' }}>MW</span>
          <span className="tnum" style={{ font: `500 ${dense ? 11 : 12}px/1 var(--font-mono)`, color: 'var(--text-3)', marginLeft: 4 }}>
            / {agg.totalCap.toFixed(0)} · %{(agg.totalMw/agg.totalCap*100).toFixed(0)}
          </span>
        </div>
        <div className="tnum" style={{ font: '500 11.5px/1.4 var(--font-mono)', color: 'var(--text-2)', marginTop: 4 }}>
          {hourly ? `${fmtHr(date)} · ` : ''}{fmtDate(date)}
        </div>
      </div>
      {/* Conditions */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 7, padding: '6px 10px', background: 'rgba(0,0,0,.22)', borderRadius: 9, border: '1px solid var(--border-2)' }}>
        <IC n={cond.icon} s={17} c="#FBBF24"/>
        <div>
          <div className="tnum" style={{ font: '700 14px/1 var(--font)', color: 'var(--text)' }}>{cond.temp}°</div>
          <div style={{ font: '500 9.5px/1.3 var(--font)', color: 'var(--text-3)', marginTop: 2 }}>{cond.wind} km/sa</div>
        </div>
      </div>
    </div>
  );
};

// ─── Expanded panel body (shared across variants) ─────────────────────────
const PanelBody = ({ sim, onCollapse, accent = '#14B8A6', dense = false, breakdownLayout = 'row' }) => {
  const { date, setDate, playing, setPlaying, speed, setSpeed, agg, hourly } = sim;
  return (
    <>
      {/* Big readout */}
      <BigReadout date={date} agg={agg} hourly={hourly} accent={accent} dense={dense}/>

      {/* Presets */}
      <div style={{ marginTop: 12 }}>
        <PresetChips date={date} setDate={setDate}/>
      </div>

      {/* Timeline */}
      <div style={{ marginTop: 10, padding: '4px 6px', background: 'rgba(0,0,0,.25)', border: '1px solid var(--border-2)', borderRadius: 9 }}>
        <Timeline date={date} setDate={setDate} setPlaying={setPlaying} height={dense ? 52 : 62}/>
      </div>

      {/* Breakdown */}
      <div style={{ marginTop: 10 }}>
        <Breakdown agg={agg} layout={breakdownLayout}/>
      </div>

      {/* Bottom controls */}
      <div style={{ marginTop: 10, display: 'flex', alignItems: 'center', gap: 8 }}>
        <button onClick={() => { setPlaying(false); setDate(NOW); }} title="Şimdiye dön"
          style={{ display: 'inline-flex', alignItems: 'center', gap: 4, padding: '6px 10px', borderRadius: 8, background: 'rgba(20,184,166,.10)', border: '1px solid rgba(20,184,166,.40)', color: accent, cursor: 'pointer', font: '600 11px/1 var(--font)' }}>
          <IC n="now" s={11}/><span>ŞİMDİ</span>
        </button>
        <PlayBtn playing={playing} onClick={() => { if (Math.abs(date - NOW) < HOUR_MS) setDate(new Date(NOW - 7*DAY_MS)); setPlaying(p => !p); }} size={34}/>
        <div style={{ flex: 1 }}/>
        <span className="label" style={{ font: '500 9.5px/1 var(--font)' }}>Hız</span>
        <SpeedSeg speed={speed} setSpeed={setSpeed} compact={dense}/>
      </div>
    </>
  );
};

// ─── Variants ──────────────────────────────────────────────────────────────
const DesktopWidget = ({ pins, expanded: ext, setExpanded: setExt, onClose }) => {
  const sim = useTimeSim(pins);
  const internalState = useS(true);
  const expanded = ext !== undefined ? ext : internalState[0];
  const setExpanded = setExt || internalState[1];

  if (!expanded) {
    return <MiniBar sim={sim} variant="web" onExpand={() => setExpanded(true)} onClose={onClose}/>;
  }
  return (
    <div style={{
      width: 440,
      background: 'rgba(20,24,34,.97)', backdropFilter: 'blur(16px)',
      border: '1px solid var(--border)', borderTop: '1px solid rgba(20,184,166,.30)',
      borderRadius: 14, padding: '12px 14px 13px',
      boxShadow: '0 12px 36px rgba(0,0,0,.5), 0 0 0 1px rgba(20,184,166,.08)',
      color: 'var(--text)',
    }}>
      {/* header strip */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
        <div style={{ width: 22, height: 22, borderRadius: 6, background: 'rgba(20,184,166,.16)', border: '1px solid rgba(20,184,166,.40)', display: 'grid', placeItems: 'center' }}>
          <IC n="now" s={12} c="var(--accent)"/>
        </div>
        <span style={{ font: '600 10.5px/1 var(--font-mono)', color: 'var(--accent)', letterSpacing: '.08em' }}>ZAMAN SİMÜLASYONU</span>
        <span style={{ font: '500 10px/1.3 var(--font)', color: 'var(--text-3)' }}>· {pins.length} santral</span>
        <div style={{ flex: 1 }}/>
        <button onClick={() => setExpanded(false)} aria-label="Küçült" title="Mini'ye küçült"
          style={{ width: 24, height: 24, borderRadius: 6, background: 'rgba(255,255,255,.05)', border: '1px solid var(--border)', color: 'var(--text-2)', cursor: 'pointer', display: 'grid', placeItems: 'center' }}>
          <IC n="minimize" s={12}/>
        </button>
        {onClose && (
          <button onClick={onClose} aria-label="Kapat"
            style={{ width: 24, height: 24, borderRadius: 6, background: 'rgba(255,255,255,.05)', border: '1px solid var(--border)', color: 'var(--text-3)', cursor: 'pointer', display: 'grid', placeItems: 'center' }}>
            <IC n="x" s={11}/>
          </button>
        )}
      </div>
      <PanelBody sim={sim} accent="#14B8A6" breakdownLayout="row"/>
    </div>
  );
};

const TabletWidget = ({ pins, expanded: ext, setExpanded: setExt, onClose }) => {
  const sim = useTimeSim(pins);
  const internalState = useS(true);
  const expanded = ext !== undefined ? ext : internalState[0];
  const setExpanded = setExt || internalState[1];

  if (!expanded) {
    return <MiniBar sim={sim} variant="web" onExpand={() => setExpanded(true)} onClose={onClose}/>;
  }
  return (
    <div style={{
      width: 400,
      background: 'rgba(20,24,34,.97)', backdropFilter: 'blur(16px)',
      border: '1px solid var(--border)', borderTop: '1px solid rgba(20,184,166,.30)',
      borderRadius: 13, padding: '11px 12px 12px',
      boxShadow: '0 10px 30px rgba(0,0,0,.45)',
      color: 'var(--text)',
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 9 }}>
        <div style={{ width: 20, height: 20, borderRadius: 6, background: 'rgba(20,184,166,.16)', border: '1px solid rgba(20,184,166,.40)', display: 'grid', placeItems: 'center' }}>
          <IC n="now" s={11} c="var(--accent)"/>
        </div>
        <span style={{ font: '600 10px/1 var(--font-mono)', color: 'var(--accent)', letterSpacing: '.08em' }}>ZAMAN SİMÜLASYONU</span>
        <div style={{ flex: 1 }}/>
        <button onClick={() => setExpanded(false)} aria-label="Küçült"
          style={{ width: 22, height: 22, borderRadius: 6, background: 'rgba(255,255,255,.05)', border: '1px solid var(--border)', color: 'var(--text-2)', cursor: 'pointer', display: 'grid', placeItems: 'center' }}>
          <IC n="minimize" s={11}/>
        </button>
        {onClose && (
          <button onClick={onClose} aria-label="Kapat"
            style={{ width: 22, height: 22, borderRadius: 6, background: 'rgba(255,255,255,.05)', border: '1px solid var(--border)', color: 'var(--text-3)', cursor: 'pointer', display: 'grid', placeItems: 'center' }}>
            <IC n="x" s={10}/>
          </button>
        )}
      </div>
      <PanelBody sim={sim} accent="#14B8A6" dense breakdownLayout="rows"/>
    </div>
  );
};

const MobileWidget = ({ pins, expanded: ext, setExpanded: setExt, onClose }) => {
  const sim = useTimeSim(pins);
  const internalState = useS(false); // mobile starts collapsed
  const expanded = ext !== undefined ? ext : internalState[0];
  const setExpanded = setExt || internalState[1];

  if (!expanded) {
    return <MiniBar sim={sim} variant="mobile" onExpand={() => setExpanded(true)} onClose={onClose}/>;
  }
  return (
    <div style={{
      background: 'rgba(20,24,34,.98)', backdropFilter: 'blur(20px)',
      border: '1px solid var(--border)', borderTop: '1px solid rgba(20,184,166,.35)',
      borderTopLeftRadius: 18, borderTopRightRadius: 18,
      borderBottomLeftRadius: 14, borderBottomRightRadius: 14,
      padding: '6px 12px 12px',
      boxShadow: '0 -10px 30px rgba(0,0,0,.6)',
      color: 'var(--text)',
    }}>
      {/* drag handle */}
      <div onClick={() => setExpanded(false)} style={{ display: 'flex', justifyContent: 'center', padding: '4px 0 8px', cursor: 'pointer' }}>
        <div style={{ width: 38, height: 4, borderRadius: 2, background: 'rgba(255,255,255,.20)' }}/>
      </div>

      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginBottom: 8 }}>
        <LiveDot size={7}/>
        <span style={{ font: '600 10px/1 var(--font-mono)', color: 'var(--accent)', letterSpacing: '.08em' }}>ZAMAN SİMÜLASYONU</span>
        <div style={{ flex: 1 }}/>
        <button onClick={() => setExpanded(false)} aria-label="Küçült"
          style={{ width: 26, height: 26, borderRadius: 7, background: 'rgba(255,255,255,.05)', border: '1px solid var(--border)', color: 'var(--text-2)', cursor: 'pointer', display: 'grid', placeItems: 'center' }}>
          <IC n="collapse" s={12}/>
        </button>
        {onClose && (
          <button onClick={onClose} aria-label="Kapat"
            style={{ width: 26, height: 26, borderRadius: 7, background: 'rgba(255,255,255,.05)', border: '1px solid var(--border)', color: 'var(--text-3)', cursor: 'pointer', display: 'grid', placeItems: 'center' }}>
            <IC n="x" s={11}/>
          </button>
        )}
      </div>

      <PanelBody sim={sim} accent="#14B8A6" dense breakdownLayout="rows"/>
    </div>
  );
};

// ─── Public component — variant router ────────────────────────────────────
const MapTimeSim = ({ pins, variant = 'desktop', expanded, setExpanded, onClose }) => {
  if (variant === 'mobile') return <MobileWidget pins={pins} expanded={expanded} setExpanded={setExpanded} onClose={onClose}/>;
  if (variant === 'tablet') return <TabletWidget pins={pins} expanded={expanded} setExpanded={setExpanded} onClose={onClose}/>;
  return <DesktopWidget pins={pins} expanded={expanded} setExpanded={setExpanded} onClose={onClose}/>;
};

// Inject keyframes (once)
if (typeof document !== 'undefined' && !document.getElementById('mts-kf')) {
  const st = document.createElement('style');
  st.id = 'mts-kf';
  st.textContent = `@keyframes mtsPulse { 0% { transform: scale(1); opacity: .6 } 70% { transform: scale(2.6); opacity: 0 } 100% { opacity: 0 } }`;
  document.head.appendChild(st);
}

Object.assign(window, { MapTimeSim });
