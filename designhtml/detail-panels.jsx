// detail-panels.jsx — pin display + edit pattern variations

const PIN = SAMPLE_PINS[0]; // Konya solar
const PIN_WIND = SAMPLE_PINS[1];
const PIN_HYDRO = SAMPLE_PINS[2];

// monthly bar chart helper
const MonthlyBars = ({ data, color, height = 60, showLabels = true }) => {
  const max = Math.max(...data);
  const months = ['O','Ş','M','N','M','H','T','A','E','E','K','A'];
  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'flex-end', gap: 3, height }}>
        {data.map((v, i) => (
          <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
            <div style={{ width: '100%', height: `${(v/max)*100}%`, background: `linear-gradient(180deg, ${color}, ${color}66)`, borderRadius: '3px 3px 0 0', minHeight: 2 }}/>
          </div>
        ))}
      </div>
      {showLabels && (
        <div style={{ display: 'flex', gap: 3, marginTop: 4 }}>
          {months.map((m, i) => (
            <div key={i} style={{ flex: 1, textAlign: 'center', font: '500 9px/1 var(--font)', color: 'var(--text-3)' }}>{m}</div>
          ))}
        </div>
      )}
    </div>
  );
};

// ===== V1: Rich Dashboard Side Panel (right-side, scrollable, full data) =====
const DetailRichDashboard = ({ pin = PIN }) => {
  const c = TYPES[pin.type].color;
  return (
    <div style={{ position: 'relative', width: 880, height: 620, borderRadius: 16, overflow: 'hidden', border: '1px solid var(--border)' }}>
      <MapBackdrop/>
      <div style={{ position: 'absolute', left: '38%', top: '60%' }}>
        <div style={{ width: 14, height: 14, borderRadius: '50%', background: c, border: '2px solid white', boxShadow: `0 0 0 6px ${c}33` }}/>
      </div>
      <div style={{ position: 'absolute', right: 0, top: 0, bottom: 0, width: 420, background: 'var(--card)', borderLeft: '1px solid var(--border)', display: 'flex', flexDirection: 'column', boxShadow: '-20px 0 40px rgba(0,0,0,.4)' }}>
        {/* hero */}
        <div style={{ padding: '20px 22px 18px', background: `linear-gradient(180deg, ${c}1A, transparent)`, borderBottom: '1px solid var(--border-2)' }}>
          <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12 }}>
            <div style={{ width: 44, height: 44, borderRadius: 12, background: `${c}22`, border: `1px solid ${c}55`, display: 'grid', placeItems: 'center' }}>
              <TypeIcon type={pin.type} size={22} color={c}/>
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ font: '500 11px/1 var(--font)', color: c, textTransform: 'uppercase', letterSpacing: '.06em' }}>{TYPES[pin.type].label}</div>
              <div style={{ font: '700 18px/1.2 var(--font)', color: 'var(--text)', marginTop: 4, letterSpacing: '-.01em' }}>{pin.name}</div>
              <div style={{ font: '500 12px/1.4 var(--font)', color: 'var(--text-3)', marginTop: 4 }}>{pin.district} / {pin.city}</div>
            </div>
            <div style={{ display: 'flex', gap: 4 }}>
              <button className="btn btn-icon btn-ghost"><Icon name="edit" size={14} color="var(--text-2)"/></button>
              <button className="btn btn-icon btn-ghost"><Icon name="x" size={14} color="var(--text-2)"/></button>
            </div>
          </div>
          {/* quick KPIs */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 10, marginTop: 18 }}>
            <div>
              <div className="kpi-label">Kapasite</div>
              <div style={{ marginTop: 6 }}><span className="kpi-num tnum" style={{ color: c }}>{pin.capacityMw.toFixed(1)}</span><span className="kpi-unit">MW</span></div>
            </div>
            <div>
              <div className="kpi-label">Yıllık</div>
              <div style={{ marginTop: 6 }}><span className="kpi-num tnum">{(pin.annualKwh/1e6).toFixed(1)}</span><span className="kpi-unit">GWh</span></div>
            </div>
            <div>
              <div className="kpi-label">ROI</div>
              <div style={{ marginTop: 6 }}><span className="kpi-num tnum">{pin.roi.toFixed(1)}</span><span className="kpi-unit">yıl</span></div>
            </div>
          </div>
        </div>
        {/* scroll content */}
        <div className="scroll" style={{ flex: 1, overflow: 'auto', padding: '16px 18px', display: 'flex', flexDirection: 'column', gap: 14 }}>
          {/* monthly chart */}
          <div className="card" style={{ padding: 14, borderRadius: 12 }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
              <div className="label">Aylık üretim · 2025</div>
              <span className="chip" style={{ fontSize: 10 }}>Toplam {(pin.annualKwh/1e6).toFixed(1)} GWh</span>
            </div>
            <MonthlyBars data={pin.monthly} color={c}/>
          </div>
          {/* finansal */}
          <div className="card" style={{ padding: 14, borderRadius: 12 }}>
            <div className="label" style={{ marginBottom: 10 }}>Finansal Analiz</div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
              <div style={{ padding: 10, background: 'rgba(0,0,0,.20)', borderRadius: 8 }}>
                <div style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)', textTransform: 'uppercase' }}>NPV (25y)</div>
                <div style={{ font: '700 16px/1.1 var(--font)', color: 'var(--success)', marginTop: 4 }} className="tnum">$5.2M</div>
              </div>
              <div style={{ padding: 10, background: 'rgba(0,0,0,.20)', borderRadius: 8 }}>
                <div style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)', textTransform: 'uppercase' }}>IRR</div>
                <div style={{ font: '700 16px/1.1 var(--font)', color: 'var(--text)', marginTop: 4 }} className="tnum">14.2%</div>
              </div>
              <div style={{ padding: 10, background: 'rgba(0,0,0,.20)', borderRadius: 8 }}>
                <div style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)', textTransform: 'uppercase' }}>LCOE</div>
                <div style={{ font: '700 16px/1.1 var(--font)', color: 'var(--text)', marginTop: 4 }} className="tnum">$0.041<span style={{fontSize: 10, color: 'var(--text-3)', fontWeight: 500}}>/kWh</span></div>
              </div>
              <div style={{ padding: 10, background: 'rgba(0,0,0,.20)', borderRadius: 8 }}>
                <div style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)', textTransform: 'uppercase' }}>Yatırım</div>
                <div style={{ font: '700 16px/1.1 var(--font)', color: 'var(--text)', marginTop: 4 }} className="tnum">$11.6M</div>
              </div>
            </div>
          </div>
          {/* hava */}
          <div className="card" style={{ padding: 14, borderRadius: 12 }}>
            <div className="label" style={{ marginBottom: 10 }}>7 Günlük Hava Tahmini</div>
            <div style={{ display: 'flex', gap: 6 }}>
              {['Pzt','Sal','Çar','Per','Cum','Cmt','Paz'].map((d, i) => {
                const irr = [5.4, 5.6, 4.8, 5.2, 5.9, 6.1, 5.7][i];
                return (
                  <div key={i} style={{ flex: 1, padding: '8px 4px', background: 'rgba(0,0,0,.20)', borderRadius: 8, textAlign: 'center' }}>
                    <div style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)', textTransform: 'uppercase' }}>{d}</div>
                    <div style={{ marginTop: 6 }}><Icon name="sun" size={16} color={c}/></div>
                    <div style={{ font: '600 11px/1 var(--font-mono)', color: 'var(--text)', marginTop: 4 }} className="tnum">{irr}</div>
                  </div>
                );
              })}
            </div>
          </div>
          {/* ekipman & senaryo */}
          <div className="card" style={{ padding: 14, borderRadius: 12 }}>
            <div className="label" style={{ marginBottom: 10 }}>Konfigürasyon</div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {[
                ['Ekipman', pin.equipment],
                ['Panel alanı', `${(pin.panelArea/1000).toFixed(0)},000 m²`],
                ['Eğim açısı', '32°'],
                ['Yön (azimut)', '180° (Güney)'],
                ['Senaryo', 'Türkiye 2030 Yenilenebilir'],
              ].map(([k, v]) => (
                <div key={k} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', font: '500 12.5px/1.4 var(--font)' }}>
                  <span style={{ color: 'var(--text-3)' }}>{k}</span>
                  <span style={{ color: 'var(--text)', fontWeight: 500 }}>{v}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
        <div style={{ padding: '12px 18px', borderTop: '1px solid var(--border-2)', display: 'flex', gap: 8 }}>
          <button className="btn" style={{ flex: 1 }}><Icon name="edit" size={13}/> Düzenle</button>
          <button className="btn"><Icon name="trash" size={13} color="var(--danger)"/></button>
          <button className="btn btn-primary"><Icon name="ext" size={13} color="#06201E"/> Rapor</button>
        </div>
      </div>
    </div>
  );
};

// ===== V2: Floating bottom-aligned card (compact, glanceable) =====
const DetailFloatingCard = ({ pin = PIN_WIND }) => {
  const c = TYPES[pin.type].color;
  return (
    <div style={{ position: 'relative', width: 880, height: 620, borderRadius: 16, overflow: 'hidden', border: '1px solid var(--border)' }}>
      <MapBackdrop/>
      {/* selected pin */}
      <div style={{ position: 'absolute', left: '50%', top: '40%', transform: 'translate(-50%, -100%)' }}>
        <div style={{ position: 'relative' }}>
          <div style={{ width: 14, height: 14, borderRadius: '50%', background: c, border: '2px solid white', boxShadow: `0 0 0 6px ${c}33` }}/>
        </div>
      </div>
      {/* floating card */}
      <div style={{
        position: 'absolute', left: 24, right: 24, bottom: 22,
        background: 'rgba(28,32,44,.96)', backdropFilter: 'blur(20px)',
        border: '1px solid var(--border)', borderRadius: 18,
        boxShadow: '0 24px 60px rgba(0,0,0,.6)',
        padding: 18,
        display: 'grid', gridTemplateColumns: '300px 1fr 200px', gap: 22, alignItems: 'stretch'
      }}>
        {/* left: identity */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ width: 38, height: 38, borderRadius: 10, background: `${c}22`, border: `1px solid ${c}55`, display: 'grid', placeItems: 'center' }}>
              <TypeIcon type={pin.type} size={18} color={c}/>
            </div>
            <div>
              <div style={{ font: '700 15px/1.2 var(--font)', color: 'var(--text)', letterSpacing: '-.01em' }}>{pin.name}</div>
              <div style={{ font: '500 11.5px/1 var(--font)', color: 'var(--text-3)', marginTop: 3 }}>{pin.district} / {pin.city}</div>
            </div>
          </div>
          <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
            <span className="chip" style={{ borderColor: `${c}55`, color: c, background: `${c}11`, fontSize: 10 }}>{TYPES[pin.type].label}</span>
            <span className="chip" style={{ fontSize: 10 }}>{pin.equipment}</span>
            <span className="chip" style={{ fontSize: 10 }}>Aktif</span>
          </div>
          <div className="mono" style={{ marginTop: 'auto', font: '500 10.5px/1 var(--font-mono)', color: 'var(--text-3)' }}>{pin.lat.toFixed(4)}°N, {pin.lng.toFixed(4)}°E</div>
        </div>
        {/* center: KPI grid */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10, borderLeft: '1px solid var(--border-2)', borderRight: '1px solid var(--border-2)', padding: '0 18px' }}>
          {[
            ['Kapasite', `${pin.capacityMw}`, 'MW', c],
            ['Yıllık', `${(pin.annualKwh/1e6).toFixed(0)}`, 'GWh', 'var(--text)'],
            ['Geri Ödeme', `${pin.roi.toFixed(1)}`, 'yıl', 'var(--text)'],
            ['CF', `${(pin.capacityFactor*100).toFixed(0)}`, '%', 'var(--success)'],
          ].map(([l, v, u, col]) => (
            <div key={l}>
              <div className="kpi-label">{l}</div>
              <div style={{ marginTop: 6 }}><span className="kpi-num tnum" style={{ color: col }}>{v}</span><span className="kpi-unit">{u}</span></div>
            </div>
          ))}
          {/* spans */}
          <div style={{ gridColumn: '1 / -1', marginTop: 6 }}>
            <div className="label" style={{ marginBottom: 6 }}>Aylık üretim</div>
            <MonthlyBars data={pin.monthly} color={c} height={32} showLabels={false}/>
          </div>
        </div>
        {/* right: actions */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          <button className="btn btn-primary" style={{ justifyContent: 'center' }}><Icon name="ext" size={13} color="#06201E"/> Detaylı Analiz</button>
          <button className="btn" style={{ justifyContent: 'center' }}><Icon name="edit" size={13}/> Düzenle</button>
          <button className="btn" style={{ justifyContent: 'center' }}><Icon name="cal" size={13}/> Senaryoya ekle</button>
          <div style={{ flex: 1 }}/>
          <button className="btn btn-ghost" style={{ justifyContent: 'center', color: 'var(--danger)' }}><Icon name="trash" size={13} color="var(--danger)"/> Sil</button>
        </div>
      </div>
    </div>
  );
};

