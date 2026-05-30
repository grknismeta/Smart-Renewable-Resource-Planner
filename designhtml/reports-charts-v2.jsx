// reports-charts-v2.jsx — Advanced visualizations: HourlyProfile, LossWaterfall, TornadoChart, FanArea

// =============== HourlyProfile: typical 24h day curve (multi-source) ===============
const HourlyProfile = ({ height = 200, width = 720 }) => {
  // synthetic typical day for solar (peak noon), wind (night/dawn), hydro (steady), demand (peaks 9am, 7pm)
  const hours = Array.from({length: 25}, (_, i) => i);
  const solar = hours.map(h => h < 6 || h > 19 ? 0 : Math.max(0, Math.sin((h - 6) / 13 * Math.PI)) * 0.96);
  const wind = hours.map(h => 0.55 + 0.28 * Math.sin(h * 0.27 + 1.2) + 0.12 * Math.cos(h * 0.42));
  const hydro = hours.map(() => 0.62);
  const demand = hours.map(h => 0.55 + 0.32 * Math.exp(-((h - 9) ** 2) / 4) + 0.40 * Math.exp(-((h - 19) ** 2) / 3));

  const padL = 40, padR = 12, padT = 12, padB = 28;
  const w = width - padL - padR, h = height - padT - padB;
  const xFor = i => padL + (i / 24) * w;
  const yFor = v => padT + h - v * h;

  const path = (arr) => arr.map((v, i) => `${i ? 'L' : 'M'} ${xFor(i).toFixed(1)} ${yFor(v).toFixed(1)}`).join(' ');
  const area = (arr, baseline = 0) => `${path(arr)} L ${xFor(24)} ${yFor(baseline)} L ${padL} ${yFor(baseline)} Z`;

  return (
    <svg viewBox={`0 0 ${width} ${height}`} style={{ width: '100%', height: 'auto', display: 'block' }}>
      <defs>
        <linearGradient id="solarG" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0" stopColor="#F59E0B" stopOpacity="0.4"/>
          <stop offset="1" stopColor="#F59E0B" stopOpacity="0"/>
        </linearGradient>
      </defs>
      {/* grid */}
      {[0, 0.25, 0.5, 0.75, 1].map(v => (
        <g key={v}>
          <line x1={padL} x2={width-padR} y1={yFor(v)} y2={yFor(v)} stroke="rgba(255,255,255,.05)" strokeWidth="1"/>
          <text x={padL-6} y={yFor(v)+3} textAnchor="end" fontSize="9" fill="rgba(255,255,255,.45)" fontFamily="JetBrains Mono, monospace">{(v*100).toFixed(0)}%</text>
        </g>
      ))}
      {/* solar fill */}
      <path d={area(solar)} fill="url(#solarG)"/>
      {/* lines */}
      <path d={path(solar)} fill="none" stroke="#F59E0B" strokeWidth="2.2" strokeLinecap="round"/>
      <path d={path(wind)}  fill="none" stroke="#3B82F6" strokeWidth="2.2" strokeLinecap="round" strokeDasharray="0"/>
      <path d={path(hydro)} fill="none" stroke="#06B6D4" strokeWidth="2"  strokeLinecap="round" strokeDasharray="4 3"/>
      <path d={path(demand)} fill="none" stroke="rgba(255,255,255,.55)" strokeWidth="1.5" strokeLinecap="round" strokeDasharray="2 4"/>
      {/* peak markers */}
      <circle cx={xFor(12.5)} cy={yFor(0.96)} r="3" fill="#F59E0B" stroke="#0B0E14" strokeWidth="1.5"/>
      <text x={xFor(12.5)} y={yFor(0.96)-7} textAnchor="middle" fontSize="9" fill="#F59E0B" fontFamily="JetBrains Mono, monospace" fontWeight="600">PEAK · 12:30</text>
      {/* x ticks */}
      {[0, 6, 12, 18, 24].map(hr => (
        <g key={hr}>
          <text x={xFor(hr)} y={height-12} textAnchor="middle" fontSize="9.5" fill="rgba(255,255,255,.55)" fontFamily="JetBrains Mono, monospace">{hr.toString().padStart(2,'0')}:00</text>
        </g>
      ))}
      <text x={padL-30} y={padT+8} fontSize="8" fill="rgba(255,255,255,.4)" fontFamily="Inter">% kap.</text>
    </svg>
  );
};

