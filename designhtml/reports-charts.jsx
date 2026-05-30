// reports-charts.jsx — bespoke visualizations for the SRRP reports module

// =============== StackedMonthlyBars: monthly production by type ===============
const StackedMonthlyBars = ({ data, height = 220, width = 720 }) => {
  const months = ['Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'];
  const totals = months.map((_, i) => data.solar[i] + data.wind[i] + data.hydro[i]);
  const max = Math.max(...totals) * 1.15;
  const colSolar = '#F59E0B', colWind = '#3B82F6', colHydro = '#06B6D4';
  const padL = 36, padR = 12, padT = 8, padB = 22;
  const w = width - padL - padR, h = height - padT - padB;
  const bw = w / 12;
  // y axis ticks
  const ticks = 4;
  const tickStep = max / ticks;
  return (
    <svg viewBox={`0 0 ${width} ${height}`} style={{ width: '100%', height: 'auto', display: 'block' }}>
      {/* grid */}
      {Array.from({length: ticks+1}).map((_, i) => {
        const y = padT + h - (i / ticks) * h;
        return (
          <g key={i}>
            <line x1={padL} x2={width-padR} y1={y} y2={y} stroke="rgba(255,255,255,.06)" strokeWidth="1"/>
            <text x={padL-6} y={y+3} textAnchor="end" fontSize="9" fill="rgba(255,255,255,.45)" fontFamily="JetBrains Mono, monospace">{Math.round(i*tickStep)}</text>
          </g>
        );
      })}
      <text x={padL-30} y={padT+8} fontSize="8" fill="rgba(255,255,255,.4)" fontFamily="Inter" textAnchor="start">GWh</text>
      {/* bars */}
      {months.map((m, i) => {
        const x = padL + i * bw + bw * 0.20;
        const barW = bw * 0.60;
        const sH = (data.solar[i] / max) * h;
        const wH = (data.wind[i] / max)  * h;
        const hH = (data.hydro[i] / max) * h;
        let cursor = padT + h;
        return (
          <g key={m}>
            <rect x={x} y={(cursor -= hH)} width={barW} height={hH} fill={colHydro} rx={1.5}/>
            <rect x={x} y={(cursor -= wH)} width={barW} height={wH} fill={colWind} rx={1.5}/>
            <rect x={x} y={(cursor -= sH)} width={barW} height={sH} fill={colSolar} rx={1.5}/>
            <text x={x + barW/2} y={padT + h + 14} textAnchor="middle" fontSize="9.5" fill="rgba(255,255,255,.55)" fontFamily="Inter">{m}</text>
          </g>
        );
      })}
    </svg>
  );
};

