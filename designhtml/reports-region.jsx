// reports-region.jsx — Bölge Analizi (Region Analysis)

const { useState: useStateR2, useMemo: useMemoR2 } = React;

// ============================================================================
// Region weather card — small chart for one metric
// ============================================================================
const WeatherStrip = ({ label, data, unit, color, height = 56 }) => {
  const max = Math.max(...data) * 1.1;
  const min = Math.min(...data) * 0.9;
  const range = max - min || 1;
  const months = ['O','Ş','M','N','M','H','T','A','E','E','K','A'];
  const avg = data.reduce((s, v) => s + v, 0) / data.length;
  return (
    <div style={{ padding: 12, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 10 }}>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginBottom: 8 }}>
        <span className="label" style={{ flex: 1 }}>{label}</span>
        <span className="tnum" style={{ font: '700 15px/1 var(--font)', color }}>{avg.toFixed(1)}<span style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)', marginLeft: 2 }}>{unit}</span></span>
      </div>
      <svg width="100%" height={height + 14} viewBox={`0 0 240 ${height + 14}`} preserveAspectRatio="none" style={{ display: 'block' }}>
        <defs>
          <linearGradient id={`wsg-${label.replace(/\s/g,'')}`} x1="0" x2="0" y1="0" y2="1">
            <stop offset="0" stopColor={color} stopOpacity="0.35"/>
            <stop offset="1" stopColor={color} stopOpacity="0"/>
          </linearGradient>
        </defs>
        {data.map((v, i) => {
          const x = i * 20 + 2;
          const h = ((v - min) / range) * height;
          return (
            <g key={i}>
              <rect x={x} y={height - h + 2} width="16" height={h} rx="2" fill={`url(#wsg-${label.replace(/\s/g,'')})`}/>
              <rect x={x} y={height - h + 2} width="16" height="2" fill={color}/>
              <text x={x+8} y={height + 12} textAnchor="middle" fontSize="8" fill="rgba(255,255,255,.4)" fontFamily="Inter">{months[i]}</text>
            </g>
          );
        })}
      </svg>
    </div>
  );
};

// ============================================================================
// Wind Rose — directional frequency
// ============================================================================
const WindRose = ({ size = 200, dominantDir = 'NW' }) => {
  const dirs = ['N','NE','E','SE','S','SW','W','NW'];
  // synthetic distribution — prefer NW
  const dirIdx = dirs.indexOf(dominantDir);
  const freqs = dirs.map((_, i) => {
    const dist = Math.min(Math.abs(i - dirIdx), 8 - Math.abs(i - dirIdx));
    return Math.max(0.05, 0.35 - dist * 0.06 + (i === dirIdx ? 0.15 : 0));
  });
  const cx = size / 2, cy = size / 2;
  const maxR = size * 0.42;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      {/* concentric rings */}
      {[0.25, 0.5, 0.75, 1.0].map(t => (
        <circle key={t} cx={cx} cy={cy} r={maxR * t} fill="none" stroke="rgba(255,255,255,.06)" strokeWidth="1" strokeDasharray={t < 1 ? '2 3' : '0'}/>
      ))}
      {/* sectors */}
      {freqs.map((f, i) => {
        const angle1 = (i * 45 - 22.5 - 90) * Math.PI / 180;
        const angle2 = (i * 45 + 22.5 - 90) * Math.PI / 180;
        const r = maxR * f / 0.5;
        const x1 = cx + r * Math.cos(angle1), y1 = cy + r * Math.sin(angle1);
        const x2 = cx + r * Math.cos(angle2), y2 = cy + r * Math.sin(angle2);
        const c = i === dirIdx ? '#2DD4BF' : 'rgba(59,130,246,.55)';
        return (
          <path key={i} d={`M ${cx} ${cy} L ${x1.toFixed(1)} ${y1.toFixed(1)} A ${r} ${r} 0 0 1 ${x2.toFixed(1)} ${y2.toFixed(1)} Z`}
            fill={c} stroke="rgba(0,0,0,.4)" strokeWidth="0.5"/>
        );
      })}
      {/* direction labels */}
      {dirs.map((d, i) => {
        const angle = (i * 45 - 90) * Math.PI / 180;
        const r = maxR * 1.18;
        const x = cx + r * Math.cos(angle), y = cy + r * Math.sin(angle);
        return <text key={d} x={x} y={y + 3} textAnchor="middle" fontSize="10" fontFamily="Inter" fontWeight={d === dominantDir ? 700 : 500} fill={d === dominantDir ? '#2DD4BF' : 'rgba(255,255,255,.55)'}>{d}</text>;
      })}
    </svg>
  );
};

