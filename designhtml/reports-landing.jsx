// reports-landing.jsx — Türkiye Overview Landing Page (entry hub for Raporlar)

const { useState: useStateL, useMemo: useMemoL } = React;

// ============================================================================
// Türkiye heatmap by region — clickable
// ============================================================================
const TurkeyRegionMap = ({ activeRegion, onRegionClick, byResource = 'all', height = 400 }) => {
  const colorFor = (region) => {
    if (byResource === 'all') return region.color;
    const map = { solar: '#F59E0B', wind: '#3B82F6', hydro: '#06B6D4' };
    const intensity = region.topResource === byResource ? 1 : (region.bestFor.includes(byResource) ? 0.55 : 0.20);
    return map[byResource] || region.color;
  };

  return (
    <svg viewBox="0 0 1000 600" preserveAspectRatio="xMidYMid meet" style={{ width: '100%', height, display: 'block' }}>
      <defs>
        <linearGradient id="tlandBg" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0" stopColor="#1a2030"/>
          <stop offset="1" stopColor="#10141d"/>
        </linearGradient>
        <filter id="glow" x="-20%" y="-20%" width="140%" height="140%">
          <feGaussianBlur stdDeviation="3" result="blur"/>
          <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
        </filter>
      </defs>
      {/* base landmass */}
      <path d="M40 280 C 80 220, 160 200, 230 220 C 300 200, 380 230, 470 210 C 560 200, 640 220, 730 200 C 820 200, 900 230, 970 270 C 990 320, 950 360, 880 380 C 800 410, 700 410, 600 400 C 500 410, 400 400, 320 410 C 240 405, 160 390, 90 360 C 50 340, 30 310, 40 280 Z"
        fill="url(#tlandBg)" stroke="rgba(255,255,255,.05)" strokeWidth="1"/>
      {/* regions */}
      {TR_REGIONS.map(r => {
        const isActive = activeRegion === r.id;
        const intensity = byResource === 'all' ? 0.55 :
          (r.topResource === byResource ? 0.85 : r.bestFor.includes(byResource) ? 0.45 : 0.15);
        const c = byResource === 'all' ? r.color : ({ solar: '#F59E0B', wind: '#3B82F6', hydro: '#06B6D4' }[byResource]);
        return (
          <g key={r.id} style={{ cursor: 'pointer' }} onClick={() => onRegionClick && onRegionClick(r.id)}>
            <path d={REGION_PATHS[r.id]} fill={c} fillOpacity={isActive ? 0.78 : intensity}
              stroke={isActive ? c : 'rgba(255,255,255,.08)'} strokeWidth={isActive ? 2 : 1}
              filter={isActive ? 'url(#glow)' : undefined}
              style={{ transition: 'all .2s' }}/>
          </g>
        );
      })}
      {/* region labels */}
      {TR_REGIONS.map(r => {
        const center = {
          marmara: [220, 252], ege: [205, 320], akdeniz: [430, 360],
          icanadolu: [450, 290], karadeniz: [560, 240],
          doguanadolu: [760, 320], gdanadolu: [680, 400],
        }[r.id];
        const isActive = activeRegion === r.id;
        return (
          <g key={r.id} pointerEvents="none">
            <text x={center[0]} y={center[1]} textAnchor="middle"
              fontSize={isActive ? 13 : 11} fontFamily="Inter, sans-serif" fontWeight={isActive ? 700 : 600}
              fill={isActive ? '#fff' : 'rgba(255,255,255,.85)'}>{r.name}</text>
            <text x={center[0]} y={center[1] + 13} textAnchor="middle"
              fontSize="9" fontFamily="JetBrains Mono, monospace"
              fill={isActive ? r.color : 'rgba(255,255,255,.55)'}>{(r.capacityMw/1000).toFixed(1)} GW</text>
          </g>
        );
      })}
    </svg>
  );
};

