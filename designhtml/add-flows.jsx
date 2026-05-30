// add-flows.jsx — 5 variations of the "Add Pin" experience

// ============================================================================
// V1 — MULTI-STEP WIZARD (modern center modal, 4 steps)
// ============================================================================
const WizardAddFlow = () => {
  const [step, setStep] = useState(1);
  const [type, setType] = useState('solar');
  const [name, setName] = useState('Konya Karapınar GES-2');
  const [capacity, setCapacity] = useState('15.0');
  const [equipment, setEquipment] = useState('trina-660');
  const [scenario, setScenario] = useState(null);

  const c = TYPES[type].color;
  const STEPS = ['Tip', 'Konum', 'Kapasite', 'Ekipman'];

  return (
    <div style={{ position: 'relative', width: 880, height: 620, borderRadius: 16, overflow: 'hidden', border: '1px solid var(--border)' }}>
      <MapBackdrop/>
      {/* dim overlay */}
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(8,10,16,.65)', backdropFilter: 'blur(2px)' }}/>
      {/* wizard card */}
      <div style={{
        position: 'absolute', left: '50%', top: '50%', transform: 'translate(-50%, -50%)',
        width: 520, background: 'var(--card)', borderRadius: 18,
        border: '1px solid var(--border)',
        boxShadow: '0 32px 80px rgba(0,0,0,.6)',
        overflow: 'hidden'
      }}>
        {/* top bar with progress */}
        <div style={{ padding: '20px 22px 14px', borderBottom: '1px solid var(--border-2)' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <div style={{ width: 32, height: 32, borderRadius: 10, background: `${c}22`, display: 'grid', placeItems: 'center', border: `1px solid ${c}55` }}>
                <TypeIcon type={type} size={16} color={c}/>
              </div>
              <div>
                <div style={{ font: '600 15px/1.2 var(--font)', color: 'var(--text)' }}>Yeni Kaynak Ekle</div>
                <div style={{ font: '500 11px/1.2 var(--font)', color: 'var(--text-3)', marginTop: 2 }}>Adım {step} / 4 · {STEPS[step-1]}</div>
              </div>
            </div>
            <button className="btn btn-icon btn-ghost"><Icon name="x" size={16} color="var(--text-2)"/></button>
          </div>
          {/* progress bar */}
          <div style={{ display: 'flex', gap: 4 }}>
            {STEPS.map((s, i) => (
              <div key={i} style={{ flex: 1, height: 3, borderRadius: 2, background: i+1 <= step ? c : 'rgba(255,255,255,.08)', transition: 'background .3s' }}/>
            ))}
          </div>
        </div>

        {/* body */}
        <div style={{ padding: '20px 22px 22px', minHeight: 320 }}>
          {step === 1 && (
            <div>
              <div className="label" style={{ marginBottom: 10 }}>Kaynak tipi</div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
                {Object.values(TYPES).map(t => (
                  <button key={t.id} onClick={() => setType(t.id)} style={{
                    background: type === t.id ? `${t.color}1A` : 'rgba(0,0,0,.25)',
                    border: `1.5px solid ${type === t.id ? t.color : 'var(--border)'}`,
                    borderRadius: 12, padding: '18px 12px',
                    display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8,
                    cursor: 'pointer', transition: 'all .15s', color: 'var(--text)'
                  }}>
                    <TypeIcon type={t.id} size={26} color={t.color}/>
                    <div style={{ font: '600 12.5px/1 var(--font)' }}>{t.label}</div>
                  </button>
                ))}
              </div>
              <div style={{ marginTop: 18 }}>
                <div className="label" style={{ marginBottom: 8 }}>Bu konum için öneri</div>
                <div style={{ display: 'flex', gap: 6 }}>
                  <span className="chip" style={{ borderColor: `${TYPES.solar.color}55`, color: TYPES.solar.color, background: `${TYPES.solar.color}11` }}>
                    <Icon name="check" size={11}/> Güneş uygun · 5.4 kWh/m²
                  </span>
                  <span className="chip" style={{ borderColor: 'var(--border)' }}>
                    Rüzgar zayıf · 3.2 m/s
                  </span>
                </div>
              </div>
            </div>
          )}

          {step === 2 && (
            <div>
              <div className="label" style={{ marginBottom: 10 }}>Seçilen konum</div>
              <div style={{ background: 'rgba(0,0,0,.30)', borderRadius: 12, padding: 14, border: '1px solid var(--border)' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 8 }}>
                  <Icon name="pin" size={18} color={c}/>
                  <div style={{ font: '600 14px/1.2 var(--font)', color: 'var(--text)' }}>Karapınar / Konya</div>
                </div>
                <div className="mono" style={{ font: '500 12px/1 var(--font-mono)', color: 'var(--text-3)' }}>37.7167°N, 33.5500°E</div>
              </div>
              <div style={{ marginTop: 14, padding: 12, background: 'rgba(16,185,129,.08)', border: '1px solid rgba(16,185,129,.3)', borderRadius: 12 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
                  <Icon name="check2" size={14} color="var(--success)"/>
                  <span style={{ font: '600 13px/1 var(--font)', color: 'var(--success)' }}>Kurulum için uygun</span>
                </div>
                <div style={{ font: '500 11.5px/1.4 var(--font)', color: 'var(--text-2)' }}>
                  Korunan alan değil · Eğim &lt; 8° · İletim hattı 3.2 km
                </div>
              </div>
              <div style={{ marginTop: 14 }}>
                <div className="label" style={{ marginBottom: 6 }}>Kaynak adı</div>
                <input className="input" value={name} onChange={e => setName(e.target.value)}/>
              </div>
            </div>
          )}

          {step === 3 && (
            <div>
              <div className="label" style={{ marginBottom: 8 }}>Kurulu güç (MW)</div>
              <div style={{ display: 'flex', gap: 12, alignItems: 'flex-end' }}>
                <div style={{ flex: 1 }}>
                  <input className="input" value={capacity} onChange={e => setCapacity(e.target.value)} style={{ font: '700 28px/1 var(--font)', textAlign: 'center', height: 70 }}/>
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                  <button className="btn btn-icon" style={{ width: 36, height: 32 }}>+</button>
                  <button className="btn btn-icon" style={{ width: 36, height: 32 }}>−</button>
                </div>
              </div>
              <div style={{ marginTop: 16, display: 'flex', gap: 8 }}>
                {[5, 10, 15, 25, 50].map(v => (
                  <button key={v} onClick={() => setCapacity(v.toFixed(1))} className="chip" style={{ cursor: 'pointer', background: capacity === v.toFixed(1) ? `${c}22` : undefined, borderColor: capacity === v.toFixed(1) ? c : undefined, color: capacity === v.toFixed(1) ? c : undefined }}>
                    {v} MW
                  </button>
                ))}
              </div>
              {type === 'solar' && (
                <div style={{ marginTop: 18 }}>
                  <div className="label" style={{ marginBottom: 6 }}>Panel alanı (m²)</div>
                  <input className="input" defaultValue="80000"/>
                </div>
              )}
              <div style={{ marginTop: 18, padding: 12, background: 'rgba(0,0,0,.25)', borderRadius: 10, border: '1px solid var(--border-2)' }}>
                <div className="label" style={{ marginBottom: 8 }}>Tahmini Yıllık Üretim</div>
                <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
                  <span className="kpi-num" style={{ color: c, fontSize: 28 }} className2="tnum">{(parseFloat(capacity) * 1789).toFixed(0)}</span>
                  <span className="kpi-unit">MWh/yıl</span>
                  <span style={{ marginLeft: 'auto', color: 'var(--success)', font: '600 12px/1 var(--font)' }}>~{(parseFloat(capacity) * 0.42).toFixed(2)}M $ NPV</span>
                </div>
              </div>
            </div>
          )}

          {step === 4 && (
            <div>
              <div className="label" style={{ marginBottom: 8 }}>Panel modeli</div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                {[
                  { id: 'trina-660', name: 'Trina Vertex 660W', eff: '21.3%', tag: 'Önerilen' },
                  { id: 'jinko-580', name: 'Jinko Tiger Neo 580W', eff: '22.5%', tag: null },
                  { id: 'longi-555', name: 'LONGi Hi-MO 5 555W', eff: '21.0%', tag: null },
                ].map(eq => (
                  <button key={eq.id} onClick={() => setEquipment(eq.id)} style={{
                    display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                    padding: '12px 14px',
                    background: equipment === eq.id ? `${c}11` : 'rgba(0,0,0,.20)',
                    border: `1px solid ${equipment === eq.id ? c : 'var(--border)'}`,
                    borderRadius: 10, cursor: 'pointer', textAlign: 'left'
                  }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                      <div style={{ width: 16, height: 16, borderRadius: '50%', border: `1.5px solid ${equipment === eq.id ? c : 'var(--border)'}`, display: 'grid', placeItems: 'center' }}>
                        {equipment === eq.id && <div style={{ width: 7, height: 7, borderRadius: '50%', background: c }}/>}
                      </div>
                      <div>
                        <div style={{ font: '600 13px/1.2 var(--font)', color: 'var(--text)' }}>{eq.name}</div>
                        <div style={{ font: '500 11px/1 var(--font)', color: 'var(--text-3)', marginTop: 3 }}>Verim {eq.eff}</div>
                      </div>
                    </div>
                    {eq.tag && <span className="chip" style={{ borderColor: `${c}55`, color: c, background: `${c}11`, fontSize: 10 }}>{eq.tag}</span>}
                  </button>
                ))}
              </div>
              <div style={{ marginTop: 16 }}>
                <div className="label" style={{ marginBottom: 6 }}>Senaryoya ekle (opsiyonel)</div>
                <select className="input" value={scenario || ''} onChange={e => setScenario(e.target.value)}>
                  <option value="">— Senaryo seçilmedi —</option>
                  <option value="1">Türkiye 2030 Yenilenebilir</option>
                  <option value="2">İç Anadolu Solar Portföy</option>
                  <option value="3">+ Yeni senaryo oluştur</option>
                </select>
              </div>
            </div>
          )}
        </div>

        {/* footer */}
        <div style={{ padding: '14px 22px 18px', borderTop: '1px solid var(--border-2)', display: 'flex', alignItems: 'center', gap: 10 }}>
          <button className="btn" onClick={() => setStep(s => Math.max(1, s-1))} disabled={step === 1} style={{ opacity: step === 1 ? 0.4 : 1 }}>
            <Icon name="chevL" size={14}/> Geri
          </button>
          <div style={{ flex: 1 }}/>
          {step < 4 ? (
            <button className="btn btn-primary" onClick={() => setStep(s => Math.min(4, s+1))}>
              Devam <Icon name="chevR" size={14}/>
            </button>
          ) : (
            <button className="btn btn-primary">
              <Icon name="check" size={14}/> Kaynağı Kaydet
            </button>
          )}
        </div>
      </div>
    </div>
  );
};

// ============================================================================
// V2 — MAP-ANCHORED FLOATING CARD (compact form floating next to a pin)
// ============================================================================
const FloatingCardAddFlow = () => {
  const [type, setType] = useState('wind');
  const c = TYPES[type].color;
  return (
    <div style={{ position: 'relative', width: 880, height: 620, borderRadius: 16, overflow: 'hidden', border: '1px solid var(--border)' }}>
      <MapBackdrop/>
      {/* placeholder pin */}
      <div style={{ position: 'absolute', left: '36%', top: '52%' }}>
        <div style={{ width: 14, height: 14, borderRadius: '50%', background: c, border: '2px solid white', boxShadow: `0 0 0 4px ${c}33, 0 6px 20px rgba(0,0,0,.5)` }}/>
        {/* connector line */}
        <svg style={{ position: 'absolute', left: 7, top: 7, overflow: 'visible' }} width="1" height="1">
          <line x1="0" y1="0" x2="80" y2="-50" stroke={c} strokeWidth="1.5" strokeDasharray="3 3" opacity="0.5"/>
        </svg>
      </div>
      {/* floating form */}
      <div style={{
        position: 'absolute', left: 'calc(36% + 80px)', top: 'calc(52% - 60px)',
        width: 340, background: 'rgba(28,32,44,.96)', backdropFilter: 'blur(18px)',
        border: '1px solid var(--border)', borderRadius: 14,
        boxShadow: '0 20px 60px rgba(0,0,0,.6)', overflow: 'hidden'
      }}>
        {/* header strip */}
        <div style={{ padding: '12px 14px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', borderBottom: '1px solid var(--border-2)', background: `linear-gradient(180deg, ${c}1A, transparent)` }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <Icon name="plus" size={14} color={c}/>
            <span style={{ font: '600 13px/1 var(--font)', color: 'var(--text)' }}>Yeni Kaynak</span>
          </div>
          <button className="btn-icon btn-ghost" style={{ background: 'transparent', border: 'none', cursor: 'pointer', padding: 4 }}><Icon name="x" size={14} color="var(--text-3)"/></button>
        </div>
        {/* coords row */}
        <div style={{ padding: '10px 14px', borderBottom: '1px solid var(--border-2)', display: 'flex', alignItems: 'center', gap: 6 }}>
          <Icon name="pin" size={12} color="var(--text-3)"/>
          <span style={{ font: '500 11.5px/1 var(--font)', color: 'var(--text-2)' }}>Bandırma / Balıkesir</span>
          <span style={{ marginLeft: 'auto', font: '500 10px/1 var(--font-mono)', color: 'var(--text-3)' }}>40.35°N, 27.97°E</span>
        </div>
        {/* type segmented */}
        <div style={{ padding: '12px 14px 0' }}>
          <div className="seg" style={{ width: '100%' }}>
            {Object.values(TYPES).map(t => (
              <button key={t.id} onClick={() => setType(t.id)} className={type === t.id ? 'on' : ''} style={{ flex: 1, color: type === t.id ? t.color : undefined }}>
                <TypeIcon type={t.id} size={12} color={type === t.id ? t.color : 'var(--text-3)'}/>
                <span>{t.shortLabel}</span>
              </button>
            ))}
          </div>
        </div>
        {/* form body */}
        <div style={{ padding: '14px', display: 'flex', flexDirection: 'column', gap: 10 }}>
          <div>
            <div className="label" style={{ marginBottom: 5 }}>Ad</div>
            <input className="input" defaultValue="Bandırma RES-3" style={{ padding: '9px 11px', fontSize: 13 }}/>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
            <div>
              <div className="label" style={{ marginBottom: 5 }}>Kapasite</div>
              <div style={{ position: 'relative' }}>
                <input className="input" defaultValue="48.0" style={{ padding: '9px 36px 9px 11px', fontSize: 13 }}/>
                <span style={{ position: 'absolute', right: 10, top: '50%', transform: 'translateY(-50%)', font: '500 11px/1 var(--font)', color: 'var(--text-3)' }}>MW</span>
              </div>
            </div>
            <div>
              <div className="label" style={{ marginBottom: 5 }}>Türbin sayısı</div>
              <input className="input" defaultValue="12" style={{ padding: '9px 11px', fontSize: 13 }}/>
            </div>
          </div>
          <div>
            <div className="label" style={{ marginBottom: 5 }}>Türbin modeli</div>
            <select className="input" style={{ padding: '9px 11px', fontSize: 13 }}>
              <option>Vestas V150 4.5 MW</option>
              <option>Enercon E-138</option>
              <option>Siemens Gamesa SG 5.0</option>
            </select>
          </div>
          {/* live estimate */}
          <div style={{ background: `${c}11`, border: `1px solid ${c}33`, borderRadius: 10, padding: '10px 12px', display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ width: 26, height: 26, borderRadius: 8, background: `${c}22`, display: 'grid', placeItems: 'center' }}>
              <Icon name="spark" size={13} color={c}/>
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '.04em' }}>Yıllık tahmin</div>
              <div style={{ font: '700 14px/1.2 var(--font)', color: c, marginTop: 2 }} className="tnum">142 GWh · 8.1 yıl ROI</div>
            </div>
          </div>
        </div>
        {/* footer */}
        <div style={{ padding: '0 14px 14px', display: 'flex', gap: 8 }}>
          <button className="btn" style={{ flex: 1 }}>İptal</button>
          <button className="btn btn-primary" style={{ flex: 1 }}><Icon name="plus" size={13} color="#06201E"/> Ekle</button>
        </div>
      </div>
    </div>
  );
};

// ============================================================================
// V3 — INLINE CONTEXTUAL POPOVER (small balloon directly at click point)
// ============================================================================
const InlinePopoverAddFlow = () => {
  const [type, setType] = useState('hydro');
  const [stage, setStage] = useState('quick'); // 'quick' or 'expanded'
  const c = TYPES[type].color;
  return (
    <div style={{ position: 'relative', width: 880, height: 620, borderRadius: 16, overflow: 'hidden', border: '1px solid var(--border)' }}>
      <MapBackdrop/>
      {/* click ripple at center */}
      <div style={{ position: 'absolute', left: '50%', top: '50%', transform: 'translate(-50%, -50%)' }}>
        <div style={{ width: 8, height: 8, borderRadius: '50%', background: c, boxShadow: `0 0 0 6px ${c}22, 0 0 0 14px ${c}11`, animation: 'srrp-pulse 1.6s ease-out infinite' }}/>
      </div>
      {/* popover */}
      <div style={{
        position: 'absolute', left: '50%', top: 'calc(50% - 14px)', transform: 'translate(-50%, -100%)',
        width: stage === 'expanded' ? 380 : 280,
        background: 'rgba(28,32,44,.97)', backdropFilter: 'blur(20px)',
        border: '1px solid var(--border)', borderRadius: 14,
        boxShadow: '0 24px 60px rgba(0,0,0,.6)',
        transition: 'width .3s'
      }}>
        {/* arrow */}
        <div style={{ position: 'absolute', left: '50%', bottom: -6, transform: 'translateX(-50%) rotate(45deg)', width: 12, height: 12, background: 'rgba(28,32,44,.97)', borderRight: '1px solid var(--border)', borderBottom: '1px solid var(--border)' }}/>
        <div style={{ padding: stage === 'quick' ? 14 : '14px 16px 16px' }}>
          {/* coords row */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 10 }}>
            <Icon name="pin" size={12} color="var(--text-3)"/>
            <span style={{ font: '500 11px/1 var(--font)', color: 'var(--text-2)' }}>Yusufeli / Artvin</span>
            <span style={{ marginLeft: 'auto', font: '500 10px/1 var(--font-mono)', color: 'var(--text-3)' }}>40.82°, 41.53°</span>
          </div>
          {stage === 'quick' ? (
            <>
              <div style={{ font: '600 13px/1.2 var(--font)', color: 'var(--text)', marginBottom: 10 }}>Burada ne kuracaksın?</div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 6 }}>
                {Object.values(TYPES).map(t => (
                  <button key={t.id} onClick={() => { setType(t.id); setStage('expanded'); }} style={{
                    background: 'rgba(0,0,0,.25)', border: '1px solid var(--border)', borderRadius: 10,
                    padding: '11px 6px', cursor: 'pointer', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 5, color: 'var(--text)'
                  }}>
                    <TypeIcon type={t.id} size={20} color={t.color}/>
                    <span style={{ font: '600 11px/1 var(--font)' }}>{t.shortLabel}</span>
                  </button>
                ))}
              </div>
              <div style={{ marginTop: 10, font: '500 10px/1.4 var(--font)', color: 'var(--text-3)', textAlign: 'center' }}>
                Tip seç → form genişler. ESC ile kapat.
              </div>
            </>
          ) : (
            <>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12 }}>
                <div style={{ width: 26, height: 26, borderRadius: 8, background: `${c}22`, display: 'grid', placeItems: 'center' }}>
                  <TypeIcon type={type} size={14} color={c}/>
                </div>
                <span style={{ font: '600 13px/1 var(--font)', color: 'var(--text)' }}>Hidroelektrik</span>
                <button onClick={() => setStage('quick')} style={{ marginLeft: 'auto', background: 'transparent', border: 'none', color: 'var(--text-3)', cursor: 'pointer', font: '500 11px/1 var(--font)' }}>Değiştir</button>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 9 }}>
                <input className="input" defaultValue="Çoruh HES-7" placeholder="Ad" style={{ padding: '8px 10px', fontSize: 12.5 }}/>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 6 }}>
                  <input className="input" defaultValue="24.0" placeholder="MW" style={{ padding: '8px 10px', fontSize: 12.5 }}/>
                  <input className="input" defaultValue="32.5" placeholder="Debi m³/s" style={{ padding: '8px 10px', fontSize: 12.5 }}/>
                </div>
                <input className="input" defaultValue="145" placeholder="Düşü yüksekliği (m)" style={{ padding: '8px 10px', fontSize: 12.5 }}/>
              </div>
              <div style={{ display: 'flex', gap: 6, marginTop: 12 }}>
                <button className="btn" style={{ flex: 1, padding: '8px 10px', fontSize: 12 }}>İptal</button>
                <button className="btn btn-primary" style={{ flex: 2, padding: '8px 10px', fontSize: 12 }}>
                  <Icon name="plus" size={12} color="#06201E"/> Hızlı Ekle
                </button>
              </div>
              <button style={{ width: '100%', marginTop: 8, background: 'transparent', border: 'none', color: 'var(--text-3)', cursor: 'pointer', font: '500 10.5px/1 var(--font)', padding: '4px' }}>
                Detaylı düzenle →
              </button>
            </>
          )}
        </div>
      </div>
    </div>
  );
};