// ===== V3: HUD-style overlay (left rail) =====
const DetailHUD = ({ pin = PIN_HYDRO }) => {
  const c = TYPES[pin.type].color;
  return (
    <div style={{ position: 'relative', width: 880, height: 620, borderRadius: 16, overflow: 'hidden', border: '1px solid var(--border)' }}>
      <MapBackdrop/>
      {/* left HUD column */}
      <div style={{ position: 'absolute', left: 16, top: 16, bottom: 16, width: 280, display: 'flex', flexDirection: 'column', gap: 10 }}>
        {/* identity card */}
        <div style={{ background: 'rgba(28,32,44,.95)', backdropFilter: 'blur(16px)', border: `1px solid ${c}55`, borderRadius: 14, padding: 14, position: 'relative', overflow: 'hidden' }}>
          <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: 3, background: c }}/>
          <div style={{ font: '500 10px/1 var(--font)', color: c, textTransform: 'uppercase', letterSpacing: '.08em', marginBottom: 6 }}>● Aktif İzleme</div>
          <div style={{ font: '700 16px/1.2 var(--font)', color: 'var(--text)', letterSpacing: '-.01em' }}>{pin.name}</div>
          <div style={{ font: '500 11.5px/1.4 var(--font)', color: 'var(--text-3)', marginTop: 4 }}>{pin.district} / {pin.city}</div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginTop: 14 }}>
            <div><div className="kpi-label">Kapasite</div><div style={{ marginTop: 4 }}><span className="kpi-num tnum" style={{ color: c, fontSize: 18 }}>{pin.capacityMw}</span><span className="kpi-unit">MW</span></div></div>
            <div><div className="kpi-label">Debi</div><div style={{ marginTop: 4 }}><span className="kpi-num tnum" style={{ fontSize: 18 }}>{pin.flowRate}</span><span className="kpi-unit">m³/s</span></div></div>
          </div>
        </div>
        {/* gauge */}
        <div style={{ background: 'rgba(28,32,44,.95)', backdropFilter: 'blur(16px)', border: '1px solid var(--border)', borderRadius: 14, padding: 14 }}>
          <div className="label" style={{ marginBottom: 10 }}>Anlık üretim</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <svg width="80" height="80" viewBox="0 0 80 80">
              <circle cx="40" cy="40" r="32" fill="none" stroke="rgba(255,255,255,.08)" strokeWidth="6"/>
              <circle cx="40" cy="40" r="32" fill="none" stroke={c} strokeWidth="6" strokeLinecap="round"
                      strokeDasharray="200" strokeDashoffset="60" transform="rotate(-90 40 40)"/>
              <text x="40" y="44" textAnchor="middle" fill="white" fontSize="18" fontWeight="700" fontFamily="Inter">70%</text>
            </svg>
            <div>
              <div style={{ font: '700 18px/1.1 var(--font)', color: 'var(--text)' }} className="tnum">16.8 <span style={{ font: '500 11px/1 var(--font)', color: 'var(--text-3)' }}>MW</span></div>
              <div style={{ font: '500 11px/1.4 var(--font)', color: 'var(--text-3)', marginTop: 4 }}>Mevsimsel ortalamanın <span style={{ color: 'var(--success)', fontWeight: 600 }}>+12%</span> üzerinde</div>
            </div>
          </div>
        </div>
        {/* monthly */}
        <div style={{ background: 'rgba(28,32,44,.95)', backdropFilter: 'blur(16px)', border: '1px solid var(--border)', borderRadius: 14, padding: 14, flex: 1 }}>
          <div className="label" style={{ marginBottom: 10 }}>Aylık üretim · GWh</div>
          <MonthlyBars data={pin.monthly.map(v => v/1000)} color={c} height={120}/>
        </div>
        <div style={{ display: 'flex', gap: 6 }}>
          <button className="btn" style={{ flex: 1, justifyContent: 'center' }}><Icon name="edit" size={12}/> Düzenle</button>
          <button className="btn btn-primary" style={{ flex: 1, justifyContent: 'center' }}><Icon name="ext" size={12} color="#06201E"/> Detay</button>
        </div>
      </div>
      {/* right side: callouts on map */}
      <div style={{ position: 'absolute', right: 24, top: 80, display: 'flex', flexDirection: 'column', gap: 8 }}>
        {[
          ['Düşü Yüksekliği', `${pin.headHeight} m`],
          ['Türbin', 'Francis'],
          ['Verim', '92%'],
          ['NPV', '$28.4M'],
        ].map(([l, v]) => (
          <div key={l} style={{ background: 'rgba(28,32,44,.95)', backdropFilter: 'blur(12px)', border: '1px solid var(--border)', borderRadius: 10, padding: '8px 12px', display: 'flex', flexDirection: 'column', alignItems: 'flex-end', minWidth: 130 }}>
            <div className="label">{l}</div>
            <div style={{ font: '700 14px/1.1 var(--font)', color: 'var(--text)', marginTop: 4 }} className="tnum">{v}</div>
          </div>
        ))}
      </div>
    </div>
  );
};

