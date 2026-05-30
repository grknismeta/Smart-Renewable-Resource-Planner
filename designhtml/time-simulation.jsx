// time-simulation.jsx — SRRP · Zaman Simülasyonu Widget
// Bir santralin devreye alımdan bugüne + 5 yıl tahmine kadar olan
// üretim/gelir/CO₂/hane eşdeğerini scrub & play ile gösterir.
// Variants: 'desktop' | 'tablet' | 'mobile'

const { useState: useStateTS, useEffect: useEffectTS, useRef: useRefTS, useMemo: useMemoTS, useCallback: useCallbackTS, useId: useIdTS } = React;

const TS_TC = { solar: '#F59E0B', wind: '#3B82F6', hydro: '#06B6D4' };
const TS_TC_DIM = { solar: 'rgba(245,158,11,.18)', wind: 'rgba(59,130,246,.18)', hydro: 'rgba(6,182,212,.18)' };

const TS_TODAY = new Date('2026-05-19');
const TS_DAY_MS = 86400000;
const tsAddDays = (d, days) => new Date(d.getTime() + Math.round(days) * TS_DAY_MS);
const tsDayDiff = (a, b) => Math.round((b - a) / TS_DAY_MS);
const TS_MONTHS_TR = ['Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'];
const tsFmtDate = (d) => `${d.getDate()} ${TS_MONTHS_TR[d.getMonth()]} ${d.getFullYear()}`;
const tsFmtYrMon = (d) => `${TS_MONTHS_TR[d.getMonth()]} '${d.getFullYear().toString().slice(-2)}`;

// metric definitions: each takes cumulative kWh -> displayed value+unit
const TS_METRICS = {
  kwh: {
    label: 'Üretim',  short: 'Üretim', icon: 'eq',
    unitMain: 'GWh', unitSub: 'kümülatif',
    value: kwh => kwh / 1e6,
    format: v => v >= 100 ? v.toFixed(0) : v.toFixed(1),
    yTick: v => v >= 100 ? `${v.toFixed(0)}` : v.toFixed(1),
    perYear: pin => pin.annualKwh / 1e6,
    colorOverride: null, // uses type color
  },
  rev: {
    label: 'Gelir', short: 'Gelir', icon: 'roi',
    unitMain: 'M ₺', unitSub: 'devreden bugüne',
    value: kwh => (kwh * 2.45) / 1e6,
    format: v => v >= 100 ? v.toFixed(0) : v.toFixed(1),
    yTick: v => v >= 100 ? `${v.toFixed(0)}` : v.toFixed(1),
    perYear: pin => (pin.annualKwh * 2.45) / 1e6,
    colorOverride: '#10B981',
  },
  co2: {
    label: 'CO₂ Önlendi', short: 'CO₂', icon: 'leaf',
    unitMain: 'kton', unitSub: 'eşd. emisyon',
    value: kwh => (kwh * 0.689) / 1e6,
    format: v => v >= 100 ? v.toFixed(0) : v.toFixed(1),
    yTick: v => v >= 100 ? `${v.toFixed(0)}` : v.toFixed(1),
    perYear: pin => (pin.annualKwh * 0.689) / 1e6,
    colorOverride: '#10B981',
  },
  home: {
    label: 'Hane Eşdeğeri', short: 'Hane', icon: 'home',
    unitMain: 'bin hane·yıl', unitSub: 'tüketim eşd.',
    value: kwh => kwh / 3500 / 1000,
    format: v => v >= 100 ? v.toFixed(0) : v.toFixed(1),
    yTick: v => v >= 100 ? `${v.toFixed(0)}` : v.toFixed(1),
    perYear: pin => (pin.annualKwh / 3500) / 1000,
    colorOverride: '#A78BFA',
  },
};