// ============================================================================
// Province card in region
// ============================================================================
const ProvinceCard = ({ province, region, onClick }) => {
  const c = TC[province.topRes];
  return (
    <button onClick={onClick} style={{
      display: 'flex', alignItems: 'center', gap: 12, padding: '12px 14px',
      background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 10,
      cursor: 'pointer', textAlign: 'left', color: 'inherit',
    }}>
      <div style={{ width: 30, height: 30, borderRadius: 8, background: `${c}22`, border: `1px solid ${c}44`, display: 'grid', placeItems: 'center' }}>
        <TypeIcon type={province.topRes} size={14} color={c}/>
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ font: '600 13px/1.2 var(--font)' }}>{province.name}</div>
        <div style={{ font: '500 10.5px/1 var(--font)', color: 'var(--text-3)', marginTop: 4 }}>{province.districts.length} ilçe · Lider: {TLabel[province.topRes]}</div>
      </div>
      <div style={{ textAlign: 'right' }}>
        <div className="tnum" style={{ font: '700 13px/1 var(--font)' }}>{province.capacityMw}<span style={{ color: 'var(--text-3)', fontWeight: 500, fontSize: 10, marginLeft: 2 }}>MW</span></div>
        <div className="tnum" style={{ font: '500 10px/1 var(--font-mono)', color: c, marginTop: 4 }}>skor {province.score}</div>
      </div>
    </button>
  );
};