// =============== LossWaterfall: theoretical → actual generation losses ===============
const LossWaterfall = ({ height = 220, width = 720 }) => {
  // values in GWh — theoretical max, then subtractive losses
  const items = [
    { label: 'Teorik Max',  value: 940, type: 'start' },
    { label: 'Topografya',   value: -22, type: 'loss' },
    { label: 'Soğurma',      value: -18, type: 'loss' },
    { label: 'Inverter',     value: -12, type: 'loss' },
    { label: 'Dejenerasyon', value: -16, type: 'loss' },
    { label: 'Toz / soiling', value: -14, type: 'loss' },
    { label: 'Şebeke',       value:  -8, type: 'loss' },
    { label: 'Kısıntı',      value:  -7, type: 'loss' },
    { label: 'Gerçek',       value: 843, type: 'end' },
  ];
  const padL = 16, padR = 16, padT = 30, padB = 60;
  const w = width - padL - padR;
  const hArea = height - padT - padB;
  const slot = w / items.length;
  const bw = slot * 0.62;
  // compute running totals for connectors
  let running = items[0].value;
  const points = [{ value: items[0].value, from: 0, to: items[0].value }];
  for (let i = 1; i < items.length; i++) {
    const it = items[i];
    if (it.type === 'end') {
      points.push({ value: it.value, from: 0, to: it.value });
    } else {
      const next = running + it.value;
      points.push({ value: it.value, from: running, to: next });
      running = next;
    }
  }
  const maxVal = Math.max(...points.flatMap(p => [p.from, p.to]));
  const yFor = v => padT + hArea - (v / maxVal) * hArea;

  return (
    <svg viewBox={`0 0 ${width} ${height}`} style={{ width: '100%', height: 'auto', display: 'block' }}>
      {/* y-axis ticks */}
      {[0, 250, 500, 750, 940].map(v => (
        <g key={v}>
          <line x1={padL} x2={width-padR} y1={yFor(v)} y2={yFor(v)} stroke="rgba(255,255,255,.04)" strokeWidth="1"/>
          <text x={padL-2} y={yFor(v)-3} textAnchor="start" fontSize="9" fill="rgba(255,255,255,.35)" fontFamily="JetBrains Mono, monospace">{v}</text>
        </g>
      ))}
      {items.map((it, i) => {
        const p = points[i];
        const cx = padL + slot * (i + 0.5);
        const x = cx - bw / 2;
        const yTop = yFor(Math.max(p.from, p.to));
        const yBot = yFor(Math.min(p.from, p.to));
        const bh = Math.max(2, yBot - yTop);
        const col = it.type === 'start' ? '#3B82F6' : it.type === 'end' ? '#10B981' : '#EF4444';
        return (
          <g key={i}>
            {/* connector */}
            {i < items.length - 1 && items[i+1].type === 'loss' && (
              <line x1={cx + bw/2} x2={padL + slot * (i+1.5) - bw/2} y1={yFor(p.to)} y2={yFor(p.to)} stroke="rgba(255,255,255,.20)" strokeWidth="1" strokeDasharray="2 3"/>
            )}
            {/* connector to end */}
            {it.type === 'loss' && i === items.length - 2 && (
              <line x1={cx + bw/2} x2={padL + slot * (i+1.5) - bw/2} y1={yFor(p.to)} y2={yFor(p.to)} stroke="rgba(255,255,255,.20)" strokeWidth="1" strokeDasharray="2 3"/>
            )}
            <rect x={x} y={yTop} width={bw} height={bh} rx="3" fill={col} fillOpacity={it.type === 'start' || it.type === 'end' ? 1 : 0.85}/>
            <text x={cx} y={yTop - 6} textAnchor="middle" fontSize="10" fill={col} fontFamily="JetBrains Mono, monospace" fontWeight="600">
              {it.type === 'loss' ? `${it.value}` : `${it.value}`}
            </text>
            {/* label */}
            <text x={cx} y={height - 32} textAnchor="middle" fontSize="10" fill="rgba(255,255,255,.7)" fontFamily="Inter" fontWeight={it.type !== 'loss' ? 600 : 500}>{it.label}</text>
            {it.type !== 'loss' && (
              <text x={cx} y={height - 16} textAnchor="middle" fontSize="9" fill="rgba(255,255,255,.4)" fontFamily="Inter">GWh</text>
            )}
            {it.type === 'loss' && (
              <text x={cx} y={height - 16} textAnchor="middle" fontSize="9" fill="rgba(255,255,255,.4)" fontFamily="JetBrains Mono, monospace">−{Math.abs((it.value / 940) * 100).toFixed(1)}%</text>
            )}
          </g>
        );
      })}
      {/* overall efficiency badge */}
      <g transform={`translate(${width-130}, ${padT+4})`}>
        <rect x="0" y="0" width="120" height="36" rx="8" fill="rgba(16,185,129,.10)" stroke="rgba(16,185,129,.30)" strokeWidth="1"/>
        <text x="10" y="14" fontSize="9" fill="rgba(255,255,255,.55)" fontFamily="Inter" letterSpacing=".06em">PERFORMANS ORANI</text>
        <text x="10" y="29" fontSize="14" fill="#10B981" fontFamily="JetBrains Mono, monospace" fontWeight="700">89.7%</text>
      </g>
    </svg>
  );
};

