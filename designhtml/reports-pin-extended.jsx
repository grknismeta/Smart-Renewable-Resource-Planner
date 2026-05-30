// reports-pin-extended.jsx — Type-specific deep-dive + TR financial + production timeline + manual override

const { useState: useStateX, useMemo: useMemoX } = React;

// ============================================================================
// Production Timeline — kümülatif üretim, custom başlangıç tarihi
// ============================================================================
const ProductionTimeline = ({ pin, height = 220 }) => {
  const [startDate, setStartDate] = useStateX('2024-01-01');
  const today = new Date('2026-05-19');
  const startD = new Date(startDate);
  const daysSinceStart = Math.max(1, Math.floor((today - startD) / (1000 * 60 * 60 * 24)));
  const yearsSince = daysSinceStart / 365;
  const annualKwh = pin.annualKwh;
  const totalKwhSinceStart = annualKwh * yearsSince;
  const cumRevenue = totalKwhSinceStart * 0.072;
  const cumCO2 = totalKwhSinceStart * 0.689 / 1000; // tons

  // Generate cumulative production curve from start date to today (monthly resolution)
  const monthsElapsed = Math.floor(daysSinceStart / 30);
  const curve = [];
  for (let m = 0; m <= monthsElapsed; m++) {
    const monthIdx = (startD.getMonth() + m) % 12;
    const monthlyKwh = pin.monthly[monthIdx] || annualKwh / 12;
    const prev = curve.length > 0 ? curve[curve.length - 1] : 0;
    // Add slight variability
    curve.push(prev + monthlyKwh * (0.93 + (m % 4) * 0.025));
  }
  const max = curve[curve.length - 1] || 1;
  const c = TC[pin.type];

  // Quick presets
  const setPreset = (days) => {
    const d = new Date(today);
    d.setDate(d.getDate() - days);
    setStartDate(d.toISOString().slice(0, 10));
  };

  return (
    <div style={{ padding: 14, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12, flexWrap: 'wrap' }}>
        <span className="label" style={{ flex: 1, minWidth: 180 }}>Geçmişten Bugüne Üretim</span>
        <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
          <span style={{ font: '500 11px/1 var(--font)', color: 'var(--text-3)' }}>Başlangıç:</span>
          <input type="date" value={startDate} onChange={e => setStartDate(e.target.value)}
            style={{ padding: '6px 9px', background: 'rgba(0,0,0,.30)', border: '1px solid var(--border)', borderRadius: 7, color: 'var(--text)', font: '500 11.5px/1 var(--font-mono)', colorScheme: 'dark' }}/>
        </div>
        <div className="seg" style={{ padding: 2 }}>
          {[
            ['30G',  30],
            ['90G',  90],
            ['1Y',   365],
            ['2Y',   730],
            ['5Y',   1825],
          ].map(([l, d]) => (
            <button key={l} onClick={() => setPreset(d)} style={{ padding: '5px 9px', font: '500 11px/1 var(--font-mono)', background: 'transparent', border: 'none', color: 'var(--text-2)', borderRadius: 5, cursor: 'pointer' }}>{l}</button>
          ))}
        </div>
      </div>

      {/* big KPIs */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10, marginBottom: 12 }}>
        <div style={{ padding: 10, background: 'rgba(0,0,0,.20)', borderRadius: 8 }}>
          <div className="label">Süre</div>
          <div className="tnum" style={{ font: '700 17px/1 var(--font)', marginTop: 5 }}>{daysSinceStart}<span style={{ fontSize: 10, color: 'var(--text-3)', fontWeight: 500, marginLeft: 2 }}>gün</span></div>
          <div className="tnum" style={{ font: '500 10px/1.3 var(--font-mono)', color: 'var(--text-3)', marginTop: 3 }}>{yearsSince.toFixed(2)} yıl · {monthsElapsed} ay</div>
        </div>
        <div style={{ padding: 10, background: 'rgba(0,0,0,.20)', borderRadius: 8 }}>
          <div className="label">Kümülatif Üretim</div>
          <div className="tnum" style={{ font: '700 17px/1 var(--font)', color: c, marginTop: 5 }}>{(totalKwhSinceStart/1e6).toFixed(1)}<span style={{ fontSize: 10, color: 'var(--text-3)', fontWeight: 500, marginLeft: 2 }}>GWh</span></div>
          <div className="tnum" style={{ font: '500 10px/1.3 var(--font-mono)', color: 'var(--text-3)', marginTop: 3 }}>≈ {Math.round(totalKwhSinceStart/3500/1000)}K hane/yıl</div>
        </div>
        <div style={{ padding: 10, background: 'rgba(0,0,0,.20)', borderRadius: 8 }}>
          <div className="label">Kümülatif Gelir</div>
          <div className="tnum" style={{ font: '700 17px/1 var(--font)', color: '#10B981', marginTop: 5 }}>${(cumRevenue/1e6).toFixed(2)}<span style={{ fontSize: 10, color: 'var(--text-3)', fontWeight: 500, marginLeft: 2 }}>M</span></div>
          <div className="tnum" style={{ font: '500 10px/1.3 var(--font-mono)', color: 'var(--text-3)', marginTop: 3 }}>@$0.072/kWh</div>
        </div>
        <div style={{ padding: 10, background: 'rgba(0,0,0,.20)', borderRadius: 8 }}>
          <div className="label">CO₂ Önlendi</div>
          <div className="tnum" style={{ font: '700 17px/1 var(--font)', color: '#10B981', marginTop: 5 }}>{(cumCO2/1000).toFixed(1)}<span style={{ fontSize: 10, color: 'var(--text-3)', fontWeight: 500, marginLeft: 2 }}>kton</span></div>
          <div className="tnum" style={{ font: '500 10px/1.3 var(--font-mono)', color: 'var(--text-3)', marginTop: 3 }}>{Math.round(cumCO2/4.6/1000)}K araç eşd.</div>
        </div>
      </div>

      {/* line chart */}
      <svg viewBox={`0 0 720 ${height}`} style={{ width: '100%', height: 'auto', display: 'block' }}>
        <defs>
          <linearGradient id="prodFill" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0" stopColor={c} stopOpacity="0.35"/>
            <stop offset="1" stopColor={c} stopOpacity="0"/>
          </linearGradient>
        </defs>
        {(() => {
          const padL = 60, padR = 16, padT = 12, padB = 24;
          const w = 720 - padL - padR, h = height - padT - padB;
          const xStep = w / Math.max(1, curve.length - 1);
          const xFor = i => padL + i * xStep;
          const yFor = v => padT + h - (v / max) * h;
          const path = curve.map((v, i) => `${i ? 'L' : 'M'} ${xFor(i).toFixed(1)} ${yFor(v).toFixed(1)}`).join(' ');
          const areaD = `${path} L ${xFor(curve.length-1)} ${padT+h} L ${padL} ${padT+h} Z`;
          // year ticks
          const years = [];
          for (let m = 0; m <= curve.length; m++) {
            const d = new Date(startD); d.setMonth(startD.getMonth() + m);
            if (d.getMonth() === 0 || m === 0 || m === curve.length - 1) {
              years.push({ idx: m, label: `${d.getFullYear()}.${(d.getMonth()+1).toString().padStart(2,'0')}` });
            }
          }
          return (
            <>
              {/* grid */}
              {[0, 0.25, 0.5, 0.75, 1].map(t => (
                <g key={t}>
                  <line x1={padL} x2={720-padR} y1={yFor(t * max)} y2={yFor(t * max)} stroke="rgba(255,255,255,.05)" strokeWidth="1"/>
                  <text x={padL-6} y={yFor(t * max)+3} textAnchor="end" fontSize="9" fill="rgba(255,255,255,.45)" fontFamily="JetBrains Mono, monospace">{(t*max/1e6).toFixed(1)}M</text>
                </g>
              ))}
              <text x={padL-50} y={padT+8} fontSize="8" fill="rgba(255,255,255,.4)" fontFamily="Inter">kWh</text>
              <path d={areaD} fill="url(#prodFill)"/>
              <path d={path} fill="none" stroke={c} strokeWidth="2.4" strokeLinecap="round"/>
              {/* end marker */}
              <circle cx={xFor(curve.length-1)} cy={yFor(curve[curve.length-1])} r="5" fill={c} stroke="#0B0E14" strokeWidth="2"/>
              {/* year labels */}
              {years.slice(0, 8).map(y => (
                <text key={y.idx} x={xFor(y.idx)} y={padT+h+15} textAnchor="middle" fontSize="9.5" fill="rgba(255,255,255,.55)" fontFamily="JetBrains Mono, monospace">{y.label}</text>
              ))}
            </>
          );
        })()}
      </svg>
    </div>
  );
};