// ============================================================================
// V4 — SIDE PANEL (slides in from right, map stays interactive)
// ============================================================================
const SidePanelAddFlow = () => {
  const [type, setType] = useState('solar');
  const c = TYPES[type].color;
  return (
    <div style={{ position: 'relative', width: 880, height: 620, borderRadius: 16, overflow: 'hidden', border: '1px solid var(--border)' }}>
      <MapBackdrop/>
      {/* placeholder pin on map left */}
      <div style={{ position: 'absolute', left: '40%', top: '60%' }}>
        <div style={{ width: 12, height: 12, borderRadius: '50%', background: c, border: '2px solid white', boxShadow: `0 0 0 4px ${c}44` }}/>
      </div>
      {/* labels on map */}
      <div style={{ position: 'absolute', left: 14, top: 14, display: 'flex', alignItems: 'center', gap: 8, padding: '6px 10px', background: 'rgba(20,24,34,.85)', border: '1px solid var(--border)', borderRadius: 999 }}>
        <Icon name="info" size={12} color="var(--info)"/>
        <span style={{ font: '500 11px/1 var(--font)', color: 'var(--text-2)' }}>Haritaya tıklayıp konumu güncelleyebilirsin</span>
      </div>

      {/* side panel */}
      <div style={{
        position: 'absolute', right: 0, top: 0, bottom: 0,
        width: 380, background: 'var(--card)',
        borderLeft: '1px solid var(--border)',
        boxShadow: '-20px 0 40px rgba(0,0,0,.4)',
        display: 'flex', flexDirection: 'column'
      }}>
        {/* header */}
        <div style={{ padding: '18px 20px', borderBottom: '1px solid var(--border-2)', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div>
            <div style={{ font: '600 16px/1.2 var(--font)', color: 'var(--text)', letterSpacing: '-.01em' }}>Yeni Kaynak</div>
            <div style={{ font: '500 11.5px/1.4 var(--font)', color: 'var(--text-3)', marginTop: 4 }}>Konya · Karapınar</div>
          </div>
          <button className="btn-icon btn-ghost" style={{ background: 'transparent', border: 'none', cursor: 'pointer', padding: 6 }}>
            <Icon name="x" size={16} color="var(--text-2)"/>
          </button>
        </div>

        {/* suitability strip */}
        <div style={{ margin: 16, padding: 12, background: 'rgba(16,185,129,.08)', border: '1px solid rgba(16,185,129,.3)', borderRadius: 10, display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{ width: 32, height: 32, borderRadius: '50%', background: 'rgba(16,185,129,.15)', display: 'grid', placeItems: 'center' }}>
            <Icon name="check2" size={16} color="var(--success)"/>
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ font: '600 13px/1.2 var(--font)', color: 'var(--success)' }}>Kurulum için uygun</div>
            <div style={{ font: '500 11px/1.3 var(--font)', color: 'var(--text-2)', marginTop: 2 }}>Güneş ışınımı 5.4 kWh/m² · Eğim &lt; 8°</div>
          </div>
        </div>

        {/* type tabs */}
        <div style={{ padding: '0 16px' }}>
          <div className="seg" style={{ width: '100%' }}>
            {Object.values(TYPES).map(t => (
              <button key={t.id} onClick={() => setType(t.id)} className={type === t.id ? 'on' : ''} style={{ flex: 1, color: type === t.id ? t.color : undefined }}>
                <TypeIcon type={t.id} size={13} color={type === t.id ? t.color : 'var(--text-3)'}/>
                <span>{t.shortLabel}</span>
              </button>
            ))}
          </div>
        </div>

        {/* form body, scrollable */}
        <div className="scroll" style={{ flex: 1, overflow: 'auto', padding: '16px', display: 'flex', flexDirection: 'column', gap: 14 }}>
          <div>
            <div className="label" style={{ marginBottom: 6 }}>Kaynak adı</div>
            <input className="input" defaultValue="Konya Karapınar GES-2"/>
          </div>
          <div>
            <div className="label" style={{ marginBottom: 6 }}>Kurulu güç</div>
            <div style={{ position: 'relative' }}>
              <input className="input" defaultValue="15.0" style={{ paddingRight: 50 }}/>
              <span style={{ position: 'absolute', right: 12, top: '50%', transform: 'translateY(-50%)', font: '600 11.5px/1 var(--font)', color: 'var(--text-3)' }}>MW</span>
            </div>
            {/* slider */}
            <div style={{ marginTop: 10, position: 'relative', height: 4, background: 'rgba(255,255,255,.06)', borderRadius: 2 }}>
              <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: '30%', background: c, borderRadius: 2 }}/>
              <div style={{ position: 'absolute', left: '30%', top: '50%', transform: 'translate(-50%, -50%)', width: 14, height: 14, borderRadius: '50%', background: 'white', boxShadow: '0 1px 4px rgba(0,0,0,.4)' }}/>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 4, font: '500 10px/1 var(--font)', color: 'var(--text-3)' }}>
              <span>0.5 MW</span><span>50 MW</span>
            </div>
          </div>
          <div>
            <div className="label" style={{ marginBottom: 6 }}>Panel alanı (m²)</div>
            <input className="input" defaultValue="80,000"/>
          </div>
          <div>
            <div className="label" style={{ marginBottom: 6 }}>Panel modeli</div>
            <select className="input">
              <option>Trina Vertex 660W (önerilen)</option>
              <option>Jinko Tiger Neo 580W</option>
            </select>
          </div>
          <div>
            <div className="label" style={{ marginBottom: 6 }}>Senaryo</div>
            <select className="input">
              <option>— Senaryoya ekleme —</option>
              <option>Türkiye 2030 Yenilenebilir</option>
            </select>
          </div>

          {/* live preview KPIs */}
          <div style={{ marginTop: 4, padding: 14, background: 'rgba(0,0,0,.30)', border: '1px solid var(--border-2)', borderRadius: 12 }}>
            <div className="label" style={{ marginBottom: 10 }}>Anlık Tahmin</div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div>
                <div style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)', textTransform: 'uppercase' }}>Yıllık Üretim</div>
                <div style={{ font: '700 18px/1.1 var(--font)', color: c, marginTop: 4 }} className="tnum">26.8 <span style={{ fontSize: 11, color: 'var(--text-3)', fontWeight: 500 }}>GWh</span></div>
              </div>
              <div>
                <div style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)', textTransform: 'uppercase' }}>NPV (25y)</div>
                <div style={{ font: '700 18px/1.1 var(--font)', color: 'var(--success)', marginTop: 4 }} className="tnum">$6.4M</div>
              </div>
              <div>
                <div style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)', textTransform: 'uppercase' }}>Geri Ödeme</div>
                <div style={{ font: '700 18px/1.1 var(--font)', color: 'var(--text)', marginTop: 4 }} className="tnum">6.2 <span style={{ fontSize: 11, color: 'var(--text-3)', fontWeight: 500 }}>yıl</span></div>
              </div>
              <div>
                <div style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)', textTransform: 'uppercase' }}>LCOE</div>
                <div style={{ font: '700 18px/1.1 var(--font)', color: 'var(--text)', marginTop: 4 }} className="tnum">$0.041 <span style={{ fontSize: 11, color: 'var(--text-3)', fontWeight: 500 }}>/kWh</span></div>
              </div>
            </div>
          </div>
        </div>

        {/* footer */}
        <div style={{ padding: '14px 16px', borderTop: '1px solid var(--border-2)', display: 'flex', gap: 10 }}>
          <button className="btn" style={{ flex: 1 }}>İptal</button>
          <button className="btn btn-primary" style={{ flex: 2 }}>
            <Icon name="check" size={14} color="#06201E"/> Kaynağı Ekle
          </button>
        </div>
      </div>
    </div>
  );
};