// =============== TornadoChart: sensitivity analysis ===============
// each variable shows downside (red) / upside (green) impact on NPV
const TornadoChart = ({ items, baseline, width = 720, height = 240, currency = '$' }) => {
  // items: [{ label, low, high, lowDelta, highDelta }]  delta in % vs baseline
  const padL = 180, padR = 80, padT = 30, padB = 24;
  const w = width - padL - padR, hArea = height - padT - padB;
  const rowH = hArea / items.length;
  const maxAbs = Math.max(...items.flatMap(it => [Math.abs(it.lowDelta), Math.abs(it.highDelta)]));
  const xCenter = padL + w / 2;
  const xFor = (delta) => xCenter + (delta / maxAbs) * (w / 2);
  return (
    <svg viewBox={`0 0 ${width} ${height}`} style={{ width: '100%', height: 'auto', display: 'block' }}>
      {/* center axis (baseline) */}
      <line x1={xCenter} x2={xCenter} y1={padT-6} y2={padT+hArea+4} stroke="rgba(255,255,255,.30)" strokeWidth="1.5"/>
      <text x={xCenter} y={padT-12} textAnchor="middle" fontSize="9.5" fill="rgba(255,255,255,.6)" fontFamily="Inter" letterSpacing=".06em">BASELİNE NPV · {currency}{baseline.toFixed(1)}M</text>
      {/* % scale ticks */}
      {[-1, -0.5, 0.5, 1].map(t => {
        const x = xCenter + t * (w / 2);
        return (
          <g key={t}>
            <line x1={x} x2={x} y1={padT-2} y2={padT+hArea+2} stroke="rgba(255,255,255,.04)" strokeWidth="1"/>
            <text x={x} y={height - 8} textAnchor="middle" fontSize="9" fill="rgba(255,255,255,.4)" fontFamily="JetBrains Mono, monospace">{t > 0 ? '+' : ''}{(t * maxAbs).toFixed(0)}%</text>
          </g>
        );
      })}
      {items.map((it, i) => {
        const y = padT + i * rowH + rowH * 0.5;
        const xLow = xFor(it.lowDelta);   // negative side
        const xHigh = xFor(it.highDelta); // positive side
        const bH = rowH * 0.52;
        return (
          <g key={it.label}>
            {/* variable label */}
            <text x={padL-12} y={y+3} textAnchor="end" fontSize="11.5" fill="rgba(255,255,255,.85)" fontFamily="Inter" fontWeight="500">{it.label}</text>
            {/* downside bar */}
            <rect x={Math.min(xCenter, xLow)} y={y-bH/2} width={Math.abs(xCenter - xLow)} height={bH} fill="#EF4444" fillOpacity="0.78" rx="2"/>
            <text x={xLow - 5} y={y+3} textAnchor="end" fontSize="9.5" fill="#FCA5A5" fontFamily="JetBrains Mono, monospace" fontWeight="600">{it.lowDelta.toFixed(1)}%</text>
            <text x={xLow - 5} y={y+13} textAnchor="end" fontSize="8.5" fill="rgba(252,165,165,.6)" fontFamily="Inter">{it.lowLabel}</text>
            {/* upside bar */}
            <rect x={xCenter} y={y-bH/2} width={Math.abs(xHigh - xCenter)} height={bH} fill="#10B981" fillOpacity="0.78" rx="2"/>
            <text x={xHigh + 5} y={y+3} textAnchor="start" fontSize="9.5" fill="#86EFAC" fontFamily="JetBrains Mono, monospace" fontWeight="600">+{it.highDelta.toFixed(1)}%</text>
            <text x={xHigh + 5} y={y+13} textAnchor="start" fontSize="8.5" fill="rgba(134,239,172,.6)" fontFamily="Inter">{it.highLabel}</text>
          </g>
        );
      })}
    </svg>
  );
};