// ============================================================================
// Solar Deep-Dive: tilt/azimuth interactive
// ============================================================================
const SolarDeepDive = ({ pin }) => {
  const [tilt, setTilt] = useStateX(pin.panelTilt || 32);
  const [azimuth, setAzimuth] = useStateX(pin.panelAzimuth || 180);
  const baseAnnual = pin.annualKwh;
  // Simple model: tilt optimal ≈ latitude (37°), each degree off = -0.1% to -0.2%
  // Azimuth optimal = 180° (south), each degree off = -0.05% to -0.10%
  const tiltLoss = Math.min(0.18, Math.abs(tilt - 32) * 0.0028);
  const azLoss = Math.min(0.22, Math.abs(azimuth - 180) * 0.0014);
  const adjusted = baseAnnual * (1 - tiltLoss) * (1 - azLoss);
  const delta = ((adjusted - baseAnnual) / baseAnnual) * 100;

  // Solar elevation simple sketch
  const solarPathPoints = [];
  for (let h = 6; h <= 18; h += 0.5) {
    const elev = Math.max(0, 70 * Math.sin((h - 6) / 12 * Math.PI));
    solarPathPoints.push([h, elev]);
  }

  return (
    <div style={{ padding: 16, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14 }}>
        <Icon name="sun" size={15} color="#F59E0B"/>
        <span style={{ font: '600 13px/1 var(--font)', color: '#F59E0B', flex: 1 }}>Güneş Paneli · Teknik Konfigürasyon</span>
        <span className="chip" style={{ borderColor: 'rgba(245,158,11,.4)', color: '#F59E0B' }}>İNTERAKTİF</span>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1.4fr 1fr', gap: 14 }}>
        {/* sliders */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginBottom: 6 }}>
              <span className="label" style={{ flex: 1 }}>Panel Eğimi</span>
              <span className="tnum" style={{ font: '700 16px/1 var(--font)', color: '#F59E0B' }}>{tilt}°</span>
              <span style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)' }}>(optimal ≈ 32°)</span>
            </div>
            <input type="range" min={0} max={60} step={1} value={tilt} onChange={e => setTilt(+e.target.value)}
              style={{ width: '100%', accentColor: '#F59E0B' }}/>
            <div className="tnum" style={{ display: 'flex', justifyContent: 'space-between', font: '500 9.5px/1 var(--font-mono)', color: 'var(--text-4)' }}>
              <span>0°</span><span>30°</span><span>60°</span>
            </div>
          </div>
          <div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginBottom: 6 }}>
              <span className="label" style={{ flex: 1 }}>Azimut Açısı</span>
              <span className="tnum" style={{ font: '700 16px/1 var(--font)', color: '#F59E0B' }}>{azimuth}°</span>
              <span style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)' }}>(180° = Güney)</span>
            </div>
            <input type="range" min={90} max={270} step={5} value={azimuth} onChange={e => setAzimuth(+e.target.value)}
              style={{ width: '100%', accentColor: '#F59E0B' }}/>
            <div className="tnum" style={{ display: 'flex', justifyContent: 'space-between', font: '500 9.5px/1 var(--font-mono)', color: 'var(--text-4)' }}>
              <span>D</span><span>G</span><span>B</span>
            </div>
          </div>
          {/* Panel meta */}
          <div style={{ padding: 11, background: 'rgba(0,0,0,.20)', borderRadius: 8 }}>
            <div className="label" style={{ marginBottom: 7 }}>Panel Konfigürasyonu</div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 6, font: '500 11px/1.4 var(--font)' }}>
              <div><span style={{ color: 'var(--text-3)' }}>Model:</span> <b style={{ color: 'var(--text)' }}>{pin.equipment || 'Trina Vertex 660W'}</b></div>
              <div><span style={{ color: 'var(--text-3)' }}>Panel sayısı:</span> <b className="tnum" style={{ color: 'var(--text)', fontFamily: 'var(--font-mono)' }}>24,800</b></div>
              <div><span style={{ color: 'var(--text-3)' }}>Panel alanı:</span> <b className="tnum" style={{ color: 'var(--text)', fontFamily: 'var(--font-mono)' }}>{((pin.panelArea || 80000)/10000).toFixed(1)} ha</b></div>
              <div><span style={{ color: 'var(--text-3)' }}>Verim:</span> <b className="tnum" style={{ color: 'var(--text)', fontFamily: 'var(--font-mono)' }}>%22.4</b></div>
              <div><span style={{ color: 'var(--text-3)' }}>Yıllık ışınım:</span> <b className="tnum" style={{ color: 'var(--text)', fontFamily: 'var(--font-mono)' }}>{pin.irradiance || 5.4} kWh/m²</b></div>
              <div><span style={{ color: 'var(--text-3)' }}>Inverter verimi:</span> <b className="tnum" style={{ color: 'var(--text)', fontFamily: 'var(--font-mono)' }}>%98.4</b></div>
            </div>
          </div>
        </div>
        {/* result */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <div style={{ padding: 14, background: delta >= -2 ? 'rgba(16,185,129,.10)' : 'rgba(239,68,68,.08)', border: delta >= -2 ? '1px solid rgba(16,185,129,.30)' : '1px solid rgba(239,68,68,.30)', borderRadius: 10 }}>
            <div className="label" style={{ marginBottom: 7 }}>Yıllık Üretim Tahmini</div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 5 }}>
              <span className="tnum" style={{ font: '700 28px/1 var(--font)', color: '#F59E0B', letterSpacing: '-.02em' }}>{(adjusted/1e6).toFixed(1)}</span>
              <span style={{ font: '600 13px/1 var(--font)', color: 'var(--text-2)' }}>GWh</span>
            </div>
            <div style={{ marginTop: 8, paddingTop: 8, borderTop: '1px dashed var(--border-2)', display: 'flex', justifyContent: 'space-between', font: '500 11px/1 var(--font)', color: 'var(--text-3)' }}>
              <span>Baseline (32°/180°)</span>
              <span className="tnum">{(baseAnnual/1e6).toFixed(1)} GWh</span>
            </div>
            <div style={{ marginTop: 6, display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
              <span style={{ font: '500 11px/1 var(--font)', color: 'var(--text-3)' }}>Etki</span>
              <span className="tnum" style={{ font: '700 14px/1 var(--font-mono)', color: delta >= 0 ? '#10B981' : '#EF4444' }}>{delta >= 0 ? '+' : ''}{delta.toFixed(2)}%</span>
            </div>
          </div>
          <div style={{ padding: 12, background: 'rgba(0,0,0,.20)', borderRadius: 9 }}>
            <div className="label" style={{ marginBottom: 8 }}>Tipik Gün · Güneş Yüksekliği</div>
            <svg viewBox="0 0 240 90" style={{ width: '100%', height: 'auto' }}>
              <line x1="10" x2="230" y1="80" y2="80" stroke="rgba(255,255,255,.15)" strokeWidth="1"/>
              <path d={solarPathPoints.map((p, i) => `${i ? 'L' : 'M'} ${10 + (p[0]-6)/12 * 220} ${80 - p[1]}`).join(' ')} fill="none" stroke="#F59E0B" strokeWidth="2"/>
              <circle cx="120" cy="10" r="3.5" fill="#F59E0B"/>
              <text x="120" y="6" textAnchor="middle" fontSize="8" fill="#F59E0B" fontFamily="JetBrains Mono, monospace">12:30 · 70°</text>
              {['06:00','12:00','18:00'].map((t, i) => (
                <text key={t} x={10 + i * 110} y="88" textAnchor="middle" fontSize="8" fill="rgba(255,255,255,.45)" fontFamily="JetBrains Mono, monospace">{t}</text>
              ))}
            </svg>
          </div>
        </div>
      </div>
    </div>
  );
};