// ============================================================================
// Multi-line trend chart (capacity over 10 years)
// ============================================================================
const TrendChart = ({ data, width = 720, height = 220 }) => {
  const padL = 50, padR = 12, padT = 14, padB = 26;
  const w = width - padL - padR, h = height - padT - padB;
  const max = Math.max(...data.map(d => d.total)) * 1.05;
  const xStep = w / (data.length - 1);
  const xFor = i => padL + i * xStep;
  const yFor = v => padT + h - (v / max) * h;
  const totalPath = data.map((d, i) => `${i ? 'L' : 'M'} ${xFor(i).toFixed(1)} ${yFor(d.total).toFixed(1)}`).join(' ');
  const renPath = data.map((d, i) => `${i ? 'L' : 'M'} ${xFor(i).toFixed(1)} ${yFor(d.renewable).toFixed(1)}`).join(' ');
  const renArea = `${renPath} L ${xFor(data.length-1)} ${padT+h} L ${padL} ${padT+h} Z`;
  return (
    <svg viewBox={`0 0 ${width} ${height}`} style={{ width: '100%', height: 'auto', display: 'block' }}>
      <defs>
        <linearGradient id="trendG" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0" stopColor="#14B8A6" stopOpacity="0.40"/>
          <stop offset="1" stopColor="#14B8A6" stopOpacity="0"/>
        </linearGradient>
      </defs>
      {[0, 30, 60, 90, 120].map(v => (
        <g key={v}>
          <line x1={padL} x2={width-padR} y1={yFor(v)} y2={yFor(v)} stroke="rgba(255,255,255,.05)" strokeWidth="1"/>
          <text x={padL-5} y={yFor(v)+3} textAnchor="end" fontSize="9" fill="rgba(255,255,255,.45)" fontFamily="JetBrains Mono, monospace">{v}</text>
        </g>
      ))}
      <text x={padL-30} y={padT+8} fontSize="8" fill="rgba(255,255,255,.4)" fontFamily="Inter">GW</text>
      {/* renewable area */}
      <path d={renArea} fill="url(#trendG)"/>
      <path d={renPath} fill="none" stroke="#2DD4BF" strokeWidth="2.2" strokeLinecap="round"/>
      {/* total line */}
      <path d={totalPath} fill="none" stroke="rgba(255,255,255,.75)" strokeWidth="1.8" strokeDasharray="4 3" strokeLinecap="round"/>
      {/* points + final value */}
      {data.map((d, i) => i === data.length - 1 && (
        <g key={i}>
          <circle cx={xFor(i)} cy={yFor(d.renewable)} r="4" fill="#2DD4BF" stroke="#0B0E14" strokeWidth="2"/>
          <text x={xFor(i)+8} y={yFor(d.renewable)+4} fontSize="11" fill="#2DD4BF" fontFamily="JetBrains Mono, monospace" fontWeight="600">{d.renewable.toFixed(1)} GW</text>
          <circle cx={xFor(i)} cy={yFor(d.total)} r="3" fill="rgba(255,255,255,.85)" stroke="#0B0E14" strokeWidth="2"/>
          <text x={xFor(i)+8} y={yFor(d.total)-2} fontSize="11" fill="rgba(255,255,255,.85)" fontFamily="JetBrains Mono, monospace" fontWeight="600">{d.total.toFixed(1)} GW</text>
        </g>
      ))}
      {/* x labels */}
      {data.map((d, i) => (i % 2 === 0 || i === data.length-1) && (
        <text key={i} x={xFor(i)} y={padT+h+16} textAnchor="middle" fontSize="9.5" fill="rgba(255,255,255,.55)" fontFamily="JetBrains Mono, monospace">{d.year}</text>
      ))}
    </svg>
  );
};

// ============================================================================
// Resource type filter chips (used for region map)
// ============================================================================
const ResourceFilterChips = ({ active, onChange }) => (
  <div className="seg" style={{ background: 'rgba(0,0,0,.30)' }}>
    {[
      { id: 'all',   label: 'Tümü',   col: '#fff' },
      { id: 'solar', label: 'Güneş',  col: '#F59E0B' },
      { id: 'wind',  label: 'Rüzgar', col: '#3B82F6' },
      { id: 'hydro', label: 'Hidro',  col: '#06B6D4' },
    ].map(t => (
      <button key={t.id} onClick={() => onChange(t.id)}
        className={active === t.id ? 'on' : ''}
        style={{ padding: '6px 11px', font: '500 11.5px/1 var(--font)', color: active === t.id ? t.col : undefined }}>
        {t.id !== 'all' && <span style={{ display: 'inline-block', width: 7, height: 7, borderRadius: '50%', background: t.col, marginRight: 5 }}/>}
        {t.label}
      </button>
    ))}
  </div>
);