// =============== AreaLineChart: 25-year cumulative cashflow ===============
const AreaLineChart = ({ data, height = 200, width = 720, color = '#10B981', paybackYear }) => {
  const padL = 50, padR = 16, padT = 10, padB = 26;
  const w = width - padL - padR, h = height - padT - padB;
  const min = Math.min(...data), max = Math.max(...data);
  const range = max - min;
  const xStep = w / (data.length - 1);
  const yFor = v => padT + h - ((v - min) / range) * h;
  const xFor = i => padL + i * xStep;
  const points = data.map((v, i) => `${xFor(i).toFixed(1)},${yFor(v).toFixed(1)}`).join(' ');
  // zero line
  const zeroY = yFor(0);
  // fill area
  const areaD = `M ${padL},${padT+h} L ${data.map((v,i)=>`${xFor(i).toFixed(1)},${yFor(v).toFixed(1)}`).join(' L ')} L ${padL+w},${padT+h} Z`;
  // y ticks (in millions $)
  const tickN = 4;
  const fmt = v => {
    const m = v / 1e6;
    return m > 0 ? `+$${m.toFixed(0)}M` : `-$${Math.abs(m).toFixed(0)}M`;
  };
  return (
    <svg viewBox={`0 0 ${width} ${height}`} style={{ width: '100%', height: 'auto', display: 'block' }}>
      <defs>
        <linearGradient id="cashfill" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0" stopColor={color} stopOpacity="0.35"/>
          <stop offset="1" stopColor={color} stopOpacity="0.0"/>
        </linearGradient>
      </defs>
      {/* y grid + ticks */}
      {Array.from({length: tickN+1}).map((_, i) => {
        const v = min + (range * i) / tickN;
        const y = yFor(v);
        return (
          <g key={i}>
            <line x1={padL} x2={width-padR} y1={y} y2={y} stroke="rgba(255,255,255,.06)" strokeWidth="1"/>
            <text x={padL-6} y={y+3} textAnchor="end" fontSize="9" fill="rgba(255,255,255,.45)" fontFamily="JetBrains Mono, monospace">{fmt(v)}</text>
          </g>
        );
      })}
      {/* zero line */}
      <line x1={padL} x2={width-padR} y1={zeroY} y2={zeroY} stroke="rgba(255,255,255,.20)" strokeWidth="1" strokeDasharray="3 3"/>
      {/* area */}
      <path d={areaD} fill="url(#cashfill)"/>
      {/* line */}
      <polyline points={points} fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
      {/* payback marker */}
      {paybackYear > 0 && paybackYear < data.length && (
        <g>
          <line x1={xFor(paybackYear)} x2={xFor(paybackYear)} y1={padT} y2={padT+h} stroke="rgba(20,184,166,.55)" strokeWidth="1" strokeDasharray="2 3"/>
          <circle cx={xFor(paybackYear)} cy={zeroY} r="4" fill="#14B8A6" stroke="#0B0E14" strokeWidth="2"/>
          <rect x={xFor(paybackYear)-32} y={padT-3} width="64" height="16" rx="3" fill="rgba(20,184,166,.18)" stroke="rgba(20,184,166,.55)" strokeWidth="1"/>
          <text x={xFor(paybackYear)} y={padT+8} textAnchor="middle" fontSize="9.5" fill="#2DD4BF" fontFamily="JetBrains Mono, monospace" fontWeight="600">Geri Ödeme · {paybackYear}y</text>
        </g>
      )}
      {/* x ticks every 5 years */}
      {[0, 5, 10, 15, 20, 25].map(y => (
        <text key={y} x={xFor(y)} y={padT + h + 16} textAnchor="middle" fontSize="9.5" fill="rgba(255,255,255,.55)" fontFamily="Inter">Yıl {y}</text>
      ))}
    </svg>
  );
};

// =============== Donut: resource mix ===============
const DonutChart = ({ segments, size = 160, thickness = 22, centerLabel, centerValue, centerUnit }) => {
  const r = (size - thickness) / 2;
  const circ = 2 * Math.PI * r;
  const total = segments.reduce((s, x) => s + x.value, 0);
  let acc = 0;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ overflow: 'visible' }}>
      <circle cx={size/2} cy={size/2} r={r} fill="none" stroke="rgba(255,255,255,.06)" strokeWidth={thickness}/>
      {segments.map((s, i) => {
        const dash = (s.value / total) * circ;
        const offset = -((acc) / total) * circ;
        acc += s.value;
        return (
          <circle key={i} cx={size/2} cy={size/2} r={r}
            fill="none" stroke={s.color} strokeWidth={thickness}
            strokeDasharray={`${dash - 1.2} ${circ}`}
            strokeDashoffset={offset}
            transform={`rotate(-90 ${size/2} ${size/2})`}
            strokeLinecap="butt"/>
        );
      })}
      {centerValue !== undefined && (
        <g>
          <text x={size/2} y={size/2 - 6} textAnchor="middle" fontSize="11" fill="rgba(255,255,255,.5)" fontFamily="Inter" letterSpacing=".06em">{centerLabel}</text>
          <text x={size/2} y={size/2 + 16} textAnchor="middle" fontSize="24" fill="#fff" fontFamily="Inter" fontWeight="700" style={{ fontVariantNumeric: 'tabular-nums' }}>{centerValue}</text>
          <text x={size/2} y={size/2 + 30} textAnchor="middle" fontSize="10" fill="rgba(255,255,255,.5)" fontFamily="Inter">{centerUnit}</text>
        </g>
      )}
    </svg>
  );
};