// ============================================================================
// Wind Deep-Dive: power curve + hub height
// ============================================================================
const WindDeepDive = ({ pin }) => {
  const [hubHeight, setHubHeight] = useStateX(120);
  const c = '#3B82F6';
  // Power curve for a 4.5MW turbine
  const curve = [];
  for (let v = 0; v <= 25; v += 0.5) {
    let p = 0;
    if (v < 3.5) p = 0;
    else if (v < 12) p = 4500 * Math.pow((v - 3.5) / 8.5, 2.5);
    else if (v < 25) p = 4500;
    else p = 0;
    curve.push([v, p]);
  }
  // Hub height correction: wind shear, exponential profile alpha=0.143
  const baseSpeed = pin.windSpeed || 8.2;
  const adjustedSpeed = baseSpeed * Math.pow(hubHeight / 100, 0.143);
  const speedDelta = ((adjustedSpeed - baseSpeed) / baseSpeed) * 100;

  return (
    <div style={{ padding: 16, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14 }}>
        <Icon name="wind" size={15} color={c}/>
        <span style={{ font: '600 13px/1 var(--font)', color: c, flex: 1 }}>Rüzgar Türbini · Power Curve & Hub Yüksekliği</span>
        <span className="chip" style={{ borderColor: `${c}44`, color: c }}>İNTERAKTİF</span>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1.4fr 1fr', gap: 14 }}>
        <div>
          {/* power curve */}
          <div className="label" style={{ marginBottom: 8 }}>Power Curve · {pin.equipment || 'Vestas V150 4.5MW'}</div>
          <svg viewBox="0 0 480 220" style={{ width: '100%', height: 'auto' }}>
            <defs>
              <linearGradient id="windCurveFill" x1="0" x2="0" y1="0" y2="1">
                <stop offset="0" stopColor={c} stopOpacity="0.30"/>
                <stop offset="1" stopColor={c} stopOpacity="0"/>
              </linearGradient>
            </defs>
            {(() => {
              const padL = 50, padR = 18, padT = 14, padB = 28;
              const w = 480 - padL - padR, h = 220 - padT - padB;
              const xFor = v => padL + (v / 25) * w;
              const yFor = p => padT + h - (p / 5000) * h;
              const pathD = curve.map((pt, i) => `${i ? 'L' : 'M'} ${xFor(pt[0]).toFixed(1)} ${yFor(pt[1]).toFixed(1)}`).join(' ');
              const areaD = `${pathD} L ${xFor(25)} ${padT+h} L ${padL} ${padT+h} Z`;
              return (
                <>
                  {[0, 1000, 2000, 3000, 4000, 5000].map(p => (
                    <g key={p}>
                      <line x1={padL} x2={480-padR} y1={yFor(p)} y2={yFor(p)} stroke="rgba(255,255,255,.05)" strokeWidth="1"/>
                      <text x={padL-5} y={yFor(p)+3} textAnchor="end" fontSize="9" fill="rgba(255,255,255,.45)" fontFamily="JetBrains Mono, monospace">{p/1000}MW</text>
                    </g>
                  ))}
                  <path d={areaD} fill="url(#windCurveFill)"/>
                  <path d={pathD} fill="none" stroke={c} strokeWidth="2.4" strokeLinecap="round"/>
                  {/* current operating point */}
                  <line x1={xFor(adjustedSpeed)} x2={xFor(adjustedSpeed)} y1={padT} y2={padT+h} stroke="#2DD4BF" strokeWidth="1" strokeDasharray="2 3"/>
                  {(() => {
                    const opPower = adjustedSpeed < 3.5 ? 0 : adjustedSpeed < 12 ? 4500 * Math.pow((adjustedSpeed-3.5)/8.5, 2.5) : adjustedSpeed < 25 ? 4500 : 0;
                    return <circle cx={xFor(adjustedSpeed)} cy={yFor(opPower)} r="5" fill="#2DD4BF" stroke="#0B0E14" strokeWidth="2"/>;
                  })()}
                  {/* zones */}
                  <text x={xFor(3.5)} y={padT-3} fontSize="8" fill="rgba(245,158,11,.7)" fontFamily="Inter">Cut-in 3.5</text>
                  <text x={xFor(12)} y={padT-3} fontSize="8" fill="rgba(16,185,129,.7)" fontFamily="Inter">Rated 12</text>
                  <text x={xFor(25)} y={padT-3} fontSize="8" textAnchor="end" fill="rgba(239,68,68,.7)" fontFamily="Inter">Cut-out 25</text>
                  {[0, 5, 10, 15, 20, 25].map(v => (
                    <text key={v} x={xFor(v)} y={220-12} textAnchor="middle" fontSize="9.5" fill="rgba(255,255,255,.55)" fontFamily="JetBrains Mono, monospace">{v}</text>
                  ))}
                  <text x="240" y="216" textAnchor="middle" fontSize="9" fill="rgba(255,255,255,.4)" fontFamily="Inter">Rüzgar hızı (m/s)</text>
                </>
              );
            })()}
          </svg>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginBottom: 6 }}>
              <span className="label" style={{ flex: 1 }}>Hub Yüksekliği</span>
              <span className="tnum" style={{ font: '700 17px/1 var(--font)', color: c }}>{hubHeight} m</span>
            </div>
            <input type="range" min={80} max={180} step={5} value={hubHeight} onChange={e => setHubHeight(+e.target.value)}
              style={{ width: '100%', accentColor: c }}/>
            <div className="tnum" style={{ display: 'flex', justifyContent: 'space-between', font: '500 9.5px/1 var(--font-mono)', color: 'var(--text-4)' }}>
              <span>80m</span><span>120m</span><span>180m</span>
            </div>
          </div>
          <div style={{ padding: 12, background: 'rgba(59,130,246,.08)', border: `1px solid ${c}33`, borderRadius: 9 }}>
            <div className="label" style={{ marginBottom: 7 }}>Etkili Rüzgar Hızı</div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 5 }}>
              <span className="tnum" style={{ font: '700 24px/1 var(--font)', color: c }}>{adjustedSpeed.toFixed(2)}</span>
              <span style={{ font: '500 11px/1 var(--font)', color: 'var(--text-3)' }}>m/s @ {hubHeight}m</span>
            </div>
            <div style={{ marginTop: 6, font: '500 11px/1.4 var(--font)', color: 'var(--text-3)' }}>
              Baseline @ 100m: <b className="tnum" style={{ color: 'var(--text-2)' }}>{baseSpeed.toFixed(2)} m/s</b>
              {' · '}<b className="tnum" style={{ color: speedDelta >= 0 ? '#10B981' : '#EF4444' }}>{speedDelta >= 0 ? '+' : ''}{speedDelta.toFixed(1)}%</b>
            </div>
          </div>
          <div style={{ padding: 10, background: 'rgba(0,0,0,.20)', borderRadius: 8 }}>
            <div className="label" style={{ marginBottom: 7 }}>Türbin Spec</div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 5, font: '500 11px/1.4 var(--font)' }}>
              <div><span style={{ color: 'var(--text-3)' }}>Rotor çapı:</span> <b className="tnum">150 m</b></div>
              <div><span style={{ color: 'var(--text-3)' }}>Türbin:</span> <b className="tnum">12 adet</b></div>
              <div><span style={{ color: 'var(--text-3)' }}>Cut-in:</span> <b className="tnum">3.5 m/s</b></div>
              <div><span style={{ color: 'var(--text-3)' }}>Cut-out:</span> <b className="tnum">25 m/s</b></div>
              <div><span style={{ color: 'var(--text-3)' }}>Rated:</span> <b className="tnum">12 m/s</b></div>
              <div><span style={{ color: 'var(--text-3)' }}>KF:</span> <b className="tnum">%34.0</b></div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

