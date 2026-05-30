// reports-province.jsx — İl Analizi + Hava Analizi (Province + Weather Analysis)

const { useState: useStateP, useMemo: useMemoP } = React;

// ============================================================================
// Province mini-map highlighter
// ============================================================================
const ProvinceMiniMap = ({ province, height = 280 }) => {
  if (!province) return null;
  const region = TR_REGIONS.find(r => r.id === province.region);

  // Approximate Turkey lng/lat → SVG coords (covering 26-44 E, 36-42 N → 1000x600)
  const project = (lng, lat) => {
    const x = ((lng - 25) / 20) * 940 + 40;
    const y = 540 - ((lat - 36) / 6) * 280;
    return { x, y };
  };
  const pPos = project(province.lng, province.lat);

  return (
    <svg viewBox="0 0 1000 600" preserveAspectRatio="xMidYMid meet" style={{ width: '100%', height, display: 'block' }}>
      <defs>
        <linearGradient id="pmland" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0" stopColor="#1a2030"/>
          <stop offset="1" stopColor="#10141d"/>
        </linearGradient>
        <radialGradient id="pmHighlight" cx="50%" cy="50%">
          <stop offset="0" stopColor={region.color} stopOpacity="0.85"/>
          <stop offset="0.5" stopColor={region.color} stopOpacity="0.4"/>
          <stop offset="1" stopColor={region.color} stopOpacity="0"/>
        </radialGradient>
      </defs>
      <path d="M40 280 C 80 220, 160 200, 230 220 C 300 200, 380 230, 470 210 C 560 200, 640 220, 730 200 C 820 200, 900 230, 970 270 C 990 320, 950 360, 880 380 C 800 410, 700 410, 600 400 C 500 410, 400 400, 320 410 C 240 405, 160 390, 90 360 C 50 340, 30 310, 40 280 Z"
        fill="url(#pmland)" stroke="rgba(255,255,255,.05)" strokeWidth="1"/>
      {/* region tint */}
      <path d={REGION_PATHS[province.region]} fill={region.color} fillOpacity="0.10" stroke={region.color} strokeOpacity="0.35" strokeWidth="1"/>
      {/* halo around province */}
      <circle cx={pPos.x} cy={pPos.y} r="50" fill="url(#pmHighlight)"/>
      {/* province dot */}
      <circle cx={pPos.x} cy={pPos.y} r="6" fill={region.color} stroke="white" strokeWidth="2"/>
      <text x={pPos.x} y={pPos.y - 14} textAnchor="middle" fontSize="13" fontFamily="Inter, sans-serif" fontWeight="700" fill="white">{province.name}</text>
      <text x={pPos.x} y={pPos.y + 18} textAnchor="middle" fontSize="9" fontFamily="JetBrains Mono, monospace" fill={region.color}>{province.lat.toFixed(2)}°, {province.lng.toFixed(2)}°</text>
    </svg>
  );
};

// ============================================================================
// Province district map — schematic
// ============================================================================
const DistrictMap = ({ province, selectedDistrict, onSelectDistrict, height = 320 }) => {
  if (!province) return null;
  const c = TC[province.topRes];
  // Generate district pseudo-positions in a circle/grid around province center
  const districts = province.districtsData;
  const W = 360, H = height;
  const cx = W / 2, cy = H / 2;
  const positions = districts.map((d, i) => {
    const angle = (i / districts.length) * Math.PI * 2 - Math.PI / 2;
    const radius = i === 0 ? 0 : 110 + (i % 3) * 20;
    return { x: cx + Math.cos(angle) * radius, y: cy + Math.sin(angle) * radius };
  });

  return (
    <svg viewBox={`0 0 ${W} ${H}`} style={{ width: '100%', height: 'auto', display: 'block' }}>
      <defs>
        <radialGradient id="dmprov" cx="50%" cy="50%">
          <stop offset="0" stopColor={c} stopOpacity="0.18"/>
          <stop offset="1" stopColor={c} stopOpacity="0.02"/>
        </radialGradient>
      </defs>
      {/* province boundary (synthetic) */}
      <circle cx={cx} cy={cy} r="155" fill="url(#dmprov)" stroke={c} strokeOpacity="0.35" strokeWidth="1.5" strokeDasharray="4 4"/>
      {/* district connections */}
      {positions.slice(1).map((p, i) => (
        <line key={i} x1={cx} y1={cy} x2={p.x} y2={p.y} stroke="rgba(255,255,255,.06)" strokeWidth="1" strokeDasharray="2 3"/>
      ))}
      {/* district dots */}
      {districts.map((d, i) => {
        const p = positions[i];
        const score = Math.max(d.solarScore, d.windScore, d.hydroScore);
        const isSelected = d.name === selectedDistrict;
        const r = 8 + (score / 100) * 14;
        const fillC = d.solarScore > Math.max(d.windScore, d.hydroScore) ? '#F59E0B' :
                     d.windScore > d.hydroScore ? '#3B82F6' : '#06B6D4';
        return (
          <g key={d.name} onClick={() => onSelectDistrict(d.name)} style={{ cursor: 'pointer' }}>
            {isSelected && <circle cx={p.x} cy={p.y} r={r + 6} fill="none" stroke={fillC} strokeWidth="2" opacity="0.6"/>}
            <circle cx={p.x} cy={p.y} r={r} fill={fillC} fillOpacity={isSelected ? 0.95 : 0.75} stroke="rgba(0,0,0,.4)" strokeWidth="1"/>
            <text x={p.x} y={p.y + 3} textAnchor="middle" fontSize="9.5" fontFamily="Inter" fontWeight="700" fill="white">{d.name}</text>
            <text x={p.x} y={p.y + r + 12} textAnchor="middle" fontSize="9" fontFamily="JetBrains Mono, monospace" fill={fillC}>{score}</text>
          </g>
        );
      })}
      {/* center label */}
      <text x={cx} y={cy + 3} textAnchor="middle" fontSize="11" fontFamily="Inter" fontWeight="700" fill="rgba(255,255,255,.45)" style={{ pointerEvents: 'none' }}>—</text>
      {/* legend */}
      <g transform={`translate(10, ${H-30})`}>
        <text x="0" y="-4" fontSize="9" fontFamily="Inter" fill="rgba(255,255,255,.45)" letterSpacing=".06em">İLÇE POTANSİYELİ</text>
        {[
          ['#F59E0B', 'Güneş'],
          ['#3B82F6', 'Rüzgar'],
          ['#06B6D4', 'Hidro'],
        ].map(([col, l], i) => (
          <g key={l} transform={`translate(${i * 56}, 8)`}>
            <circle cx="6" cy="6" r="4.5" fill={col}/>
            <text x="14" y="9" fontSize="9" fill="rgba(255,255,255,.65)" fontFamily="Inter">{l}</text>
          </g>
        ))}
      </g>
    </svg>
  );
};

