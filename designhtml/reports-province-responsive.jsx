// reports-province-responsive.jsx — Tablet + Mobile versions of Province Analysis

// ============================================================================
// İl Analizi — Tablet (820×1180)
// ============================================================================
const ProvinceAnalysisTablet = ({ initialProvinceId = 'konya' }) => {
  const [provinceId, setProvinceId] = useStateP(initialProvinceId);
  const [tab, setTab] = useStateP('overview');
  const [selectedDistrict, setSelectedDistrict] = useStateP(null);
  const [bestSpotType, setBestSpotType] = useStateP('solar');
  const province = TR_PROVINCES.find(p => p.id === provinceId);
  const region = TR_REGIONS.find(r => r.id === province.region);
  const spots = PROVINCE_BEST_SPOTS[provinceId] || { solar: [], wind: [], hydro: [] };
  const weather = REGION_WEATHER[province.region];

  return (
    <div style={{ width: 820, height: 1180, background: 'var(--bg)', display: 'flex', flexDirection: 'column', borderRadius: 16, overflow: 'hidden', border: '1px solid var(--border)' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '12px 16px', background: 'rgba(20,24,34,.92)', borderBottom: '1px solid var(--border)' }}>
        <button className="btn btn-icon" style={{ padding: 6 }}><Icon name="chevL" size={13}/></button>
        <div>
          <div style={{ font: '700 13px/1 var(--font)' }}>İl Analizi</div>
          <div style={{ font: '500 10px/1 var(--font)', color: region.color, marginTop: 3 }}>{region.name} · {province.name}</div>
        </div>
        <div style={{ flex: 1 }}/>
        <select value={provinceId} onChange={e => { setProvinceId(e.target.value); setSelectedDistrict(null); }}
          className="input" style={{ width: 160, padding: '5px 9px', fontSize: 12 }}>
          {TR_REGIONS.map(r => (
            <optgroup key={r.id} label={r.name}>
              {TR_PROVINCES.filter(p => p.region === r.id).map(p => <option key={p.id} value={p.id}>{p.name}</option>)}
            </optgroup>
          ))}
        </select>
      </div>

      {/* sub-tabs */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '10px 14px', borderBottom: '1px solid var(--border-2)', background: 'rgba(0,0,0,.10)' }}>
        <div className="seg">
          {[
            { id: 'overview', l: 'Saha', ic: 'layers' },
            { id: 'weather', l: 'Hava', ic: 'temp' },
          ].map(t => (
            <button key={t.id} onClick={() => setTab(t.id)} className={tab === t.id ? 'on' : ''} style={{ padding: '6px 11px', font: '500 11.5px/1 var(--font)' }}>
              <Icon name={t.ic} size={10} color={tab === t.id ? 'var(--accent)' : 'var(--text-3)'}/>{t.l}
            </button>
          ))}
        </div>
        {selectedDistrict && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 5, padding: '4px 8px', background: 'rgba(20,184,166,.10)', border: '1px solid rgba(20,184,166,.35)', borderRadius: 6 }}>
            <span style={{ font: '600 10.5px/1 var(--font)', color: 'var(--accent)' }}>{selectedDistrict}</span>
            <button onClick={() => setSelectedDistrict(null)} style={{ background: 'transparent', border: 'none', color: 'var(--accent)', cursor: 'pointer', font: '500 13px/1 var(--font)', padding: 0 }}>×</button>
          </div>
        )}
      </div>

      <div className="scroll" style={{ flex: 1, overflow: 'auto', padding: '16px 16px 30px' }}>
        {/* hero */}
        <div style={{ padding: 14, marginBottom: 12, background: `linear-gradient(135deg, ${region.color}15, transparent 65%)`, border: `1px solid ${region.color}33`, borderRadius: 12 }}>
          <h1 style={{ margin: 0, font: '700 26px/1.1 var(--font)' }}>{province.name}</h1>
          <div style={{ marginTop: 6, font: '500 11px/1 var(--font)', color: 'var(--text-3)' }}>{region.name} · {province.districts.length} ilçe · Lider: <b style={{ color: TC[province.topRes] }}>{TLabel[province.topRes]}</b></div>
          <div style={{ marginTop: 12, display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8 }}>
            {[
              ['Kapasite', `${province.capacityMw}`, 'MW', region.color],
              ['Üretim', `${(province.annualGwh/1000).toFixed(2)}`, 'TWh'],
              ['Skor', `${province.score}`, '/100', TC[province.topRes]],
              ['Saha', `${spots.solar.length + spots.wind.length + spots.hydro.length}`, ''],
            ].map(([l, v, u, col]) => (
              <div key={l} style={{ padding: 8, background: 'rgba(0,0,0,.25)', borderRadius: 7 }}>
                <div className="label">{l}</div>
                <div style={{ display: 'flex', alignItems: 'baseline', gap: 3, marginTop: 4 }}>
                  <span className="tnum" style={{ font: '700 14px/1 var(--font)', color: col || 'var(--text)' }}>{v}</span>
                  {u && <span style={{ font: '500 9px/1 var(--font)', color: 'var(--text-3)' }}>{u}</span>}
                </div>
              </div>
            ))}
          </div>
        </div>

        {tab === 'overview' && (
          <>
            {/* district map */}
            <div style={{ padding: 12, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 10, marginBottom: 10 }}>
              <div className="label" style={{ marginBottom: 8 }}>İlçe Haritası</div>
              <DistrictMap province={province} selectedDistrict={selectedDistrict} onSelectDistrict={setSelectedDistrict} height={280}/>
            </div>

            {/* type tabs for spots */}
            <div className="seg" style={{ marginBottom: 10, width: '100%' }}>
              {['solar', 'wind', 'hydro'].map(t => (
                <button key={t} onClick={() => setBestSpotType(t)} className={bestSpotType === t ? 'on' : ''} style={{ flex: 1, padding: '8px 12px', color: bestSpotType === t ? TC[t] : undefined }}>
                  <TypeIcon type={t} size={11} color={bestSpotType === t ? TC[t] : 'var(--text-3)'}/>{TLabel[t]} ({(spots[t] || []).length})
                </button>
              ))}
            </div>
            {/* best spots */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: 7, marginBottom: 12 }}>
              {((selectedDistrict ? spots[bestSpotType].filter(s => s.district === selectedDistrict) : spots[bestSpotType]) || []).map((s, i) => (
                <BestSpotCard key={s.id} spot={s} type={bestSpotType} isTop={i === 0}/>
              ))}
              {(spots[bestSpotType] || []).length === 0 && (
                <div style={{ padding: 18, background: 'rgba(0,0,0,.15)', borderRadius: 8, font: '500 11.5px/1.5 var(--font)', color: 'var(--text-3)', textAlign: 'center' }}>
                  Bu kaynak tipi için saha tespit edilmedi.
                </div>
              )}
            </div>

            {/* district ranking */}
            <div style={{ padding: 12, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 10 }}>
              <div className="label" style={{ marginBottom: 8 }}>İlçe Sıralaması</div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                {province.districtsData
                  .map(d => ({ ...d, _score: Math.max(d.solarScore, d.windScore, d.hydroScore) }))
                  .sort((a, b) => b._score - a._score).map((d, i) => {
                  const best = d.solarScore > Math.max(d.windScore, d.hydroScore) ? 'solar' :
                               d.windScore > d.hydroScore ? 'wind' : 'hydro';
                  const c = TC[best];
                  return (
                    <div key={d.name} onClick={() => setSelectedDistrict(d.name)} style={{
                      display: 'grid', gridTemplateColumns: '22px 1fr 22px 36px 40px', gap: 8, alignItems: 'center',
                      padding: '7px 9px', background: d.name === selectedDistrict ? `${c}15` : 'rgba(0,0,0,.18)',
                      border: d.name === selectedDistrict ? `1px solid ${c}44` : '1px solid var(--border-2)',
                      borderRadius: 7, cursor: 'pointer',
                    }}>
                      <span className="tnum" style={{ font: '700 10px/1 var(--font-mono)', color: c }}>#{i+1}</span>
                      <span style={{ font: '500 12px/1 var(--font)' }}>{d.name}</span>
                      <TypeIcon type={best} size={11} color={c}/>
                      <span className="tnum" style={{ font: '700 11px/1 var(--font-mono)', color: c, textAlign: 'right' }}>{d._score}</span>
                      <span className="tnum" style={{ font: '500 10px/1 var(--font-mono)', color: 'var(--text-3)', textAlign: 'right' }}>{d.availableMw}MW</span>
                    </div>
                  );
                })}
              </div>
            </div>
          </>
        )}

        {tab === 'weather' && (
          <ProvinceWeatherTab province={province} weather={weather}/>
        )}
      </div>
    </div>
  );
};