// ============================================================================
// Hydro Deep-Dive: flow profile + turbine recommendation
// ============================================================================
const HydroDeepDive = ({ pin }) => {
  const c = '#06B6D4';
  // monthly flow rates (synthetic)
  const flowRates = [12.5, 14.2, 22.8, 32.5, 38.4, 28.0, 18.5, 10.2, 7.8, 9.4, 11.0, 13.2];
  const months = ['O','Ş','M','N','M','H','T','A','E','E','K','A'];
  const envFlow = 4.2; // minimum environmental flow

  // Turbine suitability based on head (m) and flow (m³/s)
  const head = pin.headHeight || 145;
  const flow = pin.flowRate || 32.5;
  const turbineRec = head > 200 ? 'Pelton' : head > 50 ? 'Francis' : 'Kaplan';
  const turbineColor = turbineRec === 'Pelton' ? '#F59E0B' : turbineRec === 'Francis' ? '#06B6D4' : '#10B981';

  return (
    <div style={{ padding: 16, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14 }}>
        <Icon name="water" size={15} color={c}/>
        <span style={{ font: '600 13px/1 var(--font)', color: c, flex: 1 }}>Hidroelektrik · Akarsu Profili & Türbin Seçimi</span>
        <span className="chip" style={{ borderColor: `${c}44`, color: c }}>{pin.waterBodyName || 'Çoruh Nehri'}</span>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1.4fr 1fr', gap: 14 }}>
        {/* flow chart */}
        <div>
          <div className="label" style={{ marginBottom: 8 }}>Aylık Debi · Can Suyu Kesintisi</div>
          <svg viewBox="0 0 480 200" style={{ width: '100%', height: 'auto' }}>
            {(() => {
              const padL = 44, padR = 16, padT = 12, padB = 26;
              const w = 480 - padL - padR, h = 200 - padT - padB;
              const bw = w / 12;
              const max = 45;
              const yFor = v => padT + h - (v / max) * h;
              return (
                <>
                  {[0, 10, 20, 30, 40].map(v => (
                    <g key={v}>
                      <line x1={padL} x2={480-padR} y1={yFor(v)} y2={yFor(v)} stroke="rgba(255,255,255,.05)" strokeWidth="1"/>
                      <text x={padL-5} y={yFor(v)+3} textAnchor="end" fontSize="9" fill="rgba(255,255,255,.45)" fontFamily="JetBrains Mono, monospace">{v}</text>
                    </g>
                  ))}
                  {/* env flow line */}
                  <line x1={padL} x2={480-padR} y1={yFor(envFlow)} y2={yFor(envFlow)} stroke="#EF4444" strokeWidth="1.5" strokeDasharray="3 3" opacity="0.7"/>
                  <text x={480-padR} y={yFor(envFlow)-2} textAnchor="end" fontSize="9" fill="#EF4444" fontFamily="Inter">Min Can Suyu</text>
                  {flowRates.map((v, i) => {
                    const x = padL + bw * (i + 0.20);
                    const barW = bw * 0.60;
                    // gross flow
                    const grossY = yFor(v);
                    const grossH = padT + h - grossY;
                    // net flow (after env)
                    const netV = Math.max(0, v - envFlow);
                    const netY = yFor(netV);
                    const netH = padT + h - netY;
                    return (
                      <g key={i}>
                        <rect x={x} y={grossY} width={barW} height={grossH} rx="2" fill={c} fillOpacity="0.3"/>
                        <rect x={x} y={netY} width={barW} height={netH} rx="2" fill={c}/>
                        <text x={padL + bw * (i + 0.5)} y={200-10} textAnchor="middle" fontSize="9" fill="rgba(255,255,255,.55)" fontFamily="Inter">{months[i]}</text>
                      </g>
                    );
                  })}
                </>
              );
            })()}
          </svg>
          <div style={{ marginTop: 6, display: 'flex', gap: 14, font: '500 10.5px/1 var(--font)' }}>
            <span style={{ display: 'flex', alignItems: 'center', gap: 5, color: c }}><span style={{ width: 10, height: 10, borderRadius: 2, background: c }}/>Net debi (üretimde)</span>
            <span style={{ display: 'flex', alignItems: 'center', gap: 5, color: 'rgba(6,182,212,.55)' }}><span style={{ width: 10, height: 10, borderRadius: 2, background: c, opacity: 0.3 }}/>Brüt debi</span>
            <span style={{ display: 'flex', alignItems: 'center', gap: 5, color: '#EF4444' }}><span style={{ width: 10, height: 1.5, borderTop: '1.5px dashed currentColor' }}/>Çevresel min</span>
          </div>
        </div>
        {/* turbine selection */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <div style={{ padding: 14, background: `${turbineColor}10`, border: `1px solid ${turbineColor}44`, borderRadius: 10 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 9 }}>
              <Icon name="gear" size={13} color={turbineColor}/>
              <span style={{ font: '600 11px/1 var(--font)', color: turbineColor, letterSpacing: '.06em', textTransform: 'uppercase' }}>ÖNERİLEN TÜRBİN</span>
            </div>
            <div className="tnum" style={{ font: '700 26px/1 var(--font)', color: turbineColor, letterSpacing: '-.02em' }}>{turbineRec} Tipi</div>
            <div style={{ marginTop: 8, font: '500 11.5px/1.5 var(--font)', color: 'var(--text-3)' }}>
              Düşü {head}m · Debi {flow} m³/s için uygun. {turbineRec === 'Francis' ? 'Orta düşü/orta debi için en yaygın seçim.' : turbineRec === 'Pelton' ? 'Yüksek düşü/düşük debi için uygundur.' : 'Düşük düşü/yüksek debi için uygundur.'}
            </div>
          </div>
          <div style={{ padding: 10, background: 'rgba(0,0,0,.20)', borderRadius: 8 }}>
            <div className="label" style={{ marginBottom: 8 }}>Hidrolik Parametreler</div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 5, font: '500 11px/1.4 var(--font)' }}>
              {[
                ['Net düşü',         `${head} m`],
                ['Tasarım debisi',   `${flow} m³/s`],
                ['Çevresel debi',    `${envFlow} m³/s (%${(envFlow/flow*100).toFixed(0)})`],
                ['Yıllık akış',      '142M m³'],
                ['Türbin verimi',    '%93 max'],
                ['Hizmet kullanımı', '%99.2'],
                ['Tesis tipi',       'Nehir Tipi HES'],
              ].map(([k, v]) => (
                <div key={k} style={{ display: 'flex', justifyContent: 'space-between', padding: '3px 0', borderBottom: '1px dashed var(--border-2)' }}>
                  <span style={{ color: 'var(--text-3)' }}>{k}</span>
                  <span className="tnum" style={{ color: 'var(--text)', fontFamily: 'var(--font-mono)', fontWeight: 600 }}>{v}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

// ============================================================================
// TR Financial Panel — YEKDEM/Market + price history + tax + manual override
// ============================================================================
const TRFinancialPanel = ({ pin }) => {
  const [pricingMode, setPricingMode] = useStateX('yekdem'); // yekdem | market
  const [manualMode, setManualMode] = useStateX(false);
  // 5 anahtar değişken
  const [capexPerMw, setCapexPerMw] = useStateX(0.78);
  const [pricePerKwh, setPricePerKwh] = useStateX(0.072);
  const [discount, setDiscount] = useStateX(8.5);
  const [escalation, setEscalation] = useStateX(2.5);
  const [lifetime, setLifetime] = useStateX(25);

  // Electricity price history (real-ish data 2015-2025 + projection)
  const priceHistory = [
    { year: 2015, yekdem: 0.133, market: 0.067 },
    { year: 2016, yekdem: 0.133, market: 0.058 },
    { year: 2017, yekdem: 0.133, market: 0.065 },
    { year: 2018, yekdem: 0.103, market: 0.072 },
    { year: 2019, yekdem: 0.082, market: 0.054 },
    { year: 2020, yekdem: 0.082, market: 0.048 },
    { year: 2021, yekdem: 0.082, market: 0.069 },
    { year: 2022, yekdem: 0.072, market: 0.108 },
    { year: 2023, yekdem: 0.068, market: 0.092 },
    { year: 2024, yekdem: 0.064, market: 0.078 },
    { year: 2025, yekdem: 0.060, market: 0.075 },
    { year: 2026, yekdem: 0.055, market: 0.072 },
    { year: 2027, yekdem: 0.050, market: 0.071 },
    { year: 2028, yekdem: null,  market: 0.078 }, // YEKDEM ends
    { year: 2029, yekdem: null,  market: 0.082 },
    { year: 2030, yekdem: null,  market: 0.088 },
  ];

  const c = TC[pin.type] || 'var(--accent)';

  return (
    <div style={{ padding: 16, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14, flexWrap: 'wrap' }}>
        <Icon name="finance" size={14} color="var(--accent)"/>
        <span style={{ font: '600 13px/1 var(--font)', color: 'var(--text)', flex: 1, minWidth: 200 }}>Türkiye Finansal Modeli</span>
        {/* pricing mode toggle */}
        <div className="seg">
          {['yekdem', 'market'].map(m => (
            <button key={m} onClick={() => setPricingMode(m)} className={pricingMode === m ? 'on' : ''} style={{ padding: '6px 11px', font: '500 11.5px/1 var(--font)' }}>
              {m === 'yekdem' ? 'YEKDEM' : 'Spot Piyasa'}
            </button>
          ))}
        </div>
        <button onClick={() => setManualMode(!manualMode)} className="btn" style={{ padding: '6px 11px', background: manualMode ? 'rgba(20,184,166,.18)' : undefined, borderColor: manualMode ? 'rgba(20,184,166,.45)' : undefined, color: manualMode ? 'var(--accent)' : undefined }}>
          <Icon name="edit" size={11}/> Manuel Override
        </button>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: manualMode ? '1.5fr 1fr' : '1fr', gap: 14 }}>
        <div>
          {/* Price history chart */}
          <div className="label" style={{ marginBottom: 8 }}>Elektrik Fiyatı Geçmişi · Türkiye</div>
          <svg viewBox="0 0 700 220" style={{ width: '100%', height: 'auto', display: 'block' }}>
            {(() => {
              const padL = 50, padR = 16, padT = 14, padB = 26;
              const w = 700 - padL - padR, h = 220 - padT - padB;
              const max = 0.14, min = 0;
              const xStep = w / (priceHistory.length - 1);
              const xFor = i => padL + i * xStep;
              const yFor = v => padT + h - ((v - min) / (max - min)) * h;
              const yekdemPath = priceHistory.filter(d => d.yekdem !== null).map((d, idx, arr) => `${idx ? 'L' : 'M'} ${xFor(priceHistory.indexOf(d))} ${yFor(d.yekdem)}`).join(' ');
              const marketPath = priceHistory.map((d, i) => `${i ? 'L' : 'M'} ${xFor(i)} ${yFor(d.market)}`).join(' ');
              return (
                <>
                  {[0, 0.05, 0.10, 0.14].map(v => (
                    <g key={v}>
                      <line x1={padL} x2={700-padR} y1={yFor(v)} y2={yFor(v)} stroke="rgba(255,255,255,.05)" strokeWidth="1"/>
                      <text x={padL-5} y={yFor(v)+3} textAnchor="end" fontSize="9" fill="rgba(255,255,255,.45)" fontFamily="JetBrains Mono, monospace">${v.toFixed(2)}</text>
                    </g>
                  ))}
                  <text x={padL-50} y={padT+8} fontSize="8" fill="rgba(255,255,255,.4)" fontFamily="Inter">$/kWh</text>
                  {/* 2028 marker — YEKDEM end */}
                  <line x1={xFor(priceHistory.findIndex(d => d.year === 2028))} x2={xFor(priceHistory.findIndex(d => d.year === 2028))} y1={padT} y2={padT+h} stroke="#F59E0B" strokeWidth="1.5" strokeDasharray="4 3"/>
                  <text x={xFor(priceHistory.findIndex(d => d.year === 2028))} y={padT-4} textAnchor="middle" fontSize="9" fill="#F59E0B" fontFamily="JetBrains Mono, monospace">YEKDEM SON</text>
                  {/* paths */}
                  <path d={yekdemPath} fill="none" stroke="#3B82F6" strokeWidth="2.2" strokeLinecap="round"/>
                  <path d={marketPath} fill="none" stroke="#F59E0B" strokeWidth="2.2" strokeLinecap="round"/>
                  {/* current point */}
                  {priceHistory.map((d, i) => {
                    if (d.year !== 2026) return null;
                    return (
                      <g key={i}>
                        <circle cx={xFor(i)} cy={yFor(d[pricingMode])} r="5" fill={pricingMode === 'yekdem' ? '#3B82F6' : '#F59E0B'} stroke="#0B0E14" strokeWidth="2"/>
                        <text x={xFor(i)+8} y={yFor(d[pricingMode])-4} fontSize="11" fill={pricingMode === 'yekdem' ? '#3B82F6' : '#F59E0B'} fontFamily="JetBrains Mono, monospace" fontWeight="700">${d[pricingMode]}</text>
                      </g>
                    );
                  })}
                  {priceHistory.map((d, i) => (i % 2 === 0 || i === priceHistory.length-1) && (
                    <text key={i} x={xFor(i)} y={220-10} textAnchor="middle" fontSize="9.5" fill="rgba(255,255,255,.55)" fontFamily="JetBrains Mono, monospace">{d.year}</text>
                  ))}
                </>
              );
            })()}
          </svg>
          <div style={{ display: 'flex', gap: 16, marginTop: 6, font: '500 11px/1 var(--font)' }}>
            <span style={{ display: 'flex', alignItems: 'center', gap: 5, color: '#3B82F6' }}><span style={{ width: 12, height: 2, background: '#3B82F6' }}/>YEKDEM ($/kWh)</span>
            <span style={{ display: 'flex', alignItems: 'center', gap: 5, color: '#F59E0B' }}><span style={{ width: 12, height: 2, background: '#F59E0B' }}/>Spot Piyasa Tahmini</span>
          </div>

          {/* Tax breakdown */}
          <div style={{ marginTop: 14, padding: 12, background: 'rgba(0,0,0,.20)', borderRadius: 9 }}>
            <div className="label" style={{ marginBottom: 9 }}>Türkiye Vergi & Yük Yapısı</div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8 }}>
              {[
                ['KDV',              '%20',  'Mal/hizmet alımı'],
                ['Kurumlar Vergisi', '%25',  'Net kâr'],
                ['Fon Payı + TRT',   '%5.5', 'Elektrik faturası'],
                ['MUM Kesintisi',    '%1',   'Üretim Lisans Bedeli'],
              ].map(([k, v, sub]) => (
                <div key={k} style={{ padding: 9, background: 'rgba(0,0,0,.20)', border: '1px solid var(--border-2)', borderRadius: 7 }}>
                  <div className="label">{k}</div>
                  <div className="tnum" style={{ font: '700 16px/1 var(--font)', marginTop: 5 }}>{v}</div>
                  <div style={{ font: '500 10px/1.3 var(--font)', color: 'var(--text-3)', marginTop: 5 }}>{sub}</div>
                </div>
              ))}
            </div>
            <div style={{ marginTop: 10, paddingTop: 9, borderTop: '1px dashed var(--border-2)', font: '500 11px/1.5 var(--font)', color: 'var(--text-3)' }}>
              <Icon name="info" size={10} color="var(--text-3)"/> YEKDEM mekanizması 2028 sonu itibariyle sona eriyor. Sonrası için yenilenebilir kaynaklar serbest piyasa veya YEKA-3 ihaleleri yoluyla satış yapacak.
            </div>
          </div>
        </div>

        {/* Manual override */}
        {manualMode && (
          <div style={{ padding: 12, background: 'rgba(20,184,166,.06)', border: '1px solid rgba(20,184,166,.30)', borderRadius: 10 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12 }}>
              <Icon name="edit" size={12} color="var(--accent)"/>
              <span style={{ font: '600 11.5px/1 var(--font)', color: 'var(--accent)', flex: 1 }}>Anahtar Değişkenler</span>
              <button onClick={() => { setCapexPerMw(0.78); setPricePerKwh(0.072); setDiscount(8.5); setEscalation(2.5); setLifetime(25); }} style={{ background: 'transparent', border: 'none', color: 'var(--text-3)', cursor: 'pointer', font: '500 10px/1 var(--font)' }}>↺ Varsayılan</button>
            </div>
            {[
              { l: 'CAPEX',        v: capexPerMw,  s: setCapexPerMw,  min: 0.4, max: 2.5, step: 0.05, unit: '$M/MW', fmt: v => `$${v.toFixed(2)}M/MW`, base: 0.78 },
              { l: 'Elektrik Fiyatı', v: pricePerKwh, s: setPricePerKwh, min: 0.04, max: 0.15, step: 0.005, unit: '$/kWh', fmt: v => `$${v.toFixed(3)}`, base: 0.072 },
              { l: 'İskonto',      v: discount,    s: setDiscount,    min: 4,   max: 14,  step: 0.1,  unit: '%', fmt: v => `%${v.toFixed(1)}`, base: 8.5 },
              { l: 'Eskalasyon',   v: escalation,  s: setEscalation,  min: 0,   max: 6,   step: 0.1,  unit: '%/y', fmt: v => `%${v.toFixed(1)}`, base: 2.5 },
              { l: 'Ömür',         v: lifetime,    s: setLifetime,    min: 15,  max: 35,  step: 1,    unit: 'yıl', fmt: v => `${v} yıl`, base: 25 },
            ].map(p => {
              const pct = ((p.v - p.min) / (p.max - p.min)) * 100;
              const isBase = Math.abs(p.v - p.base) < p.step / 2;
              return (
                <div key={p.l} style={{ marginBottom: 11 }}>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginBottom: 4 }}>
                    <span style={{ font: '500 11px/1 var(--font)', color: 'var(--text-2)', flex: 1 }}>{p.l}</span>
                    <span className="tnum" style={{ font: '700 12.5px/1 var(--font-mono)', color: isBase ? 'var(--text)' : 'var(--accent)' }}>{p.fmt(p.v)}</span>
                  </div>
                  <div style={{ position: 'relative', height: 16 }}>
                    <div style={{ position: 'absolute', left: 0, right: 0, top: 6, height: 4, background: 'rgba(255,255,255,.06)', borderRadius: 2 }}>
                      <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: `${pct}%`, background: isBase ? 'rgba(255,255,255,.20)' : 'var(--accent)', borderRadius: 2 }}/>
                    </div>
                    <input type="range" min={p.min} max={p.max} step={p.step} value={p.v} onChange={e => p.s(+e.target.value)}
                      style={{ position: 'absolute', left: 0, right: 0, top: 0, bottom: 0, width: '100%', opacity: 0, cursor: 'grab' }}/>
                    <div style={{ position: 'absolute', left: `${pct}%`, top: 1, transform: 'translateX(-50%)', width: 13, height: 13, borderRadius: '50%', background: 'white', boxShadow: '0 1px 3px rgba(0,0,0,.4)', pointerEvents: 'none' }}/>
                  </div>
                </div>
              );
            })}
            <div style={{ marginTop: 14, paddingTop: 10, borderTop: '1px dashed var(--border-2)' }}>
              <div className="label" style={{ marginBottom: 6 }}>Bu varsayımlarla NPV (25y)</div>
              {(() => {
                const capex = pin.capacityMw * capexPerMw * 1e6;
                const annualRev = pin.annualKwh * pricePerKwh;
                const annualNet = annualRev * (1 - 0.14); // O&M
                let npv = -capex;
                for (let y = 1; y <= lifetime; y++) {
                  const cf = annualNet * Math.pow(1 + escalation/100, y) * Math.pow(1 - 0.006, y);
                  npv += cf / Math.pow(1 + discount/100, y);
                }
                return (
                  <div className="tnum" style={{ font: '700 26px/1 var(--font)', color: npv > 0 ? '#10B981' : '#EF4444', letterSpacing: '-.01em' }}>
                    {npv > 0 ? '+' : '-'}${(Math.abs(npv)/1e6).toFixed(2)}M
                  </div>
                );
              })()}
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

