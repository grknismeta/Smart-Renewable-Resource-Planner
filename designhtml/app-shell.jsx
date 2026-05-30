// app-shell.jsx — unified responsive SRRP prototype
// Single shared state — same data renders across desktop/tablet/mobile frames

const { useState, useRef, useEffect } = React;

// ===== shared state hook =====
const useAppState = (initial = {}) => {
  const [leftPanel, setLeftPanel] = useState(initial.leftPanel ?? 'senaryolar'); // 'senaryolar' | 'pinlerim' | null
  const [selectedPinId, setSelectedPinId] = useState(initial.selectedPinId ?? null);
  const [addFlowStage, setAddFlowStage] = useState(initial.addFlowStage ?? null); // null | 'popover' | 'panel'
  const [addFlowCoords, setAddFlowCoords] = useState(initial.addFlowCoords ?? { x: 0.5, y: 0.5 });
  const [markerMode, setMarkerMode] = useState(initial.markerMode ?? 'ops'); // 'ops' (CF ring) | 'trend' (spark)
  const [scenarioOpen, setScenarioOpen] = useState(initial.scenarioOpen ?? true);
  // Suitability overlay state
  const [suitOn, setSuitOn] = useState(initial.suitOn ?? false);
  const [suitType, setSuitType] = useState(initial.suitType ?? 'solar'); // 'solar' | 'wind' | 'hydro'
  const [suitThreshold, setSuitThreshold] = useState(initial.suitThreshold ?? 40);
  const [suitLayers, setSuitLayers] = useState(initial.suitLayers ?? { choropleth: true, suitable: true, restricted: true });
  const [suitZoom, setSuitZoom] = useState(initial.suitZoom ?? 'province'); // 'province' | 'district' | 'polygon'
  const [restrictedHover, setRestrictedHover] = useState(null); // {zone, x, y}
  // Map-level time simulation overlay
  const [timeSimOn, setTimeSimOn] = useState(initial.timeSimOn ?? false);
  return { leftPanel, setLeftPanel, selectedPinId, setSelectedPinId, addFlowStage, setAddFlowStage, addFlowCoords, setAddFlowCoords, markerMode, setMarkerMode, scenarioOpen, setScenarioOpen, suitOn, setSuitOn, suitType, setSuitType, suitThreshold, setSuitThreshold, suitLayers, setSuitLayers, suitZoom, setSuitZoom, restrictedHover, setRestrictedHover, timeSimOn, setTimeSimOn };
};

// ===== Sample scenarios =====
const SAMPLE_SCENARIOS = [
  { id: 's1', name: 'Türkiye 2030 Yenilenebilir', pinCount: 14, totalMw: 285, npv: '$58.2M', color: '#10B981' },
  { id: 's2', name: 'İç Anadolu Solar Portföy', pinCount: 6, totalMw: 92, npv: '$23.4M', color: TYPES.solar.color },
  { id: 's3', name: 'Marmara RES Genişleme', pinCount: 8, totalMw: 168, npv: '$41.1M', color: TYPES.wind.color },
  { id: 's4', name: 'Doğu Karadeniz HES', pinCount: 5, totalMw: 76, npv: '$28.6M', color: TYPES.hydro.color },
];

// ===== unified marker (mode-aware) =====
const UnifiedMarker = ({ pin, mode, selected, onClick, scale = 1 }) => {
  const c = TYPES[pin.type].color;
  if (mode === 'trend') {
    const weekly = pin.monthly.slice(0, 7).map((m, i) => m * (0.85 + Math.sin(i*1.3)*0.12));
    return (
      <div onClick={onClick} style={{ cursor: 'pointer', transform: `scale(${selected ? scale*1.08 : scale})`, transition: 'transform .2s' }}>
        <div style={{
          background: 'rgba(20,24,34,.95)',
          border: `1.5px solid ${c}`,
          borderRadius: 10, padding: '4px 8px',
          boxShadow: selected ? `0 0 0 3px ${c}33, 0 8px 20px rgba(0,0,0,.5)` : '0 4px 12px rgba(0,0,0,.4)',
          display: 'flex', alignItems: 'center', gap: 6
        }}>
          <TypeIcon type={pin.type} size={11} color={c}/>
          <Sparkline data={weekly} color={c} width={36} height={12}/>
          <span style={{ font: '700 9.5px/1 var(--font-mono)', color: 'white' }}>{pin.capacityMw}</span>
        </div>
      </div>
    );
  }
  // ops mode: ring + CF
  const cf = pin.capacityFactor || (pin.type === 'solar' ? 0.22 : pin.type === 'wind' ? 0.34 : 0.55);
  const r = 14 * scale;
  const circ = 2 * Math.PI * r;
  const dash = circ * cf;
  const sz = 38 * scale;
  return (
    <div onClick={onClick} style={{ position: 'relative', cursor: 'pointer', transform: selected ? 'scale(1.12)' : 'scale(1)', transition: 'transform .2s' }}>
      <svg width={sz} height={sz} viewBox={`0 0 ${sz} ${sz}`}>
        <circle cx={sz/2} cy={sz/2} r={r} fill="none" stroke="rgba(255,255,255,.2)" strokeWidth="2.5"/>
        <circle cx={sz/2} cy={sz/2} r={r} fill="none" stroke={c} strokeWidth="2.5" strokeLinecap="round"
                strokeDasharray={`${dash} ${circ}`} transform={`rotate(-90 ${sz/2} ${sz/2})`}/>
        <circle cx={sz/2} cy={sz/2} r={r-4} fill="rgba(20,24,34,.95)" stroke="rgba(255,255,255,.08)"/>
      </svg>
      <div style={{ position: 'absolute', inset: 0, display: 'grid', placeItems: 'center' }}>
        <TypeIcon type={pin.type} size={12*scale} color={c}/>
      </div>
    </div>
  );
};

// ===== Cluster marker (when pins are close) =====
const ClusterMarker = ({ counts, total, onClick }) => {
  const segs = [];
  let acc = 0;
  Object.entries(counts).forEach(([type, n]) => {
    if (n > 0) segs.push({ type, n, start: acc, end: acc + n });
    acc += n;
  });
  const r = 22, circ = 2 * Math.PI * r;
  return (
    <div onClick={onClick} style={{ position: 'relative', cursor: 'pointer', filter: 'drop-shadow(0 6px 14px rgba(0,0,0,.45))' }}>
      <svg width="56" height="56" viewBox="0 0 56 56">
        <circle cx="28" cy="28" r={r} fill="rgba(20,24,34,.97)" stroke="rgba(255,255,255,.10)" strokeWidth="1"/>
        {segs.map((s, i) => {
          const dash = ((s.end - s.start) / total) * circ;
          const offset = -((s.start) / total) * circ;
          return <circle key={i} cx="28" cy="28" r={r-1} fill="none" stroke={TYPES[s.type].color} strokeWidth="3"
                  strokeDasharray={`${dash} ${circ}`} strokeDashoffset={offset} transform="rotate(-90 28 28)"/>;
        })}
      </svg>
      <div style={{ position: 'absolute', inset: 0, display: 'grid', placeItems: 'center' }}>
        <span style={{ font: '700 16px/1 var(--font)', color: 'white' }}>{total}</span>
      </div>
    </div>
  );
};

