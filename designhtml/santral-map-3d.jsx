// SRRP — Harita üstü 3D santral yerleşimi
// Eğimli terrain plane + rüzgâr yönü + güneş açısı + akarsu yatağı
// Mevcut WindTurbine3D / SolarPanel3D / HydroDam3D'yi sahnede konumlandırır.

const { useState: useStateM, useEffect: useEffectM, useMemo: useMemoM, useRef: useRefM, useId: useIdM } = React;

// ─────────────────────────────────────────────────────────────
// Map'in tilt açısı (ground plane)
const MAP_TILT = 56; // degrees

// Akarsu yatağı — terrain üzerinde flat olarak çizilir
// path SVG koordinatları (viewBox 1000x600)
const RIVER_PATH = "M 980 80 C 820 140, 760 220, 700 280 C 640 340, 560 360, 480 330 L 380 330 C 300 330, 240 360, 160 420 L 20 520";

// HES'in path üstündeki konumu (yaklaşık param. t=0.55)
const DAM_T = 0.52;
const DAM_POS = { x: 420, y: 332, angle: -8 }; // path tangentine yakın

// Wind farm cluster — terrain üzerinde
const WIND_POSITIONS = [
  { x: 760, y: 90,  size: 110, scale: 1.0 },
  { x: 870, y: 180, size: 96,  scale: 0.9 },
  { x: 660, y: 60,  size: 100, scale: 0.95 },
  { x: 800, y: 200, size: 88,  scale: 0.85 },
  { x: 580, y: 130, size: 90,  scale: 0.9 },
];

// Solar farm grid — terrain üzerinde
const SOLAR_POSITIONS = (() => {
  const out = [];
  const cols = 4, rows = 3;
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      out.push({ x: 120 + c * 90, y: 80 + r * 60, size: 70 });
    }
  }
  return out;
})();

// Util: derece → radyan
const D2R = Math.PI / 180;