// ============================================================================
// Hook: derive timeline data once per pin
// ============================================================================
function useTimelineTS(pin) {
  return useMemoTS(() => {
    // Commission date: 2.2 – 3.5 years ago, varies by pin id (deterministic)
    const seed = ((pin.id || 1) * 137) % 365;
    const commissionDate = tsAddDays(TS_TODAY, -(820 + seed));
    const horizonDate = tsAddDays(TS_TODAY, 365 * 5);
    const totalDays = tsDayDiff(commissionDate, horizonDate);
    const todayDayIdx = tsDayDiff(commissionDate, TS_TODAY);

    // Monthly cumulative curve from commission → horizon
    const monthCount = Math.ceil(totalDays / 30) + 1;
    const curve = [];
    let cum = 0;
    for (let m = 0; m < monthCount; m++) {
      const monthOfYear = (commissionDate.getMonth() + m) % 12;
      const monthly = (pin.monthly && pin.monthly[monthOfYear]) || (pin.annualKwh / 12);
      // Deterministic variability (weather)
      const noise = Math.sin(m * 1.7 + (pin.id || 1)) * 0.08 + Math.cos(m * 0.9) * 0.05;
      // Mild degradation after year 5 (panels/turbines age)
      const age = m / 12;
      const degr = age > 5 ? Math.min(0.08, (age - 5) * 0.004) : 0;
      const realized = monthly * (1 + noise) * (1 - degr);
      cum += realized;
      curve.push({ dayIdx: m * 30, monthDate: tsAddDays(commissionDate, m * 30), cumKwh: cum, monthlyKwh: realized });
    }
    const finalKwh = curve[curve.length - 1].cumKwh;

    // Linear interp helper
    const valueAtDay = (day) => {
      const d = Math.max(0, Math.min(totalDays, day));
      const m = d / 30;
      const i0 = Math.floor(m);
      const i1 = Math.min(curve.length - 1, i0 + 1);
      const t = m - i0;
      return (curve[i0]?.cumKwh || 0) + ((curve[i1]?.cumKwh || 0) - (curve[i0]?.cumKwh || 0)) * t;
    };

    // Confidence factor for forecast band (grows with time after today)
    const bandFactor = (day) => {
      if (day <= todayDayIdx) return 0;
      const yrsForward = (day - todayDayIdx) / 365;
      return Math.min(0.20, 0.035 + yrsForward * 0.026);
    };

    // Milestones
    const capexPerMw = { solar: 1.05e6, wind: 1.30e6, hydro: 1.45e6 }[pin.type] || 1.2e6;
    const capexTL = pin.capacityMw * capexPerMw * 27; // USD→TL approx
    const breakEvenTargetKwh = capexTL / 2.45;
    const milestones = [];
    milestones.push({ day: 0, kind: 'start', label: 'Devreye Alındı', date: commissionDate });
    // breakeven
    for (let i = 0; i < curve.length; i++) {
      if (curve[i].cumKwh >= breakEvenTargetKwh) {
        milestones.push({ day: i * 30, kind: 'breakeven', label: 'Geri Ödeme', date: curve[i].monthDate });
        break;
      }
    }
    // peak past month
    let peakIdx = 0, peakVal = 0;
    for (let i = 1; i < curve.length; i++) {
      if (i * 30 <= todayDayIdx && curve[i].monthlyKwh > peakVal) {
        peakVal = curve[i].monthlyKwh; peakIdx = i;
      }
    }
    if (peakIdx > 0) milestones.push({ day: peakIdx * 30, kind: 'peak', label: 'Tepe Ay', date: curve[peakIdx].monthDate });
    // first GWh threshold
    for (let i = 0; i < curve.length; i++) {
      if (curve[i].cumKwh >= 1e6) {
        milestones.push({ day: i * 30, kind: 'first', label: '1 GWh', date: curve[i].monthDate });
        break;
      }
    }

    return { commissionDate, horizonDate, totalDays, todayDayIdx, curve, finalKwh, valueAtDay, bandFactor, milestones };
  }, [pin.id, pin.type, pin.capacityMw, pin.annualKwh, pin.monthly]);
}

// ============================================================================
// Sub-components
// ============================================================================
const TSPlayBtn = ({ playing, onClick, size = 36, accent }) => (
  <button onClick={onClick} aria-label={playing ? 'Duraklat' : 'Oynat'}
    style={{
      width: size, height: size, borderRadius: size / 2,
      background: playing ? 'rgba(255,255,255,.08)' : accent,
      border: `1px solid ${playing ? 'var(--border)' : accent}`,
      color: playing ? 'var(--text)' : '#0B0E14',
      cursor: 'pointer', display: 'grid', placeItems: 'center',
      boxShadow: playing ? 'none' : `0 0 0 6px ${accent}22`,
      transition: 'background .15s, box-shadow .15s',
    }}>
    {playing ? (
      <svg width={size*0.36} height={size*0.36} viewBox="0 0 12 12"><rect x="2" y="1.5" width="2.5" height="9" rx="0.7" fill="currentColor"/><rect x="7.5" y="1.5" width="2.5" height="9" rx="0.7" fill="currentColor"/></svg>
    ) : (
      <svg width={size*0.40} height={size*0.40} viewBox="0 0 12 12"><path d="M2.5 1.5 L10 6 L2.5 10.5 Z" fill="currentColor"/></svg>
    )}
  </button>
);

const TSIconBtn = ({ onClick, label, children, size = 28 }) => (
  <button onClick={onClick} aria-label={label} title={label}
    style={{
      width: size, height: size, borderRadius: 8, background: 'rgba(255,255,255,.05)',
      border: '1px solid var(--border)', color: 'var(--text-2)',
      cursor: 'pointer', display: 'grid', placeItems: 'center', padding: 0,
    }}>{children}</button>
);

const TSSpeed = ({ speed, setSpeed, options = [1, 4, 16] }) => (
  <div className="seg" style={{ padding: 2 }}>
    {options.map(s => (
      <button key={s} onClick={() => setSpeed(s)} className={speed === s ? 'on' : ''}
        style={{ padding: '5px 9px', font: '600 11px/1 var(--font-mono)', minWidth: 30 }}>
        {s}×
      </button>
    ))}
  </div>
);

const TSMetricSeg = ({ metric, setMetric, compact = false }) => {
  const items = [
    ['kwh', 'Üretim'],
    ['rev', compact ? '₺' : 'Gelir'],
    ['co2', 'CO₂'],
    ['home', compact ? 'Hane' : 'Hane'],
  ];
  return (
    <div className="seg" style={{ padding: 2 }}>
      {items.map(([k, lbl]) => (
        <button key={k} onClick={() => setMetric(k)} className={metric === k ? 'on' : ''}
          style={{ padding: compact ? '6px 8px' : '7px 11px', font: `${metric === k ? 600 : 500} 11.5px/1 var(--font)`, color: metric === k ? 'var(--text)' : 'var(--text-2)' }}>
          {lbl}
        </button>
      ))}
    </div>
  );
};