// ============================================================================
// Best Spot Card
// ============================================================================
const BestSpotCard = ({ spot, type, isTop = false }) => {
  const c = TC[type];
  return (
    <div style={{
      padding: 12, background: isTop ? `${c}10` : 'rgba(0,0,0,.20)',
      border: isTop ? `1px solid ${c}44` : '1px solid var(--border-2)',
      borderRadius: 9, position: 'relative', overflow: 'hidden',
    }}>
      {isTop && <div style={{ position: 'absolute', right: 6, top: 6, padding: '2px 6px', background: c, borderRadius: 4, font: '700 8.5px/1 var(--font)', color: '#06201E', letterSpacing: '.08em' }}>EN İYİ</div>}
      <div style={{ font: '600 12.5px/1.3 var(--font)', color: 'var(--text)', marginBottom: 4, paddingRight: isTop ? 40 : 0 }}>{spot.name}</div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 5, font: '500 10px/1 var(--font)', color: 'var(--text-3)', marginBottom: 8 }}>
        <Icon name="pin" size={9} color="var(--text-4)"/>{spot.district}
        <span>·</span>
        <span className="tnum">{spot.lat?.toFixed(3)}°, {spot.lng?.toFixed(3)}°</span>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 5, marginBottom: 9 }}>
        <div style={{ flex: 1, height: 4, background: 'rgba(255,255,255,.06)', borderRadius: 2 }}>
          <div style={{ height: '100%', width: `${spot.potential}%`, background: c, borderRadius: 2 }}/>
        </div>
        <span className="tnum" style={{ font: '700 11px/1 var(--font-mono)', color: c, minWidth: 22, textAlign: 'right' }}>{spot.potential}</span>
      </div>
      {/* type-specific stats */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 6, font: '500 10px/1.4 var(--font)' }}>
        {type === 'solar' && (
          <>
            <div><span style={{ color: 'var(--text-3)' }}>Alan</span> <b className="tnum" style={{ color: 'var(--text-2)', fontFamily: 'var(--font-mono)' }}>{spot.area} ha</b></div>
            <div><span style={{ color: 'var(--text-3)' }}>Işınım</span> <b className="tnum" style={{ color: 'var(--text-2)', fontFamily: 'var(--font-mono)' }}>{spot.irradiance}</b></div>
            <div><span style={{ color: 'var(--text-3)' }}>Eğim</span> <b style={{ color: 'var(--text-2)' }}>{spot.slope}</b></div>
            <div><span style={{ color: 'var(--text-3)' }}>Şebeke</span> <b style={{ color: 'var(--text-2)' }}>{spot.distance}</b></div>
          </>
        )}
        {type === 'wind' && (
          <>
            <div><span style={{ color: 'var(--text-3)' }}>Hız</span> <b className="tnum" style={{ color: 'var(--text-2)', fontFamily: 'var(--font-mono)' }}>{spot.windSpeed} m/s</b></div>
            <div><span style={{ color: 'var(--text-3)' }}>Hub</span> <b style={{ color: 'var(--text-2)' }}>{spot.hubHeight}</b></div>
            <div><span style={{ color: 'var(--text-3)' }}>Alan</span> <b className="tnum" style={{ color: 'var(--text-2)', fontFamily: 'var(--font-mono)' }}>{spot.area} ha</b></div>
            <div><span style={{ color: 'var(--text-3)' }}>Şebeke</span> <b style={{ color: 'var(--text-2)' }}>{spot.distance}</b></div>
          </>
        )}
        {type === 'hydro' && (
          <>
            <div><span style={{ color: 'var(--text-3)' }}>Debi</span> <b className="tnum" style={{ color: 'var(--text-2)', fontFamily: 'var(--font-mono)' }}>{spot.flowRate} m³/s</b></div>
            <div><span style={{ color: 'var(--text-3)' }}>Düşü</span> <b className="tnum" style={{ color: 'var(--text-2)', fontFamily: 'var(--font-mono)' }}>{spot.head} m</b></div>
          </>
        )}
      </div>
      <div style={{ marginTop: 9, paddingTop: 9, borderTop: '1px dashed var(--border-2)', display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
        <span style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)' }}>Yıllık üretim tahmini</span>
        <span className="tnum" style={{ font: '700 13px/1 var(--font)', color: c }}>{(spot.kwhAnnual/1e6).toFixed(1)}<span style={{ fontSize: 9, color: 'var(--text-3)', fontWeight: 500, marginLeft: 2 }}>GWh</span></span>
      </div>
    </div>
  );
};