// ===== Unified left panel (Senaryolar + Pinlerim tabs) =====
const UnifiedLeftPanel = ({ activeTab, onTab, onClose, selectedPinId, onSelectPin, compact = false, onAdd }) => {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: 'var(--card)', borderRight: '1px solid var(--border)' }}>
      {/* header */}
      <div style={{ padding: compact ? '14px 16px 10px' : '18px 18px 14px', borderBottom: '1px solid var(--border-2)' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}>
          <div style={{ width: 28, height: 28, borderRadius: 8, background: 'linear-gradient(135deg, var(--solar), var(--wind))', display: 'grid', placeItems: 'center' }}>
            <Icon name="layers" size={14} color="white"/>
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ font: '700 14px/1 var(--font)', color: 'var(--text)', letterSpacing: '-.01em' }}>Kütüphane</div>
          </div>
          {onClose && <button className="btn btn-icon btn-ghost" onClick={onClose} style={{ padding: 4 }}><Icon name="x" size={14} color="var(--text-2)"/></button>}
        </div>
        {/* tabs */}
        <div className="seg" style={{ width: '100%' }}>
          <button onClick={() => onTab('senaryolar')} className={activeTab === 'senaryolar' ? 'on' : ''} style={{ flex: 1, color: activeTab === 'senaryolar' ? 'var(--text)' : undefined }}>
            <Icon name="cal" size={11} color={activeTab === 'senaryolar' ? 'var(--accent)' : 'var(--text-3)'}/> Senaryolar
          </button>
          <button onClick={() => onTab('pinlerim')} className={activeTab === 'pinlerim' ? 'on' : ''} style={{ flex: 1, color: activeTab === 'pinlerim' ? 'var(--text)' : undefined }}>
            <Icon name="pin" size={11} color={activeTab === 'pinlerim' ? 'var(--accent)' : 'var(--text-3)'}/> Pinlerim
          </button>
        </div>
      </div>

      {/* search */}
      <div style={{ padding: '10px 14px 8px', position: 'relative' }}>
        <input className="input" placeholder={activeTab === 'senaryolar' ? 'Senaryo ara…' : 'Pin ara…'} style={{ paddingLeft: 32, fontSize: 12.5, padding: '8px 10px 8px 32px' }}/>
        <div style={{ position: 'absolute', left: 25, top: '50%', transform: 'translateY(-50%)', display: 'flex', pointerEvents: 'none' }}>
          <Icon name="search" size={13} color="var(--text-3)"/>
        </div>
      </div>

      {/* body */}
      <div className="scroll" style={{ flex: 1, overflow: 'auto', padding: '4px 12px 12px' }}>
        {activeTab === 'senaryolar' && (
          <div>
            {SAMPLE_SCENARIOS.map((s, i) => (
              <div key={s.id} style={{
                padding: 12, borderRadius: 10, marginBottom: 6,
                background: i === 0 ? 'rgba(20,184,166,.08)' : 'rgba(0,0,0,.20)',
                border: i === 0 ? '1px solid rgba(20,184,166,.45)' : '1px solid var(--border-2)',
                cursor: 'pointer', position: 'relative', overflow: 'hidden'
              }}>
                {i === 0 && <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: 3, background: 'var(--accent)' }}/>}
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
                  <div style={{ width: 8, height: 8, borderRadius: '50%', background: s.color }}/>
                  <span style={{ font: '600 13px/1.2 var(--font)', color: 'var(--text)', flex: 1, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{s.name}</span>
                  {i === 0 && <span style={{ font: '500 9px/1 var(--font)', color: 'var(--accent)', textTransform: 'uppercase', letterSpacing: '.06em' }}>● Aktif</span>}
                </div>
                <div style={{ display: 'flex', gap: 12, font: '500 11px/1.2 var(--font)', color: 'var(--text-3)' }}>
                  <span><Icon name="pin" size={10} color="var(--text-3)"/> {s.pinCount} pin</span>
                  <span className="tnum">{s.totalMw} MW</span>
                  <span style={{ marginLeft: 'auto', color: 'var(--success)', fontWeight: 600 }} className="tnum">{s.npv}</span>
                </div>
              </div>
            ))}
            <button style={{ width: '100%', padding: '10px', background: 'transparent', border: '1px dashed var(--border)', borderRadius: 10, color: 'var(--text-3)', font: '500 12px/1 var(--font)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, marginTop: 4 }}>
              <Icon name="plus" size={12}/> Yeni senaryo oluştur
            </button>
          </div>
        )}
        {activeTab === 'pinlerim' && (
          <div>
            {Object.values(TYPES).map(t => {
              const pins = SAMPLE_PINS.filter(p => p.type === t.id);
              if (!pins.length) return null;
              return (
                <div key={t.id} style={{ marginBottom: 12 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 4px 6px' }}>
                    <div style={{ width: 3, height: 11, borderRadius: 2, background: t.color }}/>
                    <span style={{ font: '600 10.5px/1 var(--font)', color: 'var(--text-2)', textTransform: 'uppercase', letterSpacing: '.06em' }}>{t.label}</span>
                    <span style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)' }}>· {pins.length}</span>
                  </div>
                  {pins.map(p => {
                    const sel = p.id === selectedPinId;
                    return (
                      <div key={p.id} onClick={() => onSelectPin(p.id)} style={{
                        padding: '9px 10px', borderRadius: 9, marginBottom: 3,
                        background: sel ? `${t.color}15` : 'rgba(0,0,0,.18)',
                        border: sel ? `1px solid ${t.color}66` : '1px solid var(--border-2)',
                        display: 'flex', alignItems: 'center', gap: 9, cursor: 'pointer'
                      }}>
                        <div style={{ width: 24, height: 24, borderRadius: 7, background: `${t.color}22`, display: 'grid', placeItems: 'center' }}>
                          <TypeIcon type={t.id} size={11} color={t.color}/>
                        </div>
                        <div style={{ flex: 1, minWidth: 0 }}>
                          <div style={{ font: '600 12px/1.2 var(--font)', color: 'var(--text)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{p.name}</div>
                          <div style={{ font: '500 10px/1.2 var(--font)', color: 'var(--text-3)', marginTop: 2 }} className="tnum">{p.district} · {p.capacityMw} MW</div>
                        </div>
                        <Sparkline data={p.monthly} color={t.color} width={26} height={12}/>
                      </div>
                    );
                  })}
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* footer */}
      <div style={{ padding: 10, borderTop: '1px solid var(--border-2)' }}>
        <button className="btn btn-primary" style={{ width: '100%', justifyContent: 'center' }} onClick={onAdd}>
          <Icon name="plus" size={13} color="#06201E"/> Yeni Kaynak Ekle
        </button>
      </div>
    </div>
  );
};

// ===== Production summary (top-left widget on map) =====
const ProductionSummary = ({ compact = false }) => (
  <div style={{
    background: 'rgba(28,32,44,.92)', backdropFilter: 'blur(14px)',
    border: '1px solid var(--border)', borderRadius: 12, padding: compact ? 10 : 12,
    boxShadow: '0 8px 24px rgba(0,0,0,.35)', minWidth: compact ? 180 : 240
  }}>
    <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 8 }}>
      <Icon name="spark" size={11} color="var(--accent)"/>
      <span style={{ font: '600 10.5px/1 var(--font)', color: 'var(--text-2)', textTransform: 'uppercase', letterSpacing: '.06em' }}>Aktif Senaryo</span>
    </div>
    <div style={{ font: '700 13px/1.2 var(--font)', color: 'var(--text)', marginBottom: 8 }}>Türkiye 2030 Yenilenebilir</div>
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
      {[
        ['Toplam', '285', 'MW', 'var(--accent)'],
        ['Üretim', '742', 'GWh', 'var(--text)'],
        ['Pin', '14', '', 'var(--text)'],
      ].map(([l, v, u, col]) => (
        <div key={l}>
          <div style={{ font: '500 9px/1 var(--font)', color: 'var(--text-3)', textTransform: 'uppercase' }}>{l}</div>
          <div style={{ font: '700 14px/1 var(--font)', color: col, marginTop: 4 }} className="tnum">{v}<span style={{ fontSize: 9, color: 'var(--text-3)', fontWeight: 500, marginLeft: 2 }}>{u}</span></div>
        </div>
      ))}
    </div>
  </div>
);

// ===== marker mode toggle =====
const MarkerModeToggle = ({ mode, onChange, compact = false }) => (
  <div className="seg" style={{ background: 'rgba(28,32,44,.92)', backdropFilter: 'blur(14px)' }}>
    <button onClick={() => onChange('ops')} className={mode === 'ops' ? 'on' : ''} style={{ color: mode === 'ops' ? 'var(--text)' : undefined, padding: compact ? '6px 9px' : undefined }}>
      <Icon name="eq" size={11} color={mode === 'ops' ? 'var(--accent)' : 'var(--text-3)'}/>{!compact && ' Operasyon'}
    </button>
    <button onClick={() => onChange('trend')} className={mode === 'trend' ? 'on' : ''} style={{ color: mode === 'trend' ? 'var(--text)' : undefined, padding: compact ? '6px 9px' : undefined }}>
      <Icon name="roi" size={11} color={mode === 'trend' ? 'var(--accent)' : 'var(--text-3)'}/>{!compact && ' Trend'}
    </button>
  </div>
);

// ===== Pin positions on map =====
const pinPos = (id) => ({
  1: { x: 0.50, y: 0.69 }, 2: { x: 0.30, y: 0.40 },
  3: { x: 0.86, y: 0.36 }, 4: { x: 0.45, y: 0.82 },
  5: { x: 0.18, y: 0.55 },
}[id] || { x: 0.5, y: 0.5 });

// ===== Map area (shared across devices) =====
const MapArea = ({ state, scale = 1, showCluster = false }) => {
  const { selectedPinId, setSelectedPinId, addFlowStage, setAddFlowStage, addFlowCoords, markerMode, setMarkerMode, suitOn, suitType, suitThreshold, suitLayers, suitZoom, restrictedHover, setRestrictedHover } = state;
  // dim pins when suitability mode is heavily active
  const pinOpacity = suitOn ? 0.85 : 1;
  return (
    <div style={{ position: 'absolute', inset: 0 }}>
      <MapBackdrop/>
      {/* Suitability overlay (under pins, over backdrop) */}
      {suitOn && (
        <SuitabilityOverlay
          activeType={suitType}
          threshold={suitThreshold}
          showRestricted={suitLayers.restricted}
          showSuitable={suitLayers.suitable}
          showChoropleth={suitLayers.choropleth}
          zoom={suitZoom}
        />
      )}
      {/* invisible click catchers for restricted zones (so tooltip works) */}
      {suitOn && suitLayers.restricted && (
        <svg viewBox="0 0 1000 600" preserveAspectRatio="xMidYMid slice" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', pointerEvents: 'none' }}>
          {RESTRICTED_ZONES.filter(z => z.forTypes.includes(suitType)).map(z => (
            <path key={z.id} d={z.d} fill="transparent" style={{ pointerEvents: 'all', cursor: 'help' }}
                  onMouseEnter={(e) => {
                    const rect = e.currentTarget.ownerSVGElement.getBoundingClientRect();
                    const parent = e.currentTarget.ownerSVGElement.parentElement.getBoundingClientRect();
                    setRestrictedHover && setRestrictedHover({ zone: z, x: e.clientX - parent.left, y: e.clientY - parent.top });
                  }}
                  onMouseLeave={() => setRestrictedHover && setRestrictedHover(null)}/>
          ))}
        </svg>
      )}
      {/* pins */}
      {SAMPLE_PINS.map(pin => {
        const p = pinPos(pin.id);
        return (
          <div key={pin.id} style={{ position: 'absolute', left: `${p.x*100}%`, top: `${p.y*100}%`, transform: 'translate(-50%, -50%)', zIndex: pin.id === selectedPinId ? 20 : 10, opacity: pinOpacity }}>
            <UnifiedMarker pin={pin} mode={markerMode} selected={pin.id === selectedPinId} scale={scale} onClick={() => { setSelectedPinId(pin.id); setAddFlowStage(null); }}/>
          </div>
        );
      })}
      {/* cluster (mock) */}
      {showCluster && (
        <div style={{ position: 'absolute', left: '70%', top: '64%', transform: 'translate(-50%, -50%)' }}>
          <ClusterMarker counts={{ solar: 4, wind: 2, hydro: 1 }} total={7}/>
        </div>
      )}
      {/* restricted-zone tooltip */}
      {suitOn && restrictedHover && (
        <RestrictedTooltip zone={restrictedHover.zone} x={restrictedHover.x} y={restrictedHover.y} type={suitType}/>
      )}
      {/* add flow popover */}
      {addFlowStage === 'popover' && (
        <div style={{ position: 'absolute', left: `${addFlowCoords.x*100}%`, top: `${addFlowCoords.y*100}%`, zIndex: 50 }}>
          {/* ripple */}
          <div style={{ position: 'absolute', left: 0, top: 0, transform: 'translate(-50%, -50%)' }}>
            <div style={{ width: 8, height: 8, borderRadius: '50%', background: 'var(--accent)', boxShadow: '0 0 0 6px rgba(20,184,166,.25), 0 0 0 14px rgba(20,184,166,.10)' }}/>
          </div>
          <AddPopover state={state}/>
        </div>
      )}
    </div>
  );
};

// ===== Add popover =====
const AddPopover = ({ state }) => {
  const [type, setType] = useState(null);
  return (
    <div style={{
      position: 'absolute', left: 0, top: -16, transform: 'translate(-50%, -100%)',
      width: 260, background: 'rgba(28,32,44,.97)', backdropFilter: 'blur(20px)',
      border: '1px solid var(--border)', borderRadius: 14, padding: 12,
      boxShadow: '0 20px 50px rgba(0,0,0,.6)'
    }}>
      <div style={{ position: 'absolute', left: '50%', bottom: -6, transform: 'translateX(-50%) rotate(45deg)', width: 12, height: 12, background: 'rgba(28,32,44,.97)', borderRight: '1px solid var(--border)', borderBottom: '1px solid var(--border)' }}/>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 10 }}>
        <Icon name="pin" size={11} color="var(--text-3)"/>
        <span style={{ font: '500 11px/1 var(--font)', color: 'var(--text-2)' }}>Karapınar / Konya</span>
        <span style={{ marginLeft: 'auto', font: '500 9.5px/1 var(--font-mono)', color: 'var(--text-3)' }}>37.71°, 33.55°</span>
      </div>
      <div style={{ font: '600 12.5px/1.2 var(--font)', color: 'var(--text)', marginBottom: 10 }}>Burada ne kuracaksın?</div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 5 }}>
        {Object.values(TYPES).map(t => (
          <button key={t.id} onClick={() => state.setAddFlowStage('panel')} style={{
            background: 'rgba(0,0,0,.25)', border: '1px solid var(--border)', borderRadius: 9,
            padding: '10px 4px', cursor: 'pointer', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 5, color: 'var(--text)'
          }}>
            <TypeIcon type={t.id} size={18} color={t.color}/>
            <span style={{ font: '600 10.5px/1 var(--font)' }}>{t.shortLabel}</span>
          </button>
        ))}
      </div>
      <button onClick={() => state.setAddFlowStage('panel')} style={{ width: '100%', marginTop: 8, padding: '6px', background: 'transparent', border: 'none', color: 'var(--accent)', cursor: 'pointer', font: '600 10.5px/1 var(--font)' }}>
        Detaylı düzenle →
      </button>
    </div>
  );
};

// ===== Right-side Add panel (V4) =====
const AddSidePanel = ({ onClose, compact = false }) => {
  const c = TYPES.solar.color;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: 'var(--card)', borderLeft: '1px solid var(--border)' }}>
      <div style={{ padding: '16px 18px 12px', borderBottom: '1px solid var(--border-2)', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <div style={{ font: '600 15px/1 var(--font)', color: 'var(--text)', letterSpacing: '-.01em' }}>Yeni Kaynak</div>
          <div style={{ font: '500 11px/1.4 var(--font)', color: 'var(--text-3)', marginTop: 4 }}>Konya · Karapınar</div>
        </div>
        <button onClick={onClose} className="btn btn-icon btn-ghost"><Icon name="x" size={14} color="var(--text-2)"/></button>
      </div>
      {/* suitability */}
      <div style={{ margin: 12, padding: 10, background: 'rgba(16,185,129,.08)', border: '1px solid rgba(16,185,129,.3)', borderRadius: 10, display: 'flex', alignItems: 'center', gap: 8 }}>
        <Icon name="check2" size={14} color="var(--success)"/>
        <div style={{ flex: 1 }}>
          <div style={{ font: '600 12px/1 var(--font)', color: 'var(--success)' }}>Kurulum için uygun</div>
          <div style={{ font: '500 10.5px/1.3 var(--font)', color: 'var(--text-2)', marginTop: 3 }}>5.4 kWh/m² · Eğim &lt; 8°</div>
        </div>
      </div>
      {/* type tabs */}
      <div style={{ padding: '0 12px' }}>
        <div className="seg" style={{ width: '100%' }}>
          {Object.values(TYPES).map((t, i) => (
            <button key={t.id} className={i === 0 ? 'on' : ''} style={{ flex: 1, color: i === 0 ? t.color : undefined }}>
              <TypeIcon type={t.id} size={11} color={i === 0 ? t.color : 'var(--text-3)'}/> {t.shortLabel}
            </button>
          ))}
        </div>
      </div>
      <div className="scroll" style={{ flex: 1, overflow: 'auto', padding: 12, display: 'flex', flexDirection: 'column', gap: 10 }}>
        <div>
          <div className="label" style={{ marginBottom: 5 }}>Ad</div>
          <input className="input" defaultValue="Konya Karapınar GES-2" style={{ padding: '8px 10px', fontSize: 12.5 }}/>
        </div>
        <div>
          <div className="label" style={{ marginBottom: 5 }}>Kurulu güç</div>
          <div style={{ position: 'relative' }}>
            <input className="input" defaultValue="15.0" style={{ padding: '8px 36px 8px 10px', fontSize: 12.5 }}/>
            <span style={{ position: 'absolute', right: 10, top: '50%', transform: 'translateY(-50%)', font: '600 11px/1 var(--font)', color: 'var(--text-3)' }}>MW</span>
          </div>
          <div style={{ marginTop: 8, position: 'relative', height: 4, background: 'rgba(255,255,255,.06)', borderRadius: 2 }}>
            <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: '30%', background: c, borderRadius: 2 }}/>
            <div style={{ position: 'absolute', left: '30%', top: '50%', transform: 'translate(-50%, -50%)', width: 12, height: 12, borderRadius: '50%', background: 'white', boxShadow: '0 1px 3px rgba(0,0,0,.4)' }}/>
          </div>
        </div>
        <div>
          <div className="label" style={{ marginBottom: 5 }}>Panel modeli</div>
          <select className="input" style={{ padding: '8px 10px', fontSize: 12.5 }}>
            <option>Trina Vertex 660W</option>
          </select>
        </div>
        <div>
          <div className="label" style={{ marginBottom: 5 }}>Senaryo</div>
          <select className="input" style={{ padding: '8px 10px', fontSize: 12.5 }}>
            <option>Türkiye 2030 Yenilenebilir</option>
          </select>
        </div>
        <div style={{ marginTop: 4, padding: 12, background: 'rgba(0,0,0,.30)', border: '1px solid var(--border-2)', borderRadius: 10 }}>
          <div className="label" style={{ marginBottom: 8 }}>Anlık tahmin</div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
            <div>
              <div style={{ font: '500 9.5px/1 var(--font)', color: 'var(--text-3)', textTransform: 'uppercase' }}>Yıllık</div>
              <div style={{ font: '700 16px/1 var(--font)', color: c, marginTop: 4 }} className="tnum">26.8 <span style={{ fontSize: 10, color: 'var(--text-3)', fontWeight: 500 }}>GWh</span></div>
            </div>
            <div>
              <div style={{ font: '500 9.5px/1 var(--font)', color: 'var(--text-3)', textTransform: 'uppercase' }}>NPV</div>
              <div style={{ font: '700 16px/1 var(--font)', color: 'var(--success)', marginTop: 4 }} className="tnum">$5.2M</div>
            </div>
          </div>
        </div>
      </div>
      <div style={{ padding: 12, borderTop: '1px solid var(--border-2)', display: 'flex', gap: 8 }}>
        <button onClick={onClose} className="btn" style={{ flex: 1 }}>İptal</button>
        <button className="btn btn-primary" style={{ flex: 2 }}><Icon name="check" size={13} color="#06201E"/> Kaynağı Ekle</button>
      </div>
    </div>
  );
};

