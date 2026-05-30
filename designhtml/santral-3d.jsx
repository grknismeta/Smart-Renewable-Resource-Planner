// SRRP — 3D Santral görselleştirmeleri
// Üç tip: WindTurbine3D, SolarPanel3D, HydroDam3D
// State-driven; rAF tabanlı yumuşak hız geçişleri (Flutter AnimationController eşdeğeri)

const { useState, useEffect, useRef, useId } = React;

// ─────────────────────────────────────────────────────────────
// Ortak: yumuşak değer izleme (Flutter'da Tween + AnimationController)
// target değerine doğru exponential ease ile yaklaşır
// ─────────────────────────────────────────────────────────────
function useEased(target, k = 2.5) {
  const [v, setV] = useState(target);
  const ref = useRef(target);
  const targetRef = useRef(target);
  useEffect(() => { targetRef.current = target; }, [target]);
  useEffect(() => {
    let raf, last;
    const tick = (t) => {
      const dt = Math.min(0.06, (t - (last ?? t)) / 1000);
      last = t;
      ref.current += (targetRef.current - ref.current) * Math.min(1, dt * k);
      setV(ref.current);
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [k]);
  return v;
}

// ─────────────────────────────────────────────────────────────
// 1) RÜZGAR GÜLÜ
// Prop: state = 'idle' | 'windy' | 'editing'
// Spin sadece windy/editing'de; geçişlerde yumuşak ramp.
// ─────────────────────────────────────────────────────────────
const WindTurbine3D = ({ state = 'windy', size = 140, accent = '#3B82F6', yaw = 0 }) => {
  const id = useId();
  // target angular velocity (deg/s)
  const targetSpeed = state === 'idle' ? 0 : state === 'editing' ? 180 : 110;
  const speed = useEased(targetSpeed, 1.8);
  const [angle, setAngle] = useState(0);
  useEffect(() => {
    let raf, last;
    const tick = (t) => {
      const dt = Math.min(0.06, (t - (last ?? t)) / 1000);
      last = t;
      setAngle(a => (a + speed * dt) % 360);
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [speed]);

  const editing = state === 'editing';

  return (
    <div style={{
      width: size, height: size * 1.5,
      position: 'relative',
      perspective: 320,
      filter: editing ? `drop-shadow(0 0 14px ${accent}cc)` : 'drop-shadow(0 8px 20px rgba(0,0,0,.45))',
      transition: 'filter .35s',
    }}>
      {/* Wind streaks — sadece windy state'de */}
      {state === 'windy' && [0,1,2].map(i => (
        <div key={i} style={{
          position: 'absolute',
          left: -size * 0.35, top: `${22 + i * 6}%`,
          width: size * 0.32, height: 1.4,
          background: 'linear-gradient(90deg, transparent, rgba(255,255,255,.55))',
          borderRadius: 2,
          animation: `wind-streak-${id} ${1.6 + i*0.25}s linear ${i*0.2}s infinite`,
          opacity: 0.7,
        }}/>
      ))}
      <style>{`
        @keyframes wind-streak-${id} {
          0%   { transform: translateX(0) scaleX(.6); opacity: 0; }
          30%  { opacity: .7; }
          100% { transform: translateX(${size*1.2}px) scaleX(1.2); opacity: 0; }
        }
        @keyframes edit-pulse-${id} {
          0%, 100% { box-shadow: 0 0 0 0 ${accent}aa, inset 0 0 0 2px ${accent}; }
          50%      { box-shadow: 0 0 0 8px ${accent}00, inset 0 0 0 2px ${accent}; }
        }
      `}</style>

      {/* Tower + nacelle (SVG, 3D-feel via gradient) */}
      <svg viewBox="0 0 100 150" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}>
        <defs>
          <linearGradient id={`tower-${id}`} x1="0" x2="1">
            <stop offset="0" stopColor="#C8CFDA"/>
            <stop offset="0.45" stopColor="#F4F6FA"/>
            <stop offset="1" stopColor="#7B8597"/>
          </linearGradient>
          <linearGradient id={`nacelle-${id}`} x1="0" x2="0" y1="0" y2="1">
            <stop offset="0" stopColor="#F4F6FA"/>
            <stop offset="1" stopColor="#8E97A8"/>
          </linearGradient>
        </defs>
        <ellipse cx="50" cy="143" rx="22" ry="3.5" fill="rgba(0,0,0,.45)"/>
        <path d="M 45 142 L 48 48 L 52 48 L 55 142 Z" fill={`url(#tower-${id})`} stroke="rgba(0,0,0,.35)" strokeWidth="0.5"/>
        <ellipse cx="50" cy="48" rx="9" ry="5" fill={`url(#nacelle-${id})`} stroke="rgba(0,0,0,.3)" strokeWidth="0.5"/>
        <rect x="46" y="44" width="10" height="4" rx="1" fill="#5C6678"/>
      </svg>

      {/* Rotor — 3D perspectiveli, JS-driven rotation. yaw → nacelle yön kontrolü */}
      <div style={{
        position: 'absolute',
        left: '50%', top: '32%',
        width: size, height: size,
        transform: `translate(-50%, -50%) rotateX(10deg) rotateY(${yaw}deg) rotateZ(${angle}deg)`,
        transformStyle: 'preserve-3d',
        willChange: 'transform',
      }}>
        {[0, 120, 240].map(a => (
          <div key={a} style={{
            position: 'absolute',
            left: '50%', top: '50%',
            width: 6, height: size * 0.48,
            transform: `translate(-50%, -100%) rotate(${a}deg)`,
            transformOrigin: '50% 100%',
          }}>
            <div style={{
              width: '100%', height: '100%',
              background: 'linear-gradient(180deg, #FCFCFE 0%, #E5E7EB 55%, #94A3B8 100%)',
              clipPath: 'polygon(38% 100%, 62% 100%, 100% 0, 0 0)',
              boxShadow: 'inset -1px 0 2px rgba(0,0,0,.25)',
            }}/>
          </div>
        ))}
        {/* Hub */}
        <div style={{
          position: 'absolute', left: '50%', top: '50%',
          width: 13, height: 13, borderRadius: '50%',
          transform: 'translate(-50%, -50%)',
          background: `radial-gradient(circle at 30% 30%, #FFF, ${accent})`,
          boxShadow: `0 0 0 1.5px rgba(0,0,0,.35), 0 0 10px ${accent}88`,
        }}/>
      </div>

      {/* Edit halkası */}
      {editing && (
        <div style={{
          position: 'absolute', left: '50%', top: '32%',
          width: size * 1.05, height: size * 1.05, borderRadius: '50%',
          transform: 'translate(-50%, -50%)',
          animation: `edit-pulse-${id} 1.4s ease-in-out infinite`,
          pointerEvents: 'none',
        }}/>
      )}
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// 2) GÜNEŞ PANELİ
// Prop: state = 'sun' | 'cloud' | 'night'
//  sun   → state'e girince tek seferlik parlama
//  cloud → 10 saniyede bir gri ışık geçişi
//  night → siyah panel + ay
// ─────────────────────────────────────────────────────────────
const SolarPanel3D = ({ state = 'sun', size = 160 }) => {
  const id = useId();

  // 'sun' state'ine girince shine'ı bir kez tetikle → key bump ile remount
  const [shineKey, setShineKey] = useState(0);
  useEffect(() => { if (state === 'sun') setShineKey(k => k + 1); }, [state]);

  // 'cloud' → 10s'de bir wash. Hemen birini de oynat.
  const [washKey, setWashKey] = useState(0);
  useEffect(() => {
    if (state !== 'cloud') return;
    const t0 = setTimeout(() => setWashKey(k => k+1), 300);
    const iv = setInterval(() => setWashKey(k => k+1), 10000);
    return () => { clearTimeout(t0); clearInterval(iv); };
  }, [state]);

  // Night transitionu için panel rengi
  const night = state === 'night';
  const panelBg = night
    ? 'linear-gradient(135deg, #060810 0%, #0B1020 50%, #050810 100%)'
    : 'linear-gradient(135deg, #1E3A8A 0%, #2563EB 40%, #1E40AF 100%)';
  const cellBg = night
    ? 'linear-gradient(135deg, #060810 0%, #0C1428 100%)'
    : 'linear-gradient(135deg, #1E40AF 0%, #3B82F6 50%, #1E3A8A 100%)';

  return (
    <div style={{
      width: size, height: size * 0.9,
      position: 'relative',
      perspective: 360,
      filter: 'drop-shadow(0 14px 22px rgba(0,0,0,.5))',
    }}>
      <style>{`
        @keyframes solar-shine-${id} {
          0%   { transform: translateX(-120%) skewX(-22deg); opacity: 0; }
          15%  { opacity: 1; }
          100% { transform: translateX(220%) skewX(-22deg); opacity: 0; }
        }
        @keyframes solar-wash-${id} {
          0%   { transform: translateX(-120%) skewX(-22deg); opacity: 0; }
          15%  { opacity: .55; }
          100% { transform: translateX(220%) skewX(-22deg); opacity: 0; }
        }
        @keyframes moon-rise-${id} {
          0%   { transform: translate(-50%, 30%) scale(.7); opacity: 0; }
          100% { transform: translate(-50%, -10%) scale(1); opacity: 1; }
        }
      `}</style>

      {/* Sky/sun in the corner — sadece sun state */}
      {state === 'sun' && (
        <div style={{
          position: 'absolute', right: '8%', top: '6%',
          width: 24, height: 24, borderRadius: '50%',
          background: 'radial-gradient(circle, #FBBF24 0%, #F59E0B 55%, transparent 75%)',
          boxShadow: '0 0 20px #FBBF24aa',
        }}/>
      )}
      {state === 'cloud' && (
        <div style={{
          position: 'absolute', right: '6%', top: '8%',
          width: 38, height: 18, borderRadius: 12,
          background: 'linear-gradient(180deg, #94A3B8, #64748B)',
          boxShadow: '0 4px 8px rgba(0,0,0,.4)',
          opacity: .9,
        }}/>
      )}

      {/* Tilted 3D panel */}
      <div style={{
        position: 'absolute', left: '50%', bottom: '14%',
        transform: 'translateX(-50%) rotateX(56deg) rotateZ(-6deg)',
        transformStyle: 'preserve-3d',
        width: size * 0.82, height: size * 0.5,
        background: panelBg,
        border: '1.5px solid #475569',
        borderRadius: 3,
        display: 'grid',
        gridTemplateColumns: 'repeat(4, 1fr)',
        gridTemplateRows: 'repeat(2, 1fr)',
        gap: 2,
        padding: 3,
        boxShadow: '0 8px 16px rgba(0,0,0,.6), inset 0 0 0 1px rgba(255,255,255,.08)',
        overflow: 'hidden',
        transition: 'background .6s ease',
      }}>
        {Array.from({ length: 8 }).map((_, i) => (
          <div key={i} style={{
            background: cellBg,
            borderRadius: 1,
            transition: 'background .6s ease',
          }}/>
        ))}

        {/* Tek seferlik güneş parlaması */}
        {state === 'sun' && (
          <div key={`shine-${shineKey}`} style={{
            position: 'absolute', inset: 0,
            background: 'linear-gradient(90deg, transparent 0%, rgba(255,255,255,.95) 50%, transparent 100%)',
            width: '60%',
            animation: `solar-shine-${id} 1.4s ease-out 1`,
            pointerEvents: 'none',
            mixBlendMode: 'screen',
          }}/>
        )}

        {/* 10s'de bir gri wash */}
        {state === 'cloud' && (
          <div key={`wash-${washKey}`} style={{
            position: 'absolute', inset: 0,
            background: 'linear-gradient(90deg, transparent 0%, rgba(180,190,210,.85) 50%, transparent 100%)',
            width: '70%',
            animation: `solar-wash-${id} 2.6s ease-in-out 1`,
            pointerEvents: 'none',
            mixBlendMode: 'screen',
          }}/>
        )}

        {/* Gece: ayın yansıması panel üzerinde */}
        {night && (
          <div style={{
            position: 'absolute', inset: 0,
            background: 'radial-gradient(ellipse 40% 50% at 65% 35%, rgba(220,230,255,.18), transparent 70%)',
            pointerEvents: 'none',
          }}/>
        )}
      </div>

      {/* Gece: Ay simgesi */}
      {night && (
        <div style={{
          position: 'absolute',
          left: '50%', top: '12%',
          width: 40, height: 40, borderRadius: '50%',
          background: 'radial-gradient(circle at 35% 35%, #F8FAFC 0%, #E2E8F0 55%, #94A3B8 100%)',
          boxShadow: '0 0 28px rgba(248,250,252,.55), inset -6px -4px 10px rgba(0,0,0,.25)',
          animation: `moon-rise-${id} 1.2s cubic-bezier(.2,.7,.3,1) both`,
        }}>
          {/* Krater */}
          <div style={{ position:'absolute', left:'58%', top:'42%', width:6, height:6, borderRadius:'50%', background:'rgba(0,0,0,.18)' }}/>
          <div style={{ position:'absolute', left:'34%', top:'58%', width:4, height:4, borderRadius:'50%', background:'rgba(0,0,0,.16)' }}/>
        </div>
      )}

      {/* Zemin gölgesi */}
      <div style={{
        position: 'absolute', left: '50%', bottom: '6%',
        transform: 'translateX(-50%)',
        width: size * 0.65, height: 6,
        background: 'rgba(0,0,0,.55)',
        borderRadius: '50%',
        filter: 'blur(3px)',
      }}/>
    </div>
  );
};

// ─────────────────────────────────────────────────────────────
// 3) HES — Beton baraj + akan su
// State'e gerek yok; basit, sürekli su akışı.
// ─────────────────────────────────────────────────────────────
const HydroDam3D = ({ size = 180, flow = 1 }) => {
  const id = useId();
  const w = size, h = size * 0.9;

  return (
    <div style={{
      width: w, height: h,
      position: 'relative',
      perspective: 420,
      filter: 'drop-shadow(0 14px 22px rgba(0,0,0,.5))',
    }}>
      <style>{`
        @keyframes water-fall-${id} {
          0%   { transform: translateY(-100%); opacity: 0; }
          15%  { opacity: 1; }
          100% { transform: translateY(100%); opacity: 0; }
        }
        @keyframes pool-ripple-${id} {
          0%   { transform: translate(-50%, 0) scale(.6); opacity: .7; }
          100% { transform: translate(-50%, 0) scale(1.4); opacity: 0; }
        }
        @keyframes top-water-${id} {
          0%, 100% { transform: translateX(0); }
          50%      { transform: translateX(-4px); }
        }
      `}</style>

      {/* 3D scene — concrete dam */}
      <div style={{
        position: 'absolute', inset: 0,
        transformStyle: 'preserve-3d',
        transform: 'rotateX(8deg)',
      }}>
        {/* Üstteki rezervuar suyu (uzaktan görünür şerit) */}
        <div style={{
          position: 'absolute',
          left: '8%', right: '8%', top: '14%',
          height: 14,
          background: 'linear-gradient(180deg, #0EA5C4 0%, #0891B2 100%)',
          borderRadius: '50% / 100% 100% 0 0',
          boxShadow: 'inset 0 -3px 6px rgba(0,0,0,.3), 0 1px 0 rgba(255,255,255,.15)',
          animation: `top-water-${id} 3.6s ease-in-out infinite`,
          overflow: 'hidden',
        }}>
          {/* Su yüzeyindeki çizgiler */}
          <div style={{
            position:'absolute', inset:0,
            background: 'repeating-linear-gradient(90deg, transparent 0 8px, rgba(255,255,255,.18) 8px 10px)',
            opacity: .5,
          }}/>
        </div>

        {/* Beton baraj — trapezoidal ön yüz */}
        <svg viewBox="0 0 200 180" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}>
          <defs>
            <linearGradient id={`concrete-${id}`} x1="0" x2="0" y1="0" y2="1">
              <stop offset="0" stopColor="#C7CBD3"/>
              <stop offset="0.4" stopColor="#9BA3AE"/>
              <stop offset="1" stopColor="#6B7280"/>
            </linearGradient>
            <linearGradient id={`concrete-side-${id}`} x1="0" x2="1">
              <stop offset="0" stopColor="#4B5563"/>
              <stop offset="1" stopColor="#374151"/>
            </linearGradient>
            <linearGradient id={`concrete-top-${id}`} x1="0" x2="0" y1="0" y2="1">
              <stop offset="0" stopColor="#E5E7EB"/>
              <stop offset="1" stopColor="#9CA3AF"/>
            </linearGradient>
          </defs>
          {/* Sağ yan yüz (perspektif) */}
          <path d="M 156 32 L 178 40 L 168 156 L 152 148 Z" fill={`url(#concrete-side-${id})`} stroke="rgba(0,0,0,.4)" strokeWidth="0.6"/>
          {/* Üst yüz (ince şerit) */}
          <path d="M 30 32 L 156 32 L 178 40 L 38 40 Z" fill={`url(#concrete-top-${id})`} stroke="rgba(0,0,0,.35)" strokeWidth="0.6"/>
          {/* Ön yüz — trapezoidal beton */}
          <path d="M 38 40 L 156 40 L 168 156 L 26 156 Z" fill={`url(#concrete-${id})`} stroke="rgba(0,0,0,.4)" strokeWidth="0.7"/>
          {/* Beton dikey eklem çizgileri */}
          {[68, 97, 126].map(x => (
            <line key={x} x1={x} y1="40" x2={x + (x-97)*0.08} y2="156" stroke="rgba(0,0,0,.18)" strokeWidth="0.6"/>
          ))}
          {/* Beton yatay segment hattı */}
          <line x1="32" y1="98" x2="162" y2="98" stroke="rgba(0,0,0,.15)" strokeWidth="0.6"/>
          {/* Savaklar — 3 kanal (ışıklı çentikler) */}
          {[60, 95, 130].map(x => (
            <rect key={x} x={x-7} y="40" width="14" height="6" fill="#1B2530" stroke="rgba(0,0,0,.4)" strokeWidth="0.4"/>
          ))}
        </svg>

        {/* Akan su — beton üzerinde 3 kanal */}
        {[
          { left: '24%', delay: 0 },
          { left: '43.5%', delay: 0.2 },
          { left: '63%', delay: 0.5 },
        ].map((c, i) => (
          <div key={i} style={{
            position: 'absolute',
            left: c.left, top: '22%',
            width: '11%', height: '67%',
            overflow: 'hidden',
            borderRadius: '0 0 4px 4px',
          }}>
            <div style={{
              position: 'absolute', inset: 0,
              background: `linear-gradient(180deg,
                rgba(125,211,252,.95) 0%,
                rgba(56,189,248,.85) 40%,
                rgba(14,165,233,.75) 100%)`,
              animation: `water-fall-${id} ${1.4/flow}s linear ${c.delay}s infinite`,
              boxShadow: 'inset 0 0 6px rgba(255,255,255,.4)',
            }}/>
            {/* İnce su şeritleri */}
            <div style={{
              position:'absolute', inset:0,
              background: 'repeating-linear-gradient(180deg, transparent 0 6px, rgba(255,255,255,.45) 6px 7px)',
              animation: `water-fall-${id} ${0.9/flow}s linear ${c.delay}s infinite`,
              opacity: .75,
            }}/>
          </div>
        ))}

        {/* Köpük / havuz */}
        <div style={{
          position: 'absolute',
          left: '8%', right: '8%', bottom: '6%',
          height: 22,
          background: 'linear-gradient(180deg, rgba(186,230,253,.95) 0%, #0EA5C4 70%, #0E7490 100%)',
          borderRadius: '40% 40% 8px 8px / 60% 60% 8px 8px',
          boxShadow: 'inset 0 4px 8px rgba(255,255,255,.4), inset 0 -4px 8px rgba(0,0,0,.35)',
          overflow: 'hidden',
        }}>
          <div style={{
            position:'absolute', inset:0,
            background: 'repeating-linear-gradient(90deg, transparent 0 12px, rgba(255,255,255,.35) 12px 14px)',
            opacity: .6,
          }}/>
        </div>

        {/* Köpük dalgaları */}
        {[15, 38, 62, 84].map((x, i) => (
          <div key={i} style={{
            position: 'absolute',
            left: `${x}%`, bottom: '13%',
            width: 18, height: 6, borderRadius: '50%',
            background: 'rgba(255,255,255,.6)',
            transform: 'translate(-50%, 0)',
            filter: 'blur(2px)',
            animation: `pool-ripple-${id} ${1.4 + i*0.2}s ease-out ${i*0.3}s infinite`,
          }}/>
        ))}

        {/* Zemin gölgesi */}
        <div style={{
          position: 'absolute', left: '50%', bottom: 0,
          transform: 'translateX(-50%)',
          width: '80%', height: 6,
          background: 'rgba(0,0,0,.55)',
          borderRadius: '50%',
          filter: 'blur(4px)',
        }}/>
      </div>
    </div>
  );
};

// Yardımcı — state'ler arası geçişi tetikleyen "demo orchestrator"
// Verilen bir liste içinde döner; her adımı `interval` ms süre tutar.
function useCycleState(states, interval = 4000, paused = false) {
  const [i, setI] = useState(0);
  useEffect(() => {
    if (paused) return;
    const id = setInterval(() => setI(x => (x + 1) % states.length), interval);
    return () => clearInterval(id);
  }, [states.length, interval, paused]);
  return [states[i], i, setI];
}

Object.assign(window, {
  WindTurbine3D, SolarPanel3D, HydroDam3D, useCycleState, useEased,
});