// ============================================================================
// EXTENDED PIN REPORT — incorporates all new sections
// ============================================================================
const PinReportExtended = ({ pinId = 2 }) => {
  const pin = REPORT_PINS.find(p => p.id === pinId);
  const c = TC[pin.type];
  const annualGwh = pin.annualKwh / 1e6;
  const capex = pin.capacityMw * SCENARIO_META.capexPerMw[pin.type];
  const annualRev = pin.annualKwh * 0.072;
  const co2 = annualGwh * 1e3 * 0.689;

  return (
    <div style={{ width: 1280, height: 2200, background: 'var(--bg)', display: 'flex', flexDirection: 'column', borderRadius: 12, overflow: 'hidden', border: '1px solid var(--border)' }}>
      {/* breadcrumb toolbar */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '12px 22px', borderBottom: '1px solid var(--border)', background: 'rgba(20,24,34,.92)' }}>
        <button className="btn" style={{ padding: '6px 10px' }}>
          <Icon name="chevL" size={11} color="var(--text-2)"/> Pin detayına dön
        </button>
        <div style={{ font: '500 11.5px/1 var(--font)', color: 'var(--text-3)', display: 'flex', alignItems: 'center', gap: 6 }}>
          <span>Raporlar</span><Icon name="chevR" size={10} color="var(--text-4)"/>
          <span>Santral Analizi</span><Icon name="chevR" size={10} color="var(--text-4)"/>
          <span style={{ color: c, fontWeight: 600 }}>{pin.name}</span>
        </div>
        <div style={{ flex: 1 }}/>
        <button className="btn" style={{ padding: '6px 10px' }}><Icon name="ext" size={11}/> PDF</button>
        <button className="btn" style={{ padding: '6px 10px' }}><Icon name="ext" size={11}/> Excel</button>
        <button className="btn btn-primary" style={{ padding: '6px 12px' }}><Icon name="ext" size={11} color="#06201E"/> Paylaş</button>
      </div>

      <div className="scroll" style={{ flex: 1, overflow: 'auto', padding: '20px 26px 40px' }}>
        {/* hero */}
        <div style={{
          padding: '24px 28px', borderRadius: 16, marginBottom: 18,
          background: `linear-gradient(135deg, ${c}15, transparent 60%)`,
          border: `1px solid ${c}33`, position: 'relative', overflow: 'hidden'
        }}>
          <div style={{ position: 'absolute', right: -40, top: -40, width: 220, height: 220, borderRadius: '50%', background: `radial-gradient(circle, ${c}22, transparent 60%)` }}/>
          <div style={{ position: 'relative', display: 'flex', alignItems: 'center', gap: 18 }}>
            <div style={{ width: 60, height: 60, borderRadius: 14, background: `${c}22`, border: `1px solid ${c}55`, display: 'grid', placeItems: 'center' }}>
              <TypeIcon type={pin.type} size={28} color={c}/>
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
                <span style={{ font: '600 10.5px/1 var(--font-mono)', color: c, textTransform: 'uppercase', letterSpacing: '.10em' }}>SANTRAL ANALİZİ · {TLabel[pin.type].toUpperCase()}</span>
              </div>
              <h1 style={{ margin: 0, font: '700 30px/1.1 var(--font)', letterSpacing: '-.02em' }}>{pin.name}</h1>
              <div style={{ marginTop: 6, display: 'flex', gap: 14, font: '500 12.5px/1.3 var(--font)', color: 'var(--text-2)' }}>
                <span><Icon name="pin" size={11} color="var(--text-3)"/> {pin.district} / {pin.city}</span>
                <span className="tnum" style={{ fontFamily: 'var(--font-mono)', color: 'var(--text-3)' }}>{pin.lat?.toFixed(4)}° · {pin.lng?.toFixed(4)}°</span>
                <span>Ekipman: <b style={{ color: 'var(--text)' }}>{pin.equipment}</b></span>
              </div>
            </div>
          </div>
          <div style={{ marginTop: 16, display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10 }}>
            <HeroKpi label="Kurulu Güç" value={pin.capacityMw.toFixed(1)} unit="MW" hint={pin.equipment} accent={c}/>
            <HeroKpi label="Yıllık Üretim" value={annualGwh.toFixed(1)} unit="GWh" hint={`KF %${((pin.capacityFactor || 0.25)*100).toFixed(1)}`}/>
            <HeroKpi label="NPV (25y)" value={fmtMoney(capex * 1.6)} unit="" hint={`IRR ${(pin.roi > 7 ? 14.2 : 11.8).toFixed(1)}%`} accent="var(--success)"/>
            <HeroKpi label="CO₂" value={`${(co2/1000).toFixed(1)}K`} unit="ton/yıl" accent="#10B981"/>
          </div>
        </div>

        {/* Production Timeline — yeni Zaman Simülasyonu widget'ı */}
        {window.TimeSimulation
          ? <TimeSimulation pin={pin} variant="desktop"/>
          : <ProductionTimeline pin={pin}/>}

        {/* Type-Specific Deep Dive */}
        <div style={{ marginTop: 12 }}>
          {pin.type === 'solar' && <SolarDeepDive pin={pin}/>}
          {pin.type === 'wind' && <WindDeepDive pin={pin}/>}
          {pin.type === 'hydro' && <HydroDeepDive pin={pin}/>}
        </div>

        {/* TR Financial Model */}
        <div style={{ marginTop: 12 }}>
          <TRFinancialPanel pin={pin}/>
        </div>

        {/* monthly production for reference */}
        <div style={{ marginTop: 12, padding: 16, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12 }}>
          <div className="label" style={{ marginBottom: 12 }}>Aylık Üretim Profili · 2025</div>
          <MonthlyBars data={pin.monthly} color={c} width={1200} height={160}/>
        </div>

        {/* footer */}
        <div style={{ marginTop: 24, paddingTop: 18, borderTop: '1px dashed var(--border-2)', display: 'flex', alignItems: 'center', gap: 14, font: '500 11px/1.4 var(--font)', color: 'var(--text-3)' }}>
          <div style={{ width: 24, height: 24, borderRadius: 6, background: 'linear-gradient(135deg, var(--solar), var(--wind))', display: 'grid', placeItems: 'center' }}>
            <Icon name="globe" size={12} color="white"/>
          </div>
          <span><b style={{ color: 'var(--text-2)' }}>SRRP</b> · {pin.name} · Santral analizi</span>
          <div style={{ flex: 1 }}/>
          <span className="tnum" style={{ fontFamily: 'var(--font-mono)' }}>RPT-PIN-EXT-{pin.id.toString().padStart(4, '0')}</span>
        </div>
      </div>
    </div>
  );
};

Object.assign(window, { ProductionTimeline, SolarDeepDive, WindDeepDive, HydroDeepDive, TRFinancialPanel, PinReportExtended });