// ============================================================================
// İL ANALİZİ — Desktop
// ============================================================================
const ProvinceAnalysisDesktop = ({ initialProvinceId = 'konya', initialTab = 'overview' }) => {
  const [provinceId, setProvinceId] = useStateP(initialProvinceId);
  const [tab, setTab] = useStateP(initialTab); // overview | weather
  const [selectedDistrict, setSelectedDistrict] = useStateP(null);
  const province = TR_PROVINCES.find(p => p.id === provinceId);
  const region = TR_REGIONS.find(r => r.id === province.region);
  const spots = PROVINCE_BEST_SPOTS[provinceId] || { solar: [], wind: [], hydro: [] };
  const weather = REGION_WEATHER[province.region];

  // Filter spots by selected district (if any)
  const filteredSpots = useMemoP(() => {
    if (!selectedDistrict) return spots;
    return {
      solar: spots.solar.filter(s => s.district === selectedDistrict),
      wind:  spots.wind.filter(s => s.district === selectedDistrict),
      hydro: spots.hydro.filter(s => s.district === selectedDistrict),
    };
  }, [spots, selectedDistrict]);

  return (
    <div style={{ width: 1280, height: 1700, background: 'var(--bg)', display: 'flex', borderRadius: 12, overflow: 'hidden', border: '1px solid var(--border)' }}>
      {/* nav rail */}
      <div style={{ width: 56, background: 'var(--bg-2)', borderRight: '1px solid var(--border)', display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '14px 0', gap: 6 }}>
        <div style={{ width: 32, height: 32, borderRadius: 9, background: 'linear-gradient(135deg, var(--solar), var(--wind))', display: 'grid', placeItems: 'center', marginBottom: 8 }}>
          <Icon name="globe" size={16} color="white"/>
        </div>
        {[
          { i: 'globe' }, { i: 'list' },
          { i: 'roi', on: true }, { i: 'finance' },
        ].map((it, i) => (
          <button key={i} className="btn btn-icon btn-ghost" style={{ width: 40, height: 40, padding: 0, background: it.on ? 'rgba(20,184,166,.10)' : 'transparent', border: it.on ? '1px solid rgba(20,184,166,.4)' : '1px solid transparent' }}>
            <Icon name={it.i} size={17} color={it.on ? 'var(--accent)' : 'var(--text-3)'}/>
          </button>
        ))}
      </div>

      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minWidth: 0 }}>
        {/* breadcrumb toolbar */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '14px 24px', background: 'rgba(20,24,34,.92)', borderBottom: '1px solid var(--border)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 7, font: '500 11.5px/1 var(--font)', color: 'var(--text-3)' }}>
            <Icon name="roi" size={12} color="var(--accent)"/>
            <span>Raporlar</span><Icon name="chevR" size={10} color="var(--text-4)"/>
            <span>İl Analizi</span><Icon name="chevR" size={10} color="var(--text-4)"/>
            <span style={{ color: region.color, fontWeight: 600 }}>{region.name}</span>
            <Icon name="chevR" size={10} color="var(--text-4)"/>
            <span style={{ color: 'var(--text)', fontWeight: 600 }}>{province.name}</span>
          </div>
          <div style={{ flex: 1 }}/>
          {/* province search */}
          <select value={provinceId} onChange={e => { setProvinceId(e.target.value); setSelectedDistrict(null); }}
            className="input" style={{ width: 240, padding: '7px 11px', fontSize: 12.5 }}>
            {TR_REGIONS.map(r => (
              <optgroup key={r.id} label={r.name}>
                {TR_PROVINCES.filter(p => p.region === r.id).map(p => (
                  <option key={p.id} value={p.id}>{p.name}</option>
                ))}
              </optgroup>
            ))}
          </select>
          <button className="btn" style={{ padding: '7px 11px' }}><Icon name="ext" size={11}/> PDF</button>
        </div>

        {/* main tabs */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 4, padding: '0 24px', background: 'rgba(0,0,0,.18)', borderBottom: '1px solid var(--border-2)' }}>
          {[
            ['landing', 'Genel Bakış', 'globe'],
            ['bolge', 'Bölge Analizi', 'layers'],
            ['il', 'İl Analizi', 'pin', true],
            ['senaryo', 'Senaryo Raporu', 'cal'],
            ['santral', 'Santral Analizi', 'eq'],
          ].map(([id, l, ic, on]) => (
            <button key={id} style={{
              padding: '12px 14px', background: 'transparent', border: 'none',
              borderBottom: on ? '2px solid var(--accent)' : '2px solid transparent',
              cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 7,
              font: on ? '600 12.5px/1 var(--font)' : '500 12.5px/1 var(--font)',
              color: on ? 'var(--text)' : 'var(--text-3)',
            }}>
              <Icon name={ic} size={13} color={on ? 'var(--accent)' : 'var(--text-3)'}/>{l}
            </button>
          ))}
        </div>

        {/* sub-tabs for province sections */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 24px', borderBottom: '1px solid var(--border-2)', background: 'rgba(0,0,0,.10)', flexShrink: 0 }}>
          <div className="seg">
            {[
              { id: 'overview', l: 'Saha Potansiyeli', ic: 'layers' },
              { id: 'weather',  l: 'Hava Analizi',     ic: 'temp' },
            ].map(t => (
              <button key={t.id} onClick={() => setTab(t.id)} className={tab === t.id ? 'on' : ''} style={{ padding: '7px 13px' }}>
                <Icon name={t.ic} size={11} color={tab === t.id ? 'var(--accent)' : 'var(--text-3)'}/>{t.l}
              </button>
            ))}
          </div>
          {selectedDistrict && (
            <div style={{ display: 'flex', alignItems: 'center', gap: 7, padding: '6px 11px', background: 'rgba(20,184,166,.10)', border: '1px solid rgba(20,184,166,.35)', borderRadius: 8 }}>
              <Icon name="filter" size={11} color="var(--accent)"/>
              <span style={{ font: '600 11.5px/1 var(--font)', color: 'var(--accent)' }}>İlçe filtresi: {selectedDistrict}</span>
              <button onClick={() => setSelectedDistrict(null)} style={{ background: 'transparent', border: 'none', color: 'var(--accent)', cursor: 'pointer', font: '500 14px/1 var(--font)', padding: 0 }}>×</button>
            </div>
          )}
          <div style={{ flex: 1 }}/>
          <span className="chip"><span style={{ width: 5, height: 5, borderRadius: '50%', background: '#10B981' }}/>Veri: TEİAŞ + PVGIS + ERA-5 · 2024</span>
        </div>

        {/* scroll content */}
        <div className="scroll" style={{ flex: 1, overflow: 'auto', padding: '22px 24px 40px' }}>
          {/* HERO */}
          <div style={{
            padding: '20px 22px', borderRadius: 14, marginBottom: 18,
            background: `linear-gradient(135deg, ${region.color}15, transparent 65%)`,
            border: `1px solid ${region.color}33`, display: 'grid', gridTemplateColumns: '1fr 320px', gap: 24, position: 'relative', overflow: 'hidden',
          }}>
            <div style={{ position: 'absolute', right: -40, top: -40, width: 180, height: 180, borderRadius: '50%', background: `radial-gradient(circle, ${region.color}22, transparent 60%)` }}/>
            <div style={{ position: 'relative' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 9, marginBottom: 6 }}>
                <span style={{ font: '600 10.5px/1 var(--font-mono)', color: region.color, textTransform: 'uppercase', letterSpacing: '.10em' }}>İL ANALİZİ · {region.name.toUpperCase()}</span>
              </div>
              <h1 style={{ margin: 0, font: '700 36px/1.05 var(--font)', letterSpacing: '-.025em' }}>{province.name}</h1>
              <div style={{ marginTop: 8, display: 'flex', gap: 14, font: '500 12px/1.3 var(--font)', color: 'var(--text-2)' }}>
                <span><Icon name="pin" size={11} color="var(--text-3)"/> {province.districts.length} ilçe</span>
                <span className="tnum">Koord: {province.lat.toFixed(2)}°, {province.lng.toFixed(2)}°</span>
                <span>Lider kaynak: <b style={{ color: TC[province.topRes] }}>{TLabel[province.topRes]}</b></span>
              </div>
              <div style={{ marginTop: 16, display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10 }}>
                {[
                  ['Kurulu Güç',    `${province.capacityMw}`, 'MW', region.color],
                  ['Yıllık Üretim', `${(province.annualGwh/1000).toFixed(2)}`, 'TWh', 'var(--text)'],
                  ['Potansiyel',    `${province.score}`, '/100', TC[province.topRes]],
                  ['Saha Sayısı',   `${(spots.solar.length + spots.wind.length + spots.hydro.length)}`, 'tespit', 'var(--text)'],
                ].map(([l, v, u, col]) => (
                  <div key={l} style={{ padding: 10, background: 'rgba(0,0,0,.25)', border: '1px solid var(--border-2)', borderRadius: 9 }}>
                    <div className="label">{l}</div>
                    <div style={{ display: 'flex', alignItems: 'baseline', gap: 3, marginTop: 5 }}>
                      <span className="tnum" style={{ font: '700 20px/1 var(--font)', color: col, letterSpacing: '-.01em' }}>{v}</span>
                      {u && <span style={{ font: '500 11px/1 var(--font)', color: 'var(--text-3)' }}>{u}</span>}
                    </div>
                  </div>
                ))}
              </div>
            </div>
            <div style={{ background: 'rgba(0,0,0,.30)', border: '1px solid var(--border-2)', borderRadius: 10, padding: 8 }}>
              <ProvinceMiniMap province={province} height={220}/>
            </div>
          </div>

          {tab === 'overview' && (
            <>
              {/* DISTRICT MAP + LIST + BEST SPOTS */}
              <div style={{ display: 'grid', gridTemplateColumns: '380px 1fr', gap: 14, marginBottom: 18 }}>
                {/* district map + list */}
                <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                  <div style={{ padding: 14, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
                      <span className="label" style={{ flex: 1 }}>İlçe Haritası</span>
                      <span style={{ font: '500 10px/1 var(--font)', color: 'var(--text-4)' }}>tıklanabilir</span>
                    </div>
                    <DistrictMap province={province} selectedDistrict={selectedDistrict} onSelectDistrict={setSelectedDistrict} height={320}/>
                  </div>
                  <div style={{ padding: 14, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
                      <span className="label" style={{ flex: 1 }}>İlçe Sıralaması</span>
                      <span style={{ font: '500 10px/1 var(--font)', color: 'var(--text-4)' }}>potansiyele göre</span>
                    </div>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                      {province.districtsData
                        .map((d, i) => ({ ...d, score: Math.max(d.solarScore, d.windScore, d.hydroScore) }))
                        .sort((a, b) => b.score - a.score)
                        .map((d, i) => {
                        const best = d.solarScore > Math.max(d.windScore, d.hydroScore) ? 'solar' :
                                     d.windScore > d.hydroScore ? 'wind' : 'hydro';
                        const c = TC[best];
                        const on = d.name === selectedDistrict;
                        return (
                          <button key={d.name} onClick={() => setSelectedDistrict(d.name === selectedDistrict ? null : d.name)} style={{
                            display: 'grid', gridTemplateColumns: '20px 1fr 30px 50px', gap: 8, alignItems: 'center',
                            padding: '8px 10px', background: on ? `${c}18` : 'transparent',
                            border: on ? `1px solid ${c}44` : '1px solid transparent',
                            borderRadius: 7, cursor: 'pointer', textAlign: 'left', color: 'inherit',
                          }}>
                            <span className="tnum" style={{ font: '700 10.5px/1 var(--font-mono)', color: c }}>#{i+1}</span>
                            <span style={{ font: '500 12px/1 var(--font)' }}>{d.name}</span>
                            <div style={{ width: 18, height: 18, borderRadius: 5, background: `${c}22`, display: 'grid', placeItems: 'center' }}>
                              <TypeIcon type={best} size={9} color={c}/>
                            </div>
                            <span className="tnum" style={{ font: '700 12px/1 var(--font-mono)', color: c, textAlign: 'right' }}>{d.score}</span>
                          </button>
                        );
                      })}
                    </div>
                  </div>
                </div>

                {/* 3 cols best spots */}
                <div>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: 12, marginBottom: 12 }}>
                    <h2 style={{ margin: 0, font: '700 16px/1 var(--font)' }}>En İyi Saha Bölgeleri</h2>
                    <span style={{ font: '500 11.5px/1 var(--font)', color: 'var(--text-3)' }}>
                      · 3 kaynak tipi · {selectedDistrict ? `${selectedDistrict} ilçesi` : 'tüm il'} · ayrı saha gösterimi
                    </span>
                  </div>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10 }}>
                    {['solar', 'wind', 'hydro'].map(t => {
                      const c = TC[t];
                      const list = filteredSpots[t] || [];
                      const isLead = province.topRes === t;
                      return (
                        <div key={t} style={{
                          padding: 12, background: 'var(--card)',
                          border: isLead ? `1px solid ${c}44` : '1px solid var(--border-2)',
                          borderRadius: 12,
                        }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12 }}>
                            <div style={{ width: 26, height: 26, borderRadius: 7, background: `${c}22`, border: `1px solid ${c}55`, display: 'grid', placeItems: 'center' }}>
                              <TypeIcon type={t} size={12} color={c}/>
                            </div>
                            <div style={{ flex: 1 }}>
                              <div style={{ font: '600 12.5px/1 var(--font)' }}>{TLabel[t]} Sahaları</div>
                              <div className="tnum" style={{ font: '500 10px/1 var(--font-mono)', color: 'var(--text-3)', marginTop: 3 }}>{list.length} aday</div>
                            </div>
                            {isLead && <span style={{ font: '700 9px/1 var(--font)', color: c, letterSpacing: '.06em' }}>LİDER</span>}
                          </div>
                          {list.length > 0 ? (
                            <div style={{ display: 'flex', flexDirection: 'column', gap: 7 }}>
                              {list.map((s, i) => <BestSpotCard key={s.id} spot={s} type={t} isTop={i === 0}/>)}
                            </div>
                          ) : (
                            <div style={{ padding: 16, background: 'rgba(0,0,0,.15)', borderRadius: 8, font: '500 11px/1.5 var(--font)', color: 'var(--text-3)', textAlign: 'center' }}>
                              {selectedDistrict ? 'Bu ilçede uygun saha tespit edilmedi.' : 'Bu il için bu kaynak tipinde yüksek-potansiyel saha yok.'}
                            </div>
                          )}
                        </div>
                      );
                    })}
                  </div>
                </div>
              </div>

              {/* COMPARISON TABLE */}
              <div style={{ padding: 14, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12 }}>
                <div className="label" style={{ marginBottom: 12 }}>İlçe Karşılaştırma Tablosu</div>
                <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                  <thead>
                    <tr style={{ background: 'rgba(0,0,0,.20)' }}>
                      {['İlçe', 'Güneş Skoru', 'Rüzgar Skoru', 'Hidro Skoru', 'En İyi Kaynak', 'Tahmini Kapasite'].map((h, i) => (
                        <th key={h} style={{ textAlign: i === 0 ? 'left' : i === 4 ? 'left' : 'right', padding: '10px 14px', font: '600 10.5px/1 var(--font)', color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '.06em', borderBottom: '1px solid var(--border-2)' }}>{h}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {province.districtsData.map((d, i) => {
                      const best = d.solarScore > Math.max(d.windScore, d.hydroScore) ? 'solar' :
                                   d.windScore > d.hydroScore ? 'wind' : 'hydro';
                      const c = TC[best];
                      const score = Math.max(d.solarScore, d.windScore, d.hydroScore);
                      return (
                        <tr key={d.name} style={{ background: i % 2 ? 'rgba(255,255,255,.01)' : 'transparent', cursor: 'pointer' }}
                            onClick={() => setSelectedDistrict(d.name)}>
                          <td style={{ padding: '10px 14px', font: '600 12.5px/1.2 var(--font)', borderBottom: '1px solid var(--border-2)' }}>{d.name}</td>
                          {[d.solarScore, d.windScore, d.hydroScore].map((s, idx) => {
                            const sc = ['#F59E0B', '#3B82F6', '#06B6D4'][idx];
                            return (
                              <td key={idx} style={{ padding: '10px 14px', textAlign: 'right', borderBottom: '1px solid var(--border-2)' }}>
                                <div style={{ display: 'inline-flex', alignItems: 'center', gap: 7 }}>
                                  <div style={{ width: 60, height: 4, background: 'rgba(255,255,255,.05)', borderRadius: 2 }}>
                                    <div style={{ height: '100%', width: `${s}%`, background: sc, borderRadius: 2 }}/>
                                  </div>
                                  <span className="tnum" style={{ font: '600 12px/1 var(--font-mono)', color: sc, minWidth: 22, textAlign: 'right' }}>{s}</span>
                                </div>
                              </td>
                            );
                          })}
                          <td style={{ padding: '10px 14px', borderBottom: '1px solid var(--border-2)' }}>
                            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, padding: '3px 7px', background: `${c}22`, border: `1px solid ${c}44`, borderRadius: 5, font: '600 10.5px/1 var(--font)', color: c }}>
                              <TypeIcon type={best} size={10} color={c}/>{TLabel[best]}
                            </span>
                          </td>
                          <td style={{ padding: '10px 14px', textAlign: 'right', font: '600 12.5px/1 var(--font-mono)', color: 'var(--text)', borderBottom: '1px solid var(--border-2)' }} className="tnum">
                            {d.availableMw}<span style={{ color: 'var(--text-3)', fontWeight: 500, fontSize: 10, marginLeft: 2 }}>MW</span>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </>
          )}

          {tab === 'weather' && (
            <ProvinceWeatherTab province={province} weather={weather}/>
          )}
        </div>
      </div>
    </div>
  );
};

// ============================================================================
// HAVA ANALİZİ — Tab content (also usable standalone)
// ============================================================================
const ProvinceWeatherTab = ({ province, weather }) => {
  const region = TR_REGIONS.find(r => r.id === province.region);
  return (
    <>
      <div style={{ padding: 14, background: 'linear-gradient(135deg, rgba(56,189,248,.06), transparent 65%)', border: '1px solid rgba(56,189,248,.20)', borderRadius: 12, marginBottom: 16, display: 'flex', alignItems: 'center', gap: 14 }}>
        <div style={{ width: 38, height: 38, borderRadius: 10, background: 'rgba(56,189,248,.14)', border: '1px solid rgba(56,189,248,.35)', display: 'grid', placeItems: 'center' }}>
          <Icon name="temp" size={18} color="#38BDF8"/>
        </div>
        <div style={{ flex: 1 }}>
          <div style={{ font: '600 14px/1.2 var(--font)' }}>Hava Analizi · {province.name}</div>
          <div style={{ font: '500 11.5px/1.4 var(--font)', color: 'var(--text-3)', marginTop: 5 }}>3 kaynak tipi için meteorolojik göstergeler. Veri: MGM (10 yıl ort.), PVGIS, ERA-5.</div>
        </div>
        <span className="chip"><span style={{ width: 5, height: 5, borderRadius: '50%', background: '#38BDF8' }}/>{region.climateNote.split(' · ')[0]}</span>
      </div>

      {/* monthly metric strips — 4 cards */}
      <h2 style={{ margin: '0 0 12px', font: '700 15px/1 var(--font)' }}>Aylık Meteorolojik Göstergeler</h2>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10, marginBottom: 18 }}>
        <WeatherStrip label="Güneş Işınımı" data={weather.irradiance}    unit="kWh/m²·gün" color="#F59E0B"/>
        <WeatherStrip label="Rüzgar Hızı"    data={weather.windSpeed}     unit="m/s @100m"  color="#3B82F6"/>
        <WeatherStrip label="Yağış"          data={weather.precipitation} unit="mm/ay"      color="#06B6D4"/>
        <WeatherStrip label="Sıcaklık"       data={weather.temperature}   unit="°C"         color="#EF4444"/>
      </div>

      {/* solar relevance */}
      <h2 style={{ margin: '0 0 12px', font: '700 15px/1 var(--font)', display: 'flex', alignItems: 'center', gap: 9 }}>
        <span style={{ width: 6, height: 18, borderRadius: 2, background: '#F59E0B' }}/>Güneş Enerjisi İçin Anlamı
      </h2>
      <div style={{ display: 'grid', gridTemplateColumns: '1.4fr 1fr', gap: 10, marginBottom: 18 }}>
        <div style={{ padding: 14, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12 }}>
          <div className="label" style={{ marginBottom: 10 }}>Bulutlanma vs Güneşlenme</div>
          <svg viewBox="0 0 720 220" style={{ width: '100%', height: 'auto', display: 'block' }}>
            {(() => {
              const months = ['O','Ş','M','N','M','H','T','A','E','E','K','A'];
              const padL = 40, padR = 36, padT = 14, padB = 26;
              const w = 720 - padL - padR, h = 220 - padT - padB;
              const bw = w / 12;
              const sunshineHrs = weather.irradiance.map(v => 30 * v * 1.4);
              const maxSun = 320;
              const xFor = i => padL + bw * (i + 0.5);
              const yCloud = v => padT + h - (v / 100) * h;
              const ySun   = v => padT + h - (v / maxSun) * h;
              return (
                <>
                  {[0, 25, 50, 75, 100].map(v => (
                    <g key={v}>
                      <line x1={padL} x2={720-padR} y1={yCloud(v)} y2={yCloud(v)} stroke="rgba(255,255,255,.05)" strokeWidth="1"/>
                      <text x={padL-5} y={yCloud(v)+3} textAnchor="end" fontSize="9" fill="rgba(255,255,255,.45)" fontFamily="JetBrains Mono, monospace">{v}</text>
                    </g>
                  ))}
                  {[0, 100, 200, 300].map(v => (
                    <text key={v} x={720-padR+5} y={ySun(v)+3} fontSize="9" fill="rgba(245,158,11,.6)" fontFamily="JetBrains Mono, monospace">{v}</text>
                  ))}
                  {weather.cloudCover.map((v, i) => {
                    const x = xFor(i) - bw*0.35;
                    const y = yCloud(v);
                    return <rect key={i} x={x} y={y} width={bw*0.70} height={padT+h-y} rx="2" fill="rgba(96,165,250,.55)"/>;
                  })}
                  <path d={sunshineHrs.map((v, i) => `${i?'L':'M'} ${xFor(i)} ${ySun(v)}`).join(' ')} fill="none" stroke="#F59E0B" strokeWidth="2.2" strokeLinecap="round"/>
                  {sunshineHrs.map((v, i) => <circle key={i} cx={xFor(i)} cy={ySun(v)} r="2.5" fill="#F59E0B"/>)}
                  {months.map((m, i) => <text key={i} x={xFor(i)} y={220-8} textAnchor="middle" fontSize="9.5" fill="rgba(255,255,255,.55)" fontFamily="Inter">{m}</text>)}
                </>
              );
            })()}
          </svg>
          <div style={{ display: 'flex', gap: 16, marginTop: 8, font: '500 11px/1 var(--font)' }}>
            <span style={{ display: 'flex', alignItems: 'center', gap: 5, color: 'rgba(96,165,250,1)' }}><span style={{ width: 10, height: 10, borderRadius: 2, background: 'rgba(96,165,250,.55)' }}/>Bulutlanma %</span>
            <span style={{ display: 'flex', alignItems: 'center', gap: 5, color: '#F59E0B' }}><span style={{ width: 10, height: 2, background: '#F59E0B' }}/>Güneşlenme (sa/ay)</span>
          </div>
        </div>
        <div style={{ padding: 14, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12 }}>
          <div className="label" style={{ marginBottom: 12 }}>Yıllık Özet</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 11 }}>
            {[
              ['Toplam Güneşlenme', `${Math.round(weather.irradiance.reduce((s,v) => s+v, 0) * 30 * 1.4)} sa/yıl`, '#F59E0B'],
              ['Yıllık Işınım',     `${(weather.irradiance.reduce((s,v) => s+v, 0) / 12).toFixed(1)} kWh/m²·gün`, '#F59E0B'],
              ['Ortalama Bulut',    `%${Math.round(weather.cloudCover.reduce((s,v) => s+v, 0) / 12)}`, 'rgba(96,165,250,1)'],
              ['Pik Ay',             ['Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'][weather.irradiance.indexOf(Math.max(...weather.irradiance))], '#F59E0B'],
            ].map(([l, v, c]) => (
              <div key={l} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', padding: '6px 0', borderBottom: '1px dashed var(--border-2)' }}>
                <span style={{ font: '500 11.5px/1 var(--font)', color: 'var(--text-3)' }}>{l}</span>
                <span className="tnum" style={{ font: '700 13px/1 var(--font)', color: c, fontFamily: 'var(--font-mono)' }}>{v}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* wind relevance */}
      <h2 style={{ margin: '0 0 12px', font: '700 15px/1 var(--font)', display: 'flex', alignItems: 'center', gap: 9 }}>
        <span style={{ width: 6, height: 18, borderRadius: 2, background: '#3B82F6' }}/>Rüzgar Enerjisi İçin Anlamı
      </h2>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1.5fr', gap: 10, marginBottom: 18 }}>
        <div style={{ padding: 14, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12 }}>
          <div className="label" style={{ marginBottom: 10 }}>Rüzgar Yön Dağılımı</div>
          <div style={{ display: 'flex', justifyContent: 'center' }}>
            <WindRose size={200} dominantDir={province.region === 'marmara' || province.region === 'ege' ? 'NW' : province.region === 'icanadolu' ? 'N' : 'NE'}/>
          </div>
        </div>
        <div style={{ padding: 14, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12 }}>
          <div className="label" style={{ marginBottom: 10 }}>Aylık Rüzgar Hızı · 100m Hub</div>
          <WeatherStrip label="" data={weather.windSpeed} unit="m/s" color="#3B82F6" height={120}/>
          <div style={{ marginTop: 10, paddingTop: 10, borderTop: '1px dashed var(--border-2)', display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8 }}>
            <div>
              <div className="label">Yıllık Ort.</div>
              <div className="tnum" style={{ font: '700 16px/1 var(--font)', color: '#3B82F6', marginTop: 5 }}>{(weather.windSpeed.reduce((s,v) => s+v, 0)/12).toFixed(1)}<span style={{ fontSize: 10, color: 'var(--text-3)', fontWeight: 500, marginLeft: 2 }}>m/s</span></div>
            </div>
            <div>
              <div className="label">Max Ay</div>
              <div className="tnum" style={{ font: '700 16px/1 var(--font)', marginTop: 5 }}>{Math.max(...weather.windSpeed).toFixed(1)}<span style={{ fontSize: 10, color: 'var(--text-3)', fontWeight: 500, marginLeft: 2 }}>m/s</span></div>
            </div>
            <div>
              <div className="label">Türbin Uygunluğu</div>
              <div style={{ font: '700 15px/1 var(--font)', marginTop: 5, color: weather.windSpeed.reduce((s,v) => s+v, 0)/12 > 6.5 ? '#10B981' : '#F59E0B' }}>{weather.windSpeed.reduce((s,v) => s+v, 0)/12 > 6.5 ? 'YÜKSEK' : 'ORTA'}</div>
            </div>
          </div>
        </div>
      </div>

      {/* hydro relevance */}
      <h2 style={{ margin: '0 0 12px', font: '700 15px/1 var(--font)', display: 'flex', alignItems: 'center', gap: 9 }}>
        <span style={{ width: 6, height: 18, borderRadius: 2, background: '#06B6D4' }}/>Hidroelektrik İçin Anlamı
      </h2>
      <div style={{ display: 'grid', gridTemplateColumns: '1.5fr 1fr', gap: 10, marginBottom: 18 }}>
        <div style={{ padding: 14, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12 }}>
          <div className="label" style={{ marginBottom: 10 }}>Aylık Yağış · Akarsu Debisine Etki</div>
          <WeatherStrip label="" data={weather.precipitation} unit="mm" color="#06B6D4" height={120}/>
          <div style={{ marginTop: 10, font: '500 11.5px/1.5 var(--font)', color: 'var(--text-3)' }}>
            <Icon name="info" size={11} color="var(--text-3)"/> Toplam yıllık yağış <b className="tnum" style={{ color: '#06B6D4' }}>{Math.round(weather.precipitation.reduce((s,v) => s+v, 0))} mm</b>. Akarsular için pik dönem: <b style={{ color: 'var(--text)' }}>İlkbahar-Yaz başı</b> (kar erimesi).
          </div>
        </div>
        <div style={{ padding: 14, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12 }}>
          <div className="label" style={{ marginBottom: 12 }}>HES Uygunluk Skoru</div>
          {(() => {
            const annual = weather.precipitation.reduce((s,v) => s+v, 0);
            const score = Math.min(100, (annual / 1500) * 100);
            const lvl = score > 70 ? 'YÜKSEK' : score > 40 ? 'ORTA' : 'DÜŞÜK';
            const c = score > 70 ? '#10B981' : score > 40 ? '#F59E0B' : '#EF4444';
            return (
              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 9 }}>
                  <span className="tnum" style={{ font: '700 28px/1 var(--font)', color: c }}>{score.toFixed(0)}</span>
                  <span style={{ font: '700 13px/1 var(--font)', color: c, letterSpacing: '.04em' }}>{lvl}</span>
                </div>
                <div style={{ height: 6, background: 'rgba(255,255,255,.06)', borderRadius: 3, overflow: 'hidden', marginBottom: 12 }}>
                  <div style={{ height: '100%', width: `${score}%`, background: c, borderRadius: 3 }}/>
                </div>
                <div style={{ font: '500 11.5px/1.5 var(--font)', color: 'var(--text-3)' }}>
                  Yağış miktarı, topografya ve mevcut akarsu yataklarına göre değerlendirilmiştir.
                </div>
              </div>
            );
          })()}
        </div>
      </div>

      {/* RİSK UYARILARI */}
      <div style={{ padding: 14, background: 'rgba(245,158,11,.06)', border: '1px solid rgba(245,158,11,.25)', borderRadius: 12 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12 }}>
          <Icon name="warn" size={14} color="#F59E0B"/>
          <span style={{ font: '600 13px/1 var(--font)', color: '#F59E0B' }}>Hava Riski Uyarıları</span>
          <span style={{ font: '500 11px/1 var(--font)', color: 'var(--text-3)' }}>· bölgesel iklim verilerinden</span>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10 }}>
          {[
            { icon: 'temp', label: 'Don/Kar', level: province.region === 'doguanadolu' ? 'Yüksek' : province.region === 'icanadolu' ? 'Orta' : 'Düşük', sub: 'GES verim kaybı' },
            { icon: 'water', label: 'Kuraklık', level: province.region === 'icanadolu' || province.region === 'gdanadolu' ? 'Yüksek' : 'Orta', sub: 'HES debi kaybı' },
            { icon: 'wind', label: 'Şiddetli Rüzgar', level: province.region === 'marmara' ? 'Yüksek' : 'Düşük', sub: 'Türbin kapatma' },
            { icon: 'water', label: 'Sel/Heyelan', level: province.region === 'karadeniz' ? 'Yüksek' : 'Düşük', sub: 'Erişim/operasyon' },
          ].map(r => {
            const lc = r.level === 'Yüksek' ? '#EF4444' : r.level === 'Orta' ? '#F59E0B' : '#10B981';
            return (
              <div key={r.label} style={{ padding: 11, background: 'rgba(0,0,0,.18)', border: `1px solid ${lc}33`, borderRadius: 9 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 6 }}>
                  <Icon name={r.icon} size={11} color={lc}/>
                  <span style={{ font: '600 11px/1 var(--font)', color: 'var(--text)', flex: 1 }}>{r.label}</span>
                  <span style={{ font: '700 10px/1 var(--font)', color: lc }}>{r.level}</span>
                </div>
                <div style={{ font: '500 10px/1.3 var(--font)', color: 'var(--text-3)' }}>{r.sub}</div>
              </div>
            );
          })}
        </div>
      </div>
    </>
  );
};

Object.assign(window, { ProvinceAnalysisDesktop, ProvinceWeatherTab, ProvinceMiniMap, DistrictMap, BestSpotCard });

// Convenience wrapper: open weather sub-tab by default
const ProvinceAnalysisWeatherView = () => <ProvinceAnalysisDesktop initialProvinceId="konya" initialTab="weather"/>;
Object.assign(window, { ProvinceAnalysisWeatherView });
