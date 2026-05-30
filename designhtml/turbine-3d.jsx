// 3D-look turbine markers — pure CSS 3D transforms, no libraries
// Three flavors: wind (rotating blades), solar (panel array tilt), hydro (rotating water turbine)

// ─────────────────────────────────────────────────────────────────────
// WIND TURBINE — 3D animated, capacity-factor-aware spin speed
// ─────────────────────────────────────────────────────────────────────
const WindTurbine3D = ({ size = 80, color = '#3B82F6', cf = 0.32, glow = false, label }) => {
  // Higher CF → faster spin. CF 0.32 → ~3s rotation; CF 0.45 → ~1.8s
  const duration = Math.max(1.2, 4.5 - cf * 7);
  const id = React.useId();
  return (
    <div style={{
      width: size, height: size * 1.4,
      position: 'relative',
      perspective: 240,
      filter: glow ? `drop-shadow(0 0 12px ${color}99)` : 'none',
    }}>
      {/* Tower */}
      <svg viewBox="0 0 80 110" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}>
        <defs>
          <linearGradient id={`tower-${id}`} x1="0" x2="1">
            <stop offset="0" stopColor="#E5E7EB"/>
            <stop offset="0.5" stopColor="#F9FAFB"/>
            <stop offset="1" stopColor="#9CA3AF"/>
          </linearGradient>
          <radialGradient id={`hub-${id}`} cx="0.4" cy="0.4">
            <stop offset="0" stopColor="#F9FAFB"/>
            <stop offset="1" stopColor={color}/>
          </radialGradient>
        </defs>
        {/* Base shadow */}
        <ellipse cx="40" cy="106" rx="14" ry="2.5" fill="rgba(0,0,0,.4)"/>
        {/* Tower */}
        <path d="M 36 105 L 38 35 L 42 35 L 44 105 Z" fill={`url(#tower-${id})`} stroke="rgba(0,0,0,.3)" strokeWidth="0.4"/>
        {/* Nacelle */}
        <ellipse cx="40" cy="35" rx="6" ry="3.5" fill={`url(#tower-${id})`} stroke="rgba(0,0,0,.25)" strokeWidth="0.4"/>
      </svg>
      {/* Rotor — CSS rotate animation, transform-style: preserve-3d for tilt */}
      <div style={{
        position: 'absolute',
        left: '50%', top: '32%',
        width: size * 0.9, height: size * 0.9,
        transform: 'translate(-50%, -50%) rotateX(8deg)',
        transformStyle: 'preserve-3d',
        animation: `turbine-spin-${id} ${duration}s linear infinite`,
      }}>
        <style>{`
          @keyframes turbine-spin-${id} {
            from { transform: translate(-50%, -50%) rotateX(8deg) rotateZ(0deg); }
            to   { transform: translate(-50%, -50%) rotateX(8deg) rotateZ(360deg); }
          }
        `}</style>
        {/* 3 blades */}
        {[0, 120, 240].map(angle => (
          <div key={angle} style={{
            position: 'absolute',
            left: '50%', top: '50%',
            width: 4, height: size * 0.42,
            transform: `translate(-50%, -100%) rotate(${angle}deg)`,
            transformOrigin: '50% 100%',
          }}>
            <div style={{
              width: '100%', height: '100%',
              background: `linear-gradient(180deg, #F9FAFB 0%, #E5E7EB 60%, #9CA3AF 100%)`,
              clipPath: 'polygon(40% 100%, 60% 100%, 100% 0, 0 0)',
              boxShadow: `inset -1px 0 2px rgba(0,0,0,.2)`,
            }}/>
          </div>
        ))}
        {/* Hub */}
        <div style={{
          position: 'absolute', left: '50%', top: '50%',
          width: 10, height: 10, borderRadius: '50%',
          transform: 'translate(-50%, -50%)',
          background: `radial-gradient(circle at 30% 30%, #F9FAFB, ${color})`,
          boxShadow: `0 0 0 1.5px rgba(0,0,0,.3), 0 0 8px ${color}66`,
        }}/>
      </div>
      {label && (
        <div style={{
          position: 'absolute', left: '50%', bottom: -2,
          transform: 'translateX(-50%)',
          font: '600 9px/1 ui-monospace, monospace',
          color: 'rgba(255,255,255,.85)',
          background: 'rgba(0,0,0,.6)',
          padding: '2px 5px', borderRadius: 3,
          whiteSpace: 'nowrap',
        }}>{label}</div>
      )}
    </div>
  );
};