// ─────────────────────────────────────────────────────────────
// Güneş paneli için aktif tilt + azimut'a göre transform üretir.
// Standart panel zaten rotateX(56deg) rotateZ(-6deg) uyguluyor — biz onu
// koruyarak DIŞ wrapper'da yönlendirme yapacağız.
// ─────────────────────────────────────────────────────────────
const OrientedSolar = ({ sunAzimuth, sunElevation, size = 70, state = 'sun' }) => {
  // Panel optimum açı: sun elevation tamamlayıcısı (yatay = 0, dik panel = 90)
  // Basitleştirilmiş model: paneller güneşin azimutuna döner.
  // Wrapper rotateY → azimut, rotateX → tilt katkısı (zaten panel kendi rotateX'iyle yatık)
  const panelTilt = Math.max(10, 90 - sunElevation); // ekstra ön eğme
  return (
    <div style={{
      transform: `rotateY(${sunAzimuth}deg) rotateX(${(panelTilt - 56) * 0.2}deg)`,
      transformStyle: 'preserve-3d',
    }}>
      <SolarPanel3D state={state} size={size}/>
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// Akan su path animasyonu — SVG <path> üstünde stroke-dasharray ile
// ─────────────────────────────────────────────────────────────
const FlowingRiver = ({ width = 1000, height = 600, animate = true }) => {
  const id = useIdM();
  return (
    <svg viewBox={`0 0 ${width} ${height}`} style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', pointerEvents: 'none' }}>
      <defs>
        <linearGradient id={`bed-${id}`} x1="0" x2="0" y1="0" y2="1">
          <stop offset="0" stopColor="#1F2937"/>
          <stop offset="1" stopColor="#0F172A"/>
        </linearGradient>
        <linearGradient id={`water-${id}`} x1="0" x2="1">
          <stop offset="0" stopColor="#7DD3FC"/>
          <stop offset="0.5" stopColor="#38BDF8"/>
          <stop offset="1" stopColor="#0EA5E9"/>
        </linearGradient>
      </defs>
      {/* Yatak (alt taban) */}
      <path d={RIVER_PATH} stroke={`url(#bed-${id})`} strokeWidth="36" fill="none" strokeLinecap="round" opacity="0.95"/>
      {/* Su yüzeyi - HES öncesi (yukarı havza, daha mavi) */}
      <path d={RIVER_PATH} stroke={`url(#water-${id})`} strokeWidth="26" fill="none" strokeLinecap="round" opacity="0.85"
        strokeDasharray="0 100000" pathLength="100" />
      {/* Akış çizgileri — animasyonlu */}
      <path d={RIVER_PATH} stroke="rgba(255,255,255,.7)" strokeWidth="1.2" fill="none"
        strokeDasharray="6 14" pathLength="200"
        style={animate ? { animation: `river-flow-${id} 2.2s linear infinite` } : {}}/>
      <path d={RIVER_PATH} stroke="rgba(186,230,253,.55)" strokeWidth="2.4" fill="none"
        strokeDasharray="3 22" pathLength="200"
        style={animate ? { animation: `river-flow-${id} 3.6s linear infinite` } : {}}/>
      <style>{`
        @keyframes river-flow-${id} {
          from { stroke-dashoffset: 200; }
          to   { stroke-dashoffset: 0; }
        }
      `}</style>
    </svg>
  );
};

// ─────────────────────────────────────────────────────────────
// Rüzgâr çizgileri — terrain üstünde hareketli streak'ler
// ─────────────────────────────────────────────────────────────
const WindStreaks = ({ direction = 45, intensity = 0.6, width = 1000, height = 600 }) => {
  const id = useIdM();
  // direction = 0 → sağa, 90 → aşağı doğru (ekran koordinatlarında)
  const streaks = useMemoM(() => {
    return Array.from({ length: 18 }).map((_, i) => ({
      x: Math.random() * width,
      y: Math.random() * height,
      len: 60 + Math.random() * 80,
      dur: 2.5 + Math.random() * 2,
      delay: -Math.random() * 4,
      op: 0.25 + Math.random() * 0.4,
    }));
  }, [width, height]);
  return (
    <div style={{ position: 'absolute', inset: 0, overflow: 'hidden', pointerEvents: 'none', opacity: intensity }}>
      <style>{`
        @keyframes wind-drift-${id} {
          0%   { transform: translate(-30px, 0) rotate(${direction}deg); opacity: 0; }
          15%  { opacity: 1; }
          100% { transform: translate(220px, 0) rotate(${direction}deg); opacity: 0; }
        }
      `}</style>
      {streaks.map((s, i) => (
        <div key={i} style={{
          position: 'absolute',
          left: s.x, top: s.y,
          width: s.len, height: 1.2,
          background: 'linear-gradient(90deg, transparent, rgba(180,210,255,.9), transparent)',
          borderRadius: 2,
          transformOrigin: '0 50%',
          animation: `wind-drift-${id} ${s.dur}s linear ${s.delay}s infinite`,
          opacity: s.op,
        }}/>
      ))}
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// 3D Harita — ana sahne
// ─────────────────────────────────────────────────────────────
const TerrainMap3D = ({
  windDirection = 45,    // 0-360, ekran koordinat dünyasında
  windSpeed = 1,         // 0 (durağan) - 1.5 (fırtına)
  sunAzimuth = 200,      // 0=K, 90=D, 180=G, 270=B
  sunElevation = 55,     // 0-90 (0=ufuk, 90=zenit)
  timeOfDay = 'day',     // 'day' | 'cloud' | 'night'
}) => {
  const id = useIdM();

  // Türbin durumu rüzgâr şiddetine göre
  const windState = windSpeed < 0.1 ? 'idle' : 'windy';
  const solarState = timeOfDay;

  // Güneş ekran konumu (yukarıdan görünüm — gökyüzünde projeksiyon)
  // azimuth 0 = north (yukarı), 90 = doğu (sağ), terrain için x: sin, y: -cos
  const sunX = 50 + Math.sin(sunAzimuth * D2R) * 38;
  const sunY = 16 + (90 - sunElevation) * 0.15;
  const isNight = timeOfDay === 'night';

  // Skyglow
  const skyGradient = isNight
    ? 'radial-gradient(ellipse 80% 60% at 50% 0%, #0B1530 0%, #050810 60%, #02030A 100%)'
    : timeOfDay === 'cloud'
    ? 'radial-gradient(ellipse 80% 60% at 50% 0%, #2A3242 0%, #1A1F2B 60%, #0F141C 100%)'
    : 'radial-gradient(ellipse 80% 60% at 50% 0%, #2C3A5C 0%, #19223A 50%, #0B0E14 100%)';

  // Ground tint
  const groundTint = isNight
    ? 'linear-gradient(180deg, #0F1422 0%, #0A0E18 60%, #06080F 100%)'
    : timeOfDay === 'cloud'
    ? 'linear-gradient(180deg, #232838 0%, #1A1E29 60%, #11141C 100%)'
    : 'linear-gradient(180deg, #1B2336 0%, #131A2A 60%, #0B0E14 100%)';

  return (
    <div style={{
      width: '100%', height: '100%',
      position: 'relative',
      background: skyGradient,
      borderRadius: 12,
      overflow: 'hidden',
      perspective: 1600,
    }}>
      {/* Yıldızlar (gece) */}
      {isNight && (
        <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
          {Array.from({ length: 60 }).map((_, i) => {
            const x = Math.random() * 100, y = Math.random() * 40;
            const sz = Math.random() * 1.6 + 0.6;
            return <div key={i} style={{
              position: 'absolute', left: `${x}%`, top: `${y}%`,
              width: sz, height: sz, borderRadius: '50%',
              background: '#E5E7EB', opacity: 0.5 + Math.random() * 0.4,
            }}/>;
          })}
        </div>
      )}

      {/* Güneş / Ay göstergesi */}
      <div style={{
        position: 'absolute',
        left: `${sunX}%`, top: `${sunY}%`,
        width: 56, height: 56, borderRadius: '50%',
        transform: 'translate(-50%, -50%)',
        background: isNight
          ? 'radial-gradient(circle at 35% 35%, #F8FAFC 0%, #E2E8F0 55%, #94A3B8 100%)'
          : timeOfDay === 'cloud'
          ? 'radial-gradient(circle, #CBD5E1 0%, #94A3B8 60%, transparent 75%)'
          : 'radial-gradient(circle, #FCD34D 0%, #F59E0B 50%, transparent 75%)',
        boxShadow: isNight
          ? '0 0 30px rgba(248,250,252,.5)'
          : timeOfDay === 'cloud'
          ? '0 0 18px rgba(148,163,184,.3)'
          : '0 0 36px rgba(251,191,36,.7)',
        zIndex: 2,
      }}/>

      {/* Bulutlar */}
      {timeOfDay === 'cloud' && (
        <>
          {[
            { x: 22, y: 18, w: 90, op: 0.55 },
            { x: 55, y: 10, w: 130, op: 0.7 },
            { x: 78, y: 22, w: 75, op: 0.5 },
          ].map((c, i) => (
            <div key={i} style={{
              position: 'absolute',
              left: `${c.x}%`, top: `${c.y}%`,
              width: c.w, height: c.w * 0.35,
              background: 'radial-gradient(ellipse at center, rgba(180,200,225,.95) 0%, rgba(120,140,170,.7) 60%, transparent 80%)',
              borderRadius: '50%',
              opacity: c.op,
              filter: 'blur(2px)',
              transform: 'translate(-50%, -50%)',
            }}/>
          ))}
        </>
      )}

      {/* Pusula — sol üst */}
      <div style={{
        position: 'absolute', left: 14, top: 14,
        width: 64, height: 64, borderRadius: '50%',
        background: 'rgba(0,0,0,.55)',
        border: '1px solid rgba(255,255,255,.15)',
        backdropFilter: 'blur(8px)',
        zIndex: 5,
        display: 'grid', placeItems: 'center',
      }}>
        <svg viewBox="0 0 100 100" width="58" height="58">
          <circle cx="50" cy="50" r="42" fill="none" stroke="rgba(255,255,255,.15)" strokeWidth="0.8"/>
          {[0, 90, 180, 270].map(a => (
            <text key={a} x="50" y={a === 0 ? 14 : a === 180 ? 92 : 54} textAnchor="middle"
                  fill="rgba(255,255,255,.45)" fontSize="9" fontWeight="700" fontFamily="Inter"
                  transform={a === 90 ? 'translate(34, 0)' : a === 270 ? 'translate(-32, 0)' : ''}>
              {a === 0 ? 'K' : a === 90 ? 'D' : a === 180 ? 'G' : 'B'}
            </text>
          ))}
          {/* Rüzgâr oku */}
          <g transform={`rotate(${windDirection - 90} 50 50)`}>
            <path d="M 50 50 L 84 50 M 78 44 L 84 50 L 78 56" stroke="#3B82F6" strokeWidth="2.5"
                  fill="none" strokeLinecap="round" strokeLinejoin="round"/>
          </g>
          <circle cx="50" cy="50" r="3" fill="#3B82F6"/>
        </svg>
      </div>

      {/* Bilgi rozeti — sağ üst */}
      <div style={{
        position: 'absolute', right: 14, top: 14,
        padding: '8px 12px',
        background: 'rgba(0,0,0,.55)',
        border: '1px solid rgba(255,255,255,.10)',
        borderRadius: 10,
        backdropFilter: 'blur(8px)',
        zIndex: 5,
        font: '500 11px/1.5 var(--font)',
        color: 'rgba(255,255,255,.85)',
        minWidth: 150,
      }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12 }}>
          <span style={{ color: 'rgba(255,255,255,.55)' }}>Rüzgâr</span>
          <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 700, color: '#93C5FD' }}>{windDirection}° · {(windSpeed*42).toFixed(0)} km/h</span>
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12 }}>
          <span style={{ color: 'rgba(255,255,255,.55)' }}>Güneş</span>
          <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 700, color: isNight ? '#CBD5E1' : '#FCD34D' }}>
            {sunAzimuth}° · {sunElevation}°
          </span>
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12 }}>
          <span style={{ color: 'rgba(255,255,255,.55)' }}>Zaman</span>
          <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 700, color: '#A78BFA' }}>
            {timeOfDay === 'day' ? 'Güneşli' : timeOfDay === 'cloud' ? 'Bulutlu' : 'Gece'}
          </span>
        </div>
      </div>

      {/* TERRAIN PLANE */}
      <div style={{
        position: 'absolute',
        left: '50%', bottom: '-8%',
        width: 1000, height: 600,
        transform: `translateX(-50%) rotateX(${MAP_TILT}deg)`,
        transformStyle: 'preserve-3d',
        transformOrigin: '50% 100%',
      }}>
        {/* Ground base */}
        <div style={{
          position: 'absolute', inset: 0,
          background: groundTint,
          borderRadius: '8px',
          boxShadow: 'inset 0 0 80px rgba(0,0,0,.6)',
        }}>
          {/* Topografya rölyef gradyanları */}
          <div style={{
            position: 'absolute', inset: 0,
            background:
              'radial-gradient(ellipse 25% 28% at 18% 28%, rgba(120,140,170,.18), transparent 70%),' +
              'radial-gradient(ellipse 18% 22% at 75% 18%, rgba(140,160,180,.20), transparent 70%),' +
              'radial-gradient(ellipse 30% 20% at 82% 75%, rgba(60,90,80,.15), transparent 70%)',
          }}/>
          {/* Yükselti konturları */}
          <svg viewBox="0 0 1000 600" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', opacity: 0.18 }}>
            <g fill="none" stroke="#FFFFFF" strokeWidth="0.8">
              <ellipse cx="180" cy="170" rx="160" ry="80"/>
              <ellipse cx="180" cy="170" rx="110" ry="55"/>
              <ellipse cx="180" cy="170" rx="60" ry="30"/>
              <ellipse cx="750" cy="110" rx="140" ry="70"/>
              <ellipse cx="750" cy="110" rx="90" ry="45"/>
              <ellipse cx="820" cy="450" rx="180" ry="90"/>
              <ellipse cx="820" cy="450" rx="120" ry="60"/>
            </g>
          </svg>
          {/* Grid */}
          <div style={{
            position: 'absolute', inset: 0,
            backgroundImage:
              'linear-gradient(rgba(255,255,255,.04) 1px, transparent 1px),' +
              'linear-gradient(90deg, rgba(255,255,255,.04) 1px, transparent 1px)',
            backgroundSize: '50px 50px',
            mixBlendMode: 'screen',
          }}/>
          {/* Vegetation patches (sol yamaç) */}
          {Array.from({ length: 24 }).map((_, i) => {
            const x = 30 + Math.random() * 320;
            const y = 40 + Math.random() * 200;
            const sz = 2 + Math.random() * 3;
            return <div key={i} style={{
              position: 'absolute', left: x, top: y,
              width: sz, height: sz, borderRadius: '50%',
              background: isNight ? 'rgba(40,80,60,.5)' : 'rgba(70,120,90,.55)',
              boxShadow: '0 1px 0 rgba(0,0,0,.4)',
            }}/>;
          })}

          {/* RÜZGAR ÇİZGİLERİ — terrain üstünde, yön rüzgârla aynı */}
          <WindStreaks direction={windDirection} intensity={Math.min(1, windSpeed)} />

          {/* AKARSU YATAĞI */}
          <FlowingRiver />

          {/* HES öncesi (rezervuar) vs sonrası (mansap) farkı */}
          <svg viewBox="0 0 1000 600" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', pointerEvents: 'none' }}>
            <defs>
              <radialGradient id={`reservoir-${id}`} cx="0.7" cy="0.5" r="0.7">
                <stop offset="0" stopColor="#0EA5E9" stopOpacity="0.85"/>
                <stop offset="1" stopColor="#0EA5E9" stopOpacity="0"/>
              </radialGradient>
            </defs>
            {/* Rezervuar genişlemesi (HES'in arkası) */}
            <ellipse cx={DAM_POS.x + 60} cy={DAM_POS.y - 6} rx="120" ry="36"
                     fill={`url(#reservoir-${id})`} opacity="0.6"/>
          </svg>

          {/* SOLAR FARM gölgeleri (terrain düzleminde) */}
          {SOLAR_POSITIONS.map((p, i) => (
            <div key={`ss-${i}`} style={{
              position: 'absolute',
              left: p.x, top: p.y + 14,
              width: p.size * 0.7, height: 8,
              transform: 'translate(-50%, 0)',
              background: 'rgba(0,0,0,.55)',
              borderRadius: '50%',
              filter: 'blur(2px)',
            }}/>
          ))}

          {/* WIND FARM gölgeleri */}
          {WIND_POSITIONS.map((p, i) => (
            <div key={`ws-${i}`} style={{
              position: 'absolute',
              left: p.x, top: p.y + p.size * 0.55,
              width: p.size * 0.45, height: 7,
              transform: 'translate(-50%, 0)',
              background: 'rgba(0,0,0,.55)',
              borderRadius: '50%',
              filter: 'blur(2px)',
            }}/>
          ))}
        </div>

        {/* === MARKERS (terrain'in çocukları; counter-rotate ile billboard) === */}

        {/* WIND TURBINES */}
        {WIND_POSITIONS.map((p, i) => (
          <div key={`w-${i}`} style={{
            position: 'absolute',
            left: p.x, top: p.y,
            transform: `translate(-50%, -100%) rotateX(-${MAP_TILT}deg) scale(${p.scale})`,
            transformStyle: 'preserve-3d',
            transformOrigin: '50% 100%',
          }}>
            <WindTurbine3D
              state={windState}
              size={p.size}
              yaw={windDirection - 90}
              accent="#60A5FA"
            />
          </div>
        ))}

        {/* SOLAR PANELS */}
        {SOLAR_POSITIONS.map((p, i) => (
          <div key={`s-${i}`} style={{
            position: 'absolute',
            left: p.x, top: p.y,
            transform: `translate(-50%, -50%) rotateX(-${MAP_TILT}deg)`,
            transformStyle: 'preserve-3d',
            transformOrigin: '50% 50%',
          }}>
            <OrientedSolar
              sunAzimuth={sunAzimuth - 180}
              sunElevation={sunElevation}
              size={p.size}
              state={solarState}
            />
          </div>
        ))}

        {/* HES — akarsu üstüne */}
        <div style={{
          position: 'absolute',
          left: DAM_POS.x, top: DAM_POS.y,
          transform: `translate(-50%, -50%) rotateX(-${MAP_TILT}deg) rotateZ(${DAM_POS.angle}deg)`,
          transformStyle: 'preserve-3d',
          transformOrigin: '50% 50%',
        }}>
          <HydroDam3D size={150} flow={1.2}/>
        </div>

        {/* Etiketler (her zaman okunabilir) */}
        {[
          { x: 720, y: 230, label: 'RES · 5 türbin', color: '#60A5FA' },
          { x: 240, y: 250, label: 'GES · 12 panel', color: '#FBBF24' },
          { x: 430, y: 410, label: 'HES · Baraj', color: '#22D3EE' },
        ].map((l, i) => (
          <div key={i} style={{
            position: 'absolute',
            left: l.x, top: l.y,
            transform: `translate(-50%, 0) rotateX(-${MAP_TILT}deg)`,
            transformOrigin: '50% 0',
            pointerEvents: 'none',
          }}>
            <div style={{
              display: 'inline-flex', alignItems: 'center', gap: 6,
              padding: '4px 9px',
              background: 'rgba(0,0,0,.7)',
              border: `1px solid ${l.color}55`,
              borderRadius: 6,
              font: '700 10px/1 var(--font)',
              color: l.color,
              letterSpacing: '.04em',
              textTransform: 'uppercase',
              whiteSpace: 'nowrap',
              boxShadow: `0 0 12px ${l.color}33`,
            }}>{l.label}</div>
          </div>
        ))}
      </div>
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// Kontrol paneliyle birlikte canlı sahne
// ─────────────────────────────────────────────────────────────
const TerrainMapDemo = () => {
  const [windDirection, setWindDirection] = useStateM(60);
  const [windSpeed, setWindSpeed] = useStateM(0.9);
  const [sunAzimuth, setSunAzimuth] = useStateM(200);
  const [sunElevation, setSunElevation] = useStateM(55);
  const [timeOfDay, setTimeOfDay] = useStateM('day');

  // Time of day → sun position auto
  useEffectM(() => {
    if (timeOfDay === 'night') { setSunAzimuth(0); setSunElevation(-10); }
    else if (timeOfDay === 'cloud') { setSunElevation(35); }
    else { setSunElevation(55); }
  }, [timeOfDay]);

  return (
    <div style={{ width: '100%', height: '100%', position: 'relative' }}>
      <TerrainMap3D
        windDirection={windDirection}
        windSpeed={windSpeed}
        sunAzimuth={sunAzimuth}
        sunElevation={Math.max(0, sunElevation)}
        timeOfDay={timeOfDay}
      />

      {/* Control panel */}
      <div style={{
        position: 'absolute',
        left: 14, bottom: 14,
        padding: '14px 16px',
        background: 'rgba(0,0,0,.72)',
        border: '1px solid rgba(255,255,255,.10)',
        borderRadius: 12,
        backdropFilter: 'blur(10px)',
        zIndex: 10,
        font: '500 11.5px/1.4 var(--font)',
        color: 'rgba(255,255,255,.9)',
        width: 280,
      }}>
        <div style={{ font: '700 11px/1 var(--font)', letterSpacing: '.06em', textTransform: 'uppercase', color: 'var(--accent)', marginBottom: 10 }}>
          Çevre Koşulları
        </div>

        <div style={{ marginBottom: 10 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
            <span style={{ color: 'rgba(255,255,255,.6)' }}>Rüzgâr yönü</span>
            <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 700, color: '#93C5FD' }}>{windDirection}°</span>
          </div>
          <input type="range" min="0" max="359" value={windDirection}
            onChange={e => setWindDirection(+e.target.value)}
            style={{ width: '100%', accentColor: '#3B82F6' }}/>
        </div>

        <div style={{ marginBottom: 10 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
            <span style={{ color: 'rgba(255,255,255,.6)' }}>Rüzgâr şiddeti</span>
            <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 700, color: '#93C5FD' }}>{(windSpeed * 42).toFixed(0)} km/h</span>
          </div>
          <input type="range" min="0" max="1.5" step="0.05" value={windSpeed}
            onChange={e => setWindSpeed(+e.target.value)}
            style={{ width: '100%', accentColor: '#3B82F6' }}/>
        </div>

        <div style={{ marginBottom: 10 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
            <span style={{ color: 'rgba(255,255,255,.6)' }}>Güneş azimut</span>
            <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 700, color: '#FCD34D' }}>{sunAzimuth}°</span>
          </div>
          <input type="range" min="0" max="359" value={sunAzimuth}
            onChange={e => setSunAzimuth(+e.target.value)}
            style={{ width: '100%', accentColor: '#F59E0B' }}/>
        </div>

        <div style={{ marginBottom: 12 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
            <span style={{ color: 'rgba(255,255,255,.6)' }}>Güneş yüksekliği</span>
            <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 700, color: '#FCD34D' }}>{sunElevation}°</span>
          </div>
          <input type="range" min="0" max="90" value={sunElevation}
            onChange={e => setSunElevation(+e.target.value)}
            style={{ width: '100%', accentColor: '#F59E0B' }}/>
        </div>

        <div style={{ display: 'flex', gap: 4, background: 'rgba(255,255,255,.06)', padding: 3, borderRadius: 999 }}>
          {[
            { v: 'day', l: 'Güneşli' },
            { v: 'cloud', l: 'Bulutlu' },
            { v: 'night', l: 'Gece' },
          ].map(o => (
            <button key={o.v}
              onClick={() => setTimeOfDay(o.v)}
              style={{
                flex: 1, appearance: 'none', border: 'none', cursor: 'pointer',
                padding: '7px 8px', borderRadius: 999,
                background: timeOfDay === o.v ? 'rgba(255,255,255,.14)' : 'transparent',
                color: timeOfDay === o.v ? '#fff' : 'rgba(255,255,255,.55)',
                font: '600 11px/1 var(--font)',
              }}>{o.l}</button>
          ))}
        </div>
      </div>
    </div>
  );
};

Object.assign(window, { TerrainMap3D, TerrainMapDemo, OrientedSolar });