// ============================================================================
// V5 — RADICAL: COMMAND-PALETTE STYLE
// ============================================================================
const CommandPaletteAddFlow = () => {
  const [query, setQuery] = useState('Konya 15');
  const c = TYPES.solar.color;
  return (
    <div style={{ position: 'relative', width: 880, height: 620, borderRadius: 16, overflow: 'hidden', border: '1px solid var(--border)' }}>
      <MapBackdrop/>
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(8,10,16,.55)', backdropFilter: 'blur(3px)' }}/>
      {/* command palette */}
      <div style={{
        position: 'absolute', left: '50%', top: 90, transform: 'translateX(-50%)',
        width: 580, background: 'rgba(34,40,54,.97)', backdropFilter: 'blur(24px)',
        borderRadius: 16, border: '1px solid var(--border)',
        boxShadow: '0 30px 80px rgba(0,0,0,.7)',
        overflow: 'hidden'
      }}>
        {/* search input */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '14px 18px', borderBottom: '1px solid var(--border-2)' }}>
          <Icon name="plus" size={18} color={c}/>
          <input value={query} onChange={e => setQuery(e.target.value)} style={{
            flex: 1, background: 'transparent', border: 'none', outline: 'none',
            font: '500 16px/1 var(--font)', color: 'var(--text)', letterSpacing: '-.01em'
          }} placeholder="Konum, tip ve kapasite yaz: 'Konya 15 MW solar'"/>
          <kbd style={{ font: '600 10px/1 var(--font-mono)', color: 'var(--text-3)', background: 'rgba(0,0,0,.35)', padding: '4px 6px', borderRadius: 4, border: '1px solid var(--border-2)' }}>⌘K</kbd>
        </div>

        {/* parsed intent */}
        <div style={{ padding: '12px 18px 8px' }}>
          <div className="label" style={{ marginBottom: 8 }}>Akıllı yorum</div>
          <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
            <span className="chip" style={{ borderColor: `${TYPES.solar.color}55`, color: TYPES.solar.color, background: `${TYPES.solar.color}11` }}>
              <TypeIcon type="solar" size={11} color={TYPES.solar.color}/> Güneş Paneli
            </span>
            <span className="chip">📍 Konya / Karapınar</span>
            <span className="chip"><Icon name="mw" size={10} color="var(--text-3)"/> 15.0 MW</span>
            <span className="chip" style={{ borderColor: 'rgba(16,185,129,.4)', color: 'var(--success)', background: 'rgba(16,185,129,.08)' }}>
              <Icon name="check" size={10}/> Konum uygun
            </span>
          </div>
        </div>

        {/* suggestions */}
        <div style={{ padding: '6px 8px', maxHeight: 320, overflow: 'auto' }} className="scroll">
          {[
            { icon: 'check', primary: 'Bu yorumla ekle', sec: 'Güneş · 15 MW · Karapınar/Konya', kbd: '↵', highlight: true },
            { icon: 'edit', primary: 'Detayları aç', sec: 'Tüm parametreleri elle düzenle', kbd: '⌘E' },
            { icon: 'cal', primary: 'Senaryoya ekle: Türkiye 2030', sec: 'Yeni kaynak senaryoda eklenir', kbd: '⌘S' },
            { icon: 'pin', primary: 'Önce konum analizi yap', sec: 'Eğim, koruma alanı, iletim hattı kontrolü', kbd: '⌘A' },
          ].map((it, i) => (
            <div key={i} style={{
              display: 'flex', alignItems: 'center', gap: 12,
              padding: '10px 12px', borderRadius: 10,
              background: it.highlight ? `${c}15` : 'transparent',
              border: it.highlight ? `1px solid ${c}55` : '1px solid transparent',
              cursor: 'pointer'
            }}>
              <div style={{ width: 28, height: 28, borderRadius: 8, background: it.highlight ? `${c}22` : 'rgba(255,255,255,.05)', display: 'grid', placeItems: 'center' }}>
                <Icon name={it.icon} size={14} color={it.highlight ? c : 'var(--text-2)'}/>
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ font: '600 13px/1.2 var(--font)', color: it.highlight ? c : 'var(--text)' }}>{it.primary}</div>
                <div style={{ font: '500 11px/1 var(--font)', color: 'var(--text-3)', marginTop: 3 }}>{it.sec}</div>
              </div>
              <kbd style={{ font: '600 10px/1 var(--font-mono)', color: 'var(--text-3)', background: 'rgba(0,0,0,.35)', padding: '4px 6px', borderRadius: 4, border: '1px solid var(--border-2)' }}>{it.kbd}</kbd>
            </div>
          ))}
        </div>

        {/* footer hint */}
        <div style={{ padding: '10px 18px', borderTop: '1px solid var(--border-2)', display: 'flex', alignItems: 'center', gap: 14, font: '500 10.5px/1 var(--font)', color: 'var(--text-3)' }}>
          <span><kbd style={{ font: '600 10px/1 var(--font-mono)', background: 'rgba(0,0,0,.4)', padding: '2px 5px', borderRadius: 3 }}>↑↓</kbd> Gez</span>
          <span><kbd style={{ font: '600 10px/1 var(--font-mono)', background: 'rgba(0,0,0,.4)', padding: '2px 5px', borderRadius: 3 }}>↵</kbd> Seç</span>
          <span><kbd style={{ font: '600 10px/1 var(--font-mono)', background: 'rgba(0,0,0,.4)', padding: '2px 5px', borderRadius: 3 }}>esc</kbd> Kapat</span>
          <span style={{ marginLeft: 'auto' }}>AI öneri açık</span>
        </div>
      </div>
    </div>
  );
};

Object.assign(window, { WizardAddFlow, FloatingCardAddFlow, InlinePopoverAddFlow, SidePanelAddFlow, CommandPaletteAddFlow });