// ============================================================================
// BÖLGE ANALİZİ — Desktop
// ============================================================================
const RegionAnalysisDesktop = ({ initialRegion = 'icanadolu' }) => {
  const [regionId, setRegionId] = useStateR2(initialRegion);
  const region = TR_REGIONS.find(r => r.id === regionId);
  const provinces = TR_PROVINCES.filter(p => p.region === regionId);
  const weather = REGION_WEATHER[regionId];

  return (
    <div style={{ width: 1280, height: 1800, background: 'var(--bg)', display: 'flex', borderRadius: 12, overflow: 'hidden', border: '1px solid var(--border)', position: 'relative' }}>
      <div style={{ width: 56, background: 'var(--bg-2)', borderRight: '1px solid var(--border)', display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '14px 0', gap: 6 }}>
        <div style={{ width: 32, height: 32, borderRadius: 9, background: 'linear-gradient(135deg, var(--solar), var(--wind))', display: 'grid', placeItems: 'center', marginBottom: 8 }}>
          <Icon name="globe" size={16} color="white"/>
        </div>
        {[
          { i: 'globe', lbl: 'Harita' }, { i: 'list', lbl: 'Liste' },
          { i: 'roi', lbl: 'Raporlar', on: true }, { i: 'finance', lbl: 'Finans' },
        ].map((it, i) => (
          <button key={i} className="btn btn-icon btn-ghost" style={{ width: 40, height: 40, padding: 0, background: it.on ? 'rgba(20,184,166,.10)' : 'transparent', border: it.on ? '1px solid rgba(20,184,166,.4)' : '1px solid transparent' }}>
            <Icon name={it.i} size={17} color={it.on ? 'var(--accent)' : 'var(--text-3)'}/>
          </button>
        ))}
      </div>

      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minWidth: 0 }}>
        {/* toolbar */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '14px 24px', borderBottom: '1px solid var(--border)', background: 'rgba(20,24,34,.92)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, font: '500 11.5px/1 var(--font)', color: 'var(--text-3)' }}>
            <Icon name="roi" size={12} color="var(--accent)"/>
            <span>Raporlar</span><Icon name="chevR" size={10} color="var(--text-4)"/>
            <span style={{ color: 'var(--text)', fontWeight: 600 }}>Bölge Analizi</span>
            <Icon name="chevR" size={10} color="var(--text-4)"/>
            <span style={{ color: region.color, fontWeight: 600 }}>{region.name}</span>
          </div>
          <div style={{ flex: 1 }}/>
          <button className="btn" style={{ padding: '7px 11px' }}><Icon name="ext" size={11}/> Bölgeyi dışa aktar</button>
        </div>

        {/* report tabs */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 4, padding: '0 24px', background: 'rgba(0,0,0,.18)', borderBottom: '1px solid var(--border-2)' }}>
          {[
            ['landing', 'Genel Bakış', 'globe'],
            ['bolge', 'Bölge Analizi', 'layers', true],
            ['il', 'İl Analizi', 'pin'],
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

        {/* region picker bar */}
        <div style={{ padding: '14px 24px', borderBottom: '1px solid var(--border-2)', display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap', flexShrink: 0 }}>
          <span className="label" style={{ marginRight: 8 }}>Bölge:</span>
          {TR_REGIONS.map(r => {
            const on = r.id === regionId;
            return (
              <button key={r.id} onClick={() => setRegionId(r.id)} style={{
                padding: '7px 13px', borderRadius: 8,
                background: on ? `${r.color}22` : 'rgba(0,0,0,.18)',
                border: on ? `1px solid ${r.color}66` : '1px solid var(--border-2)',
                cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 7,
                font: on ? '600 12px/1 var(--font)' : '500 12px/1 var(--font)',
                color: on ? r.color : 'var(--text-2)',
              }}>
                <div style={{ width: 7, height: 7, borderRadius: '50%', background: r.color }}/>{r.name}
              </button>
            );
          })}
        </div>

        {/* scroll content */}
        <div className="scroll" style={{ flex: 1, overflow: 'auto', padding: '22px 26px 50px' }}>
          {/* HERO */}
          <div style={{
            padding: '22px 26px', borderRadius: 16, marginBottom: 18,
            background: `linear-gradient(135deg, ${region.color}18, transparent 65%)`,
            border: `1px solid ${region.color}33`, position: 'relative', overflow: 'hidden',
          }}>
            <div style={{ position: 'absolute', right: -50, top: -50, width: 260, height: 260, borderRadius: '50%', background: `radial-gradient(circle, ${region.color}22, transparent 60%)` }}/>
            <div style={{ position: 'relative', display: 'grid', gridTemplateColumns: '1fr 460px', gap: 24 }}>
              <div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 9, marginBottom: 8 }}>
                  <span style={{ font: '600 10.5px/1 var(--font-mono)', color: region.color, textTransform: 'uppercase', letterSpacing: '.10em' }}>BÖLGE ANALİZİ</span>
                </div>
                <h1 style={{ margin: 0, font: '700 38px/1.05 var(--font)', letterSpacing: '-.03em' }}>{region.name}</h1>
                <p style={{ margin: '12px 0 0', font: '500 13px/1.55 var(--font)', color: 'var(--text-2)', maxWidth: 600 }}>{region.description}</p>
                <div style={{ marginTop: 14, font: '500 12px/1.4 var(--font)', color: 'var(--text-3)' }}>
                  <Icon name="info" size={11} color="var(--text-3)"/> {region.climateNote}
                </div>
                {/* KPI strip */}
                <div style={{ marginTop: 18, display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10 }}>
                  {[
                    ['Toplam Kapasite', `${(region.capacityMw/1000).toFixed(1)}`, 'GW', region.color],
                    ['Yıllık Üretim',    `${(region.annualGwh/1000).toFixed(1)}`, 'TWh', 'var(--text)'],
                    ['İl Sayısı',        `${region.provincesCount}`, '', 'var(--text)'],
                    ['Lider Kaynak',     TLabel[region.topResource], '', TC[region.topResource]],
                  ].map(([l, v, u, col]) => (
                    <div key={l} style={{ padding: 10, background: 'rgba(0,0,0,.25)', border: '1px solid var(--border-2)', borderRadius: 9 }}>
                      <div className="label">{l}</div>
                      <div style={{ display: 'flex', alignItems: 'baseline', gap: 3, marginTop: 5 }}>
                        <span className="tnum" style={{ font: '700 18px/1 var(--font)', color: col, letterSpacing: '-.01em' }}>{v}</span>
                        {u && <span style={{ font: '500 11px/1 var(--font)', color: 'var(--text-3)' }}>{u}</span>}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
              {/* region map highlight */}
              <div style={{ background: 'rgba(0,0,0,.25)', border: '1px solid var(--border-2)', borderRadius: 12, padding: 12 }}>
                <TurkeyRegionMap activeRegion={regionId} height={300}/>
              </div>
            </div>
          </div>

          {/* CLIMATE PROFILE */}
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 12, marginBottom: 14 }}>
            <h2 style={{ margin: 0, font: '700 17px/1 var(--font)' }}>İklim Profili · 12 Aylık</h2>
            <span style={{ font: '500 11.5px/1 var(--font)', color: 'var(--text-3)' }}>· Veri kaynakları: MGM, PVGIS, ERA-5, DSİ</span>
            <div style={{ flex: 1 }}/>
            <span className="chip">2014-2024 ortalama</span>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10, marginBottom: 18 }}>
            <WeatherStrip label="Güneş Işınımı" data={weather.irradiance}    unit="kWh/m²·gün" color="#F59E0B"/>
            <WeatherStrip label="Rüzgar Hızı"    data={weather.windSpeed}    unit="m/s @100m"  color="#3B82F6"/>
            <WeatherStrip label="Yağış"           data={weather.precipitation} unit="mm/ay"     color="#06B6D4"/>
            <WeatherStrip label="Sıcaklık"        data={weather.temperature}  unit="°C"        color="#EF4444"/>
          </div>

          {/* WIND ROSE + CLOUD + SOLAR HOURS */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1.5fr', gap: 12, marginBottom: 18 }}>
            <div style={{ padding: 16, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12 }}>
              <div className="label" style={{ marginBottom: 10 }}>Rüzgar Yön Dağılımı</div>
              <div style={{ display: 'flex', justifyContent: 'center' }}>
                <WindRose size={220} dominantDir={region.id === 'marmara' || region.id === 'ege' ? 'NW' : region.id === 'icanadolu' ? 'N' : region.id === 'akdeniz' ? 'W' : 'NE'}/>
              </div>
              <div style={{ marginTop: 8, padding: 8, background: 'rgba(0,0,0,.20)', borderRadius: 7, font: '500 11px/1.4 var(--font)', color: 'var(--text-3)' }}>
                <Icon name="info" size={10} color="var(--text-3)"/> Dominant rüzgar yönü, türbin yerleşim planlaması için kritik faktördür.
              </div>
            </div>
            <div style={{ padding: 16, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12 }}>
              <div className="label" style={{ marginBottom: 10 }}>Aylık Bulutlanma · Güneşlenme</div>
              <svg viewBox="0 0 720 240" style={{ width: '100%', height: 'auto', display: 'block' }}>
                {/* dual-axis bar+line: cloud cover bars + sunshine hours line */}
                {(() => {
                  const months = ['O','Ş','M','N','M','H','T','A','E','E','K','A'];
                  const padL = 40, padR = 36, padT = 16, padB = 24;
                  const w = 720 - padL - padR, h = 240 - padT - padB;
                  const bw = w / 12;
                  const sunshineHrs = weather.irradiance.map(v => 30 * v * 1.4); // approx hours/month
                  const maxSun = 320;
                  const xFor = i => padL + bw * (i + 0.5);
                  const yCloud = v => padT + h - (v / 100) * h;
                  const ySun   = v => padT + h - (v / maxSun) * h;
                  return (
                    <>
                      {/* grid */}
                      {[0, 25, 50, 75, 100].map(v => (
                        <g key={v}>
                          <line x1={padL} x2={720-padR} y1={yCloud(v)} y2={yCloud(v)} stroke="rgba(255,255,255,.05)" strokeWidth="1"/>
                          <text x={padL-5} y={yCloud(v)+3} textAnchor="end" fontSize="9" fill="rgba(255,255,255,.45)" fontFamily="JetBrains Mono, monospace">{v}</text>
                        </g>
                      ))}
                      {/* right axis */}
                      {[0, 100, 200, 300].map(v => (
                        <text key={v} x={720-padR+5} y={ySun(v)+3} fontSize="9" fill="rgba(245,158,11,.6)" fontFamily="JetBrains Mono, monospace">{v}</text>
                      ))}
                      <text x={padL-30} y={padT+8} fontSize="8" fill="rgba(255,255,255,.4)" fontFamily="Inter">% bulut</text>
                      <text x={720-padR+5} y={padT+8} fontSize="8" fill="rgba(245,158,11,.6)" fontFamily="Inter">saat/ay</text>
                      {/* cloud bars */}
                      {weather.cloudCover.map((v, i) => {
                        const x = xFor(i) - bw*0.35;
                        const y = yCloud(v);
                        return <rect key={i} x={x} y={y} width={bw*0.70} height={padT+h-y} rx="2" fill="rgba(96,165,250,.55)"/>;
                      })}
                      {/* sun line */}
                      <path d={sunshineHrs.map((v, i) => `${i?'L':'M'} ${xFor(i)} ${ySun(v)}`).join(' ')} fill="none" stroke="#F59E0B" strokeWidth="2.2" strokeLinecap="round"/>
                      {sunshineHrs.map((v, i) => <circle key={i} cx={xFor(i)} cy={ySun(v)} r="2.5" fill="#F59E0B"/>)}
                      {/* x labels */}
                      {months.map((m, i) => <text key={i} x={xFor(i)} y={240-8} textAnchor="middle" fontSize="9.5" fill="rgba(255,255,255,.55)" fontFamily="Inter">{m}</text>)}
                    </>
                  );
                })()}
              </svg>
              <div style={{ display: 'flex', gap: 14, marginTop: 6, font: '500 11px/1 var(--font)' }}>
                <span style={{ display: 'flex', alignItems: 'center', gap: 5, color: 'rgba(96,165,250,1)' }}><span style={{ width: 10, height: 10, borderRadius: 2, background: 'rgba(96,165,250,.55)' }}/>Bulutlanma %</span>
                <span style={{ display: 'flex', alignItems: 'center', gap: 5, color: '#F59E0B' }}><span style={{ width: 10, height: 2, background: '#F59E0B' }}/>Güneşlenme (saat/ay)</span>
              </div>
            </div>
          </div>

          {/* PROVINCES IN REGION */}
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 12, marginBottom: 14 }}>
            <h2 style={{ margin: 0, font: '700 17px/1 var(--font)' }}>Bu Bölgedeki İller</h2>
            <span style={{ font: '500 11.5px/1 var(--font)', color: 'var(--text-3)' }}>· {provinces.length} il öne çıkıyor · potansiyele göre sıralı</span>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 8, marginBottom: 18 }}>
            {provinces.length > 0 ? provinces.sort((a,b) => b.score - a.score).map(p => (
              <ProvinceCard key={p.id} province={p} region={region}/>
            )) : (
              <div style={{ gridColumn: '1 / -1', padding: 30, textAlign: 'center', background: 'rgba(0,0,0,.15)', borderRadius: 10, color: 'var(--text-3)', font: '500 12px/1.5 var(--font)' }}>
                Bu bölgede öne çıkan il verisi henüz mevcut değil.
              </div>
            )}
          </div>

          {/* INVESTMENT OPPORTUNITIES */}
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 12, marginBottom: 14 }}>
            <h2 style={{ margin: 0, font: '700 17px/1 var(--font)' }}>Bölge Yatırım Fırsatları</h2>
            <span style={{ font: '500 11.5px/1 var(--font)', color: 'var(--text-3)' }}>· Henüz değerlendirilmemiş yüksek-potansiyel sahalar</span>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10, marginBottom: 18 }}>
            {['solar', 'wind', 'hydro'].map(t => {
              const c = TC[t];
              const fit = region.bestFor.includes(t);
              const opps = provinces.flatMap(p => (PROVINCE_BEST_SPOTS[p.id] || {})[t] || []).slice(0, 3);
              return (
                <div key={t} style={{
                  padding: 14, background: 'var(--card)',
                  border: fit ? `1px solid ${c}44` : '1px solid var(--border-2)',
                  borderRadius: 12, opacity: fit ? 1 : 0.55,
                }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 9, marginBottom: 12 }}>
                    <div style={{ width: 28, height: 28, borderRadius: 8, background: `${c}22`, border: `1px solid ${c}55`, display: 'grid', placeItems: 'center' }}>
                      <TypeIcon type={t} size={14} color={c}/>
                    </div>
                    <span style={{ font: '600 13px/1 var(--font)', color: 'var(--text)', flex: 1 }}>{TLabel[t]}</span>
                    {fit && <span className="chip" style={{ borderColor: `${c}44`, color: c }}>BÖLGE LİDER</span>}
                  </div>
                  {opps.length > 0 ? (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                      {opps.map(s => (
                        <div key={`${s.district}-${s.id}-${s.name}`} style={{ padding: '8px 9px', background: 'rgba(0,0,0,.20)', border: '1px solid var(--border-2)', borderRadius: 7 }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                            <span style={{ font: '600 11.5px/1.2 var(--font)', flex: 1, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{s.name}</span>
                            <span className="tnum" style={{ font: '700 11px/1 var(--font-mono)', color: c }}>{s.potential}</span>
                          </div>
                          <div className="tnum" style={{ font: '500 10px/1.3 var(--font-mono)', color: 'var(--text-3)', marginTop: 4 }}>{s.district} · {(s.kwhAnnual/1e6).toFixed(1)}M kWh/y</div>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <div style={{ padding: 12, background: 'rgba(0,0,0,.15)', borderRadius: 8, font: '500 11px/1.4 var(--font)', color: 'var(--text-3)', textAlign: 'center' }}>
                      Bu kaynak tipi için bu bölgede yüksek-potansiyel saha yok.
                    </div>
                  )}
                </div>
              );
            })}
          </div>

          {/* DRILL DOWN */}
          <div style={{ padding: 16, background: 'linear-gradient(135deg, rgba(20,184,166,.06), transparent 65%)', border: '1px solid rgba(20,184,166,.25)', borderRadius: 12 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <div style={{ width: 38, height: 38, borderRadius: 10, background: 'rgba(20,184,166,.16)', border: '1px solid rgba(20,184,166,.4)', display: 'grid', placeItems: 'center' }}>
                <Icon name="pin" size={18} color="var(--accent)"/>
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ font: '600 14px/1.2 var(--font)' }}>İl bazlı detaylı analiz</div>
                <div style={{ font: '500 11.5px/1.4 var(--font)', color: 'var(--text-3)', marginTop: 5 }}>Bir il seçerek ilçe potansiyel haritasına, en iyi GES/RES/HES sahalarına ve detaylı hava analizine ulaşın.</div>
              </div>
              <button className="btn btn-primary" style={{ padding: '8px 14px' }}>İl Analizine geç <Icon name="arrowR" size={12} color="#06201E"/></button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

// ============================================================================
// BÖLGE ANALİZİ — Tablet (820×1180)
// ============================================================================
const RegionAnalysisTablet = ({ initialRegion = 'icanadolu' }) => {
  const [regionId, setRegionId] = useStateR2(initialRegion);
  const region = TR_REGIONS.find(r => r.id === regionId);
  const provinces = TR_PROVINCES.filter(p => p.region === regionId);
  const weather = REGION_WEATHER[regionId];

  return (
    <div style={{ width: 820, height: 1180, background: 'var(--bg)', display: 'flex', flexDirection: 'column', borderRadius: 16, overflow: 'hidden', border: '1px solid var(--border)' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '12px 16px', background: 'rgba(20,24,34,.92)', borderBottom: '1px solid var(--border)' }}>
        <button className="btn btn-icon" style={{ padding: 6 }}><Icon name="chevL" size={13}/></button>
        <div>
          <div style={{ font: '700 13px/1 var(--font)' }}>Bölge Analizi</div>
          <div style={{ font: '500 10px/1 var(--font)', color: region.color, marginTop: 3 }}>{region.name}</div>
        </div>
        <div style={{ flex: 1 }}/>
        <button className="btn btn-icon"><Icon name="ext" size={13}/></button>
      </div>
      {/* region pills */}
      <div style={{ display: 'flex', gap: 5, padding: '10px 14px', borderBottom: '1px solid var(--border-2)', background: 'rgba(0,0,0,.18)', overflowX: 'auto', whiteSpace: 'nowrap' }} className="scroll">
        {TR_REGIONS.map(r => {
          const on = r.id === regionId;
          return (
            <button key={r.id} onClick={() => setRegionId(r.id)} style={{
              padding: '6px 11px', borderRadius: 7,
              background: on ? `${r.color}22` : 'transparent',
              border: on ? `1px solid ${r.color}55` : '1px solid var(--border-2)',
              cursor: 'pointer', display: 'inline-flex', alignItems: 'center', gap: 6,
              font: on ? '600 11.5px/1 var(--font)' : '500 11.5px/1 var(--font)',
              color: on ? r.color : 'var(--text-2)', flexShrink: 0,
            }}>
              <div style={{ width: 6, height: 6, borderRadius: '50%', background: r.color }}/>{r.name}
            </button>
          );
        })}
      </div>

      <div className="scroll" style={{ flex: 1, overflow: 'auto', padding: '16px 16px 30px' }}>
        {/* Hero */}
        <div style={{ padding: 16, marginBottom: 12, background: `linear-gradient(135deg, ${region.color}18, transparent 65%)`, border: `1px solid ${region.color}33`, borderRadius: 12, position: 'relative', overflow: 'hidden' }}>
          <div style={{ position: 'absolute', right: -30, top: -30, width: 140, height: 140, borderRadius: '50%', background: `radial-gradient(circle, ${region.color}22, transparent 60%)` }}/>
          <div style={{ position: 'relative' }}>
            <div style={{ font: '600 10px/1 var(--font-mono)', color: region.color, letterSpacing: '.10em' }}>BÖLGE</div>
            <h1 style={{ margin: '8px 0 0', font: '700 28px/1.1 var(--font)', letterSpacing: '-.025em' }}>{region.name}</h1>
            <p style={{ margin: '8px 0 14px', font: '500 12px/1.5 var(--font)', color: 'var(--text-3)' }}>{region.description}</p>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8 }}>
              {[
                ['Kapasite', `${(region.capacityMw/1000).toFixed(1)} GW`, region.color],
                ['Üretim',   `${(region.annualGwh/1000).toFixed(1)} TWh`],
                ['İl',       `${region.provincesCount}`],
                ['Lider',    TLabel[region.topResource], TC[region.topResource]],
              ].map(([l, v, col]) => (
                <div key={l} style={{ padding: 8, background: 'rgba(0,0,0,.25)', borderRadius: 7 }}>
                  <div className="label">{l}</div>
                  <div className="tnum" style={{ font: '700 14px/1 var(--font)', color: col || 'var(--text)', marginTop: 4 }}>{v}</div>
                </div>
              ))}
            </div>
          </div>
        </div>

        <TurkeyRegionMap activeRegion={regionId} height={250}/>

        {/* Climate */}
        <h2 style={{ margin: '14px 0 10px', font: '700 14px/1 var(--font)' }}>İklim Profili</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 8, marginBottom: 12 }}>
          <WeatherStrip label="Işınım"  data={weather.irradiance}    unit="kWh/m²" color="#F59E0B"/>
          <WeatherStrip label="Rüzgar"  data={weather.windSpeed}    unit="m/s"   color="#3B82F6"/>
          <WeatherStrip label="Yağış"   data={weather.precipitation} unit="mm"   color="#06B6D4"/>
          <WeatherStrip label="Sıcaklık" data={weather.temperature} unit="°C"   color="#EF4444"/>
        </div>

        {/* Provinces */}
        <h2 style={{ margin: '14px 0 10px', font: '700 14px/1 var(--font)' }}>İller</h2>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6, marginBottom: 14 }}>
          {provinces.sort((a,b) => b.score - a.score).map(p => <ProvinceCard key={p.id} province={p} region={region}/>)}
        </div>

        {/* Opportunities — vertical */}
        <h2 style={{ margin: '14px 0 10px', font: '700 14px/1 var(--font)' }}>Yatırım Fırsatları</h2>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {['solar', 'wind', 'hydro'].map(t => {
            const c = TC[t];
            const fit = region.bestFor.includes(t);
            const opps = provinces.flatMap(p => (PROVINCE_BEST_SPOTS[p.id] || {})[t] || []).slice(0, 2);
            return (
              <div key={t} style={{ padding: 12, background: 'var(--card)', border: fit ? `1px solid ${c}44` : '1px solid var(--border-2)', borderRadius: 10, opacity: fit ? 1 : 0.6 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginBottom: 8 }}>
                  <TypeIcon type={t} size={14} color={c}/>
                  <span style={{ font: '600 13px/1 var(--font)', flex: 1 }}>{TLabel[t]}</span>
                  {fit && <span className="chip" style={{ borderColor: `${c}44`, color: c }}>LİDER</span>}
                </div>
                {opps.length ? opps.map(s => (
                  <div key={`${s.district}-${s.id}-${s.name}`} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: 7, background: 'rgba(0,0,0,.18)', borderRadius: 6, marginBottom: 4 }}>
                    <span style={{ font: '500 11.5px/1.2 var(--font)', flex: 1 }}>{s.name}</span>
                    <span className="tnum" style={{ font: '700 11px/1 var(--font-mono)', color: c }}>{s.potential}</span>
                  </div>
                )) : <div style={{ font: '500 10.5px/1 var(--font)', color: 'var(--text-3)' }}>Yüksek-potansiyel saha yok.</div>}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};

// ============================================================================
// BÖLGE ANALİZİ — Mobile (390×844)
// ============================================================================
const RegionAnalysisMobile = ({ initialRegion = 'icanadolu' }) => {
  const [regionId, setRegionId] = useStateR2(initialRegion);
  const region = TR_REGIONS.find(r => r.id === regionId);
  const provinces = TR_PROVINCES.filter(p => p.region === regionId);
  const weather = REGION_WEATHER[regionId];

  return (
    <div style={{ width: 390, height: 844, background: 'var(--bg)', position: 'relative', overflow: 'hidden' }}>
      <div style={{ height: 47 }}/>
      <div style={{ position: 'absolute', left: 0, right: 0, top: 47, padding: '10px 14px', display: 'flex', alignItems: 'center', gap: 9, background: 'rgba(20,24,34,.95)', backdropFilter: 'blur(14px)', borderBottom: '1px solid var(--border)', zIndex: 5 }}>
        <button className="btn btn-icon" style={{ padding: 5 }}><Icon name="chevL" size={13}/></button>
        <div style={{ flex: 1 }}>
          <div style={{ font: '700 13.5px/1 var(--font)' }}>Bölge Analizi</div>
          <div style={{ font: '500 10px/1 var(--font)', color: region.color, marginTop: 3 }}>{region.name}</div>
        </div>
        <button className="btn btn-icon" style={{ padding: 5 }}><Icon name="ext" size={13}/></button>
      </div>
      <div style={{ position: 'absolute', left: 0, right: 0, top: 105, padding: '7px 14px', background: 'rgba(0,0,0,.18)', borderBottom: '1px solid var(--border-2)', overflowX: 'auto', whiteSpace: 'nowrap', zIndex: 4 }} className="scroll">
        {TR_REGIONS.map(r => {
          const on = r.id === regionId;
          return (
            <button key={r.id} onClick={() => setRegionId(r.id)} style={{
              display: 'inline-flex', alignItems: 'center', gap: 4,
              padding: '6px 9px', marginRight: 4,
              background: on ? `${r.color}22` : 'transparent',
              border: on ? `1px solid ${r.color}55` : '1px solid var(--border-2)',
              borderRadius: 6, cursor: 'pointer',
              font: on ? '600 10.5px/1 var(--font)' : '500 10.5px/1 var(--font)',
              color: on ? r.color : 'var(--text-2)',
            }}>
              <div style={{ width: 5, height: 5, borderRadius: '50%', background: r.color }}/>{r.name}
            </button>
          );
        })}
      </div>

      <div className="scroll" style={{ position: 'absolute', left: 0, right: 0, top: 148, bottom: 0, overflow: 'auto', padding: '14px 14px 30px' }}>
        {/* hero */}
        <div style={{ padding: 12, marginBottom: 10, background: `linear-gradient(135deg, ${region.color}18, transparent 60%)`, border: `1px solid ${region.color}33`, borderRadius: 10 }}>
          <h1 style={{ margin: 0, font: '700 22px/1.1 var(--font)', letterSpacing: '-.02em' }}>{region.name}</h1>
          <p style={{ margin: '6px 0 10px', font: '500 11px/1.4 var(--font)', color: 'var(--text-3)' }}>{region.description}</p>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 6 }}>
            {[
              ['Kapasite', `${(region.capacityMw/1000).toFixed(1)} GW`, region.color],
              ['Üretim', `${(region.annualGwh/1000).toFixed(1)} TWh`],
              ['İl', `${region.provincesCount}`],
              ['Lider', TLabel[region.topResource], TC[region.topResource]],
            ].map(([l, v, col]) => (
              <div key={l} style={{ padding: 8, background: 'rgba(0,0,0,.25)', borderRadius: 6 }}>
                <div className="label">{l}</div>
                <div className="tnum" style={{ font: '700 14px/1 var(--font)', color: col || 'var(--text)', marginTop: 4 }}>{v}</div>
              </div>
            ))}
          </div>
        </div>

        <TurkeyRegionMap activeRegion={regionId} height={180}/>

        <h2 style={{ margin: '12px 0 8px', font: '700 13px/1 var(--font)' }}>İklim Profili</h2>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: 6, marginBottom: 12 }}>
          <WeatherStrip label="Işınım" data={weather.irradiance} unit="kWh/m²" color="#F59E0B"/>
          <WeatherStrip label="Rüzgar" data={weather.windSpeed} unit="m/s" color="#3B82F6"/>
        </div>

        <h2 style={{ margin: '12px 0 8px', font: '700 13px/1 var(--font)' }}>İller ({provinces.length})</h2>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 5 }}>
          {provinces.sort((a,b) => b.score - a.score).map(p => <ProvinceCard key={p.id} province={p} region={region}/>)}
        </div>
      </div>
    </div>
  );
};

Object.assign(window, { RegionAnalysisDesktop, RegionAnalysisTablet, RegionAnalysisMobile, WeatherStrip, WindRose, ProvinceCard });