// ============================================================================
// QuickAccessCard — bottom strip with shortcut links to other reports
// ============================================================================
const QuickAccessCard = ({ icon, title, sub, count, color = 'var(--accent)', onClick }) => (
  <button onClick={onClick} style={{
    flex: 1, display: 'flex', alignItems: 'center', gap: 14,
    padding: '14px 16px',
    background: 'var(--card)',
    border: '1px solid var(--border)',
    borderRadius: 12, cursor: 'pointer', textAlign: 'left',
    transition: 'border-color .15s, background .15s', color: 'inherit',
  }}
  onMouseEnter={e => { e.currentTarget.style.borderColor = color; e.currentTarget.style.background = 'var(--card-2)'; }}
  onMouseLeave={e => { e.currentTarget.style.borderColor = 'var(--border)'; e.currentTarget.style.background = 'var(--card)'; }}>
    <div style={{ width: 38, height: 38, borderRadius: 10, background: `${color}22`, border: `1px solid ${color}55`, display: 'grid', placeItems: 'center', flexShrink: 0 }}>
      <Icon name={icon} size={18} color={color}/>
    </div>
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
        <span style={{ font: '600 13px/1.2 var(--font)', color: 'var(--text)' }}>{title}</span>
        {count !== undefined && <span className="tnum" style={{ font: '600 10px/1 var(--font-mono)', color, padding: '2px 6px', background: `${color}15`, borderRadius: 4 }}>{count}</span>}
      </div>
      <div style={{ font: '500 11px/1.4 var(--font)', color: 'var(--text-3)', marginTop: 5 }}>{sub}</div>
    </div>
    <Icon name="chevR" size={14} color="var(--text-3)"/>
  </button>
);