// =============== FanAreaChart: cashflow with P50/P90 uncertainty bands ===============
const FanAreaChart = ({ data, height = 220, width = 720, paybackYear }) => {
  // generate symmetric bands around data: P50 ±12%, P90 ±25%
  const p50Up = data.map(v => v * 1.12);
  const p50Lo = data.map(v => v * 0.88);
  const p90Up = data.map(v => v * 1.25);
  const p90Lo = data.map(v => v * 0.75);
  const padL = 56, padR = 20, padT = 12, padB = 30;
  const w = width - padL - padR, h = height - padT - padB;
  const allVals = [...data, ...p90Up, ...p90Lo];
  const min = Math.min(...allVals), max = Math.max(...allVals);
  const range = max - min;
  const xStep = w / (data.length - 1);
  const yFor = v => padT + h - ((v - min) / range) * h;
  const xFor = i => padL + i * xStep;
  const zeroY = yFor(0);

  const band = (up, lo) => {
    let d = `M ${xFor(0)} ${yFor(up[0])}`;
    for (let i = 1; i < up.length; i++) d += ` L ${xFor(i)} ${yFor(up[i])}`;
    for (let i = lo.length - 1; i >= 0; i--) d += ` L ${xFor(i)} ${yFor(lo[i])}`;
    return d + ' Z';
  };
  const line = (arr) => arr.map((v, i) => `${i ? 'L' : 'M'} ${xFor(i)} ${yFor(v)}`).join(' ');

  const fmt = v => {
    const m = v / 1e6;
    return m > 0 ? `+$${m.toFixed(0)}M` : `-$${Math.abs(m).toFixed(0)}M`;
  };

  return (
    <svg viewBox={`0 0 ${width} ${height}`} style={{ width: '100%', height: 'auto', display: 'block' }}>
      <defs>
        <linearGradient id="fanG" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0" stopColor="#14B8A6" stopOpacity="0.5"/>
          <stop offset="1" stopColor="#14B8A6" stopOpacity="0"/>
        </linearGradient>
      </defs>
      {/* grid */}
      {[min, min + range*0.25, min + range*0.5, min + range*0.75, max].map((v, i) => (
        <g key={i}>
          <line x1={padL} x2={width-padR} y1={yFor(v)} y2={yFor(v)} stroke="rgba(255,255,255,.05)" strokeWidth="1"/>
          <text x={padL-6} y={yFor(v)+3} textAnchor="end" fontSize="9" fill="rgba(255,255,255,.45)" fontFamily="JetBrains Mono, monospace">{fmt(v)}</text>
        </g>
      ))}
      <line x1={padL} x2={width-padR} y1={zeroY} y2={zeroY} stroke="rgba(255,255,255,.20)" strokeWidth="1" strokeDasharray="3 3"/>
      {/* P90 band */}
      <path d={band(p90Up, p90Lo)} fill="#14B8A6" fillOpacity="0.10"/>
      {/* P50 band */}
      <path d={band(p50Up, p50Lo)} fill="#14B8A6" fillOpacity="0.20"/>
      {/* median line */}
      <path d={line(data)} fill="none" stroke="#2DD4BF" strokeWidth="2.4" strokeLinejoin="round" strokeLinecap="round"/>
      {/* P50 outline dashed */}
      <path d={line(p50Up)} fill="none" stroke="rgba(45,212,191,.6)" strokeWidth="1" strokeDasharray="3 3"/>
      <path d={line(p50Lo)} fill="none" stroke="rgba(45,212,191,.6)" strokeWidth="1" strokeDasharray="3 3"/>
      {/* payback marker */}
      {paybackYear > 0 && paybackYear < data.length && (
        <g>
          <line x1={xFor(paybackYear)} x2={xFor(paybackYear)} y1={padT} y2={padT+h} stroke="rgba(20,184,166,.55)" strokeWidth="1" strokeDasharray="2 3"/>
          <circle cx={xFor(paybackYear)} cy={zeroY} r="4" fill="#14B8A6" stroke="#0B0E14" strokeWidth="2"/>
        </g>
      )}
      {/* labels */}
      <g transform={`translate(${xFor(data.length - 1) - 70}, ${yFor(p90Up[p90Up.length-1])})`}>
        <text x="0" y="0" fontSize="9.5" fill="rgba(20,184,166,.55)" fontFamily="JetBrains Mono, monospace">P90</text>
      </g>
      <g transform={`translate(${xFor(data.length - 1) - 70}, ${yFor(p50Up[p50Up.length-1])-2})`}>
        <text x="0" y="0" fontSize="9.5" fill="rgba(45,212,191,.85)" fontFamily="JetBrains Mono, monospace">P50</text>
      </g>
      <g transform={`translate(${xFor(data.length - 1) - 70}, ${yFor(data[data.length-1])-4})`}>
        <text x="0" y="0" fontSize="9.5" fill="#2DD4BF" fontFamily="JetBrains Mono, monospace" fontWeight="700">MEDYAN</text>
      </g>
      {/* x ticks */}
      {[0, 5, 10, 15, 20, 25].map(y => (
        <text key={y} x={xFor(y)} y={padT + h + 16} textAnchor="middle" fontSize="9.5" fill="rgba(255,255,255,.55)" fontFamily="Inter">Yıl {y}</text>
      ))}
    </svg>
  );
};

Object.assign(window, { HourlyProfile, LossWaterfall, TornadoChart, FanAreaChart });