// =============== HeatmapCalendar: daily production over a year ===============
const HeatmapCalendar = ({ data, width = 720, height = 110 }) => {
  // 53 weeks × 7 days grid
  const cell = 11, gap = 2;
  const cols = 53, rows = 7;
  const gridW = cols * (cell + gap);
  const padL = 28, padT = 12, padB = 14;
  const max = Math.max(...data);
  const color = (v) => {
    const t = v / max;
    if (t < 0.10) return 'rgba(255,255,255,.04)';
    if (t < 0.30) return 'rgba(20,184,166,.18)';
    if (t < 0.55) return 'rgba(20,184,166,.40)';
    if (t < 0.80) return 'rgba(20,184,166,.70)';
    return 'rgba(45,212,191,1)';
  };
  const dayLabels = ['Pzt','','Çar','','Cum','',''];
  const monthLabels = ['Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'];
  return (
    <svg viewBox={`0 0 ${padL + gridW + 8} ${height}`} style={{ width: '100%', height: 'auto', display: 'block' }}>
      {/* day labels */}
      {dayLabels.map((l, i) => l && (
        <text key={i} x={padL - 4} y={padT + i * (cell + gap) + cell - 1} textAnchor="end" fontSize="8.5" fill="rgba(255,255,255,.45)" fontFamily="Inter">{l}</text>
      ))}
      {/* month labels */}
      {monthLabels.map((m, i) => (
        <text key={m} x={padL + (i * 53 / 12) * (cell + gap) + 4} y={padT - 3} fontSize="9" fill="rgba(255,255,255,.5)" fontFamily="Inter">{m}</text>
      ))}
      {/* cells */}
      {data.map((v, d) => {
        const col = Math.floor(d / 7);
        const row = d % 7;
        return <rect key={d} x={padL + col * (cell + gap)} y={padT + row * (cell + gap)} width={cell} height={cell} rx="2" fill={color(v)}/>;
      })}
      {/* legend */}
      <g transform={`translate(${padL + gridW - 110}, ${height - 8})`}>
        <text x="-6" y="3" textAnchor="end" fontSize="8.5" fill="rgba(255,255,255,.5)" fontFamily="Inter">az</text>
        {[0.05, 0.25, 0.50, 0.75, 0.95].map((t, i) => (
          <rect key={i} x={i * 12} y="-7" width="10" height="10" rx="2" fill={color(t * max)}/>
        ))}
        <text x={66} y="3" fontSize="8.5" fill="rgba(255,255,255,.5)" fontFamily="Inter">çok</text>
      </g>
    </svg>
  );
};

// =============== Waterfall: financial breakdown ===============
const Waterfall = ({ items, width = 720, height = 220 }) => {
  // items = [{ label, value, type: 'in'|'out'|'total' }]
  const padL = 16, padR = 16, padT = 28, padB = 50;
  const w = width - padL - padR;
  const h = height - padT - padB;
  // compute cumulative levels
  let running = 0;
  const bars = items.map((it, i) => {
    if (it.type === 'total') {
      const b = { ...it, from: 0, to: it.value, abs: it.value };
      return b;
    }
    const from = running;
    const to = it.type === 'in' ? running + it.value : running - it.value;
    running = to;
    return { ...it, from, to, abs: Math.abs(it.value) };
  });
  const allVals = bars.flatMap(b => [b.from, b.to]);
  const min = Math.min(0, ...allVals);
  const max = Math.max(...allVals);
  const range = max - min;
  const yFor = v => padT + h - ((v - min) / range) * h;
  const bw = w / items.length * 0.55;
  const slot = w / items.length;
  const colorFor = (t) => t === 'in' ? '#10B981' : t === 'out' ? '#EF4444' : '#14B8A6';
  return (
    <svg viewBox={`0 0 ${width} ${height}`} style={{ width: '100%', height: 'auto', display: 'block' }}>
      {/* zero line */}
      <line x1={padL} x2={width-padR} y1={yFor(0)} y2={yFor(0)} stroke="rgba(255,255,255,.15)" strokeWidth="1" strokeDasharray="3 3"/>
      {bars.map((b, i) => {
        const cx = padL + slot * (i + 0.5);
        const x = cx - bw/2;
        const yTop = yFor(Math.max(b.from, b.to));
        const yBot = yFor(Math.min(b.from, b.to));
        const bh = Math.max(2, yBot - yTop);
        const col = colorFor(b.type);
        return (
          <g key={i}>
            {/* connector line to next bar (running value) */}
            {i < bars.length - 1 && bars[i+1].type !== 'total' && (
              <line x1={cx + bw/2} x2={padL + slot * (i + 1.5) - bw/2} y1={yFor(b.to)} y2={yFor(b.to)} stroke="rgba(255,255,255,.20)" strokeWidth="1" strokeDasharray="2 2"/>
            )}
            <rect x={x} y={yTop} width={bw} height={bh} rx="3" fill={col} fillOpacity={b.type === 'total' ? 1 : 0.85}/>
            {/* value */}
            <text x={cx} y={yTop - 6} textAnchor="middle" fontSize="10.5" fill={col} fontFamily="JetBrains Mono, monospace" fontWeight="600">
              {b.type === 'out' ? '−' : b.type === 'in' ? '+' : ''}${(b.abs/1e6).toFixed(1)}M
            </text>
            {/* label */}
            <text x={cx} y={height - 28} textAnchor="middle" fontSize="10" fill="rgba(255,255,255,.7)" fontFamily="Inter" fontWeight="500">{b.label}</text>
            <text x={cx} y={height - 14} textAnchor="middle" fontSize="9" fill="rgba(255,255,255,.4)" fontFamily="Inter">{b.note || ''}</text>
          </g>
        );
      })}
    </svg>
  );
};