// ─────────────────────────────────────────────────────────────────────
// SOLAR PANEL — tilted 3D array with subtle shimmer
// ─────────────────────────────────────────────────────────────────────
const SolarPanel3D = ({ size = 80, color = '#F59E0B', irradiance = 5.7, glow = false, label }) => {
  const id = React.useId();
  return (
    <div style={{
      width: size, height: size * 1.1,
      position: 'relative',
      perspective: 200,
      filter: glow ? `drop-shadow(0 0 12px ${color}99)` : 'none',
    }}>
      {/* Sun rays */}
      <div style={{
        position: 'absolute',
        right: '8%', top: '5%',
        width: 18, height: 18,
        borderRadius: '50%',
        background: `radial-gradient(circle, ${color} 0%, ${color}aa 40%, transparent 70%)`,
        animation: `solar-pulse-${id} 2.4s ease-in-out infinite`,
      }}>
        <style>{`
          @keyframes solar-pulse-${id} {
            0%, 100% { transform: scale(1); opacity: .9; }
            50% { transform: scale(1.18); opacity: 1; }
          }
          @keyframes solar-shimmer-${id} {
            0%, 100% { opacity: 0.55; }
            50% { opacity: 0.95; }
          }
        `}</style>
      </div>
      {/* Tilted panel array — 3D perspective */}
      <div style={{
        position: 'absolute', left: '50%', bottom: '12%',
        transform: 'translateX(-50%) rotateX(58deg) rotateZ(-8deg)',
        transformStyle: 'preserve-3d',
        width: size * 0.78, height: size * 0.5,
        background: `linear-gradient(135deg, #1E3A8A 0%, #1E40AF 40%, #2563EB 100%)`,
        border: '1.5px solid #475569',
        borderRadius: 2,
        display: 'grid',
        gridTemplateColumns: 'repeat(4, 1fr)',
        gridTemplateRows: 'repeat(2, 1fr)',
        gap: 1.5,
        padding: 2,
        boxShadow: `0 6px 14px rgba(0,0,0,.6), inset 0 0 0 1px rgba(255,255,255,.1)`,
      }}>
        {Array.from({ length: 8 }).map((_, i) => (
          <div key={i} style={{
            background: `linear-gradient(135deg, #1E40AF 0%, #3B82F6 50%, #1E3A8A 100%)`,
            borderRadius: 0.5,
            position: 'relative',
            overflow: 'hidden',
          }}>
            <div style={{
              position: 'absolute', inset: 0,
              background: `linear-gradient(135deg, transparent 30%, rgba(255,255,255,.4) 50%, transparent 70%)`,
              animation: `solar-shimmer-${id} ${2 + (i % 3) * 0.4}s ease-in-out ${i * 0.15}s infinite`,
            }}/>
          </div>
        ))}
      </div>
      {/* Ground shadow */}
      <div style={{
        position: 'absolute', left: '50%', bottom: '6%',
        transform: 'translateX(-50%)',
        width: size * 0.6, height: 4,
        background: 'rgba(0,0,0,.5)',
        borderRadius: '50%',
        filter: 'blur(2px)',
      }}/>
      {label && (
        <div style={{
          position: 'absolute', left: '50%', bottom: -2,
          transform: 'translateX(-50%)',
          font: '600 9px/1 ui-monospace, monospace',
          color: 'rgba(255,255,255,.85)',
          background: 'rgba(0,0,0,.6)',
          padding: '2px 5px', borderRadius: 3,
          whiteSpace: 'nowrap',
        }}>{label}</div>
      )}
    </div>
  );
};

