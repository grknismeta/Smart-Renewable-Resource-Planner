// Two creative direction explorations for SRRP

const { useState, useRef, useEffect } = React;

// ═════════════════════════════════════════════════════════════════════════════
// YÖN 1 — MISSION CONTROL
// Brutalist, terminal-inspired, neon accents on deep black
// Inspired by: Linear, Bloomberg Terminal, sci-fi flight HUDs
// ═════════════════════════════════════════════════════════════════════════════

const MissionControlScreen = () => {
  const [selected, setSelected] = useState(2);
  return (
    <div style={{
      width: 1440, height: 900,
      background: '#000',
      fontFamily: 'JetBrains Mono, ui-monospace, monospace',
      color: '#E5FAF1',
      position: 'relative',
      overflow: 'hidden',
    }}>
      {/* Scanline texture */}
      <div style={{
        position: 'absolute', inset: 0,
        background: 'repeating-linear-gradient(0deg, rgba(0,255,180,.03) 0, rgba(0,255,180,.03) 1px, transparent 1px, transparent 3px)',
        pointerEvents: 'none', zIndex: 1,
      }}/>
      {/* Top bar */}
      <div style={{
        height: 44, padding: '0 20px',
        display: 'flex', alignItems: 'center', gap: 16,
        borderBottom: '1px solid rgba(0,255,180,.2)',
        background: 'linear-gradient(180deg, #0a0f0d 0%, #000 100%)',
        position: 'relative', zIndex: 2,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ width: 8, height: 8, borderRadius: '50%', background: '#00FFB4', boxShadow: '0 0 8px #00FFB4' }}/>
          <span style={{ font: '700 11px/1 inherit', letterSpacing: 2, color: '#00FFB4' }}>SRRP // MISSION CONTROL</span>
        </div>
        <span style={{ font: '500 10px/1 inherit', color: '#5FA88C', letterSpacing: 1 }}>v2.4.1 · UPLINK STABLE</span>
        <div style={{ flex: 1 }}/>
        {['OVERVIEW','ASSETS','SCENARIOS','FORECAST','SETTINGS'].map((t, i) => (
          <button key={t} style={{
            background: i === 1 ? 'rgba(0,255,180,.12)' : 'transparent',
            border: i === 1 ? '1px solid #00FFB4' : '1px solid transparent',
            color: i === 1 ? '#00FFB4' : '#5FA88C',
            font: '600 10px/1 inherit', letterSpacing: 1.5,
            padding: '6px 12px', cursor: 'pointer',
          }}>{t}</button>
        ))}
        <span style={{ font: '500 10px/1 inherit', color: '#5FA88C', letterSpacing: 1, marginLeft: 16 }}>14:32:08 UTC+3</span>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '280px 1fr 360px', height: 'calc(100% - 44px)', position: 'relative', zIndex: 2 }}>
        {/* Left rail — asset list */}
        <div style={{ borderRight: '1px solid rgba(0,255,180,.2)', padding: 14, overflow: 'auto' }}>
          <div style={{ font: '700 10px/1 inherit', letterSpacing: 2, color: '#5FA88C', marginBottom: 12 }}>:: ASSETS [{14}]</div>
          {[
            { id: 1, type: 'wind', name: 'BANDIRMA-7', cap: '32.4 MW', cf: 0.38, status: 'ACTIVE' },
            { id: 2, type: 'solar', name: 'KONYA-MERAM-12', cap: '18.5 MW', cf: 0.27, status: 'ACTIVE' },
            { id: 3, type: 'hydro', name: 'TRABZON-MAÇKA-3', cap: '12.0 MW', cf: 0.42, status: 'WARN' },
            { id: 4, type: 'wind', name: 'ÇEŞME-YEL-2', cap: '18.5 MW', cf: 0.31, status: 'ACTIVE' },
            { id: 5, type: 'solar', name: 'ANTALYA-KORK-1', cap: '6.8 MW', cf: 0.22, status: 'ACTIVE' },
            { id: 6, type: 'wind', name: 'BALIKESIR-N4', cap: '24.0 MW', cf: 0.34, status: 'ACTIVE' },
          ].map(a => {
            const c = a.type === 'wind' ? '#00FFB4' : a.type === 'solar' ? '#FFD700' : '#00B4FF';
            return (
              <div key={a.id} onClick={() => setSelected(a.id)} style={{
                padding: '10px 10px',
                marginBottom: 4,
                background: selected === a.id ? `${c}1a` : 'transparent',
                borderLeft: selected === a.id ? `3px solid ${c}` : '3px solid transparent',
                cursor: 'pointer',
                display: 'grid', gridTemplateColumns: '24px 1fr auto', gap: 8, alignItems: 'center',
              }}>
                <div style={{ width: 18, height: 18, border: `1px solid ${c}`, color: c, font: '700 9px/18px inherit', textAlign: 'center' }}>
                  {a.type === 'wind' ? 'W' : a.type === 'solar' ? 'S' : 'H'}
                </div>
                <div>
                  <div style={{ font: '600 11px/1 inherit', color: '#E5FAF1' }}>{a.name}</div>
                  <div style={{ font: '500 9px/1.4 inherit', color: '#5FA88C', marginTop: 3 }}>{a.cap} · CF.{Math.round(a.cf*100)}</div>
                </div>
                <div style={{ font: '700 9px/1 inherit', color: a.status === 'WARN' ? '#FFB400' : '#00FFB4', letterSpacing: 1 }}>{a.status === 'WARN' ? '◆' : '●'}</div>
              </div>
            );
          })}

          <div style={{ font: '700 10px/1 inherit', letterSpacing: 2, color: '#5FA88C', marginTop: 24, marginBottom: 12 }}>:: TELEMETRY</div>
          <div style={{ border: '1px solid rgba(0,255,180,.2)', padding: 10 }}>
            {[
              ['TOTAL CAP', '285.4 MW'],
              ['LIVE GEN', '187.2 MW'],
              ['CAPACITY F.', '0.34'],
              ['UPTIME', '99.81%'],
            ].map(([k, v]) => (
              <div key={k} style={{ display: 'flex', justifyContent: 'space-between', padding: '5px 0', borderBottom: '1px dashed rgba(0,255,180,.1)' }}>
                <span style={{ font: '500 10px/1 inherit', color: '#5FA88C', letterSpacing: 1 }}>{k}</span>
                <span style={{ font: '700 11px/1 inherit', color: '#00FFB4' }}>{v}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Center — map with 3D turbines */}
        <div style={{ position: 'relative', background: 'radial-gradient(ellipse at center, #0a1410 0%, #000 70%)' }}>
          {/* grid overlay */}
          <svg style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', opacity: 0.3 }}>
            <defs>
              <pattern id="mc-grid" x="0" y="0" width="40" height="40" patternUnits="userSpaceOnUse">
                <path d="M 40 0 L 0 0 0 40" fill="none" stroke="#00FFB4" strokeWidth="0.4"/>
              </pattern>
            </defs>
            <rect width="100%" height="100%" fill="url(#mc-grid)"/>
          </svg>
          {/* Turkey outline (rough) */}
          <svg viewBox="0 0 800 500" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }} preserveAspectRatio="xMidYMid meet">
            <path d="M 80 220 Q 120 180 200 200 Q 320 180 420 200 Q 540 195 640 215 Q 720 230 740 270 Q 720 320 640 340 Q 520 360 420 350 Q 280 360 180 340 Q 100 320 80 280 Z"
                  fill="rgba(0,255,180,.04)" stroke="#00FFB4" strokeWidth="1.2" strokeDasharray="4 4"/>
            {/* Cross-hairs at center */}
            <line x1="400" y1="0" x2="400" y2="500" stroke="rgba(0,255,180,.2)" strokeWidth="0.5"/>
            <line x1="0" y1="270" x2="800" y2="270" stroke="rgba(0,255,180,.2)" strokeWidth="0.5"/>
          </svg>

          {/* 3D turbine markers */}
          {[
            { id: 1, type: 'wind', x: 0.32, y: 0.35, name: 'BANDIRMA-7', cf: 0.38 },
            { id: 2, type: 'solar', x: 0.52, y: 0.55, name: 'KONYA-12', cf: 0.27 },
            { id: 3, type: 'hydro', x: 0.74, y: 0.32, name: 'TRABZON-3', cf: 0.42 },
            { id: 4, type: 'wind', x: 0.22, y: 0.5, name: 'ÇEŞME-2', cf: 0.31 },
            { id: 5, type: 'solar', x: 0.42, y: 0.7, name: 'ANTALYA-1', cf: 0.22 },
            { id: 6, type: 'wind', x: 0.4, y: 0.4, name: 'BALIKESIR-4', cf: 0.34 },
          ].map(p => (
            <div key={p.id} style={{
              position: 'absolute',
              left: `${p.x * 100}%`, top: `${p.y * 100}%`,
              transform: 'translate(-50%, -90%)',
            }}>
              <Turbine3D
                type={p.type}
                size={selected === p.id ? 90 : 60}
                cf={p.cf}
                flow={p.cf * 2}
                irradiance={5.5}
                glow={selected === p.id}
                label={selected === p.id ? p.name : null}
              />
              {/* Targeting reticle on selected */}
              {selected === p.id && (
                <svg width="120" height="120" style={{ position: 'absolute', left: '50%', top: '50%', transform: 'translate(-50%,-50%)', pointerEvents: 'none' }}>
                  <circle cx="60" cy="60" r="48" fill="none" stroke="#00FFB4" strokeWidth="1" strokeDasharray="3 6" opacity="0.7">
                    <animateTransform attributeName="transform" type="rotate" from="0 60 60" to="360 60 60" dur="14s" repeatCount="indefinite"/>
                  </circle>
                  <line x1="60" y1="0" x2="60" y2="14" stroke="#00FFB4" strokeWidth="1.2"/>
                  <line x1="60" y1="106" x2="60" y2="120" stroke="#00FFB4" strokeWidth="1.2"/>
                  <line x1="0" y1="60" x2="14" y2="60" stroke="#00FFB4" strokeWidth="1.2"/>
                  <line x1="106" y1="60" x2="120" y2="60" stroke="#00FFB4" strokeWidth="1.2"/>
                </svg>
              )}
            </div>
          ))}

          {/* Bottom corner readouts */}
          <div style={{ position: 'absolute', left: 14, bottom: 14, font: '500 10px/1.6 inherit', color: '#5FA88C', letterSpacing: 1 }}>
            <div>LAT 39.92° N · LNG 32.85° E</div>
            <div>ZOOM x4 · SCALE 1:2.4M</div>
            <div style={{ color: '#00FFB4', marginTop: 4 }}>► ACQUIRING TARGET...</div>
          </div>
          <div style={{ position: 'absolute', right: 14, bottom: 14, font: '500 10px/1.6 inherit', color: '#5FA88C', textAlign: 'right', letterSpacing: 1 }}>
            <div>SOLAR IRR. 5.7 kWh/m²</div>
            <div>WIND 7.2 m/s @ 80m</div>
            <div>WX: CLEAR · 18°C</div>
          </div>
        </div>

        {/* Right rail — selected detail */}
        <div style={{ borderLeft: '1px solid rgba(0,255,180,.2)', padding: 14, overflow: 'auto' }}>
          <div style={{ font: '700 10px/1 inherit', letterSpacing: 2, color: '#5FA88C', marginBottom: 4 }}>:: TARGET LOCK</div>
          <div style={{ font: '700 18px/1.2 inherit', color: '#00FFB4', marginBottom: 2, letterSpacing: 1 }}>KONYA-MERAM-12</div>
          <div style={{ font: '500 10px/1 inherit', color: '#5FA88C', letterSpacing: 1.5, marginBottom: 16 }}>SOLAR · 18.5 MW · ID 0x4F2A</div>

          {/* Live readout box */}
          <div style={{ border: '1px solid rgba(0,255,180,.3)', padding: 12, marginBottom: 12 }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
              {[
                ['CURRENT', '4.82 MW'],
                ['DAILY', '38.4 MWh'],
                ['MONTHLY', '1,082 MWh'],
                ['ANNUAL', '12,940 MWh'],
                ['IRR', '5.7 kWh/m²'],
                ['PR', '83.4%'],
              ].map(([k, v]) => (
                <div key={k}>
                  <div style={{ font: '500 9px/1 inherit', color: '#5FA88C', letterSpacing: 1 }}>{k}</div>
                  <div style={{ font: '700 14px/1 inherit', color: '#E5FAF1', marginTop: 4 }}>{v}</div>
                </div>
              ))}
            </div>
          </div>

          {/* Generation chart */}
          <div style={{ font: '700 10px/1 inherit', letterSpacing: 2, color: '#5FA88C', marginBottom: 8 }}>:: GENERATION 24H</div>
          <div style={{ border: '1px solid rgba(0,255,180,.2)', padding: 10, height: 90, position: 'relative' }}>
            <svg viewBox="0 0 300 70" preserveAspectRatio="none" style={{ width: '100%', height: '100%' }}>
              <defs>
                <linearGradient id="mc-area" x1="0" x2="0" y1="0" y2="1">
                  <stop offset="0" stopColor="#00FFB4" stopOpacity="0.5"/>
                  <stop offset="1" stopColor="#00FFB4" stopOpacity="0"/>
                </linearGradient>
              </defs>
              <path d="M 0 60 L 20 58 L 40 55 L 60 50 L 80 38 L 100 22 L 120 10 L 140 8 L 160 12 L 180 22 L 200 32 L 220 45 L 240 55 L 260 60 L 280 62 L 300 64 L 300 70 L 0 70 Z" fill="url(#mc-area)"/>
              <path d="M 0 60 L 20 58 L 40 55 L 60 50 L 80 38 L 100 22 L 120 10 L 140 8 L 160 12 L 180 22 L 200 32 L 220 45 L 240 55 L 260 60 L 280 62 L 300 64" fill="none" stroke="#00FFB4" strokeWidth="1.5"/>
              <line x1="140" y1="0" x2="140" y2="70" stroke="#FFD700" strokeWidth="1" strokeDasharray="2 2"/>
            </svg>
          </div>

          {/* Action commands */}
          <div style={{ font: '700 10px/1 inherit', letterSpacing: 2, color: '#5FA88C', marginTop: 18, marginBottom: 8 }}>:: COMMANDS</div>
          {['[E] EDIT PIN', '[D] DELETE', '[F] FORECAST', '[R] RUN SCENARIO', '[X] EXPORT REPORT'].map(c => (
            <div key={c} style={{
              padding: '8px 10px', marginBottom: 4,
              border: '1px solid rgba(0,255,180,.2)',
              font: '600 10px/1 inherit', letterSpacing: 1.5,
              color: '#E5FAF1', cursor: 'pointer',
              transition: 'all .15s',
            }}
            onMouseEnter={e => { e.currentTarget.style.borderColor = '#00FFB4'; e.currentTarget.style.background = 'rgba(0,255,180,.08)'; }}
            onMouseLeave={e => { e.currentTarget.style.borderColor = 'rgba(0,255,180,.2)'; e.currentTarget.style.background = 'transparent'; }}>
              {c}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

// ═════════════════════════════════════════════════════════════════════════════
// YÖN 2 — LIVING ATLAS
// Soft, organic, glassy depth, generative texture, calming
// Inspired by: Apple Weather, Arc browser, soft topographic atlases
// ═════════════════════════════════════════════════════════════════════════════

const LivingAtlasScreen = () => {
  const [selected, setSelected] = useState(2);
  return (
    <div style={{
      width: 1440, height: 900,
      background: 'linear-gradient(135deg, #1a1d2e 0%, #1f2640 50%, #2a1d3a 100%)',
      fontFamily: '"Instrument Serif", "Source Serif Pro", Georgia, serif',
      color: '#F5F2ED',
      position: 'relative',
      overflow: 'hidden',
    }}>
      {/* Aurora glow blobs */}
      <div style={{
        position: 'absolute', left: '-10%', top: '-15%',
        width: 600, height: 600, borderRadius: '50%',
        background: 'radial-gradient(circle, rgba(255,180,120,.18), transparent 60%)',
        filter: 'blur(40px)', pointerEvents: 'none',
      }}/>
      <div style={{
        position: 'absolute', right: '-5%', bottom: '-20%',
        width: 700, height: 700, borderRadius: '50%',
        background: 'radial-gradient(circle, rgba(120,180,255,.16), transparent 60%)',
        filter: 'blur(40px)', pointerEvents: 'none',
      }}/>
      <div style={{
        position: 'absolute', left: '40%', top: '20%',
        width: 500, height: 500, borderRadius: '50%',
        background: 'radial-gradient(circle, rgba(180,255,200,.1), transparent 60%)',
        filter: 'blur(50px)', pointerEvents: 'none',
      }}/>

      {/* Grain texture */}
      <svg style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', opacity: 0.4, mixBlendMode: 'overlay', pointerEvents: 'none' }}>
        <filter id="la-grain"><feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2"/></filter>
        <rect width="100%" height="100%" filter="url(#la-grain)" opacity="0.4"/>
      </svg>

      {/* Top bar */}
      <div style={{
        position: 'absolute', left: 24, right: 24, top: 24,
        display: 'flex', alignItems: 'center', gap: 18,
        zIndex: 10,
      }}>
        <div style={{
          padding: '10px 18px',
          background: 'rgba(255,255,255,.08)',
          backdropFilter: 'blur(24px)',
          border: '1px solid rgba(255,255,255,.14)',
          borderRadius: 100,
          display: 'flex', alignItems: 'center', gap: 10,
        }}>
          <div style={{ width: 28, height: 28, borderRadius: '50%', background: 'linear-gradient(135deg, #FFB48A, #C8A8FF)' }}/>
          <span style={{ font: '500 17px/1 "Instrument Serif", serif', letterSpacing: 0.5 }}>SRRP <span style={{ fontStyle: 'italic', color: 'rgba(245,242,237,.6)' }}>Atlas</span></span>
        </div>
        <div style={{ flex: 1 }}/>
        <div style={{
          padding: '8px 6px',
          background: 'rgba(255,255,255,.06)',
          backdropFilter: 'blur(24px)',
          border: '1px solid rgba(255,255,255,.12)',
          borderRadius: 100,
          display: 'flex', gap: 2,
        }}>
          {['Atlas', 'Senaryolar', 'Tahmin'].map((t, i) => (
            <button key={t} style={{
              background: i === 0 ? 'rgba(255,255,255,.14)' : 'transparent',
              border: 'none',
              borderRadius: 100,
              padding: '8px 18px',
              font: '500 14px/1 "Instrument Serif", serif',
              color: i === 0 ? '#F5F2ED' : 'rgba(245,242,237,.6)',
              fontStyle: i === 0 ? 'normal' : 'italic',
              cursor: 'pointer',
              letterSpacing: 0.3,
            }}>{t}</button>
          ))}
        </div>
        <button style={{
          width: 44, height: 44, borderRadius: '50%',
          background: 'rgba(255,255,255,.08)',
          backdropFilter: 'blur(24px)',
          border: '1px solid rgba(255,255,255,.14)',
          color: '#F5F2ED', font: '500 14px/1 "Instrument Serif", serif',
          cursor: 'pointer',
        }}>+</button>
      </div>

      {/* Main canvas — map area with topographic feel */}
      <div style={{ position: 'absolute', inset: 0, paddingTop: 90 }}>
        {/* Topo lines */}
        <svg viewBox="0 0 1440 800" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', opacity: 0.28 }} preserveAspectRatio="xMidYMid slice">
          {Array.from({ length: 12 }).map((_, i) => (
            <path key={i}
                  d={`M 0 ${250 + i * 35} Q ${300 + Math.sin(i) * 50} ${200 + i * 35} ${720} ${230 + i * 32} T 1440 ${250 + i * 35}`}
                  fill="none"
                  stroke={`hsla(${30 + i * 6}, 70%, 70%, ${0.4 - i * 0.025})`}
                  strokeWidth={0.8 + (i % 3) * 0.3}/>
          ))}
        </svg>

        {/* Country shape — flowing organic */}
        <svg viewBox="0 0 1440 800" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }} preserveAspectRatio="xMidYMid slice">
          <defs>
            <linearGradient id="la-country" x1="0" x2="1" y1="0" y2="1">
              <stop offset="0" stopColor="rgba(255,200,160,.2)"/>
              <stop offset="0.5" stopColor="rgba(180,200,255,.15)"/>
              <stop offset="1" stopColor="rgba(200,180,255,.18)"/>
            </linearGradient>
          </defs>
          <path d="M 180 350 Q 280 280 460 320 Q 660 290 880 330 Q 1080 320 1240 360 Q 1320 410 1280 480 Q 1100 540 880 520 Q 660 540 460 510 Q 280 510 200 460 Q 140 400 180 350 Z"
                fill="url(#la-country)"
                stroke="rgba(255,255,255,.25)"
                strokeWidth="1.5"/>
        </svg>

        {/* 3D turbine markers — softer, glowing */}
        {[
          { id: 1, type: 'wind', x: 0.28, y: 0.48, name: 'Bandırma' },
          { id: 2, type: 'solar', x: 0.5, y: 0.6, name: 'Konya' },
          { id: 3, type: 'hydro', x: 0.72, y: 0.48, name: 'Trabzon' },
          { id: 4, type: 'wind', x: 0.22, y: 0.6, name: 'Çeşme' },
          { id: 5, type: 'solar', x: 0.4, y: 0.72, name: 'Antalya' },
          { id: 6, type: 'wind', x: 0.36, y: 0.52, name: 'Balıkesir' },
        ].map(p => (
          <div key={p.id} onClick={() => setSelected(p.id)} style={{
            position: 'absolute',
            left: `${p.x * 100}%`, top: `${p.y * 100}%`,
            transform: 'translate(-50%, -85%)',
            cursor: 'pointer',
            zIndex: selected === p.id ? 5 : 2,
          }}>
            {/* Soft glow halo */}
            {selected === p.id && (
              <div style={{
                position: 'absolute',
                left: '50%', top: '85%',
                transform: 'translate(-50%, -50%)',
                width: 140, height: 140,
                borderRadius: '50%',
                background: `radial-gradient(circle, ${p.type === 'wind' ? 'rgba(180,220,255,.5)' : p.type === 'solar' ? 'rgba(255,200,140,.5)' : 'rgba(180,255,220,.5)'} 0%, transparent 60%)`,
                filter: 'blur(8px)',
                pointerEvents: 'none',
              }}/>
            )}
            <Turbine3D
              type={p.type}
              size={selected === p.id ? 88 : 56}
              cf={0.34}
              flow={1}
              irradiance={5.5}
              glow={selected === p.id}
            />
            {/* Floating label */}
            {selected === p.id && (
              <div style={{
                position: 'absolute',
                left: '50%', top: 'calc(100% + 4px)',
                transform: 'translateX(-50%)',
                padding: '6px 14px',
                background: 'rgba(255,255,255,.12)',
                backdropFilter: 'blur(20px)',
                border: '1px solid rgba(255,255,255,.18)',
                borderRadius: 100,
                font: 'italic 500 14px/1 "Instrument Serif", serif',
                color: '#F5F2ED',
                whiteSpace: 'nowrap',
                letterSpacing: 0.3,
              }}>{p.name}</div>
            )}
          </div>
        ))}

        {/* Drifting particles */}
        {Array.from({ length: 15 }).map((_, i) => (
          <div key={i} style={{
            position: 'absolute',
            left: `${(i * 73) % 100}%`,
            top: `${(i * 41) % 80 + 10}%`,
            width: 3, height: 3,
            borderRadius: '50%',
            background: 'rgba(255,255,255,.5)',
            boxShadow: '0 0 6px rgba(255,255,255,.6)',
            animation: `la-drift-${i} ${20 + (i % 5) * 3}s ease-in-out infinite`,
          }}>
            <style>{`
              @keyframes la-drift-${i} {
                0%, 100% { transform: translate(0, 0); opacity: 0.4; }
                50% { transform: translate(${30 - i * 4}px, ${-20 - i * 3}px); opacity: 1; }
              }
            `}</style>
          </div>
        ))}
      </div>

      {/* Left side panel — softer, glassy, editorial */}
      <div style={{
        position: 'absolute',
        left: 24, top: 90, bottom: 24,
        width: 320,
        background: 'rgba(20,22,40,.55)',
        backdropFilter: 'blur(40px)',
        border: '1px solid rgba(255,255,255,.1)',
        borderRadius: 24,
        padding: '28px 24px',
        zIndex: 8,
        overflow: 'auto',
      }}>
        <div style={{ font: 'italic 500 13px/1 "Instrument Serif", serif', color: 'rgba(245,242,237,.6)', letterSpacing: 0.5, marginBottom: 6 }}>Atlas of Türkiye</div>
        <div style={{ font: '500 32px/1.15 "Instrument Serif", serif', letterSpacing: -0.5, marginBottom: 4 }}>14 yenilenebilir<br/><span style={{ fontStyle: 'italic', color: 'rgba(245,242,237,.7)' }}>kaynak</span></div>
        <div style={{ font: '400 13px/1.5 system-ui, sans-serif', color: 'rgba(245,242,237,.55)', marginTop: 12 }}>
          Toplam kapasite 285 MW. Bu mevsim, güneşli günler nedeniyle <em style={{ color: '#FFB48A' }}>%4.2 üzerinde</em> üretim öngörülüyor.
        </div>

        <div style={{ height: 1, background: 'rgba(255,255,255,.08)', margin: '24px 0' }}/>

        {[
          { type: 'wind', label: 'Rüzgar', count: 6, mw: 142, color: '#B4DCFF' },
          { type: 'solar', label: 'Güneş', count: 5, mw: 78, color: '#FFD7A0' },
          { type: 'hydro', label: 'Hidro', count: 3, mw: 65, color: '#A0F0D0' },
        ].map(g => (
          <div key={g.type} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '14px 0', borderBottom: '1px solid rgba(255,255,255,.06)' }}>
            <div style={{ width: 8, height: 40, borderRadius: 4, background: g.color }}/>
            <div style={{ flex: 1 }}>
              <div style={{ font: 'italic 500 19px/1 "Instrument Serif", serif', color: '#F5F2ED' }}>{g.label}</div>
              <div style={{ font: '400 12px/1.4 system-ui, sans-serif', color: 'rgba(245,242,237,.55)', marginTop: 4 }}>{g.count} kaynak · {g.mw} MW</div>
            </div>
            <div style={{ font: '300 24px/1 "Instrument Serif", serif', color: g.color, fontStyle: 'italic' }}>{g.count}</div>
          </div>
        ))}

        <div style={{ marginTop: 24, font: 'italic 500 13px/1 "Instrument Serif", serif', color: 'rgba(245,242,237,.6)', letterSpacing: 0.5, marginBottom: 12 }}>Bugün</div>
        <div style={{ font: '300 56px/1 "Instrument Serif", serif', color: '#F5F2ED', letterSpacing: -2 }}>187<span style={{ fontSize: 24, fontStyle: 'italic', color: 'rgba(245,242,237,.6)' }}> MW</span></div>
        <div style={{ font: '400 12px/1.4 system-ui, sans-serif', color: 'rgba(245,242,237,.5)', marginTop: 6 }}>14 saatte üretim · doruk noktası 12:40'da</div>

        {/* Mini chart */}
        <svg viewBox="0 0 280 60" style={{ width: '100%', marginTop: 16 }}>
          <defs>
            <linearGradient id="la-area" x1="0" x2="0" y1="0" y2="1">
              <stop offset="0" stopColor="#FFB48A" stopOpacity="0.5"/>
              <stop offset="1" stopColor="#FFB48A" stopOpacity="0"/>
            </linearGradient>
          </defs>
          <path d="M 0 50 Q 40 48 60 42 T 120 18 T 180 8 T 240 25 T 280 38" fill="none" stroke="#FFB48A" strokeWidth="1.5"/>
          <path d="M 0 50 Q 40 48 60 42 T 120 18 T 180 8 T 240 25 T 280 38 L 280 60 L 0 60 Z" fill="url(#la-area)"/>
        </svg>
      </div>

      {/* Right floating card — selected detail */}
      <div style={{
        position: 'absolute',
        right: 24, top: 90,
        width: 340,
        background: 'rgba(20,22,40,.55)',
        backdropFilter: 'blur(40px)',
        border: '1px solid rgba(255,255,255,.1)',
        borderRadius: 24,
        padding: '24px',
        zIndex: 8,
      }}>
        <div style={{ font: 'italic 500 13px/1 "Instrument Serif", serif', color: 'rgba(255,215,160,.85)', letterSpacing: 0.5 }}>Solar · 18.5 MW</div>
        <div style={{ font: '500 26px/1.15 "Instrument Serif", serif', letterSpacing: -0.3, margin: '6px 0 14px' }}>
          Konya, <span style={{ fontStyle: 'italic', color: 'rgba(245,242,237,.7)' }}>Meram-12</span>
        </div>
        <div style={{ font: '400 13px/1.55 system-ui, sans-serif', color: 'rgba(245,242,237,.7)' }}>
          Bu mevsim öngörülen üretim toplam <em style={{ color: '#FFD7A0', fontStyle: 'normal', fontWeight: 600 }}>1,082 MWh</em>. Geçen yıla göre <span style={{ color: '#A0F0D0' }}>+8.3%</span>.
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginTop: 20 }}>
          {[
            ['Kapasite faktörü', '0.27', null],
            ['Yıllık üretim', '12.9 GWh', null],
            ['Geri ödeme', '5.8 yıl', null],
            ['Performans', '83.4%', '#A0F0D0'],
          ].map(([k, v, c]) => (
            <div key={k} style={{
              padding: 14,
              background: 'rgba(255,255,255,.04)',
              border: '1px solid rgba(255,255,255,.08)',
              borderRadius: 14,
            }}>
              <div style={{ font: '400 11px/1.4 system-ui, sans-serif', color: 'rgba(245,242,237,.55)' }}>{k}</div>
              <div style={{ font: '500 22px/1 "Instrument Serif", serif', color: c || '#F5F2ED', marginTop: 8, letterSpacing: -0.3 }}>{v}</div>
            </div>
          ))}
        </div>

        <div style={{ marginTop: 20, font: 'italic 500 13px/1 "Instrument Serif", serif', color: 'rgba(245,242,237,.6)', marginBottom: 10 }}>Bu hafta</div>
        <div style={{ display: 'flex', alignItems: 'flex-end', gap: 4, height: 60 }}>
          {[0.4, 0.55, 0.7, 0.85, 0.95, 0.6, 0.8].map((v, i) => (
            <div key={i} style={{
              flex: 1,
              height: `${v * 100}%`,
              background: `linear-gradient(180deg, #FFD7A0, rgba(255,215,160,.3))`,
              borderRadius: 4,
            }}/>
          ))}
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 6, font: '400 10px/1 system-ui, sans-serif', color: 'rgba(245,242,237,.4)' }}>
          {['P','S','Ç','P','C','C','P'].map((d, i) => <span key={i}>{d}</span>)}
        </div>

        <button style={{
          marginTop: 22, width: '100%',
          padding: '12px 18px',
          background: 'rgba(255,215,160,.18)',
          border: '1px solid rgba(255,215,160,.4)',
          borderRadius: 100,
          font: 'italic 500 15px/1 "Instrument Serif", serif',
          color: '#FFD7A0',
          cursor: 'pointer',
          letterSpacing: 0.3,
        }}>Detayları aç →</button>
      </div>
    </div>
  );
};