// ============================================================================
// LANDING PAGE — Desktop
// ============================================================================
const LandingDesktop = () => {
  const [resourceFilter, setResourceFilter] = useStateL('all');
  const [hoverRegion, setHoverRegion] = useStateL(null);
  const stats = TR_STATS;

  // sort provinces for top list
  const topProvinces = useMemoL(() => {
    return [...TR_PROVINCES]
      .filter(p => resourceFilter === 'all' || p.topRes === resourceFilter)
      .sort((a, b) => b.score - a.score)
      .slice(0, 10);
  }, [resourceFilter]);

  return (
    <div style={{ width: 1280, height: 2000, background: 'var(--bg)', display: 'flex', borderRadius: 12, overflow: 'hidden', border: '1px solid var(--border)', position: 'relative' }}>
      {/* nav rail */}
      <div style={{ width: 56, background: 'var(--bg-2)', borderRight: '1px solid var(--border)', display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '14px 0', gap: 6, flexShrink: 0 }}>
        <div style={{ width: 32, height: 32, borderRadius: 9, background: 'linear-gradient(135deg, var(--solar), var(--wind))', display: 'grid', placeItems: 'center', marginBottom: 8 }}>
          <Icon name="globe" size={16} color="white"/>
        </div>
        {[
          { i: 'globe', lbl: 'Harita' },
          { i: 'list',  lbl: 'Liste' },
          { i: 'roi',   lbl: 'Raporlar', on: true },
          { i: 'finance', lbl: 'Finans' },
        ].map((it, i) => (
          <button key={i} className="btn btn-icon btn-ghost" style={{ width: 40, height: 40, padding: 0, background: it.on ? 'rgba(20,184,166,.10)' : 'transparent', border: it.on ? '1px solid rgba(20,184,166,.4)' : '1px solid transparent' }}>
            <Icon name={it.i} size={17} color={it.on ? 'var(--accent)' : 'var(--text-3)'}/>
          </button>
        ))}
      </div>

      {/* main column */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minWidth: 0 }}>
        {/* toolbar */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '14px 24px', borderBottom: '1px solid var(--border)', background: 'rgba(20,24,34,.92)', backdropFilter: 'blur(14px)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ width: 30, height: 30, borderRadius: 8, background: 'rgba(20,184,166,.16)', border: '1px solid rgba(20,184,166,.4)', display: 'grid', placeItems: 'center' }}>
              <Icon name="roi" size={15} color="var(--accent)"/>
            </div>
            <div>
              <div style={{ font: '700 15px/1 var(--font)', letterSpacing: '-.01em' }}>Raporlar</div>
              <div style={{ font: '500 10.5px/1 var(--font)', color: 'var(--text-3)', marginTop: 4 }}>Türkiye yenilenebilir enerji analiz merkezi</div>
            </div>
          </div>
          <div style={{ flex: 1 }}/>
          <span className="chip"><span style={{ width: 6, height: 6, borderRadius: '50%', background: '#10B981' }}/>Canlı veri · TEİAŞ + EPDK</span>
          <button className="btn" style={{ padding: '7px 11px' }}><Icon name="filter" size={12}/></button>
          <button className="btn" style={{ padding: '7px 11px' }}><Icon name="ext" size={12}/> Dışa aktar</button>
        </div>

        {/* report tabs row */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 4, padding: '0 24px', background: 'rgba(0,0,0,.18)', borderBottom: '1px solid var(--border-2)', flexShrink: 0 }}>
          {[
            { id: 'landing',   label: 'Genel Bakış',     icon: 'globe',  on: true },
            { id: 'bolge',     label: 'Bölge Analizi',   icon: 'layers' },
            { id: 'il',        label: 'İl Analizi',      icon: 'pin' },
            { id: 'senaryo',   label: 'Senaryo Raporu',  icon: 'cal' },
            { id: 'santral',   label: 'Santral Analizi', icon: 'eq' },
          ].map(t => (
            <button key={t.id} style={{
              padding: '12px 14px',
              background: 'transparent', border: 'none',
              borderBottom: t.on ? '2px solid var(--accent)' : '2px solid transparent',
              cursor: 'pointer',
              display: 'flex', alignItems: 'center', gap: 7,
              font: t.on ? '600 12.5px/1 var(--font)' : '500 12.5px/1 var(--font)',
              color: t.on ? 'var(--text)' : 'var(--text-3)',
              transition: 'color .15s, border-color .15s',
            }}>
              <Icon name={t.icon} size={13} color={t.on ? 'var(--accent)' : 'var(--text-3)'}/>{t.label}
            </button>
          ))}
        </div>

        {/* scrollable content */}
        <div className="scroll" style={{ flex: 1, overflow: 'auto', padding: '24px 26px 50px' }}>

          {/* HERO */}
          <div style={{
            display: 'grid', gridTemplateColumns: '1.5fr 1fr', gap: 16, marginBottom: 22,
          }}>
            {/* Turkey map */}
            <div style={{
              padding: 18, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 14, position: 'relative', overflow: 'hidden',
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}>
                <span className="label" style={{ flex: 1 }}>Türkiye Yenilenebilir Enerji Potansiyeli</span>
                <ResourceFilterChips active={resourceFilter} onChange={setResourceFilter}/>
              </div>
              <TurkeyRegionMap activeRegion={hoverRegion} onRegionClick={setHoverRegion} byResource={resourceFilter} height={400}/>
              <div style={{ display: 'flex', gap: 8, marginTop: 6, paddingTop: 12, borderTop: '1px dashed var(--border-2)', flexWrap: 'wrap' }}>
                {TR_REGIONS.map(r => (
                  <div key={r.id} onClick={() => setHoverRegion(r.id)} style={{
                    display: 'flex', alignItems: 'center', gap: 6,
                    padding: '5px 9px', cursor: 'pointer',
                    background: hoverRegion === r.id ? `${r.color}18` : 'rgba(0,0,0,.18)',
                    border: hoverRegion === r.id ? `1px solid ${r.color}66` : '1px solid var(--border-2)',
                    borderRadius: 7,
                  }}>
                    <div style={{ width: 7, height: 7, borderRadius: '50%', background: r.color }}/>
                    <span style={{ font: '500 11px/1 var(--font)', color: hoverRegion === r.id ? 'var(--text)' : 'var(--text-2)' }}>{r.name}</span>
                    <span className="tnum" style={{ font: '500 10px/1 var(--font-mono)', color: 'var(--text-3)' }}>{(r.capacityMw/1000).toFixed(1)}GW</span>
                  </div>
                ))}
              </div>
            </div>

            {/* KPI tower */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              <div style={{
                padding: 18, borderRadius: 14, background: 'linear-gradient(160deg, rgba(20,184,166,.10), transparent 60%)',
                border: '1px solid rgba(20,184,166,.30)', position: 'relative', overflow: 'hidden',
              }}>
                <div style={{ position: 'absolute', right: -25, top: -25, width: 120, height: 120, borderRadius: '50%', background: 'radial-gradient(circle, rgba(20,184,166,.15), transparent 60%)' }}/>
                <div className="label" style={{ marginBottom: 6 }}>Toplam Kurulu Güç</div>
                <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
                  <span className="tnum" style={{ font: '700 42px/1 var(--font)', color: 'var(--accent)', letterSpacing: '-.02em' }}>{(stats.totalInstalledMw/1000).toFixed(1)}</span>
                  <span style={{ font: '600 16px/1 var(--font)', color: 'var(--text-2)' }}>GW</span>
                  <Delta value={+6.7} suffix="% YoY"/>
                </div>
                <div style={{ marginTop: 10, paddingTop: 10, borderTop: '1px dashed var(--border-2)' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', font: '500 11px/1 var(--font)', color: 'var(--text-3)', marginBottom: 6 }}>
                    <span>Yenilenebilir Pay</span>
                    <span className="tnum" style={{ color: 'var(--accent)', fontWeight: 700 }}>%{(stats.renewableShare*100).toFixed(1)}</span>
                  </div>
                  <div style={{ height: 6, background: 'rgba(255,255,255,.05)', borderRadius: 3, overflow: 'hidden' }}>
                    <div style={{ height: '100%', width: `${stats.renewableShare*100}%`, background: 'linear-gradient(90deg, var(--accent), #2DD4BF)', borderRadius: 3 }}/>
                  </div>
                  <div className="tnum" style={{ font: '500 10.5px/1.4 var(--font-mono)', color: 'var(--text-3)', marginTop: 6 }}>
                    {(stats.renewableMw/1000).toFixed(1)} GW yenilenebilir / {(stats.totalInstalledMw/1000).toFixed(1)} GW toplam
                  </div>
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
                <div style={{ padding: 14, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12 }}>
                  <div className="label">Yıllık Üretim</div>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: 4, marginTop: 6 }}>
                    <span className="tnum" style={{ font: '700 22px/1 var(--font)' }}>{Math.round(stats.annualProductionGwh/1000)}</span>
                    <span style={{ font: '500 11px/1 var(--font)', color: 'var(--text-3)' }}>TWh</span>
                  </div>
                  <div style={{ font: '500 10px/1.3 var(--font)', color: 'var(--text-3)', marginTop: 4 }}>Yenilenebilirden: <b className="tnum" style={{ color: 'var(--accent)' }}>{Math.round(stats.renewableProductionGwh/1000)} TWh</b></div>
                </div>
                <div style={{ padding: 14, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12 }}>
                  <div className="label">CO₂ Önlemesi</div>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: 4, marginTop: 6 }}>
                    <span className="tnum" style={{ font: '700 22px/1 var(--font)', color: '#10B981' }}>{Math.round(stats.co2AvoidedKtPerYear/1000)}</span>
                    <span style={{ font: '500 11px/1 var(--font)', color: 'var(--text-3)' }}>Mt/yıl</span>
                  </div>
                  <div style={{ font: '500 10px/1.3 var(--font)', color: 'var(--text-3)', marginTop: 4 }}>=12.5M araç eşdeğeri</div>
                </div>
              </div>

              <div style={{ padding: 14, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12 }}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
                  <span className="label">Kaynak Dağılımı</span>
                  <span className="tnum" style={{ font: '500 10.5px/1 var(--font-mono)', color: 'var(--text-3)' }}>{(stats.renewableMw/1000).toFixed(1)} GW</span>
                </div>
                <MixBar segments={[
                  { value: stats.hydroMw,     color: '#06B6D4' },
                  { value: stats.solarMw,     color: '#F59E0B' },
                  { value: stats.windMw,      color: '#3B82F6' },
                  { value: stats.geothermalMw + stats.biomassMw, color: '#A855F7' },
                ]} height={10}/>
                <div style={{ marginTop: 9, display: 'flex', flexDirection: 'column', gap: 5 }}>
                  {[
                    ['#06B6D4', 'Hidro',     stats.hydroMw],
                    ['#F59E0B', 'Güneş',     stats.solarMw],
                    ['#3B82F6', 'Rüzgar',    stats.windMw],
                    ['#A855F7', 'Jeotermal+Biyokütle', stats.geothermalMw + stats.biomassMw],
                  ].map(([col, l, v]) => (
                    <div key={l} style={{ display: 'flex', alignItems: 'center', gap: 7, font: '500 11px/1 var(--font)' }}>
                      <span style={{ width: 7, height: 7, borderRadius: 2, background: col }}/>
                      <span style={{ color: 'var(--text-2)', flex: 1 }}>{l}</span>
                      <span className="tnum" style={{ color: 'var(--text)', fontFamily: 'var(--font-mono)', fontWeight: 600 }}>{(v/1000).toFixed(1)}<span style={{ color: 'var(--text-3)', fontWeight: 500, fontSize: 9.5, marginLeft: 2 }}>GW</span></span>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>

          {/* SECTION: 7 BÖLGE KARTLARI */}
          <div style={{ marginBottom: 22 }}>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 12, marginBottom: 14 }}>
              <h2 style={{ margin: 0, font: '700 18px/1 var(--font)', letterSpacing: '-.01em' }}>Coğrafi Bölgeler</h2>
              <span style={{ font: '500 12px/1 var(--font)', color: 'var(--text-3)' }}>· 7 bölge · Bölge → İl → İlçe hiyerarşisi</span>
              <div style={{ flex: 1 }}/>
              <button className="btn" style={{ padding: '6px 11px' }}>Tüm bölgeler <Icon name="arrowR" size={11}/></button>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10 }}>
              {TR_REGIONS.slice(0, 4).map(r => <RegionCard key={r.id} region={r}/>)}
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10, marginTop: 10 }}>
              {TR_REGIONS.slice(4, 7).map(r => <RegionCard key={r.id} region={r}/>)}
            </div>
          </div>

          {/* SECTION: TOP 10 İL + TREND */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14, marginBottom: 22 }}>
            {/* Top 10 provinces */}
            <div style={{ padding: 16, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 14 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14 }}>
                <span className="label" style={{ flex: 1 }}>En Verimli 10 İl</span>
                <ResourceFilterChips active={resourceFilter} onChange={setResourceFilter}/>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 5 }}>
                {topProvinces.map((p, i) => {
                  const region = TR_REGIONS.find(r => r.id === p.region);
                  const c = TC[p.topRes];
                  return (
                    <div key={p.id} style={{
                      display: 'grid', gridTemplateColumns: '22px 1fr 70px 80px 80px',
                      gap: 10, alignItems: 'center', padding: '9px 10px',
                      background: i < 3 ? 'rgba(255,255,255,.025)' : 'transparent',
                      border: '1px solid var(--border-2)',
                      borderRadius: 8, cursor: 'pointer',
                    }}>
                      <span className="tnum" style={{ font: '700 12px/1 var(--font-mono)', color: i < 3 ? c : 'var(--text-3)' }}>#{i+1}</span>
                      <div>
                        <div style={{ font: '600 12.5px/1.2 var(--font)', color: 'var(--text)' }}>{p.name}</div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 3 }}>
                          <div style={{ width: 6, height: 6, borderRadius: '50%', background: region.color }}/>
                          <span style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)' }}>{region.name}</span>
                        </div>
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 5, padding: '3px 7px', background: `${c}22`, border: `1px solid ${c}44`, borderRadius: 5, justifySelf: 'start' }}>
                        <TypeIcon type={p.topRes} size={10} color={c}/>
                        <span style={{ font: '600 10px/1 var(--font)', color: c }}>{TLabel[p.topRes]}</span>
                      </div>
                      <span className="tnum" style={{ font: '600 12px/1 var(--font-mono)', color: 'var(--text)', textAlign: 'right' }}>{p.capacityMw}<span style={{ color: 'var(--text-3)', fontWeight: 500, fontSize: 9.5, marginLeft: 2 }}>MW</span></span>
                      {/* score bar */}
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                        <div style={{ flex: 1, height: 4, background: 'rgba(255,255,255,.05)', borderRadius: 2 }}>
                          <div style={{ height: '100%', width: `${p.score}%`, background: c, borderRadius: 2 }}/>
                        </div>
                        <span className="tnum" style={{ font: '600 10px/1 var(--font-mono)', color: c, minWidth: 22, textAlign: 'right' }}>{p.score}</span>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* Trend chart */}
            <div style={{ padding: 16, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 14 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 14 }}>
                <span className="label" style={{ flex: 1 }}>10 Yıllık Kurulu Güç Trendi</span>
                <div style={{ display: 'flex', gap: 10, font: '500 10.5px/1 var(--font)' }}>
                  <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, color: 'var(--text-2)' }}><span style={{ width: 12, height: 0, borderTop: '1.8px dashed currentColor' }}/>Toplam</span>
                  <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, color: 'var(--accent)' }}><span style={{ width: 12, height: 2, background: 'currentColor' }}/>Yenilenebilir</span>
                </div>
              </div>
              <TrendChart data={TR_STATS.capacityTrend} width={580} height={260}/>
              <div style={{ marginTop: 10, paddingTop: 10, borderTop: '1px dashed var(--border-2)', display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10 }}>
                <div>
                  <div className="label">10 Yıllık Artış</div>
                  <div className="tnum" style={{ font: '700 18px/1 var(--font)', color: 'var(--accent)', marginTop: 4 }}>+108%</div>
                </div>
                <div>
                  <div className="label">2035 Hedefi</div>
                  <div className="tnum" style={{ font: '700 18px/1 var(--font)', marginTop: 4 }}>220<span style={{ fontSize: 11, color: 'var(--text-3)', fontWeight: 500, marginLeft: 2 }}>GW</span></div>
                </div>
                <div>
                  <div className="label">Hedef · Yenil.</div>
                  <div className="tnum" style={{ font: '700 18px/1 var(--font)', color: 'var(--accent)', marginTop: 4 }}>%75</div>
                </div>
              </div>
            </div>
          </div>

          {/* SECTION: POTANSİYEL VS GERÇEK */}
          <div style={{ padding: 18, background: 'linear-gradient(135deg, rgba(20,184,166,.06), transparent 65%)', border: '1px solid rgba(20,184,166,.25)', borderRadius: 14, marginBottom: 22 }}>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 12, marginBottom: 14 }}>
              <h2 style={{ margin: 0, font: '700 17px/1 var(--font)', letterSpacing: '-.01em' }}>Teknik Potansiyel vs Gerçekleşen</h2>
              <span style={{ font: '500 12px/1 var(--font)', color: 'var(--text-3)' }}>· Türkiye'nin yenilenebilir kapasitesinin %{Math.round((TR_STATS.renewableMw / TR_STATS.technicalPotentialMw) * 100)}'i kullanıldı</span>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12 }}>
              {[
                { type: 'solar', label: 'Güneş',   cur: stats.solarMw, pot: stats.solarPotentialMw },
                { type: 'wind',  label: 'Rüzgar',  cur: stats.windMw,  pot: stats.windPotentialMw },
                { type: 'hydro', label: 'Hidro',   cur: stats.hydroMw, pot: stats.hydroPotentialMw },
              ].map(r => {
                const c = TC[r.type];
                const pct = (r.cur / r.pot) * 100;
                return (
                  <div key={r.type} style={{ padding: 14, background: 'rgba(0,0,0,.20)', border: '1px solid var(--border-2)', borderRadius: 10 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
                      <div style={{ width: 24, height: 24, borderRadius: 6, background: `${c}22`, display: 'grid', placeItems: 'center' }}>
                        <TypeIcon type={r.type} size={12} color={c}/>
                      </div>
                      <span style={{ font: '600 12.5px/1 var(--font)' }}>{r.label}</span>
                      <span className="tnum" style={{ font: '700 12px/1 var(--font-mono)', color: c, marginLeft: 'auto' }}>%{pct.toFixed(1)}</span>
                    </div>
                    <div style={{ position: 'relative', height: 10, background: 'rgba(255,255,255,.04)', borderRadius: 5, marginBottom: 9 }}>
                      <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: `${pct}%`, background: c, borderRadius: 5 }}/>
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between', font: '500 10.5px/1 var(--font)', color: 'var(--text-3)' }}>
                      <span>Gerçekleşen: <b className="tnum" style={{ color: c, fontFamily: 'var(--font-mono)' }}>{(r.cur/1000).toFixed(1)}GW</b></span>
                      <span>Potansiyel: <b className="tnum" style={{ color: 'var(--text-2)', fontFamily: 'var(--font-mono)' }}>{(r.pot/1000).toFixed(0)}GW</b></span>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* QUICK ACCESS — DRILL DOWN */}
          <div style={{ marginBottom: 22 }}>
            <h2 style={{ margin: '0 0 12px', font: '700 17px/1 var(--font)', letterSpacing: '-.01em' }}>Detaylı Analiz</h2>
            <div style={{ display: 'flex', gap: 10 }}>
              <QuickAccessCard icon="layers" title="Bölge Analizi" sub="7 coğrafi bölge · iklim profili + yatırım fırsatları" count="7 bölge" color="#A855F7"/>
              <QuickAccessCard icon="pin" title="İl Analizi" sub="81 il · ilçe potansiyel haritası + en iyi sahalar" count="81 il" color="#3B82F6"/>
              <QuickAccessCard icon="cal" title="Senaryo Raporları" sub="Çoklu pin · portföy düzeyinde NPV/IRR analizi" count="4 senaryo" color="var(--accent)"/>
              <QuickAccessCard icon="eq" title="Santral Analizi" sub="Pin bazlı · teknik + finans + risk profili" count="14 pin" color="#F59E0B"/>
            </div>
          </div>

          {/* footer */}
          <div style={{ paddingTop: 20, borderTop: '1px dashed var(--border-2)', display: 'flex', alignItems: 'center', gap: 14, font: '500 11px/1.4 var(--font)', color: 'var(--text-3)' }}>
            <span><b style={{ color: 'var(--text-2)' }}>SRRP</b> · Veri kaynakları: TEİAŞ, EPDK, PVGIS, ERA-5, DSİ, MGM</span>
            <div style={{ flex: 1 }}/>
            <span className="tnum" style={{ fontFamily: 'var(--font-mono)' }}>2024 sonu verisi · {Math.round(TR_STATS.totalInstalledMw)} MW</span>
          </div>
        </div>
      </div>
    </div>
  );
};

// ============================================================================
// Region card (used in landing grid)
// ============================================================================
const RegionCard = ({ region }) => {
  const c = region.color;
  return (
    <div style={{
      padding: 14, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12,
      cursor: 'pointer', position: 'relative', overflow: 'hidden', transition: 'border-color .15s',
    }}>
      {/* color accent */}
      <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: 3, background: c }}/>
      <div style={{ position: 'absolute', right: -30, top: -30, width: 100, height: 100, borderRadius: '50%', background: `radial-gradient(circle, ${c}22, transparent 60%)` }}/>
      <div style={{ position: 'relative' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
          <span style={{ font: '700 14px/1 var(--font)', letterSpacing: '-.01em' }}>{region.name}</span>
          <div style={{ marginLeft: 'auto', display: 'flex', gap: 3 }}>
            {region.bestFor.slice(0, 3).map(t => (
              <div key={t} style={{ width: 20, height: 20, borderRadius: 5, background: `${TC[t]}22`, display: 'grid', placeItems: 'center' }}>
                <TypeIcon type={t} size={10} color={TC[t]}/>
              </div>
            ))}
          </div>
        </div>
        <div style={{ font: '500 11px/1.45 var(--font)', color: 'var(--text-3)', minHeight: 50, marginBottom: 10 }}>{region.description}</div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8, paddingTop: 10, borderTop: '1px dashed var(--border-2)' }}>
          <div>
            <div style={{ font: '500 9px/1 var(--font)', color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '.06em' }}>Kapasite</div>
            <div className="tnum" style={{ font: '700 14px/1 var(--font)', marginTop: 4, color: c }}>{(region.capacityMw/1000).toFixed(1)}<span style={{ fontSize: 10, color: 'var(--text-3)', fontWeight: 500, marginLeft: 2 }}>GW</span></div>
          </div>
          <div>
            <div style={{ font: '500 9px/1 var(--font)', color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '.06em' }}>Üretim</div>
            <div className="tnum" style={{ font: '700 14px/1 var(--font)', marginTop: 4 }}>{(region.annualGwh/1000).toFixed(1)}<span style={{ fontSize: 10, color: 'var(--text-3)', fontWeight: 500, marginLeft: 2 }}>TWh</span></div>
          </div>
          <div>
            <div style={{ font: '500 9px/1 var(--font)', color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '.06em' }}>İl Sayısı</div>
            <div className="tnum" style={{ font: '700 14px/1 var(--font)', marginTop: 4 }}>{region.provincesCount}</div>
          </div>
          <div>
            <div style={{ font: '500 9px/1 var(--font)', color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '.06em' }}>Lider Kaynak</div>
            <div style={{ font: '600 12px/1 var(--font)', marginTop: 4, color: TC[region.topResource] }}>{TLabel[region.topResource]}</div>
          </div>
        </div>
      </div>
    </div>
  );
};

Object.assign(window, { LandingDesktop, TurkeyRegionMap, TrendChart, ResourceFilterChips, QuickAccessCard, RegionCard });