// ===== V4: Inline-editable card (click-to-edit pattern) =====
const DetailInlineEdit = ({ pin = PIN }) => {
  const [editing, setEditing] = useState(false);
  const [name, setName] = useState(pin.name);
  const [capacity, setCapacity] = useState(pin.capacityMw.toString());
  const c = TYPES[pin.type].color;
  return (
    <div style={{ position: 'relative', width: 880, height: 620, borderRadius: 16, overflow: 'hidden', border: '1px solid var(--border)' }}>
      <MapBackdrop/>
      <div style={{
        position: 'absolute', left: '50%', top: '50%', transform: 'translate(-50%, -50%)',
        width: 480, background: 'var(--card)', borderRadius: 18, border: '1px solid var(--border)', boxShadow: '0 32px 80px rgba(0,0,0,.6)',
        overflow: 'hidden'
      }}>
        <div style={{ padding: '22px 24px 16px', background: `linear-gradient(180deg, ${c}1A, transparent)`, borderBottom: '1px solid var(--border-2)' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <div style={{ width: 34, height: 34, borderRadius: 10, background: `${c}22`, border: `1px solid ${c}55`, display: 'grid', placeItems: 'center' }}>
                <TypeIcon type={pin.type} size={16} color={c}/>
              </div>
              <span style={{ font: '500 11px/1 var(--font)', color: c, textTransform: 'uppercase', letterSpacing: '.06em' }}>{TYPES[pin.type].label}</span>
            </div>
            <div style={{ display: 'flex', gap: 4 }}>
              {editing ? (
                <>
                  <button className="btn" onClick={() => setEditing(false)} style={{ padding: '6px 10px', fontSize: 11 }}><Icon name="x" size={12}/> Vazgeç</button>
                  <button className="btn btn-primary" onClick={() => setEditing(false)} style={{ padding: '6px 10px', fontSize: 11 }}><Icon name="check" size={12} color="#06201E"/> Kaydet</button>
                </>
              ) : (
                <button className="btn" onClick={() => setEditing(true)} style={{ padding: '6px 10px', fontSize: 11 }}><Icon name="edit" size={12}/> Düzenle</button>
              )}
            </div>
          </div>
          {/* editable name */}
          {editing ? (
            <input value={name} onChange={e => setName(e.target.value)} className="input" style={{ font: '700 22px/1.1 var(--font)', padding: '8px 10px', height: 'auto' }}/>
          ) : (
            <div style={{ font: '700 22px/1.1 var(--font)', color: 'var(--text)', letterSpacing: '-.02em' }}>{name}</div>
          )}
          <div style={{ font: '500 12.5px/1.4 var(--font)', color: 'var(--text-3)', marginTop: 6 }}>{pin.district} / {pin.city} · <span className="mono">{pin.lat.toFixed(4)}°, {pin.lng.toFixed(4)}°</span></div>
        </div>
        {/* fields */}
        <div style={{ padding: 22, display: 'flex', flexDirection: 'column', gap: 14 }}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
            {/* capacity field */}
            <div>
              <div className="label" style={{ marginBottom: 6 }}>Kurulu güç</div>
              {editing ? (
                <div style={{ position: 'relative' }}>
                  <input value={capacity} onChange={e => setCapacity(e.target.value)} className="input"/>
                  <span style={{ position: 'absolute', right: 12, top: '50%', transform: 'translateY(-50%)', font: '600 11.5px/1 var(--font)', color: 'var(--text-3)' }}>MW</span>
                </div>
              ) : (
                <div style={{ font: '700 22px/1 var(--font)', color: c }} className="tnum">{capacity}<span style={{ font: '500 12px/1 var(--font)', color: 'var(--text-3)', marginLeft: 4 }}>MW</span></div>
              )}
            </div>
            <div>
              <div className="label" style={{ marginBottom: 6 }}>Panel alanı</div>
              {editing ? (
                <input className="input" defaultValue="80000"/>
              ) : (
                <div style={{ font: '700 22px/1 var(--font)', color: 'var(--text)' }} className="tnum">80,000<span style={{ font: '500 12px/1 var(--font)', color: 'var(--text-3)', marginLeft: 4 }}>m²</span></div>
              )}
            </div>
          </div>
          <div>
            <div className="label" style={{ marginBottom: 6 }}>Ekipman</div>
            {editing ? (
              <select className="input"><option>Trina Vertex 660W</option><option>Jinko Tiger Pro</option></select>
            ) : (
              <div style={{ font: '600 14px/1.2 var(--font)', color: 'var(--text)' }}>{pin.equipment}</div>
            )}
          </div>
          {/* read-only KPIs */}
          <div className="card" style={{ padding: 12, borderRadius: 10, background: 'rgba(0,0,0,.20)' }}>
            <div className="label" style={{ marginBottom: 8 }}>Hesaplanmış metrikler</div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 10 }}>
              <div><div style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)', textTransform: 'uppercase' }}>Yıllık</div><div style={{ font: '700 14px/1.1 var(--font)', color: 'var(--text)', marginTop: 4 }} className="tnum">26.8 <span style={{ fontSize: 10, color: 'var(--text-3)', fontWeight: 500 }}>GWh</span></div></div>
              <div><div style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)', textTransform: 'uppercase' }}>NPV</div><div style={{ font: '700 14px/1.1 var(--font)', color: 'var(--success)', marginTop: 4 }} className="tnum">$5.2M</div></div>
              <div><div style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)', textTransform: 'uppercase' }}>ROI</div><div style={{ font: '700 14px/1.1 var(--font)', color: 'var(--text)', marginTop: 4 }} className="tnum">6.2 <span style={{ fontSize: 10, color: 'var(--text-3)', fontWeight: 500 }}>yıl</span></div></div>
            </div>
            {editing && <div style={{ font: '500 10.5px/1.4 var(--font)', color: 'var(--text-3)', marginTop: 10 }}>Kaydet'e basınca metrikler yeniden hesaplanacak.</div>}
          </div>
        </div>
      </div>
    </div>
  );
};