// Big focus readout — what the cursor shows right now
const TSFocusReadout = ({ tl, scrubDay, metric, pinColor, dense = false }) => {
  const m = TS_METRICS[metric];
  const cumKwh = tl.valueAtDay(scrubDay);
  const v = m.value(cumKwh);
  const accent = m.colorOverride || pinColor;
  const scrubDate = tsAddDays(tl.commissionDate, scrubDay);
  const dayFromStart = Math.round(scrubDay);
  const yrsSince = (scrubDay / 365);
  const isForecast = scrubDay > tl.todayDayIdx + 2;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: dense ? 2 : 4 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>
        <span className="label" style={{ font: '500 10px/1 var(--font)' }}>{m.label}</span>
        {isForecast && <span style={{ font: '600 9px/1 var(--font-mono)', color: 'var(--text-3)', padding: '3px 6px', background: 'rgba(255,255,255,.06)', borderRadius: 4, letterSpacing: '.04em' }}>TAHMİN · P50</span>}
        {!isForecast && scrubDay < tl.todayDayIdx - 2 && <span style={{ font: '600 9px/1 var(--font-mono)', color: 'var(--text-3)', padding: '3px 6px', background: 'rgba(255,255,255,.06)', borderRadius: 4, letterSpacing: '.04em' }}>GEÇMİŞ</span>}
        {Math.abs(scrubDay - tl.todayDayIdx) <= 2 && <span style={{ font: '600 9px/1 var(--font-mono)', color: pinColor, padding: '3px 6px', background: `${pinColor}1A`, borderRadius: 4, letterSpacing: '.04em' }}>● BUGÜN</span>}
      </div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
        <span className="tnum" style={{ font: `700 ${dense ? 28 : 38}px/1 var(--font)`, color: accent, letterSpacing: '-.025em' }}>{m.format(v)}</span>
        <span style={{ font: `600 ${dense ? 12 : 14}px/1 var(--font)`, color: 'var(--text-2)' }}>{m.unitMain}</span>
      </div>
      <div style={{ font: '500 11.5px/1.3 var(--font)', color: 'var(--text-3)', fontVariantNumeric: 'tabular-nums', display: 'flex', alignItems: 'center', gap: 6, flexWrap: 'wrap' }}>
        <span>{tsFmtDate(scrubDate)}</span>
        <span style={{ color: 'var(--text-4)' }}>·</span>
        <span>{dayFromStart} gün ({yrsSince.toFixed(1)} yıl)</span>
      </div>
    </div>
  );
};