// ============================================================================
// İl Analizi — Mobile (390×844)
// ============================================================================
const ProvinceAnalysisMobile = ({ initialProvinceId = 'konya' }) => {
  const [provinceId, setProvinceId] = useStateP(initialProvinceId);
  const [tab, setTab] = useStateP('overview');
  const [bestSpotType, setBestSpotType] = useStateP('solar');
  const province = TR_PROVINCES.find(p => p.id === provinceId);
  const region = TR_REGIONS.find(r => r.id === province.region);
  const spots = PROVINCE_BEST_SPOTS[provinceId] || { solar: [], wind: [], hydro: [] };
  const weather = REGION_WEATHER[province.region];

  return (
    <div style={{ width: 390, height: 844, background: 'var(--bg)', position: 'relative', overflow: 'hidden' }}>
      <div style={{ height: 47 }}/>
      <div style={{ position: 'absolute', left: 0, right: 0, top: 47, padding: '10px 14px', display: 'flex', alignItems: 'center', gap: 8, background: 'rgba(20,24,34,.95)', backdropFilter: 'blur(14px)', borderBottom: '1px solid var(--border)', zIndex: 5 }}>
        <button className="btn btn-icon" style={{ padding: 5 }}><Icon name="chevL" size={13}/></button>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ font: '700 13px/1 var(--font)' }}>İl Analizi</div>
          <div style={{ font: '500 10px/1 var(--font)', color: region.color, marginTop: 3 }}>{region.name}</div>
        </div>
        <select value={provinceId} onChange={e => setProvinceId(e.target.value)}
          style={{ width: 120, padding: '5px 8px', fontSize: 11.5, background: 'rgba(0,0,0,.30)', border: '1px solid var(--border)', borderRadius: 6, color: 'var(--text)' }}>
          {TR_PROVINCES.map(p => <option key={p.id} value={p.id}>{p.name}</option>)}
        </select>
      </div>

      <div style={{ position: 'absolute', left: 0, right: 0, top: 102, padding: '8px 14px', background: 'rgba(0,0,0,.18)', borderBottom: '1px solid var(--border-2)', zIndex: 4 }}>
        <div className="seg" style={{ width: '100%' }}>
          <button onClick={() => setTab('overview')} className={tab === 'overview' ? 'on' : ''} style={{ flex: 1, padding: '6px 9px' }}><Icon name="layers" size={10} color={tab === 'overview' ? 'var(--accent)' : 'var(--text-3)'}/> Saha</button>
          <button onClick={() => setTab('weather')} className={tab === 'weather' ? 'on' : ''} style={{ flex: 1, padding: '6px 9px' }}><Icon name="temp" size={10} color={tab === 'weather' ? 'var(--accent)' : 'var(--text-3)'}/> Hava</button>
        </div>
      </div>

      <div className="scroll" style={{ position: 'absolute', left: 0, right: 0, top: 150, bottom: 84, overflow: 'auto', padding: '14px 14px 30px' }}>
        {/* hero */}
        <div style={{ padding: 12, marginBottom: 10, background: `linear-gradient(135deg, ${region.color}15, transparent 65%)`, border: `1px solid ${region.color}33`, borderRadius: 10 }}>
          <h1 style={{ margin: 0, font: '700 24px/1.1 var(--font)' }}>{province.name}</h1>
          <div style={{ marginTop: 4, font: '500 10.5px/1 var(--font)', color: 'var(--text-3)' }}>{province.districts.length} ilçe · {TLabel[province.topRes]}</div>
          <div style={{ marginTop: 10, display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 6 }}>
            <div style={{ padding: 8, background: 'rgba(0,0,0,.25)', borderRadius: 6 }}>
              <div className="label">Kapasite</div>
              <div className="tnum" style={{ font: '700 16px/1 var(--font)', color: region.color, marginTop: 3 }}>{province.capacityMw}<span style={{ fontSize: 9, color: 'var(--text-3)', fontWeight: 500, marginLeft: 2 }}>MW</span></div>
            </div>
            <div style={{ padding: 8, background: 'rgba(0,0,0,.25)', borderRadius: 6 }}>
              <div className="label">Skor</div>
              <div className="tnum" style={{ font: '700 16px/1 var(--font)', color: TC[province.topRes], marginTop: 3 }}>{province.score}<span style={{ fontSize: 9, color: 'var(--text-3)', fontWeight: 500, marginLeft: 2 }}>/100</span></div>
            </div>
          </div>
        </div>

        {tab === 'overview' && (
          <>
            <div style={{ padding: 10, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 10, marginBottom: 10 }}>
              <div className="label" style={{ marginBottom: 6 }}>İlçe Haritası</div>
              <DistrictMap province={province} height={220}/>
            </div>

            <div className="seg" style={{ marginBottom: 10, width: '100%' }}>
              {['solar', 'wind', 'hydro'].map(t => (
                <button key={t} onClick={() => setBestSpotType(t)} className={bestSpotType === t ? 'on' : ''} style={{ flex: 1, padding: '6px 6px', font: '500 11px/1 var(--font)' }}>
                  <TypeIcon type={t} size={10} color={bestSpotType === t ? TC[t] : 'var(--text-3)'}/>{TLabel[t]}
                </button>
              ))}
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 6, marginBottom: 12 }}>
              {(spots[bestSpotType] || []).map((s, i) => <BestSpotCard key={s.id} spot={s} type={bestSpotType} isTop={i === 0}/>)}
              {(spots[bestSpotType] || []).length === 0 && (
                <div style={{ padding: 14, background: 'rgba(0,0,0,.15)', borderRadius: 8, font: '500 11px/1.5 var(--font)', color: 'var(--text-3)', textAlign: 'center' }}>
                  Saha bulunamadı.
                </div>
              )}
            </div>

            <div className="label" style={{ marginBottom: 6 }}>İlçeler · Top 5</div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
              {province.districtsData
                .map(d => ({ ...d, _score: Math.max(d.solarScore, d.windScore, d.hydroScore) }))
                .sort((a, b) => b._score - a._score).slice(0, 5).map((d, i) => {
                const best = d.solarScore > Math.max(d.windScore, d.hydroScore) ? 'solar' :
                             d.windScore > d.hydroScore ? 'wind' : 'hydro';
                const c = TC[best];
                return (
                  <div key={d.name} style={{ display: 'flex', alignItems: 'center', gap: 7, padding: '7px 9px', background: 'rgba(0,0,0,.18)', border: '1px solid var(--border-2)', borderRadius: 7 }}>
                    <span className="tnum" style={{ font: '700 10px/1 var(--font-mono)', color: c, minWidth: 15 }}>#{i+1}</span>
                    <TypeIcon type={best} size={10} color={c}/>
                    <span style={{ font: '500 11.5px/1 var(--font)', flex: 1 }}>{d.name}</span>
                    <span className="tnum" style={{ font: '700 11px/1 var(--font-mono)', color: c }}>{d._score}</span>
                  </div>
                );
              })}
            </div>
          </>
        )}

        {tab === 'weather' && (
          <>
            <div style={{ padding: 12, background: 'linear-gradient(135deg, rgba(56,189,248,.06), transparent 65%)', border: '1px solid rgba(56,189,248,.20)', borderRadius: 10, marginBottom: 12 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <Icon name="temp" size={14} color="#38BDF8"/>
                <span style={{ font: '600 12px/1 var(--font)', color: '#38BDF8' }}>Hava Analizi</span>
              </div>
              <div style={{ font: '500 11px/1.4 var(--font)', color: 'var(--text-3)', marginTop: 6 }}>{region.climateNote}</div>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: 6, marginBottom: 12 }}>
              <WeatherStrip label="Işınım" data={weather.irradiance} unit="kWh/m²" color="#F59E0B"/>
              <WeatherStrip label="Rüzgar" data={weather.windSpeed} unit="m/s" color="#3B82F6"/>
              <WeatherStrip label="Yağış" data={weather.precipitation} unit="mm" color="#06B6D4"/>
              <WeatherStrip label="Sıcaklık" data={weather.temperature} unit="°C" color="#EF4444"/>
            </div>
            <div style={{ padding: 12, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 10, marginBottom: 12 }}>
              <div className="label" style={{ marginBottom: 8 }}>Rüzgar Yönü</div>
              <div style={{ display: 'flex', justifyContent: 'center' }}>
                <WindRose size={180} dominantDir={province.region === 'marmara' || province.region === 'ege' ? 'NW' : province.region === 'icanadolu' ? 'N' : 'NE'}/>
              </div>
            </div>
            <div className="label" style={{ marginBottom: 8 }}>Risk Uyarıları</div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
              {[
                ['Don/Kar', province.region === 'doguanadolu' ? 'Yüksek' : province.region === 'icanadolu' ? 'Orta' : 'Düşük', 'temp'],
                ['Kuraklık', province.region === 'icanadolu' || province.region === 'gdanadolu' ? 'Yüksek' : 'Orta', 'water'],
                ['Sel/Heyelan', province.region === 'karadeniz' ? 'Yüksek' : 'Düşük', 'water'],
              ].map(([l, lv, ic]) => {
                const c = lv === 'Yüksek' ? '#EF4444' : lv === 'Orta' ? '#F59E0B' : '#10B981';
                return (
                  <div key={l} style={{ display: 'flex', alignItems: 'center', gap: 9, padding: '8px 10px', background: 'rgba(0,0,0,.18)', border: `1px solid ${c}33`, borderRadius: 8 }}>
                    <Icon name={ic} size={12} color={c}/>
                    <span style={{ font: '500 12px/1 var(--font)', flex: 1 }}>{l}</span>
                    <span style={{ font: '700 11px/1 var(--font)', color: c }}>{lv}</span>
                  </div>
                );
              })}
            </div>
          </>
        )}
      </div>

      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: 84, background: 'rgba(20,24,34,.95)', backdropFilter: 'blur(20px)', borderTop: '1px solid var(--border)', display: 'flex', paddingBottom: 24 }}>
        {[
          { i: 'globe', l: 'Harita' },
          { i: 'list', l: 'Liste' },
          { i: 'roi', l: 'Rapor', on: true },
          { i: 'gear', l: 'Ayarlar' },
        ].map(t => (
          <button key={t.i} style={{ flex: 1, background: 'transparent', border: 'none', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, padding: '10px 0', cursor: 'pointer' }}>
            <Icon name={t.i} size={20} color={t.on ? 'var(--accent)' : 'var(--text-3)'}/>
            <span style={{ font: '600 10px/1 var(--font)', color: t.on ? 'var(--accent)' : 'var(--text-3)' }}>{t.l}</span>
          </button>
        ))}
      </div>
    </div>
  );
};

Object.assign(window, { ProvinceAnalysisTablet, ProvinceAnalysisMobile });