// ===== V5: Sidebar list — modern grouped pin list =====
const SidebarList = () => {
  const groups = [
    { type: 'solar', label: 'Güneş Panelleri', pins: SAMPLE_PINS.filter(p => p.type === 'solar') },
    { type: 'wind', label: 'Rüzgar Türbinleri', pins: SAMPLE_PINS.filter(p => p.type === 'wind') },
    { type: 'hydro', label: 'HES Kurulumları', pins: SAMPLE_PINS.filter(p => p.type === 'hydro') },
  ];
  return (
    <div style={{ position: 'relative', width: 880, height: 620, borderRadius: 16, overflow: 'hidden', border: '1px solid var(--border)' }}>
      <MapBackdrop/>
      <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: 320, background: 'var(--card)', borderRight: '1px solid var(--border)', display: 'flex', flexDirection: 'column' }}>
        {/* header */}
        <div style={{ padding: '18px 18px 14px', borderBottom: '1px solid var(--border-2)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}>
            <Icon name="pin" size={16} color="var(--text)"/>
            <div style={{ font: '700 15px/1 var(--font)', color: 'var(--text)' }}>Pinlerim</div>
            <span className="chip" style={{ fontSize: 10, marginLeft: 'auto' }}>{SAMPLE_PINS.length}</span>
          </div>
          <div style={{ position: 'relative' }}>
            <Icon name="search" size={13} color="var(--text-3)"/>
            <input className="input" placeholder="Ara…" style={{ paddingLeft: 32, fontSize: 12.5, padding: '8px 10px 8px 32px', position: 'relative' }}/>
            <div style={{ position: 'absolute', left: 11, top: '50%', transform: 'translateY(-50%)', display: 'flex' }}>
              <Icon name="search" size={13} color="var(--text-3)"/>
            </div>
          </div>
          <div style={{ display: 'flex', gap: 6, marginTop: 10 }}>
            {Object.values(TYPES).map(t => (
              <button key={t.id} className="chip" style={{ cursor: 'pointer', borderColor: `${t.color}55`, color: t.color, background: `${t.color}11`, flex: 1, justifyContent: 'center' }}>
                <TypeIcon type={t.id} size={10} color={t.color}/>{t.shortLabel}
              </button>
            ))}
          </div>
        </div>
        {/* list */}
        <div className="scroll" style={{ flex: 1, overflow: 'auto', padding: '8px 12px' }}>
          {groups.map(g => (
            <div key={g.type} style={{ marginBottom: 14 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '8px 6px 6px' }}>
                <div style={{ width: 3, height: 12, borderRadius: 2, background: TYPES[g.type].color }}/>
                <span style={{ font: '600 11px/1 var(--font)', color: 'var(--text-2)', textTransform: 'uppercase', letterSpacing: '.06em' }}>{g.label}</span>
                <span style={{ font: '500 10.5px/1 var(--font)', color: 'var(--text-3)' }}>· {g.pins.length}</span>
                <Icon name="chevD" size={11} color="var(--text-3)"/>
              </div>
              {g.pins.map((p, i) => {
                const c = TYPES[p.type].color;
                return (
                  <div key={p.id} style={{
                    padding: '10px 12px', borderRadius: 10, marginBottom: 4,
                    background: i === 0 && g.type === 'solar' ? `${c}11` : 'rgba(0,0,0,.20)',
                    border: i === 0 && g.type === 'solar' ? `1px solid ${c}55` : '1px solid var(--border-2)',
                    display: 'flex', alignItems: 'center', gap: 10, cursor: 'pointer'
                  }}>
                    <div style={{ width: 28, height: 28, borderRadius: 8, background: `${c}22`, display: 'grid', placeItems: 'center' }}>
                      <TypeIcon type={p.type} size={13} color={c}/>
                    </div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ font: '600 12.5px/1.2 var(--font)', color: 'var(--text)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{p.name}</div>
                      <div style={{ font: '500 10.5px/1.2 var(--font)', color: 'var(--text-3)', marginTop: 3, display: 'flex', alignItems: 'center', gap: 6 }}>
                        <span>{p.district}</span><span>·</span><span className="tnum">{p.capacityMw.toFixed(1)} MW</span>
                      </div>
                    </div>
                    <Sparkline data={p.monthly} color={c} width={32} height={14}/>
                  </div>
                );
              })}
            </div>
          ))}
        </div>
        <div style={{ padding: 12, borderTop: '1px solid var(--border-2)' }}>
          <button className="btn btn-primary" style={{ width: '100%', justifyContent: 'center' }}>
            <Icon name="plus" size={13} color="#06201E"/> Yeni Kaynak Ekle
          </button>
        </div>
      </div>
      {/* small hint */}
      <div style={{ position: 'absolute', left: 340, top: 16, padding: '8px 12px', background: 'rgba(28,32,44,.85)', backdropFilter: 'blur(8px)', border: '1px solid var(--border)', borderRadius: 10, font: '500 11px/1.4 var(--font)', color: 'var(--text-2)', maxWidth: 220 }}>
        <Icon name="info" size={11} color="var(--info)"/> Sol panel tüm pinleri gruplandırır. Sparkline = haftalık üretim trendi.
      </div>
    </div>
  );
};

Object.assign(window, { DetailRichDashboard, DetailFloatingCard, DetailHUD, DetailInlineEdit, SidebarList });