// =============== ProgressBar with split (mix bar) ===============
const MixBar = ({ segments, height = 8 }) => {
  const total = segments.reduce((s, x) => s + x.value, 0);
  return (
    <div style={{ display: 'flex', height, width: '100%', borderRadius: 4, overflow: 'hidden', background: 'rgba(255,255,255,.05)' }}>
      {segments.map((s, i) => (
        <div key={i} style={{ width: `${(s.value/total)*100}%`, background: s.color, borderRight: i < segments.length - 1 ? '1px solid #0B0E14' : 'none' }}/>
      ))}
    </div>
  );
};

// =============== Mini choropleth-ish map for the report ===============
const ReportMiniMap = ({ pins, height = 240 }) => {
  return (
    <svg viewBox="0 0 1000 600" preserveAspectRatio="xMidYMid meet" style={{ width: '100%', height, display: 'block' }}>
      <defs>
        <linearGradient id="rmland" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0" stopColor="#1d2532"/>
          <stop offset="1" stopColor="#161B26"/>
        </linearGradient>
      </defs>
      <path d="M40 280 C 80 220, 160 200, 230 220 C 300 200, 380 230, 470 210 C 560 200, 640 220, 730 200 C 820 200, 900 230, 970 270 C 990 320, 950 360, 880 380 C 800 410, 700 410, 600 400 C 500 410, 400 400, 320 410 C 240 405, 160 390, 90 360 C 50 340, 30 310, 40 280 Z"
        fill="url(#rmland)" stroke="rgba(255,255,255,.10)" strokeWidth="1"/>
      {/* faint roads */}
      <g stroke="rgba(255,255,255,.06)" strokeWidth="1" fill="none">
        <path d="M 100 320 Q 280 300, 460 330 T 880 320"/>
        <path d="M 150 260 Q 350 280, 540 270 T 920 290"/>
      </g>
      {/* city dots */}
      <g fill="rgba(255,255,255,.10)">
        {Array.from({length: 60}).map((_, i) => {
          const x = 80 + (i * 73) % 880;
          const y = 240 + ((i*131) % 160);
          return <circle key={i} cx={x} cy={y} r="1.3"/>;
        })}
      </g>
      {/* report pins */}
      {pins.map(p => {
        const pos = PIN_MAP_POS[p.id];
        if (!pos) return null;
        const c = TYPES[p.type].color === 'var(--solar)' ? '#F59E0B' : TYPES[p.type].color === 'var(--wind)' ? '#3B82F6' : '#06B6D4';
        const r = 4 + Math.min(8, Math.sqrt(p.capacityMw) * 1.2);
        return (
          <g key={p.id}>
            <circle cx={pos.x} cy={pos.y} r={r + 4} fill={c} opacity="0.20"/>
            <circle cx={pos.x} cy={pos.y} r={r} fill={c} stroke="#0B0E14" strokeWidth="1.5"/>
          </g>
        );
      })}
    </svg>
  );
};

// =============== Tiny KPI delta arrow ===============
const Delta = ({ value, suffix = '%', positiveGood = true }) => {
  const pos = value > 0;
  const good = pos === positiveGood;
  const col = good ? '#10B981' : '#EF4444';
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3, color: col, font: '600 11px/1 var(--font-mono)' }}>
      <svg width="10" height="10" viewBox="0 0 10 10"><path d={pos ? "M5 1 L9 6 H6 V9 H4 V6 H1 Z" : "M5 9 L1 4 H4 V1 H6 V4 H9 Z"} fill={col}/></svg>
      {Math.abs(value).toFixed(1)}{suffix}
    </span>
  );
};

Object.assign(window, { StackedMonthlyBars, AreaLineChart, DonutChart, HeatmapCalendar, Waterfall, MixBar, ReportMiniMap, Delta });