// ─────────────────────────────────────────────────────────────────────
// HYDRO TURBINE — rotating water wheel with flowing water effect
// ─────────────────────────────────────────────────────────────────────
const HydroTurbine3D = ({ size = 80, color = '#06B6D4', flow = 1, glow = false, label }) => {
  const id = React.useId();
  const duration = Math.max(1.5, 4 - flow * 2);
  return (
    <div style={{
      width: size, height: size * 1.1,
      position: 'relative',
      perspective: 200,
      filter: glow ? `drop-shadow(0 0 12px ${color}99)` : 'none',
    }}>
      <style>{`
        @keyframes hydro-spin-${id} {
          from { transform: translate(-50%, -50%) rotateX(15deg) rotateZ(0deg); }
          to   { transform: translate(-50%, -50%) rotateX(15deg) rotateZ(360deg); }
        }
        @keyframes hydro-flow-${id} {
          0% { transform: translateY(0); opacity: 0; }
          15% { opacity: 1; }
          100% { transform: translateY(${size * 0.5}px); opacity: 0; }
        }
      `}</style>
      {/* Flowing water lines (top to wheel) */}
      {[0, 1, 2].map(i => (
        <div key={i} style={{
          position: 'absolute',
          left: `${30 + i * 18}%`, top: 0,
          width: 2, height: 14,
          background: `linear-gradient(180deg, transparent, ${color})`,
          borderRadius: 2,
          animation: `hydro-flow-${id} ${1.4 + i * 0.2}s linear ${i * 0.3}s infinite`,
        }}/>
      ))}
      {/* Water wheel */}
      <div style={{
        position: 'absolute',
        left: '50%', top: '50%',
        width: size * 0.7, height: size * 0.7,
        borderRadius: '50%',
        transform: 'translate(-50%, -50%) rotateX(15deg)',
        transformStyle: 'preserve-3d',
        animation: `hydro-spin-${id} ${duration}s linear infinite`,
        background: `radial-gradient(circle at 35% 35%, #475569 0%, #1E293B 60%, #0F172A 100%)`,
        border: `2px solid ${color}`,
        boxShadow: `0 0 0 1px rgba(0,0,0,.4), 0 4px 12px rgba(0,0,0,.5), inset 0 0 8px ${color}44`,
      }}>
        {/* Paddles */}
        {[0, 45, 90, 135, 180, 225, 270, 315].map(angle => (
          <div key={angle} style={{
            position: 'absolute',
            left: '50%', top: '50%',
            width: 3, height: size * 0.32,
            background: `linear-gradient(180deg, #94A3B8, #475569)`,
            transform: `translate(-50%, -100%) rotate(${angle}deg)`,
            transformOrigin: '50% 100%',
            borderRadius: 1,
          }}/>
        ))}
        {/* Center hub */}
        <div style={{
          position: 'absolute', left: '50%', top: '50%',
          width: 10, height: 10,
          transform: 'translate(-50%, -50%)',
          borderRadius: '50%',
          background: `radial-gradient(circle, #F1F5F9, ${color})`,
          boxShadow: `0 0 6px ${color}cc`,
        }}/>
      </div>
      {/* Bottom water pool */}
      <div style={{
        position: 'absolute',
        left: '50%', bottom: '4%',
        transform: 'translateX(-50%)',
        width: size * 0.85, height: 6,
        background: `linear-gradient(180deg, ${color} 0%, ${color}88 100%)`,
        borderRadius: '50%',
        boxShadow: `0 0 8px ${color}66`,
      }}/>
      {label && (
        <div style={{
          position: 'absolute', left: '50%', bottom: -2,
          transform: 'translateX(-50%)',
          font: '600 9px/1 ui-monospace, monospace',
          color: 'rgba(255,255,255,.85)',
          background: 'rgba(0,0,0,.6)',
          padding: '2px 5px', borderRadius: 3,
          whiteSpace: 'nowrap',
        }}>{label}</div>
      )}
    </div>
  );
};

// Convenience: render correct turbine for type
const Turbine3D = ({ type, ...props }) => {
  if (type === 'wind') return <WindTurbine3D {...props}/>;
  if (type === 'solar') return <SolarPanel3D {...props}/>;
  if (type === 'hydro') return <HydroTurbine3D {...props}/>;
  return null;
};

Object.assign(window, { WindTurbine3D, SolarPanel3D, HydroTurbine3D, Turbine3D });