// ===== Pin detail panel (right-side, desktop/tablet) =====
const PinDetailPanel = ({ pin, onClose, compact = false }) => {
  const c = TYPES[pin.type].color;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: 'var(--card)', borderLeft: '1px solid var(--border)' }}>
      <div style={{ padding: '16px 18px 14px', background: `linear-gradient(180deg, ${c}1A, transparent)`, borderBottom: '1px solid var(--border-2)' }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 10 }}>
          <div style={{ width: 38, height: 38, borderRadius: 10, background: `${c}22`, border: `1px solid ${c}55`, display: 'grid', placeItems: 'center' }}>
            <TypeIcon type={pin.type} size={18} color={c}/>
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ font: '500 10.5px/1 var(--font)', color: c, textTransform: 'uppercase', letterSpacing: '.06em' }}>{TYPES[pin.type].label}</div>
            <div style={{ font: '700 16px/1.2 var(--font)', color: 'var(--text)', marginTop: 4, letterSpacing: '-.01em' }}>{pin.name}</div>
            <div style={{ font: '500 11px/1.3 var(--font)', color: 'var(--text-3)', marginTop: 3 }}>{pin.district} / {pin.city}</div>
          </div>
          <button onClick={onClose} className="btn btn-icon btn-ghost"><Icon name="x" size={14} color="var(--text-2)"/></button>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 10, marginTop: 14 }}>
          <div><div className="kpi-label">Kapasite</div><div style={{ marginTop: 5 }}><span className="tnum" style={{ font: '700 18px/1 var(--font)', color: c }}>{pin.capacityMw}</span><span className="kpi-unit">MW</span></div></div>
          <div><div className="kpi-label">Yıllık</div><div style={{ marginTop: 5 }}><span className="tnum" style={{ font: '700 18px/1 var(--font)' }}>{(pin.annualKwh/1e6).toFixed(0)}</span><span className="kpi-unit">GWh</span></div></div>
          <div><div className="kpi-label">ROI</div><div style={{ marginTop: 5 }}><span className="tnum" style={{ font: '700 18px/1 var(--font)' }}>{pin.roi.toFixed(1)}</span><span className="kpi-unit">yıl</span></div></div>
        </div>
      </div>
      <div className="scroll" style={{ flex: 1, overflow: 'auto', padding: 14, display: 'flex', flexDirection: 'column', gap: 12 }}>
        <div className="card" style={{ padding: 12, borderRadius: 10 }}>
          <div className="label" style={{ marginBottom: 8 }}>Aylık üretim · 2025</div>
          <MonthlyBars data={pin.monthly} color={c} height={56}/>
        </div>
        <div className="card" style={{ padding: 12, borderRadius: 10 }}>
          <div className="label" style={{ marginBottom: 8 }}>Finansal</div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
            <div style={{ padding: 8, background: 'rgba(0,0,0,.20)', borderRadius: 7 }}>
              <div style={{ font: '500 9.5px/1 var(--font)', color: 'var(--text-3)', textTransform: 'uppercase' }}>NPV (25y)</div>
              <div style={{ font: '700 14px/1.1 var(--font)', color: 'var(--success)', marginTop: 4 }} className="tnum">$5.2M</div>
            </div>
            <div style={{ padding: 8, background: 'rgba(0,0,0,.20)', borderRadius: 7 }}>
              <div style={{ font: '500 9.5px/1 var(--font)', color: 'var(--text-3)', textTransform: 'uppercase' }}>IRR</div>
              <div style={{ font: '700 14px/1.1 var(--font)', marginTop: 4 }} className="tnum">14.2%</div>
            </div>
            <div style={{ padding: 8, background: 'rgba(0,0,0,.20)', borderRadius: 7 }}>
              <div style={{ font: '500 9.5px/1 var(--font)', color: 'var(--text-3)', textTransform: 'uppercase' }}>LCOE</div>
              <div style={{ font: '700 14px/1.1 var(--font)', marginTop: 4 }} className="tnum">$0.041</div>
            </div>
            <div style={{ padding: 8, background: 'rgba(0,0,0,.20)', borderRadius: 7 }}>
              <div style={{ font: '500 9.5px/1 var(--font)', color: 'var(--text-3)', textTransform: 'uppercase' }}>Yatırım</div>
              <div style={{ font: '700 14px/1.1 var(--font)', marginTop: 4 }} className="tnum">$11.6M</div>
            </div>
          </div>
        </div>
        <div className="card" style={{ padding: 12, borderRadius: 10 }}>
          <div className="label" style={{ marginBottom: 8 }}>Konfigürasyon</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            {[['Ekipman', pin.equipment], ['Eğim', '32°'], ['Senaryo', 'Türkiye 2030']].map(([k, v]) => (
              <div key={k} style={{ display: 'flex', justifyContent: 'space-between', font: '500 12px/1.4 var(--font)' }}>
                <span style={{ color: 'var(--text-3)' }}>{k}</span>
                <span style={{ color: 'var(--text)' }}>{v}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
      <div style={{ padding: 12, borderTop: '1px solid var(--border-2)', display: 'flex', gap: 6 }}>
        <button className="btn" style={{ flex: 1 }}><Icon name="edit" size={13}/> Düzenle</button>
        <button className="btn"><Icon name="trash" size={13} color="var(--danger)"/></button>
        <button className="btn btn-primary" style={{ flex: 1 }}><Icon name="ext" size={13} color="#06201E"/> Rapor</button>
      </div>
    </div>
  );
};

// ===== Bottom sheet (mobile) — for any panel content =====
const BottomSheet = ({ children, onClose, height = '70%' }) => (
  <>
    <div onClick={onClose} style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,.55)', backdropFilter: 'blur(2px)', zIndex: 40 }}/>
    <div style={{
      position: 'absolute', left: 0, right: 0, bottom: 0, height,
      background: 'var(--card)', borderTopLeftRadius: 20, borderTopRightRadius: 20,
      boxShadow: '0 -20px 50px rgba(0,0,0,.5)', zIndex: 50,
      display: 'flex', flexDirection: 'column'
    }}>
      <div style={{ display: 'flex', justifyContent: 'center', padding: '8px 0 4px' }}>
        <div style={{ width: 36, height: 4, borderRadius: 2, background: 'rgba(255,255,255,.18)' }}/>
      </div>
      <div style={{ flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>{children}</div>
    </div>
  </>
);

// ============================================================================
// DESKTOP frame (1280x800 in canvas, browser-style)
// ============================================================================
const DesktopApp = (props) => {
  const state = useAppState(props && props.initial);
  const selectedPin = SAMPLE_PINS.find(p => p.id === state.selectedPinId);
  const showRight = selectedPin || state.addFlowStage === 'panel';

  return (
    <div style={{ width: 1280, height: 800, background: '#0B0E14', display: 'flex', borderRadius: 12, overflow: 'hidden', border: '1px solid var(--border)', position: 'relative' }}>
      {/* nav rail */}
      <div style={{ width: 56, background: 'var(--bg-2)', borderRight: '1px solid var(--border)', display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '14px 0', gap: 6 }}>
        <div style={{ width: 32, height: 32, borderRadius: 9, background: 'linear-gradient(135deg, var(--solar), var(--wind))', display: 'grid', placeItems: 'center', marginBottom: 8 }}>
          <Icon name="globe" size={16} color="white"/>
        </div>
        {[
          { i: 'globe', on: true, lbl: 'Harita' },
          { i: 'list', lbl: 'Liste' },
          { i: 'roi', lbl: 'Raporlar' },
          { i: 'finance', lbl: 'Finans' },
        ].map((it, i) => (
          <button key={i} className="btn btn-icon btn-ghost" style={{ width: 40, height: 40, padding: 0, background: it.on ? 'rgba(20,184,166,.1)' : 'transparent', border: it.on ? '1px solid rgba(20,184,166,.4)' : '1px solid transparent' }}>
            <Icon name={it.i} size={17} color={it.on ? 'var(--accent)' : 'var(--text-3)'}/>
          </button>
        ))}
        <div style={{ flex: 1 }}/>
        <button className="btn btn-icon btn-ghost" style={{ width: 40, height: 40, padding: 0 }}><Icon name="gear" size={16} color="var(--text-3)"/></button>
      </div>

      {/* unified left panel */}
      {state.leftPanel && (
        <div style={{ width: 320, flexShrink: 0 }}>
          <UnifiedLeftPanel
            activeTab={state.leftPanel}
            onTab={state.setLeftPanel}
            onClose={() => state.setLeftPanel(null)}
            selectedPinId={state.selectedPinId}
            onSelectPin={state.setSelectedPinId}
            onAdd={() => { state.setAddFlowStage('popover'); state.setAddFlowCoords({ x: 0.5, y: 0.5 }); }}
          />
        </div>
      )}

      {/* map area */}
      <div style={{ flex: 1, position: 'relative' }}>
        <MapArea state={state}/>
        {/* top-left widgets */}
        <div style={{ position: 'absolute', left: 14, top: 14, display: 'flex', gap: 10, zIndex: 5 }}>
          {!state.leftPanel && (
            <button onClick={() => state.setLeftPanel('senaryolar')} className="btn" style={{ background: 'rgba(28,32,44,.92)', backdropFilter: 'blur(14px)' }}>
              <Icon name="layers" size={14} color="var(--text)"/> Kütüphane
            </button>
          )}
          <ProductionSummary/>
        </div>
        {/* top-right tools */}
        <div style={{ position: 'absolute', right: 14, top: 14, display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 8, zIndex: 5 }}>
          <div style={{ display: 'flex', gap: 8 }}>
            <MarkerModeToggle mode={state.markerMode} onChange={state.setMarkerMode}/>
            <button onClick={() => state.setSuitOn(!state.suitOn)} className="btn" style={{
              background: state.suitOn ? 'rgba(20,184,166,.18)' : 'rgba(28,32,44,.92)',
              backdropFilter: 'blur(14px)',
              borderColor: state.suitOn ? 'rgba(20,184,166,.55)' : undefined,
              color: state.suitOn ? 'var(--accent)' : undefined
            }}>
              <Icon name="layers" size={13} color={state.suitOn ? 'var(--accent)' : 'var(--text-2)'}/>
              Kurulabilir Alanlar
            </button>
            <button className="btn btn-icon" style={{ background: 'rgba(28,32,44,.92)', backdropFilter: 'blur(14px)' }}><Icon name="filter" size={14} color="var(--text-2)"/></button>
          </div>
          {state.suitOn && (
            <SuitabilityControls
              activeType={state.suitType}
              onTypeChange={state.setSuitType}
              threshold={state.suitThreshold}
              onThreshold={state.setSuitThreshold}
              layers={state.suitLayers}
              onLayer={(k, v) => state.setSuitLayers({ ...state.suitLayers, [k]: v })}
              timeSimOn={state.timeSimOn}
              onTimeSim={state.setTimeSimOn}
              onClose={() => state.setSuitOn(false)}
            />
          )}
        </div>
        {/* zoom level indicator (bottom-left, when suit on) */}
        {state.suitOn && (
          <div style={{ position: 'absolute', left: 14, bottom: 56, zIndex: 5, background: 'rgba(20,24,34,.92)', backdropFilter: 'blur(14px)', border: '1px solid var(--border)', borderRadius: 10, padding: 4, display: 'flex', gap: 2 }}>
            {[
              { id: 'province', label: 'İl', icon: 'globe' },
              { id: 'district', label: 'İlçe', icon: 'grid' },
              { id: 'polygon', label: 'Polygon', icon: 'panel' },
            ].map(z => (
              <button key={z.id} onClick={() => state.setSuitZoom(z.id)} style={{
                background: state.suitZoom === z.id ? 'rgba(20,184,166,.18)' : 'transparent',
                border: state.suitZoom === z.id ? '1px solid rgba(20,184,166,.45)' : '1px solid transparent',
                borderRadius: 7, padding: '5px 9px', cursor: 'pointer',
                font: '600 10.5px/1 var(--font)', color: state.suitZoom === z.id ? 'var(--accent)' : 'var(--text-3)',
                display: 'flex', alignItems: 'center', gap: 5
              }}>
                <Icon name={z.icon} size={10} color={state.suitZoom === z.id ? 'var(--accent)' : 'var(--text-3)'}/>{z.label}
              </button>
            ))}
          </div>
        )}
        {/* bottom-right zoom */}
        <div style={{ position: 'absolute', right: 14, bottom: 14, display: 'flex', flexDirection: 'column', background: 'rgba(28,32,44,.92)', backdropFilter: 'blur(14px)', border: '1px solid var(--border)', borderRadius: 10, overflow: 'hidden', zIndex: 5 }}>
          <button className="btn-icon" style={{ background: 'transparent', border: 'none', padding: '8px 10px', borderBottom: '1px solid var(--border-2)', cursor: 'pointer', color: 'var(--text-2)' }}><Icon name="plus" size={13}/></button>
          <button className="btn-icon" style={{ background: 'transparent', border: 'none', padding: '8px 10px', cursor: 'pointer', color: 'var(--text-2)' }}>−</button>
        </div>
        {/* MAP TIME SIM — floating bottom-right, NOT full-width */}
        {state.timeSimOn && (
          <div style={{ position: 'absolute', right: 14, bottom: 14, zIndex: 12 }}>
            <MapTimeSim pins={SAMPLE_PINS} variant="desktop" onClose={() => state.setTimeSimOn(false)}/>
          </div>
        )}
        {/* legend */}
        <div style={{ position: 'absolute', left: 14, bottom: 14, display: 'flex', gap: 8, padding: '6px 12px', background: 'rgba(28,32,44,.92)', backdropFilter: 'blur(14px)', border: '1px solid var(--border)', borderRadius: 999, zIndex: 5 }}>
          {Object.values(TYPES).map(t => (
            <div key={t.id} style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
              <div style={{ width: 8, height: 8, borderRadius: '50%', background: t.color }}/>
              <span style={{ font: '500 10.5px/1 var(--font)', color: 'var(--text-2)' }}>{t.shortLabel}</span>
            </div>
          ))}
        </div>
      </div>

      {/* right side panel — pin detail OR add flow */}
      {showRight && (
        <div style={{ width: 360, flexShrink: 0 }}>
          {state.addFlowStage === 'panel' ? (
            <AddSidePanel onClose={() => state.setAddFlowStage(null)}/>
          ) : selectedPin ? (
            <PinDetailPanel pin={selectedPin} onClose={() => state.setSelectedPinId(null)}/>
          ) : null}
        </div>
      )}
    </div>
  );
};

// ============================================================================
// TABLET frame (820x1180 portrait — iPad)
// ============================================================================
const TabletApp = (props) => {
  const state = useAppState(props && props.initial);
  const selectedPin = SAMPLE_PINS.find(p => p.id === state.selectedPinId);

  return (
    <div style={{ width: 820, height: 1180, background: '#0B0E14', display: 'flex', borderRadius: 16, overflow: 'hidden', border: '1px solid var(--border)', position: 'relative' }}>
      {/* compact rail */}
      <div style={{ width: 56, background: 'var(--bg-2)', borderRight: '1px solid var(--border)', display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '14px 0', gap: 6 }}>
        <div style={{ width: 32, height: 32, borderRadius: 9, background: 'linear-gradient(135deg, var(--solar), var(--wind))', display: 'grid', placeItems: 'center', marginBottom: 8 }}>
          <Icon name="globe" size={16} color="white"/>
        </div>
        {['globe','list','roi','finance'].map((i, idx) => (
          <button key={i} className="btn btn-icon btn-ghost" style={{ width: 40, height: 40, padding: 0, background: idx === 0 ? 'rgba(20,184,166,.1)' : 'transparent', border: idx === 0 ? '1px solid rgba(20,184,166,.4)' : '1px solid transparent' }}>
            <Icon name={i} size={17} color={idx === 0 ? 'var(--accent)' : 'var(--text-3)'}/>
          </button>
        ))}
      </div>
      {/* unified left panel */}
      {state.leftPanel && (
        <div style={{ width: 290, flexShrink: 0 }}>
          <UnifiedLeftPanel
            activeTab={state.leftPanel}
            onTab={state.setLeftPanel}
            onClose={() => state.setLeftPanel(null)}
            selectedPinId={state.selectedPinId}
            onSelectPin={state.setSelectedPinId}
            onAdd={() => state.setAddFlowStage('popover')}
            compact
          />
        </div>
      )}
      {/* map */}
      <div style={{ flex: 1, position: 'relative' }}>
        <MapArea state={state} showCluster/>
        <div style={{ position: 'absolute', left: 12, top: 12, display: 'flex', gap: 8, zIndex: 5 }}>
          {!state.leftPanel && (
            <button onClick={() => state.setLeftPanel('senaryolar')} className="btn" style={{ background: 'rgba(28,32,44,.92)', backdropFilter: 'blur(14px)' }}>
              <Icon name="layers" size={14}/> Kütüphane
            </button>
          )}
          <ProductionSummary compact/>
        </div>
        <div style={{ position: 'absolute', right: 12, top: 12, display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 8, zIndex: 5 }}>
          <div style={{ display: 'flex', gap: 6 }}>
            <MarkerModeToggle mode={state.markerMode} onChange={state.setMarkerMode} compact/>
            <button onClick={() => state.setSuitOn(!state.suitOn)} className="btn" style={{
              background: state.suitOn ? 'rgba(20,184,166,.18)' : 'rgba(28,32,44,.92)',
              backdropFilter: 'blur(14px)',
              borderColor: state.suitOn ? 'rgba(20,184,166,.55)' : undefined,
              color: state.suitOn ? 'var(--accent)' : undefined,
              padding: '6px 9px'
            }}>
              <Icon name="layers" size={12} color={state.suitOn ? 'var(--accent)' : 'var(--text-2)'}/>
            </button>
          </div>
          {state.suitOn && (
            <SuitabilityControls
              activeType={state.suitType}
              onTypeChange={state.setSuitType}
              threshold={state.suitThreshold}
              onThreshold={state.setSuitThreshold}
              layers={state.suitLayers}
              onLayer={(k, v) => state.setSuitLayers({ ...state.suitLayers, [k]: v })}
              timeSimOn={state.timeSimOn}
              onTimeSim={state.setTimeSimOn}
              onClose={() => state.setSuitOn(false)}
              compact
            />
          )}
        </div>
      </div>
      {/* MAP TIME SIM — tablet: floating right-side, NOT full-width */}
      {state.timeSimOn && (
        <div style={{ position: 'absolute', right: 12, bottom: 12, zIndex: 12 }}>
          <MapTimeSim pins={SAMPLE_PINS} variant="tablet" onClose={() => state.setTimeSimOn(false)}/>
        </div>
      )}
      {selectedPin && (
        <BottomSheet onClose={() => state.setSelectedPinId(null)} height="60%">
          <PinDetailPanel pin={selectedPin} onClose={() => state.setSelectedPinId(null)} compact/>
        </BottomSheet>
      )}
      {state.addFlowStage === 'panel' && (
        <BottomSheet onClose={() => state.setAddFlowStage(null)} height="80%">
          <AddSidePanel onClose={() => state.setAddFlowStage(null)} compact/>
        </BottomSheet>
      )}
    </div>
  );
};

// ============================================================================
// MOBILE frame (390x844 — iPhone in iOS bezel)
// ============================================================================
const MobileApp = (props) => {
  const state = useAppState(props && props.initial);
  const selectedPin = SAMPLE_PINS.find(p => p.id === state.selectedPinId);
  return (
    <div style={{ width: 390, height: 844, background: '#0B0E14', position: 'relative', overflow: 'hidden' }}>
      {/* status bar spacer */}
      <div style={{ height: 47, background: 'transparent' }}/>
      {/* top app bar */}
      <div style={{ position: 'absolute', left: 0, right: 0, top: 47, padding: '10px 14px', display: 'flex', alignItems: 'center', gap: 8, zIndex: 30, background: 'linear-gradient(180deg, rgba(11,14,20,.85) 0%, rgba(11,14,20,0) 100%)' }}>
        <button onClick={() => state.setLeftPanel('senaryolar')} className="btn btn-icon" style={{ background: 'rgba(28,32,44,.92)', backdropFilter: 'blur(14px)' }}>
          <Icon name="layers" size={15} color="var(--text)"/>
        </button>
        <ProductionSummary compact/>
        <div style={{ flex: 1 }}/>
        <MarkerModeToggle mode={state.markerMode} onChange={state.setMarkerMode} compact/>
      </div>
      {/* mobile suitability legend strip (above tab bar) */}
      {state.suitOn && (
        <div style={{ position: 'absolute', left: 14, right: 14, bottom: 100, zIndex: 25 }}>
          <MobileLegend activeType={state.suitType} threshold={state.suitThreshold} onOpen={() => state.setLeftPanel('suitability')}/>
        </div>
      )}
      {/* suitability toggle in app bar replaces the marker mode on mobile when suit is on */}
      <div style={{ position: 'absolute', right: 14, top: 102, zIndex: 28 }}>
        <button onClick={() => state.setSuitOn(!state.suitOn)} style={{
          width: 40, height: 40, borderRadius: 10,
          background: state.suitOn ? 'rgba(20,184,166,.22)' : 'rgba(28,32,44,.92)',
          backdropFilter: 'blur(14px)',
          border: state.suitOn ? '1px solid rgba(20,184,166,.55)' : '1px solid var(--border)',
          display: 'grid', placeItems: 'center', cursor: 'pointer'
        }}>
          <Icon name="layers" size={16} color={state.suitOn ? 'var(--accent)' : 'var(--text-2)'}/>
        </button>
      </div>
      {/* map */}
      <div style={{ position: 'absolute', left: 0, right: 0, top: 47, bottom: 0 }}>
        <MapArea state={state} scale={0.85} showCluster/>
      </div>
      {/* FAB for add */}
      <button onClick={() => { state.setAddFlowStage('popover'); state.setAddFlowCoords({ x: 0.5, y: 0.45 }); }} style={{
        position: 'absolute', right: 16, bottom: 100, zIndex: 25,
        width: 56, height: 56, borderRadius: 16, border: 'none',
        background: 'linear-gradient(180deg, #2DD4BF, #0EA5A4)',
        color: '#06201E', boxShadow: '0 12px 24px rgba(20,184,166,.4)',
        display: 'grid', placeItems: 'center', cursor: 'pointer'
      }}>
        <Icon name="plus" size={22} color="#06201E" strokeWidth={2.4}/>
      </button>
      {/* MAP TIME SIM — mobile: persistent mini bar (taps-to-expand) above tab bar */}
      {state.timeSimOn && (
        <div style={{ position: 'absolute', left: 10, right: 10, bottom: 86, zIndex: 26 }}>
          <MapTimeSim pins={SAMPLE_PINS} variant="mobile" onClose={() => state.setTimeSimOn(false)}/>
        </div>
      )}
      {/* bottom tab bar */}
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: 84, background: 'rgba(20,24,34,.92)', backdropFilter: 'blur(20px)', borderTop: '1px solid var(--border)', display: 'flex', paddingBottom: 24, zIndex: 20 }}>
        {[
          { i: 'globe', l: 'Harita', on: true },
          { i: 'list', l: 'Liste' },
          { i: 'roi', l: 'Rapor' },
          { i: 'gear', l: 'Ayarlar' },
        ].map(t => (
          <button key={t.i} style={{ flex: 1, background: 'transparent', border: 'none', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, padding: '10px 0', cursor: 'pointer' }}>
            <Icon name={t.i} size={20} color={t.on ? 'var(--accent)' : 'var(--text-3)'}/>
            <span style={{ font: '600 10px/1 var(--font)', color: t.on ? 'var(--accent)' : 'var(--text-3)' }}>{t.l}</span>
          </button>
        ))}
      </div>

      {/* mobile suitability bottom sheet */}
      {state.leftPanel === 'suitability' && (
        <BottomSheet onClose={() => state.setLeftPanel(null)} height="60%">
          <div style={{ padding: 16 }}>
            <SuitabilityControls
              activeType={state.suitType}
              onTypeChange={state.setSuitType}
              threshold={state.suitThreshold}
              onThreshold={state.setSuitThreshold}
              layers={state.suitLayers}
              onLayer={(k, v) => state.setSuitLayers({ ...state.suitLayers, [k]: v })}
              timeSimOn={state.timeSimOn}
              onTimeSim={state.setTimeSimOn}
              compact
            />
          </div>
        </BottomSheet>
      )}
      {/* unified panel as bottom sheet */}
      {(state.leftPanel === 'senaryolar' || state.leftPanel === 'pinlerim') && (
        <BottomSheet onClose={() => state.setLeftPanel(null)} height="78%">
          <UnifiedLeftPanel
            activeTab={state.leftPanel}
            onTab={state.setLeftPanel}
            onClose={() => state.setLeftPanel(null)}
            selectedPinId={state.selectedPinId}
            onSelectPin={(id) => { state.setSelectedPinId(id); state.setLeftPanel(null); }}
            onAdd={() => { state.setLeftPanel(null); state.setAddFlowStage('popover'); state.setAddFlowCoords({ x: 0.5, y: 0.45 }); }}
            compact
          />
        </BottomSheet>
      )}
      {/* pin detail bottom sheet */}
      {selectedPin && (
        <BottomSheet onClose={() => state.setSelectedPinId(null)} height="72%">
          <PinDetailPanel pin={selectedPin} onClose={() => state.setSelectedPinId(null)} compact/>
        </BottomSheet>
      )}
      {state.addFlowStage === 'panel' && (
        <BottomSheet onClose={() => state.setAddFlowStage(null)} height="86%">
          <AddSidePanel onClose={() => state.setAddFlowStage(null)} compact/>
        </BottomSheet>
      )}
    </div>
  );
};

// Pre-configured variants with map time simulation overlay open
const DesktopAppWithTimeSim = () => <DesktopApp initial={{ suitOn: true, timeSimOn: true, leftPanel: null }}/>;
const TabletAppWithTimeSim   = () => <TabletApp initial={{ suitOn: true, timeSimOn: true, leftPanel: null }}/>;
const MobileAppWithTimeSim   = () => <MobileApp initial={{ suitOn: true, timeSimOn: true, leftPanel: null }}/>;

Object.assign(window, { DesktopApp, TabletApp, MobileApp, MonthlyBars, DesktopAppWithTimeSim, TabletAppWithTimeSim, MobileAppWithTimeSim });