// Compact KPI mini card
const TSKpiMini = ({ label, value, unit, color, sub }) => (
  <div style={{ padding: '9px 10px', background: 'rgba(0,0,0,.22)', border: '1px solid var(--border-2)', borderRadius: 9, minWidth: 0 }}>
    <div className="label" style={{ font: '500 9.5px/1 var(--font)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{label}</div>
    <div style={{ display: 'flex', alignItems: 'baseline', gap: 3, marginTop: 5 }}>
      <span className="tnum" style={{ font: '700 16px/1 var(--font)', color, letterSpacing: '-.01em' }}>{value}</span>
      {unit && <span style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)' }}>{unit}</span>}
    </div>
    {sub && <div className="tnum" style={{ font: '500 9.5px/1.3 var(--font-mono)', color: 'var(--text-3)', marginTop: 3, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{sub}</div>}
  </div>
);

// ============================================================================
// Chart — the heart of the widget
// ============================================================================
const TSChart = ({ tl, scrubDay, setScrubDay, setPlaying, metric, pinColor, height = 240, showAxis = true, showMilestones = true, showLegend = true }) => {
  const W = 1140; // viewBox width
  const padL = 50, padR = 16, padT = 16, padB = showAxis ? 28 : 12;
  const plotW = W - padL - padR;
  const plotH = height - padT - padB;
  const m = TS_METRICS[metric];
  const accent = m.colorOverride || pinColor;
  const isTypeMetric = !m.colorOverride;

  // Convert all curve points to display value
  const points = tl.curve.map(c => m.value(c.cumKwh));
  const maxV = Math.max(...points) * 1.05;
  const yFor = (v) => padT + plotH - (v / maxV) * plotH;
  const xFor = (day) => padL + (day / tl.totalDays) * plotW;

  // Build past line (commission → today) and forecast line (today → horizon)
  const pastPts = tl.curve.filter(c => c.dayIdx <= tl.todayDayIdx + 30);
  const fcPts   = tl.curve.filter(c => c.dayIdx >= tl.todayDayIdx);
  const pathFor = (pts) => pts.map((c, i) => `${i ? 'L' : 'M'} ${xFor(c.dayIdx).toFixed(1)} ${yFor(m.value(c.cumKwh)).toFixed(1)}`).join(' ');
  const pastPath = pathFor(pastPts);
  const fcPath = pathFor(fcPts);

  // Past area fill
  const areaPath = `${pastPath} L ${xFor(pastPts[pastPts.length - 1].dayIdx)} ${padT + plotH} L ${padL} ${padT + plotH} Z`;

  // Confidence band over forecast (P10/P90)
  const bandHi = fcPts.map(c => ({ day: c.dayIdx, v: m.value(c.cumKwh) * (1 + tl.bandFactor(c.dayIdx)) }));
  const bandLo = fcPts.map(c => ({ day: c.dayIdx, v: m.value(c.cumKwh) * (1 - tl.bandFactor(c.dayIdx)) }));
  const bandPath = (() => {
    const top = bandHi.map((p, i) => `${i ? 'L' : 'M'} ${xFor(p.day).toFixed(1)} ${yFor(p.v).toFixed(1)}`).join(' ');
    const bottom = bandLo.slice().reverse().map(p => `L ${xFor(p.day).toFixed(1)} ${yFor(p.v).toFixed(1)}`).join(' ');
    return `${top} ${bottom} Z`;
  })();

  // X axis ticks: year boundaries
  const xTicks = [];
  for (let y = tl.commissionDate.getFullYear(); y <= tl.horizonDate.getFullYear(); y++) {
    const d = new Date(y, 0, 1);
    const day = tsDayDiff(tl.commissionDate, d);
    if (day >= 0 && day <= tl.totalDays) xTicks.push({ day, label: y.toString() });
  }

  // Y ticks: 4 ticks
  const yTicks = [0, 0.25, 0.5, 0.75, 1].map(t => ({ v: t * maxV, label: m.yTick(t * maxV) }));

  // Drag interaction
  const svgRef = useRefTS();
  const draggingRef = useRefTS(false);

  const dayFromClientX = useCallbackTS((clientX) => {
    if (!svgRef.current) return scrubDay;
    const rect = svgRef.current.getBoundingClientRect();
    const ratioX = (clientX - rect.left) / rect.width;
    const xVB = ratioX * W;
    const dayRatio = (xVB - padL) / plotW;
    return Math.max(0, Math.min(tl.totalDays, dayRatio * tl.totalDays));
  }, [tl.totalDays, scrubDay]);

  const onPointerDown = useCallbackTS((e) => {
    setPlaying && setPlaying(false);
    draggingRef.current = true;
    setScrubDay(dayFromClientX(e.clientX));
    e.preventDefault();
    e.stopPropagation();
  }, [dayFromClientX, setPlaying, setScrubDay]);

  useEffectTS(() => {
    const move = (e) => { if (draggingRef.current) setScrubDay(dayFromClientX(e.clientX)); };
    const up = () => { draggingRef.current = false; };
    window.addEventListener('pointermove', move);
    window.addEventListener('pointerup', up);
    return () => { window.removeEventListener('pointermove', move); window.removeEventListener('pointerup', up); };
  }, [dayFromClientX, setScrubDay]);

  const scrubX = xFor(scrubDay);
  const scrubV = m.value(tl.valueAtDay(scrubDay));
  const scrubY = yFor(scrubV);
  const todayX = xFor(tl.todayDayIdx);

  const gid = `tsfill-${(useIdTS() || 'x').replace(/:/g, '')}-${metric}`;

  return (
    <svg ref={svgRef} viewBox={`0 0 ${W} ${height}`} style={{ width: '100%', height: 'auto', display: 'block', cursor: 'ew-resize', touchAction: 'none' }}
      onPointerDown={onPointerDown}>
      <defs>
        <linearGradient id={gid} x1="0" x2="0" y1="0" y2="1">
          <stop offset="0" stopColor={accent} stopOpacity="0.35"/>
          <stop offset="1" stopColor={accent} stopOpacity="0"/>
        </linearGradient>
      </defs>

      {/* y grid */}
      {yTicks.map(t => (
        <g key={t.v}>
          <line x1={padL} x2={W - padR} y1={yFor(t.v)} y2={yFor(t.v)} stroke="rgba(255,255,255,.04)"/>
          <text x={padL - 7} y={yFor(t.v) + 3} textAnchor="end" fontSize="9" fill="rgba(255,255,255,.45)" fontFamily="JetBrains Mono, monospace">{t.label}</text>
        </g>
      ))}
      <text x={padL - 42} y={padT - 4} fontSize="8.5" fill="rgba(255,255,255,.45)" fontFamily="Inter">{m.unitMain}</text>

      {/* x ticks */}
      {showAxis && xTicks.map(t => (
        <g key={t.label}>
          <line x1={xFor(t.day)} x2={xFor(t.day)} y1={padT + plotH} y2={padT + plotH + 4} stroke="rgba(255,255,255,.18)"/>
          <text x={xFor(t.day)} y={padT + plotH + 16} textAnchor="middle" fontSize="9.5" fill="rgba(255,255,255,.50)" fontFamily="JetBrains Mono, monospace">{t.label}</text>
        </g>
      ))}

      {/* forecast band */}
      <path d={bandPath} fill={accent} opacity="0.10"/>

      {/* past area + line */}
      <path d={areaPath} fill={`url(#${gid})`}/>
      <path d={pastPath} fill="none" stroke={accent} strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"/>
      <path d={fcPath} fill="none" stroke={accent} strokeWidth="2" strokeDasharray="4 4" strokeLinecap="round" strokeOpacity="0.7"/>

      {/* today vertical reference */}
      <line x1={todayX} x2={todayX} y1={padT} y2={padT + plotH} stroke="rgba(255,255,255,.20)" strokeDasharray="2 3"/>
      <text x={todayX} y={padT - 5} textAnchor="middle" fontSize="9" fill="rgba(255,255,255,.55)" fontFamily="JetBrains Mono, monospace">BUGÜN</text>

      {/* milestones */}
      {showMilestones && tl.milestones.map((ms, i) => {
        const x = xFor(ms.day);
        const y = yFor(m.value(tl.valueAtDay(ms.day)));
        const color = ms.kind === 'breakeven' ? '#10B981' : ms.kind === 'peak' ? '#F59E0B' : ms.kind === 'first' ? accent : 'var(--text-3)';
        return (
          <g key={i}>
            <line x1={x} x2={x} y1={padT + plotH - 4} y2={padT + plotH + 1} stroke={color} strokeWidth="1.5"/>
            <circle cx={x} cy={y} r="3.5" fill="#0B0E14" stroke={color} strokeWidth="1.6"/>
          </g>
        );
      })}

      {/* scrub vertical line */}
      <line x1={scrubX} x2={scrubX} y1={padT} y2={padT + plotH} stroke={accent} strokeWidth="1.2" opacity="0.9"/>
      {/* scrub current value bubble */}
      <g transform={`translate(${scrubX} ${padT + 8})`}>
        <rect x="-32" y="0" width="64" height="20" rx="4" fill={accent} opacity="0.95"/>
        <text x="0" y="14" textAnchor="middle" fontSize="11" fill="#0B0E14" fontFamily="JetBrains Mono, monospace" fontWeight="700">{m.format(scrubV)} {m.unitMain}</text>
      </g>
      <circle cx={scrubX} cy={scrubY} r="6" fill={accent} stroke="#0B0E14" strokeWidth="2.5"/>
      <circle cx={scrubX} cy={scrubY} r="11" fill={accent} opacity="0.18"/>

      {/* legend */}
      {showLegend && (
        <g transform={`translate(${padL}, ${height - 4})`}>
          <line x1="0" x2="14" y1="0" y2="0" stroke={accent} strokeWidth="2"/>
          <text x="18" y="3" fontSize="9.5" fill="rgba(255,255,255,.55)" fontFamily="Inter">Gerçekleşen</text>
          <line x1="80" x2="94" y1="0" y2="0" stroke={accent} strokeWidth="2" strokeDasharray="3 2" opacity="0.7"/>
          <text x="98" y="3" fontSize="9.5" fill="rgba(255,255,255,.55)" fontFamily="Inter">Tahmin P50</text>
          <rect x="155" y="-4" width="14" height="8" fill={accent} opacity="0.18"/>
          <text x="173" y="3" fontSize="9.5" fill="rgba(255,255,255,.55)" fontFamily="Inter">Güven aralığı P10–P90</text>
        </g>
      )}
    </svg>
  );
};

// ============================================================================
// Layouts per variant
// ============================================================================
const TimeSimulation = ({ pin, variant = 'desktop' }) => {
  const tl = useTimelineTS(pin);
  const pinColor = TS_TC[pin.type];
  const typeLabel = { solar: 'GES', wind: 'RES', hydro: 'HES' }[pin.type];

  const [scrubDay, setScrubDay] = useStateTS(tl.todayDayIdx);
  const [playing, setPlaying] = useStateTS(false);
  const [speed, setSpeed] = useStateTS(4);
  const [metric, setMetric] = useStateTS('kwh');

  // Reset scrub when pin changes
  useEffectTS(() => { setScrubDay(tl.todayDayIdx); setPlaying(false); }, [pin.id, tl.todayDayIdx]);

  // Animation
  const rafRef = useRefTS();
  const lastT = useRefTS(0);
  const scrubRef = useRefTS(scrubDay);
  scrubRef.current = scrubDay;
  useEffectTS(() => {
    if (!playing) { lastT.current = 0; return; }
    const tick = (now) => {
      if (!lastT.current) lastT.current = now;
      const dt = (now - lastT.current) / 1000;
      lastT.current = now;
      const dps = 90 * speed; // days per second
      const next = scrubRef.current + dps * dt;
      if (next >= tl.totalDays) { setScrubDay(tl.totalDays); setPlaying(false); return; }
      setScrubDay(next);
      rafRef.current = requestAnimationFrame(tick);
    };
    rafRef.current = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(rafRef.current);
  }, [playing, speed, tl.totalDays]);

  const handleReset = () => { setPlaying(false); setScrubDay(tl.todayDayIdx); };
  const handlePlay = () => {
    if (scrubDay >= tl.totalDays - 1) setScrubDay(0);
    setPlaying(p => !p);
  };
  const handleJumpStart = () => { setPlaying(false); setScrubDay(0); };
  const handleJumpEnd = () => { setPlaying(false); setScrubDay(tl.totalDays); };
  const handleJumpToday = () => { setPlaying(false); setScrubDay(tl.todayDayIdx); };

  // KPI snapshot values for current scrub
  const cumKwh = tl.valueAtDay(scrubDay);
  const yrsSince = scrubDay / 365;
  const annualAvg = yrsSince > 0.1 ? cumKwh / yrsSince : pin.annualKwh;
  const cumRev = cumKwh * 2.45;
  const cumCO2 = cumKwh * 0.689;
  const cumHomes = cumKwh / 3500;
  const capacityFactor = (pin.annualKwh / (pin.capacityMw * 1000 * 8760)) * 100;
  const finalKwh = tl.finalKwh;
  const finalRev = finalKwh * 2.45;

  // ===== DESKTOP =====
  if (variant === 'desktop') {
    return (
      <div style={{ width: '100%', padding: 18, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 14, color: 'var(--text)' }}>
        {/* Header */}
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 14, marginBottom: 14 }}>
          <div style={{ width: 38, height: 38, borderRadius: 10, background: `${pinColor}1A`, border: `1px solid ${pinColor}55`, display: 'grid', placeItems: 'center', flexShrink: 0 }}>
            <Icon name={pin.type === 'solar' ? 'sun' : pin.type === 'wind' ? 'wind' : 'water'} size={18} color={pinColor}/>
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, flexWrap: 'wrap' }}>
              <span style={{ font: '700 15px/1 var(--font)', color: 'var(--text)', letterSpacing: '-.01em' }}>Zaman Simülasyonu</span>
              <span style={{ font: '500 11px/1 var(--font-mono)', color: 'var(--text-3)', letterSpacing: '.04em' }}>{typeLabel} · {pin.name || `Santral #${pin.id}`}</span>
              <span style={{ font: '500 11px/1 var(--font-mono)', color: pinColor, padding: '3px 7px', background: `${pinColor}15`, borderRadius: 4 }}>{pin.capacityMw} MW</span>
            </div>
            <div style={{ font: '500 11.5px/1.4 var(--font)', color: 'var(--text-3)', marginTop: 5 }}>
              {tsFmtDate(tl.commissionDate)} → {tsFmtDate(tl.horizonDate)} · {(tl.totalDays/365).toFixed(1)} yıl pencere · kapasite faktörü %{capacityFactor.toFixed(1)}
            </div>
          </div>
          <TSMetricSeg metric={metric} setMetric={setMetric}/>
        </div>

        {/* Big focus + KPIs row */}
        <div style={{ display: 'grid', gridTemplateColumns: 'minmax(0, 1.3fr) minmax(0, 2fr)', gap: 14, marginBottom: 14 }}>
          <div style={{ padding: '14px 16px', background: 'rgba(0,0,0,.30)', border: '1px solid var(--border-2)', borderRadius: 12 }}>
            <TSFocusReadout tl={tl} scrubDay={scrubDay} metric={metric} pinColor={pinColor}/>
            <div style={{ marginTop: 10, paddingTop: 10, borderTop: '1px dashed var(--border-2)', display: 'flex', gap: 14, font: '500 11px/1.4 var(--font)', color: 'var(--text-3)' }}>
              <div>
                <div className="label" style={{ font: '500 9.5px/1 var(--font)', marginBottom: 4 }}>Ort. Yıllık</div>
                <div className="tnum" style={{ font: '600 13px/1 var(--font-mono)', color: 'var(--text-2)' }}>{(annualAvg/1e6).toFixed(1)} GWh</div>
              </div>
              <div>
                <div className="label" style={{ font: '500 9.5px/1 var(--font)', marginBottom: 4 }}>Yatırım Yaşı</div>
                <div className="tnum" style={{ font: '600 13px/1 var(--font-mono)', color: 'var(--text-2)' }}>{yrsSince.toFixed(1)} yıl</div>
              </div>
              <div>
                <div className="label" style={{ font: '500 9.5px/1 var(--font)', marginBottom: 4 }}>Hedef Hor.</div>
                <div className="tnum" style={{ font: '600 13px/1 var(--font-mono)', color: 'var(--text-2)' }}>{(finalKwh/1e6).toFixed(0)} GWh</div>
              </div>
            </div>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0, 1fr))', gap: 9 }}>
            <TSKpiMini label="ÜRETİM (kümülatif)" value={(cumKwh/1e6).toFixed(1)} unit="GWh" color={pinColor}
              sub={`${(cumKwh / pin.annualKwh).toFixed(2)}× yıllık`}/>
            <TSKpiMini label="GELİR" value={`${(cumRev/1e6).toFixed(1)}M`} unit="₺" color="#10B981"
              sub={`₺2.45/kWh tarife`}/>
            <TSKpiMini label="CO₂ ÖNLENDİ" value={(cumCO2/1e6).toFixed(1)} unit="kton" color="#10B981"
              sub={`${Math.round(cumCO2/4600).toLocaleString('tr-TR')} araç eşd.`}/>
            <TSKpiMini label="HANE EŞDEĞERİ" value={cumHomes >= 1e3 ? `${(cumHomes/1e3).toFixed(1)}K` : Math.round(cumHomes).toLocaleString('tr-TR')} unit="hane·yıl" color="#A78BFA"
              sub={`3,500 kWh/yıl/hane`}/>
          </div>
        </div>

        {/* Chart */}
        <div style={{ background: 'rgba(0,0,0,.20)', border: '1px solid var(--border-2)', borderRadius: 12, padding: '10px 12px' }}>
          <TSChart tl={tl} scrubDay={scrubDay} setScrubDay={setScrubDay} setPlaying={setPlaying} metric={metric} pinColor={pinColor} height={250}/>
        </div>

        {/* Controls */}
        <div style={{ marginTop: 12, display: 'flex', alignItems: 'center', gap: 14, flexWrap: 'wrap' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <TSIconBtn onClick={handleJumpStart} label="Başa dön" size={32}>
              <svg width="14" height="14" viewBox="0 0 14 14"><rect x="1" y="2" width="1.5" height="10" rx=".5" fill="currentColor"/><path d="M12 2 L4 7 L12 12 Z" fill="currentColor"/></svg>
            </TSIconBtn>
            <TSPlayBtn playing={playing} onClick={handlePlay} size={42} accent={pinColor}/>
            <TSIconBtn onClick={handleJumpEnd} label="Sona git" size={32}>
              <svg width="14" height="14" viewBox="0 0 14 14"><path d="M2 2 L10 7 L2 12 Z" fill="currentColor"/><rect x="11.5" y="2" width="1.5" height="10" rx=".5" fill="currentColor"/></svg>
            </TSIconBtn>
            <TSIconBtn onClick={handleJumpToday} label="Bugüne dön" size={32}>
              <svg width="13" height="13" viewBox="0 0 13 13" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"><circle cx="6.5" cy="6.5" r="4.5"/><path d="M6.5 4 V6.5 L8 8"/></svg>
            </TSIconBtn>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span className="label" style={{ font: '500 10px/1 var(--font)' }}>Hız</span>
            <TSSpeed speed={speed} setSpeed={setSpeed}/>
            <span className="tnum" style={{ font: '500 10px/1 var(--font-mono)', color: 'var(--text-3)' }}>~{Math.round(90 * speed / 30)} ay/sn</span>
          </div>
          <div style={{ flex: 1 }}/>
          <div style={{ display: 'flex', gap: 12, font: '500 11px/1 var(--font)' }}>
            {tl.milestones.map((ms, i) => {
              const color = ms.kind === 'breakeven' ? '#10B981' : ms.kind === 'peak' ? '#F59E0B' : ms.kind === 'first' ? pinColor : 'var(--text-3)';
              return (
                <button key={i} onClick={() => { setPlaying(false); setScrubDay(ms.day); }}
                  style={{ display: 'inline-flex', alignItems: 'center', gap: 5, padding: '5px 9px', background: 'rgba(255,255,255,.04)', border: '1px solid var(--border-2)', borderRadius: 7, cursor: 'pointer', color: 'var(--text-2)', font: 'inherit' }}>
                  <span style={{ width: 7, height: 7, borderRadius: 4, background: color }}/>
                  <span>{ms.label}</span>
                  <span className="tnum" style={{ color: 'var(--text-4)', fontFamily: 'var(--font-mono)', fontSize: 10 }}>{tsFmtYrMon(ms.date)}</span>
                </button>
              );
            })}
          </div>
        </div>
      </div>
    );
  }

  // ===== TABLET =====
  if (variant === 'tablet') {
    return (
      <div style={{ width: '100%', padding: 14, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 14, color: 'var(--text)' }}>
        {/* Header */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}>
          <div style={{ width: 32, height: 32, borderRadius: 9, background: `${pinColor}1A`, border: `1px solid ${pinColor}55`, display: 'grid', placeItems: 'center' }}>
            <Icon name={pin.type === 'solar' ? 'sun' : pin.type === 'wind' ? 'wind' : 'water'} size={15} color={pinColor}/>
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ font: '700 13.5px/1 var(--font)', letterSpacing: '-.01em' }}>Zaman Simülasyonu</div>
            <div style={{ font: '500 10.5px/1.3 var(--font-mono)', color: 'var(--text-3)', marginTop: 3 }}>{typeLabel} · {pin.capacityMw} MW · {(tl.totalDays/365).toFixed(1)}y pencere</div>
          </div>
          <TSMetricSeg metric={metric} setMetric={setMetric} compact/>
        </div>

        {/* Focus readout */}
        <div style={{ padding: '12px 14px', background: 'rgba(0,0,0,.28)', border: '1px solid var(--border-2)', borderRadius: 11, marginBottom: 10 }}>
          <TSFocusReadout tl={tl} scrubDay={scrubDay} metric={metric} pinColor={pinColor} dense/>
        </div>

        {/* KPI row 2x2 */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 8, marginBottom: 10 }}>
          <TSKpiMini label="ÜRETİM" value={(cumKwh/1e6).toFixed(1)} unit="GWh" color={pinColor} sub={`${(cumKwh / pin.annualKwh).toFixed(2)}× yıllık`}/>
          <TSKpiMini label="GELİR" value={`${(cumRev/1e6).toFixed(1)}M`} unit="₺" color="#10B981" sub="₺2.45/kWh"/>
          <TSKpiMini label="CO₂" value={(cumCO2/1e6).toFixed(1)} unit="kton" color="#10B981" sub={`${Math.round(cumCO2/4600).toLocaleString('tr-TR')} araç`}/>
          <TSKpiMini label="HANE" value={cumHomes >= 1e3 ? `${(cumHomes/1e3).toFixed(1)}K` : Math.round(cumHomes).toString()} unit="hane·yıl" color="#A78BFA" sub="3.5K kWh/hane"/>
        </div>

        {/* Chart */}
        <div style={{ background: 'rgba(0,0,0,.20)', border: '1px solid var(--border-2)', borderRadius: 11, padding: '8px 10px', marginBottom: 10 }}>
          <TSChart tl={tl} scrubDay={scrubDay} setScrubDay={setScrubDay} setPlaying={setPlaying} metric={metric} pinColor={pinColor} height={220} showLegend={false}/>
        </div>

        {/* Controls — single row */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <TSIconBtn onClick={handleJumpStart} label="Başa" size={30}>
              <svg width="13" height="13" viewBox="0 0 14 14"><rect x="1" y="2" width="1.5" height="10" rx=".5" fill="currentColor"/><path d="M12 2 L4 7 L12 12 Z" fill="currentColor"/></svg>
            </TSIconBtn>
            <TSPlayBtn playing={playing} onClick={handlePlay} size={38} accent={pinColor}/>
            <TSIconBtn onClick={handleJumpToday} label="Bugüne dön" size={30}>
              <svg width="12" height="12" viewBox="0 0 13 13" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"><circle cx="6.5" cy="6.5" r="4.5"/><path d="M6.5 4 V6.5 L8 8"/></svg>
            </TSIconBtn>
          </div>
          <TSSpeed speed={speed} setSpeed={setSpeed}/>
          <div style={{ flex: 1 }}/>
          <div style={{ display: 'flex', gap: 6 }}>
            {tl.milestones.slice(0, 4).map((ms, i) => {
              const color = ms.kind === 'breakeven' ? '#10B981' : ms.kind === 'peak' ? '#F59E0B' : ms.kind === 'first' ? pinColor : 'var(--text-3)';
              return (
                <button key={i} onClick={() => { setPlaying(false); setScrubDay(ms.day); }}
                  style={{ display: 'inline-flex', alignItems: 'center', gap: 4, padding: '5px 8px', background: 'rgba(255,255,255,.04)', border: '1px solid var(--border-2)', borderRadius: 6, cursor: 'pointer', color: 'var(--text-2)', font: '500 10.5px/1 var(--font)' }}>
                  <span style={{ width: 6, height: 6, borderRadius: 3, background: color }}/>
                  <span>{ms.label}</span>
                </button>
              );
            })}
          </div>
        </div>
      </div>
    );
  }

  // ===== MOBILE =====
  return (
    <div style={{ width: '100%', padding: 12, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12, color: 'var(--text)' }}>
      {/* compact header */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
        <div style={{ width: 26, height: 26, borderRadius: 7, background: `${pinColor}1A`, border: `1px solid ${pinColor}55`, display: 'grid', placeItems: 'center' }}>
          <Icon name={pin.type === 'solar' ? 'sun' : pin.type === 'wind' ? 'wind' : 'water'} size={13} color={pinColor}/>
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ font: '700 12px/1 var(--font)' }}>Zaman Simülasyonu</div>
          <div style={{ font: '500 9.5px/1.3 var(--font-mono)', color: 'var(--text-3)', marginTop: 2, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{typeLabel} · {pin.capacityMw}MW</div>
        </div>
      </div>

      {/* Focus readout */}
      <div style={{ padding: 10, background: 'rgba(0,0,0,.30)', border: '1px solid var(--border-2)', borderRadius: 10, marginBottom: 8 }}>
        <TSFocusReadout tl={tl} scrubDay={scrubDay} metric={metric} pinColor={pinColor} dense/>
      </div>

      {/* metric segmented (full width) */}
      <div style={{ marginBottom: 8 }}>
        <div className="seg" style={{ padding: 2, width: '100%', display: 'flex' }}>
          {[['kwh','Üretim'],['rev','Gelir'],['co2','CO₂'],['home','Hane']].map(([k, lbl]) => (
            <button key={k} onClick={() => setMetric(k)} className={metric === k ? 'on' : ''}
              style={{ flex: 1, padding: '7px 4px', font: `${metric === k ? 600 : 500} 11px/1 var(--font)`, color: metric === k ? 'var(--text)' : 'var(--text-2)' }}>
              {lbl}
            </button>
          ))}
        </div>
      </div>

      {/* Chart — compact */}
      <div style={{ background: 'rgba(0,0,0,.20)', border: '1px solid var(--border-2)', borderRadius: 9, padding: '6px 8px', marginBottom: 8 }}>
        <TSChart tl={tl} scrubDay={scrubDay} setScrubDay={setScrubDay} setPlaying={setPlaying} metric={metric} pinColor={pinColor} height={180} showLegend={false} showAxis/>
      </div>

      {/* Controls compact */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
        <TSIconBtn onClick={handleJumpStart} label="Başa" size={28}>
          <svg width="11" height="11" viewBox="0 0 14 14"><rect x="1" y="2" width="1.5" height="10" rx=".5" fill="currentColor"/><path d="M12 2 L4 7 L12 12 Z" fill="currentColor"/></svg>
        </TSIconBtn>
        <TSPlayBtn playing={playing} onClick={handlePlay} size={36} accent={pinColor}/>
        <TSIconBtn onClick={handleJumpToday} label="Bugün" size={28}>
          <svg width="11" height="11" viewBox="0 0 13 13" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"><circle cx="6.5" cy="6.5" r="4.5"/><path d="M6.5 4 V6.5 L8 8"/></svg>
        </TSIconBtn>
        <div style={{ flex: 1 }}/>
        <TSSpeed speed={speed} setSpeed={setSpeed} options={[1, 4, 16]}/>
      </div>

      {/* Milestones — chip row */}
      <div style={{ display: 'flex', gap: 5, overflowX: 'auto', paddingBottom: 2 }} className="scroll">
        {tl.milestones.map((ms, i) => {
          const color = ms.kind === 'breakeven' ? '#10B981' : ms.kind === 'peak' ? '#F59E0B' : ms.kind === 'first' ? pinColor : 'var(--text-3)';
          return (
            <button key={i} onClick={() => { setPlaying(false); setScrubDay(ms.day); }}
              style={{ flexShrink: 0, display: 'inline-flex', alignItems: 'center', gap: 4, padding: '5px 8px', background: 'rgba(255,255,255,.04)', border: '1px solid var(--border-2)', borderRadius: 6, cursor: 'pointer', color: 'var(--text-2)', font: '500 10px/1 var(--font)' }}>
              <span style={{ width: 6, height: 6, borderRadius: 3, background: color }}/>
              <span style={{ whiteSpace: 'nowrap' }}>{ms.label}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
};

Object.assign(window, { TimeSimulation, useTimelineTS, TS_METRICS, TS_TC });