// ═════════════════════════════════════════════════════════════════════════════
// MOBILE MOCKS — quick smaller previews
// ═════════════════════════════════════════════════════════════════════════════

const MissionControlMobile = () => (
  <div style={{ width: 390, height: 844, background: '#000', fontFamily: 'JetBrains Mono, ui-monospace, monospace', color: '#E5FAF1', position: 'relative', overflow: 'hidden' }}>
    <div style={{
      position: 'absolute', inset: 0,
      background: 'repeating-linear-gradient(0deg, rgba(0,255,180,.03) 0, rgba(0,255,180,.03) 1px, transparent 1px, transparent 3px)',
      pointerEvents: 'none',
    }}/>
    <div style={{ paddingTop: 47 }}/>
    <div style={{ padding: '12px 16px', borderBottom: '1px solid rgba(0,255,180,.2)', display: 'flex', alignItems: 'center', gap: 8 }}>
      <div style={{ width: 6, height: 6, borderRadius: '50%', background: '#00FFB4' }}/>
      <span style={{ font: '700 10px/1 inherit', letterSpacing: 2, color: '#00FFB4' }}>SRRP // CONTROL</span>
      <div style={{ flex: 1 }}/>
      <span style={{ font: '500 9px/1 inherit', color: '#5FA88C' }}>14:32</span>
    </div>
    <div style={{ padding: 16, display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end' }}>
      <div>
        <div style={{ font: '700 9px/1 inherit', letterSpacing: 1.5, color: '#5FA88C' }}>:: TOTAL CAP</div>
        <div style={{ font: '700 28px/1 inherit', color: '#00FFB4', marginTop: 6 }}>285.4<span style={{ fontSize: 14, color: '#5FA88C' }}> MW</span></div>
      </div>
      <div style={{ font: '500 10px/1.5 inherit', color: '#5FA88C', textAlign: 'right' }}>
        14 ASSETS<br/>● 13 ACTIVE<br/>◆ 1 WARN
      </div>
    </div>

    {/* Mini map with turbines */}
    <div style={{ position: 'relative', height: 260, margin: '0 16px', border: '1px solid rgba(0,255,180,.2)', background: 'radial-gradient(ellipse at center, #0a1410 0%, #000 70%)' }}>
      <svg style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', opacity: 0.3 }}>
        <defs><pattern id="mc-mob-grid" x="0" y="0" width="20" height="20" patternUnits="userSpaceOnUse"><path d="M 20 0 L 0 0 0 20" fill="none" stroke="#00FFB4" strokeWidth="0.3"/></pattern></defs>
        <rect width="100%" height="100%" fill="url(#mc-mob-grid)"/>
      </svg>
      <div style={{ position: 'absolute', left: '25%', top: '40%', transform: 'translate(-50%,-50%)' }}>
        <Turbine3D type="wind" size={42} cf={0.38} glow/>
      </div>
      <div style={{ position: 'absolute', left: '55%', top: '60%', transform: 'translate(-50%,-50%)' }}>
        <Turbine3D type="solar" size={42} irradiance={5.7}/>
      </div>
      <div style={{ position: 'absolute', left: '78%', top: '38%', transform: 'translate(-50%,-50%)' }}>
        <Turbine3D type="hydro" size={42} flow={0.84}/>
      </div>
    </div>

    <div style={{ padding: '14px 16px' }}>
      <div style={{ font: '700 10px/1 inherit', letterSpacing: 2, color: '#5FA88C', marginBottom: 10 }}>:: ACTIVE LOG</div>
      {[
        { name: 'BANDIRMA-7', cap: '32.4 MW', status: '●' },
        { name: 'KONYA-12', cap: '18.5 MW', status: '●' },
        { name: 'TRABZON-3', cap: '12.0 MW', status: '◆' },
      ].map(a => (
        <div key={a.name} style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 0', borderBottom: '1px dashed rgba(0,255,180,.15)' }}>
          <div>
            <div style={{ font: '600 11px/1 inherit', color: '#E5FAF1' }}>{a.name}</div>
            <div style={{ font: '500 9px/1 inherit', color: '#5FA88C', marginTop: 4 }}>{a.cap}</div>
          </div>
          <div style={{ font: '700 12px/1 inherit', color: a.status === '◆' ? '#FFB400' : '#00FFB4', alignSelf: 'center' }}>{a.status}</div>
        </div>
      ))}
    </div>
  </div>
);

const LivingAtlasMobile = () => (
  <div style={{
    width: 390, height: 844,
    background: 'linear-gradient(160deg, #1a1d2e 0%, #1f2640 50%, #2a1d3a 100%)',
    fontFamily: '"Instrument Serif", Georgia, serif',
    color: '#F5F2ED', position: 'relative', overflow: 'hidden',
  }}>
    <div style={{ position: 'absolute', left: '-20%', top: '-10%', width: 400, height: 400, borderRadius: '50%', background: 'radial-gradient(circle, rgba(255,180,120,.18), transparent 60%)', filter: 'blur(40px)' }}/>
    <div style={{ position: 'absolute', right: '-15%', bottom: '20%', width: 400, height: 400, borderRadius: '50%', background: 'radial-gradient(circle, rgba(120,180,255,.16), transparent 60%)', filter: 'blur(40px)' }}/>

    <div style={{ paddingTop: 47 }}/>
    <div style={{ padding: '20px 22px', position: 'relative', zIndex: 2 }}>
      <div style={{ font: 'italic 500 13px/1 inherit', color: 'rgba(245,242,237,.6)', letterSpacing: 0.5 }}>Atlas · Bugün</div>
      <div style={{ font: '500 32px/1.1 inherit', letterSpacing: -0.5, margin: '6px 0', color: '#F5F2ED' }}>
        14 yenilenebilir<br/><span style={{ fontStyle: 'italic', color: 'rgba(245,242,237,.7)' }}>kaynak</span>
      </div>
      <div style={{ font: '400 13px/1.55 system-ui, sans-serif', color: 'rgba(245,242,237,.6)', marginTop: 8 }}>
        Şu an <em style={{ color: '#FFB48A' }}>187 MW</em> üretim — geçen haftadan %4.2 yüksek.
      </div>
    </div>

    {/* Map preview */}
    <div style={{ position: 'relative', height: 280, margin: '4px 22px', borderRadius: 24, overflow: 'hidden', background: 'rgba(255,255,255,.04)', border: '1px solid rgba(255,255,255,.1)' }}>
      <svg viewBox="0 0 350 280" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', opacity: 0.3 }}>
        {Array.from({ length: 6 }).map((_, i) => (
          <path key={i} d={`M 0 ${100 + i * 25} Q 175 ${80 + i * 25} 350 ${110 + i * 25}`} fill="none" stroke={`hsla(${30 + i * 10}, 70%, 70%, 0.4)`} strokeWidth="0.7"/>
        ))}
      </svg>
      <div style={{ position: 'absolute', left: '25%', top: '45%', transform: 'translate(-50%,-50%)' }}>
        <Turbine3D type="wind" size={48} cf={0.34}/>
      </div>
      <div style={{ position: 'absolute', left: '52%', top: '62%', transform: 'translate(-50%,-50%)' }}>
        <Turbine3D type="solar" size={56} irradiance={5.7} glow/>
      </div>
      <div style={{ position: 'absolute', left: '78%', top: '42%', transform: 'translate(-50%,-50%)' }}>
        <Turbine3D type="hydro" size={48} flow={0.84}/>
      </div>
      <div style={{ position: 'absolute', left: 14, bottom: 12, font: 'italic 500 13px/1 "Instrument Serif", serif', color: '#F5F2ED', padding: '6px 12px', background: 'rgba(255,255,255,.12)', backdropFilter: 'blur(20px)', borderRadius: 100, border: '1px solid rgba(255,255,255,.18)' }}>Konya, Meram-12</div>
    </div>

    <div style={{ padding: '20px 22px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
      {[
        ['Bugünkü doruk', '212 MW', '#FFB48A'],
        ['Kapasite f.', '0.34', '#A0F0D0'],
        ['Yıllık', '892 GWh', '#B4DCFF'],
        ['Tasarruf', '$1.2M', '#FFD7A0'],
      ].map(([k, v, c]) => (
        <div key={k} style={{ padding: 14, background: 'rgba(255,255,255,.04)', border: '1px solid rgba(255,255,255,.08)', borderRadius: 16 }}>
          <div style={{ font: '400 11px/1.4 system-ui, sans-serif', color: 'rgba(245,242,237,.55)' }}>{k}</div>
          <div style={{ font: '500 22px/1 "Instrument Serif", serif', color: c, marginTop: 8, letterSpacing: -0.3 }}>{v}</div>
        </div>
      ))}
    </div>
  </div>
);

Object.assign(window, { MissionControlScreen, LivingAtlasScreen, MissionControlMobile, LivingAtlasMobile });
