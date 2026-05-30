// landing-cinematic.jsx — SRRP cinematic landing
// Reuses data from reports-data-tr.jsx (TR_STATS, TR_REGIONS, TR_PROVINCES, REGION_PATHS)
// and shared.jsx (TYPES, Icon, TypeIcon).

const { useState, useEffect, useRef, useMemo, useLayoutEffect } = React;

const TYPECOL = { solar: '#F59E0B', wind: '#3B82F6', hydro: '#06B6D4' };
const TYPELBL = { solar: 'Güneş', wind: 'Rüzgar', hydro: 'Hidro' };

// ============================================================================
// Flowing background — fixed filmstrip of image slots that slowly drifts
// ============================================================================
const FlowingBackground = () => {
  const cols = [
    {
      cls: 'drift-a',
      slots: [
        { id: 'bg-a1', ph: 'Rüzgâr türbinleri — Bandırma / Çeşme' },
        { id: 'bg-a2', ph: 'Güneş paneli tarlası — Konya Karapınar' },
      ],
    },
    {
      cls: 'drift-b',
      slots: [
        { id: 'bg-b1', ph: 'Hidroelektrik — Artvin Yusufeli / Çoruh' },
        { id: 'bg-b2', ph: 'Türk kıyısı / Boğaz havadan' },
      ],
    },
    {
      cls: 'drift-c',
      slots: [
        { id: 'bg-c1', ph: 'Plato / step manzarası — İç Anadolu' },
        { id: 'bg-c2', ph: 'Atmosferik gökyüzü / bulut / şafak' },
      ],
    },
  ];
  return (
    <div className="bg-stage" aria-hidden="false">
      <div className="columns">
        {cols.map((c, i) => (
          <div key={i} className="bg-col">
            <div className={`bg-track ${c.cls}`}>
              {[0, 1].map(k => (
                <React.Fragment key={k}>
                  {c.slots.map(s => (
                    <image-slot key={s.id + '-' + k} id={s.id} placeholder={s.ph} shape="rect"></image-slot>
                  ))}
                </React.Fragment>
              ))}
            </div>
            {i < cols.length - 1 && <div className="bg-divider" style={{ right: 0 }}/>}
          </div>
        ))}
      </div>
      <div className="bg-overlay"/>
      <div className="bg-grain"/>
    </div>
  );
};

// ============================================================================
// Hooks
// ============================================================================
const useInView = (rootMargin = '-12% 0px') => {
  const ref = useRef(null);
  const [inView, setInView] = useState(false);
  useEffect(() => {
    if (!ref.current) return;
    const obs = new IntersectionObserver(([e]) => {
      if (e.isIntersecting) { setInView(true); obs.disconnect(); }
    }, { rootMargin, threshold: 0.05 });
    obs.observe(ref.current);
    return () => obs.disconnect();
  }, []);
  return [ref, inView];
};

const useCounter = (target, { duration = 2200, decimals = 0, start = false } = {}) => {
  const [v, setV] = useState(0);
  useEffect(() => {
    if (!start) return;
    let raf, t0;
    const tick = (t) => {
      if (!t0) t0 = t;
      const p = Math.min(1, (t - t0) / duration);
      const eased = 1 - Math.pow(1 - p, 3);
      setV(+(target * eased).toFixed(decimals));
      if (p < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [target, start, duration, decimals]);
  return v;
};

const useScrollY = () => {
  const [y, setY] = useState(0);
  useEffect(() => {
    const f = () => setY(window.scrollY);
    window.addEventListener('scroll', f, { passive: true });
    f();
    return () => window.removeEventListener('scroll', f);
  }, []);
  return y;
};

// Mouse tracker for hero parallax
const useMouseParallax = (ref) => {
  const [pos, setPos] = useState({ x: 0, y: 0 });
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const f = (e) => {
      const r = el.getBoundingClientRect();
      const x = (e.clientX - r.left) / r.width - 0.5;
      const y = (e.clientY - r.top) / r.height - 0.5;
      setPos({ x, y });
    };
    el.addEventListener('mousemove', f);
    return () => el.removeEventListener('mousemove', f);
  }, [ref]);
  return pos;
};

// ============================================================================
// Reveal wrapper
// ============================================================================
const Reveal = ({ children, delay = 0, as: As = 'div', className = '', style }) => {
  const [ref, inView] = useInView();
  return (
    <As ref={ref} className={`reveal ${inView ? 'in' : ''} ${className}`} style={{ transitionDelay: `${delay}ms`, ...style }}>
      {children}
    </As>
  );
};

// ============================================================================
// Hero — fullscreen, kinetic
// ============================================================================
const Hero = () => {
  const [started, setStarted] = useState(false);
  const heroRef = useRef(null);
  const parallax = useMouseParallax(heroRef);
  const scrollY = useScrollY();

  useEffect(() => {
    const t = setTimeout(() => setStarted(true), 250);
    return () => clearTimeout(t);
  }, []);

  const total = useCounter(116.8, { start: started, duration: 2600, decimals: 1 });
  const renew = useCounter(65.4, { start: started, duration: 2800, decimals: 1 });
  const share = useCounter(56, { start: started, duration: 2400, decimals: 0 });

  // canvas constellation
  const canvasRef = useRef(null);
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    let raf, w = 0, h = 0, dpr = Math.min(window.devicePixelRatio || 1, 2);
    const resize = () => {
      const r = canvas.parentElement.getBoundingClientRect();
      w = r.width; h = r.height;
      canvas.width = w * dpr; canvas.height = h * dpr;
      canvas.style.width = w + 'px'; canvas.style.height = h + 'px';
      ctx.scale(dpr, dpr);
    };
    resize();
    window.addEventListener('resize', resize);

    // particles — clustered around Turkey-ish silhouette region of the canvas
    const N = 110;
    const pts = Array.from({ length: N }, () => {
      // bias toward horizontal band in middle (Turkey strip)
      const x = Math.random() * w;
      const y = h * 0.35 + (Math.random() - 0.5) * h * 0.45;
      const t = Math.random();
      const color = t < 0.45 ? '#F59E0B' : t < 0.75 ? '#3B82F6' : '#06B6D4';
      return {
        x, y, vx: (Math.random() - 0.5) * 0.12, vy: (Math.random() - 0.5) * 0.08,
        r: Math.random() * 1.4 + 0.6, color, phase: Math.random() * Math.PI * 2,
      };
    });

    let mx = w / 2, my = h / 2;
    const onMove = (e) => {
      const r = canvas.getBoundingClientRect();
      mx = e.clientX - r.left; my = e.clientY - r.top;
    };
    window.addEventListener('mousemove', onMove);

    const tick = (t) => {
      ctx.clearRect(0, 0, w, h);
      // links
      for (let i = 0; i < pts.length; i++) {
        for (let j = i + 1; j < pts.length; j++) {
          const dx = pts[i].x - pts[j].x, dy = pts[i].y - pts[j].y;
          const d = Math.hypot(dx, dy);
          if (d < 110) {
            ctx.strokeStyle = `rgba(255,255,255,${0.06 * (1 - d / 110)})`;
            ctx.lineWidth = 0.6;
            ctx.beginPath();
            ctx.moveTo(pts[i].x, pts[i].y);
            ctx.lineTo(pts[j].x, pts[j].y);
            ctx.stroke();
          }
        }
      }
      // points
      pts.forEach(p => {
        p.x += p.vx; p.y += p.vy;
        // pull gently toward mouse
        const dx = mx - p.x, dy = my - p.y;
        const d = Math.hypot(dx, dy);
        if (d < 180) { p.vx += (dx / d) * 0.002; p.vy += (dy / d) * 0.002; }
        // friction
        p.vx *= 0.985; p.vy *= 0.985;
        // wrap
        if (p.x < -10) p.x = w + 10; if (p.x > w + 10) p.x = -10;
        if (p.y < -10) p.y = h + 10; if (p.y > h + 10) p.y = -10;
        // twinkle
        const a = 0.55 + Math.sin(t * 0.002 + p.phase) * 0.35;
        ctx.beginPath();
        ctx.fillStyle = p.color;
        ctx.globalAlpha = a;
        ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
        ctx.fill();
        // glow
        ctx.globalAlpha = a * 0.15;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.r * 4, 0, Math.PI * 2);
        ctx.fill();
      });
      ctx.globalAlpha = 1;
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => { cancelAnimationFrame(raf); window.removeEventListener('resize', resize); window.removeEventListener('mousemove', onMove); };
  }, []);

  // fade hero text on scroll
  const fadeT = Math.max(0, Math.min(1, scrollY / 500));

  return (
    <section ref={heroRef} style={{
      position: 'relative', height: '100vh', minHeight: 720, width: '100%',
      overflow: 'hidden', background: '#06080C',
    }}>
      {/* hero cover image */}
      <div className="hero-cover">
        <image-slot id="hero-cover" placeholder="Hero kapak — Türkiye'den geniş açı manzara (sahil, dağ ya da plato — drone shot)" shape="rect"></image-slot>
        <div className="hero-cover-overlay"/>
      </div>

      {/* canvas constellation */}
      <canvas ref={canvasRef} style={{ position: 'absolute', inset: 0, opacity: 0.7, mixBlendMode: 'screen' }}/>

      {/* gradient orbs */}
      <div className="drift1" style={{ position: 'absolute', width: 720, height: 720, left: '-10%', top: '-20%', borderRadius: '50%', background: 'radial-gradient(circle, rgba(245,158,11,.10), transparent 60%)', filter: 'blur(40px)', pointerEvents: 'none' }}/>
      <div className="drift2" style={{ position: 'absolute', width: 640, height: 640, right: '-15%', top: '20%', borderRadius: '50%', background: 'radial-gradient(circle, rgba(20,184,166,.12), transparent 60%)', filter: 'blur(40px)', pointerEvents: 'none' }}/>

      {/* top nav */}
      <header style={{
        position: 'absolute', top: 0, left: 0, right: 0, zIndex: 10,
        display: 'flex', alignItems: 'center', padding: '28px 48px',
        opacity: 1 - fadeT * 0.5,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ width: 28, height: 28, borderRadius: 7, background: 'linear-gradient(135deg, #F59E0B, #2DD4BF 55%, #3B82F6)', display: 'grid', placeItems: 'center', boxShadow: '0 4px 20px rgba(20,184,166,.25)' }}>
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="#06080C" strokeWidth="2.6" strokeLinecap="round"><path d="M12 3v18M3 12h18"/></svg>
          </div>
          <span style={{ font: '700 14px/1 Inter', letterSpacing: '-.01em' }}>SRRP</span>
          <span className="mono" style={{ fontSize: 11, color: 'rgba(255,255,255,.4)', marginLeft: 4 }}>v.3</span>
        </div>
        <nav style={{ flex: 1, display: 'flex', justifyContent: 'center', gap: 36 }}>
          {['Atlas', 'Bölgeler', 'İller', 'Senaryolar', 'Santraller'].map(x => (
            <a key={x} href={`#${x.toLowerCase()}`} className="ul-link" style={{ font: '500 13px/1 Inter', color: 'rgba(255,255,255,.65)', textDecoration: 'none', letterSpacing: '-.005em' }}>{x}</a>
          ))}
        </nav>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <span className="chip-live"><span className="pulse-dot" style={{ width: 6, height: 6, borderRadius: '50%', background: '#2DD4BF' }}/>TEİAŞ · canlı</span>
          <button className="mag" style={{ padding: '10px 18px', fontSize: 12.5 }}>Raporlara gir <svg className="mag-arrow" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><path d="M5 12h14M13 5l7 7-7 7"/></svg></button>
        </div>
      </header>

      {/* hero content */}
      <div style={{
        position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column',
        justifyContent: 'center', padding: '0 48px',
        transform: `translateY(${scrollY * 0.18}px)`,
        opacity: 1 - fadeT,
      }}>
        <div style={{ maxWidth: 1500, margin: '0 auto', width: '100%' }}>

          {/* eyebrow */}
          <div className="reveal in" style={{ display: 'flex', alignItems: 'center', gap: 14, marginBottom: 32, transform: `translate(${parallax.x * 8}px, ${parallax.y * 6}px)` }}>
            <span style={{ width: 36, height: 1, background: 'rgba(255,255,255,.4)' }}/>
            <span className="mono" style={{ fontSize: 11, letterSpacing: '.18em', textTransform: 'uppercase', color: 'rgba(255,255,255,.55)' }}>Türkiye · 2024 · Yenilenebilir Enerji Atlası</span>
          </div>

          {/* headline */}
          <h1 className="serif display" style={{
            margin: 0, font: '400 clamp(56px, 9.5vw, 168px)/0.95 "Instrument Serif", serif',
            letterSpacing: '-0.025em', maxWidth: 1500,
            transform: `translate(${parallax.x * 12}px, ${parallax.y * 8}px)`,
          }}>
            <span style={{ opacity: started ? 1 : 0, transition: 'opacity 1.2s' }}>Bir ülke,</span><br/>
            <span style={{ opacity: started ? 1 : 0, transition: 'opacity 1.2s', transitionDelay: '.25s' }}>
              <span style={{ fontStyle: 'italic', color: '#F5C77E' }}>güneşi,</span>{' '}
              <span style={{ fontStyle: 'italic', color: '#7FB4FF' }}>rüzgârı</span>{' '}
              <span style={{ color: 'rgba(255,255,255,.45)' }}>ve</span>{' '}
              <span style={{ fontStyle: 'italic', color: '#5EE3F2' }}>suyu</span>
            </span><br/>
            <span style={{ opacity: started ? 1 : 0, transition: 'opacity 1.2s', transitionDelay: '.5s' }}>okuyor.</span>
          </h1>

          {/* sub + live counter */}
          <div style={{ display: 'grid', gridTemplateColumns: '1.3fr 1fr', gap: 56, alignItems: 'end', marginTop: 56 }}>
            <p className="reveal in reveal-d3" style={{ margin: 0, font: '400 17px/1.55 Inter', color: 'rgba(255,255,255,.65)', maxWidth: 540, letterSpacing: '-.005em' }}>
              SRRP, Türkiye'nin 81 ili ve 7 coğrafi bölgesi boyunca her güneş ışını, her rüzgâr saniyesi ve her akarsu metreküpünü tek bir atlasta birleştirir — yatırımdan üretime, potansiyelden gerçekleşmeye.
            </p>

            <div className="reveal in reveal-d4" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 28, padding: '24px 0', borderTop: '1px solid rgba(255,255,255,.12)' }}>
              <div>
                <div className="mono" style={{ fontSize: 10, letterSpacing: '.12em', color: 'rgba(255,255,255,.4)', textTransform: 'uppercase', marginBottom: 10 }}>Kurulu Güç</div>
                <div className="display" style={{ font: '500 38px/1 "Instrument Serif", serif', letterSpacing: '-.02em' }}>{total.toFixed(1)}<span style={{ fontSize: 16, color: 'rgba(255,255,255,.5)', marginLeft: 4 }}>GW</span></div>
              </div>
              <div>
                <div className="mono" style={{ fontSize: 10, letterSpacing: '.12em', color: 'rgba(255,255,255,.4)', textTransform: 'uppercase', marginBottom: 10 }}>Yenilenebilir</div>
                <div className="display" style={{ font: '500 38px/1 "Instrument Serif", serif', letterSpacing: '-.02em', color: '#2DD4BF' }}>{renew.toFixed(1)}<span style={{ fontSize: 16, color: 'rgba(255,255,255,.5)', marginLeft: 4 }}>GW</span></div>
              </div>
              <div>
                <div className="mono" style={{ fontSize: 10, letterSpacing: '.12em', color: 'rgba(255,255,255,.4)', textTransform: 'uppercase', marginBottom: 10 }}>Pay</div>
                <div className="display" style={{ font: '500 38px/1 "Instrument Serif", serif', letterSpacing: '-.02em' }}>%{Math.round(share)}</div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* scroll hint */}
      <div className="scroll-hint" style={{ position: 'absolute', bottom: 32, left: '50%', transform: 'translateX(-50%)', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
        <span className="mono" style={{ fontSize: 10, letterSpacing: '.2em', color: 'rgba(255,255,255,.4)', textTransform: 'uppercase' }}>Atlas'a in</span>
        <svg width="14" height="20" viewBox="0 0 14 20" fill="none" stroke="rgba(255,255,255,.45)" strokeWidth="1.4"><rect x="1" y="1" width="12" height="18" rx="6"/><circle cx="7" cy="6" r="1.4" fill="rgba(255,255,255,.5)" stroke="none"/></svg>
      </div>
    </section>
  );
};

// ============================================================================
// Section 2 — The Numbers (kinetic stats reveal)
// ============================================================================
const NumbersSection = () => {
  const [ref, inView] = useInView();
  const s = TR_STATS;
  const cap = useCounter(s.totalInstalledMw, { start: inView, duration: 2400, decimals: 0 });
  const prod = useCounter(326.5, { start: inView, duration: 2400, decimals: 1 });
  const co2 = useCounter(105.2, { start: inView, duration: 2400, decimals: 1 });
  const homes = useCounter(43.7, { start: inView, duration: 2400, decimals: 1 });

  const items = [
    { kicker: 'Yıllık üretim', big: prod.toFixed(1), unit: 'TWh', sub: 'Toplam · 2024 · TEİAŞ', tint: '#fff' },
    { kicker: 'Kurulu güç', big: Math.round(cap).toLocaleString('tr-TR'), unit: 'MW', sub: `${(s.renewableMw/1000).toFixed(1)} GW yenilenebilir · %${(s.renewableShare*100).toFixed(0)}`, tint: '#2DD4BF' },
    { kicker: 'Önlenmiş CO₂', big: co2.toFixed(1), unit: 'Mt/yıl', sub: '≈ 12.5M araç eşdeğeri', tint: '#A7F3D0' },
    { kicker: 'Hane eşdeğeri', big: homes.toFixed(1), unit: 'milyon', sub: 'Yıllık tüketim · 3,500 kWh', tint: '#F5C77E' },
  ];

  return (
    <section id="atlas" ref={ref} style={{ padding: '180px 48px 120px', position: 'relative' }}>
      <div style={{ maxWidth: 1500, margin: '0 auto' }}>
        <Reveal>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 24, marginBottom: 80 }}>
            <span className="mono" style={{ fontSize: 11, letterSpacing: '.18em', color: 'rgba(255,255,255,.4)', textTransform: 'uppercase' }}>01 — Genel görünüm</span>
            <span style={{ flex: 1, height: 1, background: 'rgba(255,255,255,.1)' }}/>
          </div>
        </Reveal>

        <Reveal>
          <h2 className="serif" style={{ margin: '0 0 100px', font: '400 clamp(40px, 6vw, 96px)/1 "Instrument Serif", serif', letterSpacing: '-.02em', maxWidth: 1100 }}>
            2024'te Türkiye <span style={{ fontStyle: 'italic', color: 'rgba(255,255,255,.55)' }}>her saatte</span><br/>
            <span style={{ fontStyle: 'italic', color: '#2DD4BF' }}>37 milyon kWh</span> elektrik üretti.<br/>
            <span style={{ color: 'rgba(255,255,255,.4)' }}>Bunun yarısından fazlası,</span><br/>
            doğadan geldi.
          </h2>
        </Reveal>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 1, background: 'rgba(255,255,255,.08)', border: '1px solid rgba(255,255,255,.08)' }}>
          {items.map((it, i) => (
            <Reveal key={it.kicker} delay={i * 120}>
              <div style={{ padding: '36px 32px 40px', background: '#06080C', minHeight: 220, display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
                <div className="mono" style={{ fontSize: 10, letterSpacing: '.16em', textTransform: 'uppercase', color: 'rgba(255,255,255,.4)' }}>{it.kicker}</div>
                <div>
                  <div className="display" style={{ font: '500 72px/0.95 "Instrument Serif", serif', letterSpacing: '-.025em', color: it.tint }}>
                    {it.big}<span style={{ fontSize: 22, color: 'rgba(255,255,255,.4)', marginLeft: 6 }}>{it.unit}</span>
                  </div>
                  <div style={{ marginTop: 14, font: '400 12.5px/1.4 Inter', color: 'rgba(255,255,255,.5)' }}>{it.sub}</div>
                </div>
              </div>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
};

// ============================================================================
// Section 3 — Interactive Turkey Map (7 regions)
// ============================================================================
const RegionMap = () => {
  const [active, setActive] = useState('icanadolu');
  const [filter, setFilter] = useState('all');
  const region = TR_REGIONS.find(r => r.id === active);

  const colorFor = (r) => {
    if (filter === 'all') return r.color;
    const map = { solar: '#F59E0B', wind: '#3B82F6', hydro: '#06B6D4' };
    return map[filter];
  };
  const opacityFor = (r) => {
    if (active === r.id) return 0.85;
    if (filter === 'all') return 0.42;
    return r.topResource === filter ? 0.78 : r.bestFor.includes(filter) ? 0.40 : 0.10;
  };
  const labelCenters = {
    marmara: [220, 252], ege: [205, 320], akdeniz: [430, 360],
    icanadolu: [450, 290], karadeniz: [560, 240],
    doguanadolu: [760, 320], gdanadolu: [680, 400],
  };

  return (
    <section id="bölgeler" style={{ padding: '120px 48px 160px', position: 'relative' }}>
      <div style={{ maxWidth: 1500, margin: '0 auto' }}>

        <Reveal>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 24, marginBottom: 56 }}>
            <span className="mono" style={{ fontSize: 11, letterSpacing: '.18em', color: 'rgba(255,255,255,.4)', textTransform: 'uppercase' }}>02 — Atlas</span>
            <span style={{ flex: 1, height: 1, background: 'rgba(255,255,255,.1)' }}/>
            <span className="mono" style={{ fontSize: 11, color: 'rgba(255,255,255,.4)' }}>7 bölge · 81 il</span>
          </div>
        </Reveal>

        <div style={{ display: 'grid', gridTemplateColumns: '1.2fr 1fr', gap: 72, alignItems: 'start' }}>
          <Reveal>
            <h2 className="serif" style={{ margin: 0, font: '400 clamp(36px, 5vw, 72px)/1.05 "Instrument Serif", serif', letterSpacing: '-.02em' }}>
              Coğrafyayı<br/>
              <span style={{ fontStyle: 'italic', color: 'rgba(255,255,255,.55)' }}>kaynağa çevir.</span>
            </h2>
          </Reveal>
          <Reveal delay={120}>
            <p style={{ margin: 0, font: '400 16px/1.6 Inter', color: 'rgba(255,255,255,.6)', maxWidth: 460 }}>
              Marmara'nın rüzgâr koridorlarından İç Anadolu'nun güneş platolarına, Karadeniz'in akarsularına — yedi bölge, üç kaynak, bir atlas. Üzerine gel, kaynağa göre süz, içine in.
            </p>
          </Reveal>
        </div>

        {/* Filter chips */}
        <Reveal delay={200}>
          <div style={{ display: 'flex', gap: 8, marginTop: 56, marginBottom: 28 }}>
            {[
              { id: 'all', label: 'Tümü', col: '#fff' },
              { id: 'solar', label: 'Güneş', col: '#F59E0B' },
              { id: 'wind', label: 'Rüzgâr', col: '#3B82F6' },
              { id: 'hydro', label: 'Hidro', col: '#06B6D4' },
            ].map(t => {
              const on = filter === t.id;
              return (
                <button key={t.id} onClick={() => setFilter(t.id)} style={{
                  padding: '11px 20px', borderRadius: 999,
                  border: `1px solid ${on ? t.col + 'aa' : 'rgba(255,255,255,.14)'}`,
                  background: on ? t.col + '15' : 'transparent',
                  color: on ? t.col : 'rgba(255,255,255,.7)',
                  font: '500 13px/1 Inter', letterSpacing: '-.005em',
                  display: 'inline-flex', alignItems: 'center', gap: 8,
                  transition: 'all .25s', cursor: 'pointer',
                }}>
                  {t.id !== 'all' && <span style={{ width: 6, height: 6, borderRadius: '50%', background: t.col }}/>}
                  {t.label}
                </button>
              );
            })}
          </div>
        </Reveal>

        {/* Map + side panel */}
        <div style={{ display: 'grid', gridTemplateColumns: '1.6fr 1fr', gap: 32 }}>
          {/* Map */}
          <div style={{ position: 'relative', border: '1px solid rgba(255,255,255,.08)', borderRadius: 4, overflow: 'hidden', background: 'radial-gradient(ellipse at 50% 50%, #0B1018 0%, #06080C 80%)', aspectRatio: '1000/600' }}>
            {/* dot grid bg */}
            <div className="dotgrid" style={{ position: 'absolute', inset: 0, opacity: 0.5, pointerEvents: 'none' }}/>

            <svg viewBox="0 0 1000 600" style={{ width: '100%', height: '100%', display: 'block', position: 'relative' }}>
              <defs>
                <filter id="rmGlow" x="-30%" y="-30%" width="160%" height="160%">
                  <feGaussianBlur stdDeviation="4"/>
                </filter>
                <radialGradient id="rmHalo">
                  <stop offset="0" stopColor="#2DD4BF" stopOpacity="0.5"/>
                  <stop offset="1" stopColor="#2DD4BF" stopOpacity="0"/>
                </radialGradient>
              </defs>

              {/* base landmass */}
              <path d="M40 280 C 80 220, 160 200, 230 220 C 300 200, 380 230, 470 210 C 560 200, 640 220, 730 200 C 820 200, 900 230, 970 270 C 990 320, 950 360, 880 380 C 800 410, 700 410, 600 400 C 500 410, 400 400, 320 410 C 240 405, 160 390, 90 360 C 50 340, 30 310, 40 280 Z"
                fill="#0E141E" stroke="rgba(255,255,255,.04)" strokeWidth="1"/>

              {/* regions */}
              {TR_REGIONS.map(r => {
                const isActive = active === r.id;
                const c = colorFor(r);
                return (
                  <g key={r.id} style={{ cursor: 'pointer' }}
                    onMouseEnter={() => setActive(r.id)}>
                    {isActive && (
                      <path d={REGION_PATHS[r.id]} fill={c} fillOpacity="0.25" filter="url(#rmGlow)"/>
                    )}
                    <path d={REGION_PATHS[r.id]}
                      fill={c} fillOpacity={opacityFor(r)}
                      stroke={isActive ? c : 'rgba(255,255,255,.06)'}
                      strokeWidth={isActive ? 1.5 : 0.8}
                      style={{ transition: 'all .35s cubic-bezier(.22,.61,.36,1)' }}/>
                  </g>
                );
              })}

              {/* labels */}
              {TR_REGIONS.map(r => {
                const [x, y] = labelCenters[r.id];
                const isActive = active === r.id;
                const c = filter === 'all' ? r.color : colorFor(r);
                return (
                  <g key={r.id} pointerEvents="none" style={{ transition: 'all .25s' }}>
                    <text x={x} y={y} textAnchor="middle"
                      fontSize={isActive ? 15 : 11.5} fontFamily="Inter, sans-serif" fontWeight={isActive ? 700 : 500}
                      fill={isActive ? '#fff' : 'rgba(255,255,255,.78)'}
                      style={{ transition: 'all .25s' }}>{r.name}</text>
                    <text x={x} y={y + 16} textAnchor="middle"
                      fontSize={isActive ? 11 : 9} fontFamily="JetBrains Mono, monospace"
                      fill={isActive ? c : 'rgba(255,255,255,.4)'}>
                      {(r.capacityMw/1000).toFixed(1)} GW
                    </text>
                  </g>
                );
              })}
            </svg>

            {/* corner label */}
            <div style={{ position: 'absolute', top: 24, left: 24, font: '400 11px/1.4 "JetBrains Mono", monospace', color: 'rgba(255,255,255,.4)', letterSpacing: '.1em' }}>
              <div>TÜRKİYE · 37°N–42°N</div>
              <div style={{ marginTop: 4 }}>26°E–45°E</div>
            </div>
          </div>

          {/* Active region detail */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
            <div style={{ padding: '28px 28px 32px', border: '1px solid rgba(255,255,255,.08)', borderRadius: 4, background: 'rgba(255,255,255,.015)', position: 'relative', overflow: 'hidden' }} key={region.id}>
              <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: 2, background: region.color }}/>
              <div className="mono" style={{ fontSize: 10, letterSpacing: '.16em', textTransform: 'uppercase', color: region.color, marginBottom: 14 }}>Aktif Bölge</div>
              <h3 className="serif" style={{ margin: 0, font: '400 48px/1 "Instrument Serif", serif', letterSpacing: '-.02em' }}>{region.name}</h3>
              <p style={{ margin: '18px 0 0', font: '400 13.5px/1.55 Inter', color: 'rgba(255,255,255,.65)' }}>{region.description}</p>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginTop: 24, paddingTop: 20, borderTop: '1px solid rgba(255,255,255,.08)' }}>
                <Stat label="Kurulu Güç" value={(region.capacityMw/1000).toFixed(1)} unit="GW" col={region.color}/>
                <Stat label="Yıllık Üretim" value={(region.annualGwh/1000).toFixed(1)} unit="TWh"/>
                <Stat label="İl Sayısı" value={region.provincesCount} unit=""/>
                <Stat label="Lider Kaynak" value={TYPELBL[region.topResource]} unit="" col={TYPECOL[region.topResource]} text/>
              </div>

              <div style={{ marginTop: 22 }}>
                <div className="mono" style={{ fontSize: 10, letterSpacing: '.12em', color: 'rgba(255,255,255,.4)', textTransform: 'uppercase', marginBottom: 10 }}>İklim profili</div>
                <div style={{ display: 'flex', gap: 24 }}>
                  <ClimateBar label="Işınım" value={region.irradiance} max={6} unit="kWh/m²" color="#F59E0B"/>
                  <ClimateBar label="Rüzgâr" value={region.windSpeed} max={9} unit="m/s" color="#3B82F6"/>
                  <ClimateBar label="Yağış" value={region.precipitation} max={1300} unit="mm" color="#06B6D4"/>
                </div>
              </div>
            </div>

            {/* region list */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: 1, background: 'rgba(255,255,255,.06)', border: '1px solid rgba(255,255,255,.08)' }}>
              {TR_REGIONS.map(r => {
                const on = active === r.id;
                return (
                  <button key={r.id} onMouseEnter={() => setActive(r.id)} style={{
                    display: 'grid', gridTemplateColumns: '14px 1fr auto auto', gap: 14, alignItems: 'center',
                    padding: '14px 18px', background: on ? 'rgba(255,255,255,.04)' : '#06080C',
                    border: 'none', textAlign: 'left', cursor: 'pointer',
                    transition: 'background .2s',
                  }}>
                    <span style={{ width: 8, height: 8, borderRadius: '50%', background: r.color, opacity: on ? 1 : 0.6 }}/>
                    <span style={{ font: '500 13.5px/1 Inter', color: on ? '#fff' : 'rgba(255,255,255,.7)', letterSpacing: '-.005em' }}>{r.name}</span>
                    <span className="mono" style={{ fontSize: 11, color: 'rgba(255,255,255,.4)' }}>{TYPELBL[r.topResource]}</span>
                    <span className="mono" style={{ fontSize: 11.5, color: on ? '#fff' : 'rgba(255,255,255,.5)', minWidth: 60, textAlign: 'right' }}>{(r.capacityMw/1000).toFixed(1)} GW</span>
                  </button>
                );
              })}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
};

const Stat = ({ label, value, unit, col = '#fff', text = false }) => (
  <div>
    <div className="mono" style={{ fontSize: 9.5, letterSpacing: '.14em', color: 'rgba(255,255,255,.4)', textTransform: 'uppercase', marginBottom: 7 }}>{label}</div>
    <div className="serif" style={{ font: text ? '500 22px/1 Inter' : '500 28px/1 "Instrument Serif", serif', letterSpacing: '-.015em', color: col }}>
      {value}{unit && <span style={{ fontSize: 12, color: 'rgba(255,255,255,.4)', marginLeft: 4, fontFamily: 'Inter' }}>{unit}</span>}
    </div>
  </div>
);

const ClimateBar = ({ label, value, max, unit, color }) => {
  const pct = Math.min(100, (value / max) * 100);
  return (
    <div style={{ flex: 1 }}>
      <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 5 }}>
        <span style={{ font: '500 10.5px/1 Inter', color: 'rgba(255,255,255,.55)' }}>{label}</span>
        <span className="mono" style={{ fontSize: 11, color, fontWeight: 600 }}>{value}<span style={{ color: 'rgba(255,255,255,.35)', marginLeft: 2, fontWeight: 400, fontSize: 9 }}>{unit}</span></span>
      </div>
      <div style={{ height: 2, background: 'rgba(255,255,255,.06)', overflow: 'hidden' }}>
        <div style={{ height: '100%', width: `${pct}%`, background: color, transition: 'width .8s cubic-bezier(.22,.61,.36,1)' }}/>
      </div>
    </div>
  );
};

// ============================================================================
// Section 4 — Top provinces editorial list
// ============================================================================
const TopProvinces = () => {
  const [ref, inView] = useInView();
  const [filter, setFilter] = useState('all');
  const list = useMemo(() => {
    return [...TR_PROVINCES]
      .filter(p => filter === 'all' || p.topRes === filter)
      .sort((a, b) => b.score - a.score)
      .slice(0, 10);
  }, [filter]);

  return (
    <section id="iller" style={{ padding: '120px 48px 140px', position: 'relative' }} ref={ref}>
      <div style={{ maxWidth: 1500, margin: '0 auto' }}>
        <Reveal>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 24, marginBottom: 56 }}>
            <span className="mono" style={{ fontSize: 11, letterSpacing: '.18em', color: 'rgba(255,255,255,.4)', textTransform: 'uppercase' }}>03 — En verimli iller</span>
            <span style={{ flex: 1, height: 1, background: 'rgba(255,255,255,.1)' }}/>
            <div style={{ display: 'flex', gap: 6 }}>
              {[
                { id: 'all', label: 'Tümü', col: '#fff' },
                { id: 'solar', label: 'Güneş', col: '#F59E0B' },
                { id: 'wind', label: 'Rüzgâr', col: '#3B82F6' },
                { id: 'hydro', label: 'Hidro', col: '#06B6D4' },
              ].map(t => {
                const on = filter === t.id;
                return (
                  <button key={t.id} onClick={() => setFilter(t.id)} style={{
                    padding: '8px 14px', borderRadius: 999,
                    border: `1px solid ${on ? t.col + 'aa' : 'rgba(255,255,255,.14)'}`,
                    background: on ? t.col + '15' : 'transparent',
                    color: on ? t.col : 'rgba(255,255,255,.55)',
                    font: '500 11.5px/1 Inter', cursor: 'pointer',
                  }}>{t.label}</button>
                );
              })}
            </div>
          </div>
        </Reveal>

        <Reveal>
          <h2 className="serif" style={{ margin: '0 0 64px', font: '400 clamp(36px, 5vw, 72px)/1.05 "Instrument Serif", serif', letterSpacing: '-.02em' }}>
            Türkiye'nin en <span style={{ fontStyle: 'italic', color: '#2DD4BF' }}>verimli</span> on ili.
          </h2>
        </Reveal>

        <div style={{ display: 'flex', flexDirection: 'column' }}>
          {list.map((p, i) => {
            const region = TR_REGIONS.find(r => r.id === p.region);
            const c = TYPECOL[p.topRes];
            return (
              <Reveal key={p.id} delay={i * 70}>
                <div className="lift" style={{
                  display: 'grid', gridTemplateColumns: '70px 1fr 160px 140px 1fr 24px',
                  gap: 32, alignItems: 'center',
                  padding: '24px 4px',
                  borderTop: i === 0 ? '1px solid rgba(255,255,255,.12)' : 'none',
                  borderBottom: '1px solid rgba(255,255,255,.12)',
                  cursor: 'pointer',
                }}>
                  <span className="mono display" style={{ font: '500 18px/1 "Instrument Serif", serif', color: i < 3 ? c : 'rgba(255,255,255,.35)', letterSpacing: '-.02em' }}>
                    {String(i+1).padStart(2, '0')}
                  </span>
                  <div>
                    <div className="serif" style={{ font: '400 28px/1 "Instrument Serif", serif', letterSpacing: '-.01em' }}>{p.name}</div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 8 }}>
                      <span style={{ width: 5, height: 5, borderRadius: '50%', background: region.color }}/>
                      <span style={{ font: '500 11.5px/1 Inter', color: 'rgba(255,255,255,.5)' }}>{region.name}</span>
                    </div>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <span style={{ width: 8, height: 8, borderRadius: '50%', background: c }}/>
                    <span style={{ font: '500 12px/1 Inter', color: c }}>{TYPELBL[p.topRes]}</span>
                  </div>
                  <div className="mono" style={{ fontSize: 14, fontWeight: 600 }}>
                    {p.capacityMw}<span style={{ color: 'rgba(255,255,255,.4)', fontSize: 11, fontWeight: 400, marginLeft: 3 }}>MW</span>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                    <div style={{ flex: 1, height: 1, background: 'rgba(255,255,255,.08)' }}>
                      <div style={{ height: '100%', background: c, width: inView ? `${p.score}%` : '0%', transition: `width 1.4s cubic-bezier(.22,.61,.36,1) ${i*70}ms` }}/>
                    </div>
                    <span className="mono" style={{ fontSize: 12.5, color: c, fontWeight: 600, minWidth: 26, textAlign: 'right' }}>{p.score}</span>
                  </div>
                  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,.4)" strokeWidth="1.6"><path d="M5 12h14M13 5l7 7-7 7"/></svg>
                </div>
              </Reveal>
            );
          })}
        </div>
      </div>
    </section>
  );
};

// ============================================================================
// Section 5 — Potential vs realized (manifesto moment)
// ============================================================================
const PotentialMoment = () => {
  const [ref, inView] = useInView();
  const s = TR_STATS;
  const usedPct = (s.renewableMw / s.technicalPotentialMw) * 100;
  const pct = useCounter(usedPct, { start: inView, duration: 2400, decimals: 1 });
  const rows = [
    { type: 'solar', label: 'Güneş', cur: s.solarMw, pot: s.solarPotentialMw },
    { type: 'wind',  label: 'Rüzgâr', cur: s.windMw,  pot: s.windPotentialMw },
    { type: 'hydro', label: 'Hidro',  cur: s.hydroMw, pot: s.hydroPotentialMw },
  ];

  return (
    <section ref={ref} style={{ padding: '160px 48px 160px', position: 'relative', borderTop: '1px solid rgba(255,255,255,.06)', borderBottom: '1px solid rgba(255,255,255,.06)', background: 'linear-gradient(180deg, transparent, rgba(20,184,166,.025), transparent)' }}>
      <div style={{ maxWidth: 1500, margin: '0 auto' }}>
        <Reveal>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 24, marginBottom: 56 }}>
            <span className="mono" style={{ fontSize: 11, letterSpacing: '.18em', color: 'rgba(255,255,255,.4)', textTransform: 'uppercase' }}>04 — Potansiyel</span>
            <span style={{ flex: 1, height: 1, background: 'rgba(255,255,255,.1)' }}/>
          </div>
        </Reveal>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 80, alignItems: 'start' }}>
          <Reveal>
            <div>
              <div className="mono" style={{ fontSize: 11, letterSpacing: '.18em', textTransform: 'uppercase', color: 'rgba(255,255,255,.5)', marginBottom: 24 }}>Teknik potansiyel · {(s.technicalPotentialMw/1000).toFixed(0)} GW</div>
              <h2 className="serif display" style={{
                margin: 0,
                font: '400 clamp(80px, 14vw, 220px)/0.9 "Instrument Serif", serif',
                letterSpacing: '-.035em',
                color: '#2DD4BF',
              }}>%{pct.toFixed(1)}</h2>
              <div style={{ marginTop: 24, font: '400 22px/1.45 "Instrument Serif", serif', color: 'rgba(255,255,255,.85)', letterSpacing: '-.01em', fontStyle: 'italic' }}>
                Bu kadarını kullandık.<br/>
                Geri kalan <span style={{ color: '#fff', fontWeight: 500, fontStyle: 'normal' }}>%{(100-usedPct).toFixed(1)}</span> hâlâ orada.
              </div>
            </div>
          </Reveal>

          <Reveal delay={150}>
            <div>
              <p style={{ margin: '0 0 48px', font: '400 16px/1.6 Inter', color: 'rgba(255,255,255,.6)', maxWidth: 480 }}>
                Güneş, rüzgâr ve hidroelektrik için Türkiye'nin teknik kapasitesi <b className="mono" style={{ fontFamily: 'JetBrains Mono', color: '#fff' }}>{(s.technicalPotentialMw/1000).toFixed(0)} GW</b>'a yakın. Bugün kurulu olan, bunun çok küçük bir kısmı. Aşağıdaki üç çubuk, hangi kaynağın nerede olduğunu söylüyor.
              </p>

              <div style={{ display: 'flex', flexDirection: 'column', gap: 36 }}>
                {rows.map((r, i) => {
                  const c = TYPECOL[r.type];
                  const p = (r.cur / r.pot) * 100;
                  return (
                    <div key={r.type}>
                      <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 14 }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                          <span style={{ width: 8, height: 8, borderRadius: '50%', background: c }}/>
                          <span className="serif" style={{ font: '400 30px/1 "Instrument Serif", serif', letterSpacing: '-.015em' }}>{r.label}</span>
                        </div>
                        <div className="mono" style={{ fontSize: 12, color: 'rgba(255,255,255,.45)' }}>
                          {(r.cur/1000).toFixed(1)} / <span style={{ color: 'rgba(255,255,255,.85)' }}>{(r.pot/1000).toFixed(0)}</span> GW
                        </div>
                      </div>
                      <div style={{ position: 'relative', height: 4, background: 'rgba(255,255,255,.05)' }}>
                        <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: inView ? `${p}%` : 0, background: c, transition: `width 1.6s cubic-bezier(.22,.61,.36,1) ${300 + i*200}ms`, boxShadow: `0 0 18px ${c}88` }}/>
                      </div>
                      <div className="mono" style={{ fontSize: 11, color: c, marginTop: 8, letterSpacing: '.04em' }}>%{p.toFixed(1)} kullanıldı</div>
                    </div>
                  );
                })}
              </div>
            </div>
          </Reveal>
        </div>
      </div>
    </section>
  );
};

// ============================================================================
// Section 6 — 10-year trend
// ============================================================================
const TrendSection = () => {
  const [ref, inView] = useInView();
  const data = TR_STATS.capacityTrend;
  const W = 1100, H = 360, padL = 56, padR = 30, padT = 30, padB = 40;
  const w = W - padL - padR, h = H - padT - padB;
  const max = 130;
  const xStep = w / (data.length - 1);
  const xFor = i => padL + i * xStep;
  const yFor = v => padT + h - (v / max) * h;
  const totalPath = data.map((d, i) => `${i ? 'L' : 'M'} ${xFor(i)} ${yFor(d.total)}`).join(' ');
  const renPath = data.map((d, i) => `${i ? 'L' : 'M'} ${xFor(i)} ${yFor(d.renewable)}`).join(' ');
  const renArea = `${renPath} L ${xFor(data.length-1)} ${padT+h} L ${padL} ${padT+h} Z`;

  return (
    <section ref={ref} style={{ padding: '140px 48px 140px' }}>
      <div style={{ maxWidth: 1500, margin: '0 auto' }}>

        <Reveal>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 24, marginBottom: 56 }}>
            <span className="mono" style={{ fontSize: 11, letterSpacing: '.18em', color: 'rgba(255,255,255,.4)', textTransform: 'uppercase' }}>05 — On yıl</span>
            <span style={{ flex: 1, height: 1, background: 'rgba(255,255,255,.1)' }}/>
          </div>
        </Reveal>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1.6fr', gap: 64, alignItems: 'end', marginBottom: 56 }}>
          <Reveal>
            <h2 className="serif" style={{ margin: 0, font: '400 clamp(36px, 5vw, 72px)/1.05 "Instrument Serif", serif', letterSpacing: '-.02em' }}>
              On yılda<br/>
              <span style={{ fontStyle: 'italic', color: '#2DD4BF' }}>iki katına</span> çıktı.
            </h2>
          </Reveal>
          <Reveal delay={150}>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 28, paddingBottom: 12 }}>
              <div>
                <div className="mono" style={{ fontSize: 10, letterSpacing: '.14em', color: 'rgba(255,255,255,.4)', textTransform: 'uppercase', marginBottom: 10 }}>10 Yıllık Artış</div>
                <div className="serif" style={{ font: '400 44px/1 "Instrument Serif", serif', color: '#2DD4BF', letterSpacing: '-.02em' }}>+108<span style={{ fontSize: 18, color: 'rgba(255,255,255,.5)' }}>%</span></div>
              </div>
              <div>
                <div className="mono" style={{ fontSize: 10, letterSpacing: '.14em', color: 'rgba(255,255,255,.4)', textTransform: 'uppercase', marginBottom: 10 }}>2035 Hedefi</div>
                <div className="serif" style={{ font: '400 44px/1 "Instrument Serif", serif', letterSpacing: '-.02em' }}>220<span style={{ fontSize: 18, color: 'rgba(255,255,255,.5)', marginLeft: 4 }}>GW</span></div>
              </div>
              <div>
                <div className="mono" style={{ fontSize: 10, letterSpacing: '.14em', color: 'rgba(255,255,255,.4)', textTransform: 'uppercase', marginBottom: 10 }}>Yenil. Hedef</div>
                <div className="serif" style={{ font: '400 44px/1 "Instrument Serif", serif', color: '#2DD4BF', letterSpacing: '-.02em' }}>%75</div>
              </div>
            </div>
          </Reveal>
        </div>

        <Reveal>
          <div style={{ border: '1px solid rgba(255,255,255,.08)', padding: '24px 24px 0', position: 'relative', background: 'rgba(255,255,255,.01)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 14 }}>
              <div style={{ display: 'flex', gap: 24, font: '500 11.5px/1 Inter' }}>
                <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, color: 'rgba(255,255,255,.6)' }}><span style={{ width: 14, height: 0, borderTop: '1.6px dashed currentColor' }}/>Toplam kurulu güç</span>
                <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, color: '#2DD4BF' }}><span style={{ width: 14, height: 2, background: 'currentColor' }}/>Yenilenebilir</span>
              </div>
              <span className="mono" style={{ fontSize: 11, color: 'rgba(255,255,255,.4)' }}>2015 — 2024</span>
            </div>
            <svg viewBox={`0 0 ${W} ${H}`} style={{ width: '100%', height: 'auto', display: 'block' }}>
              <defs>
                <linearGradient id="trendArea" x1="0" x2="0" y1="0" y2="1">
                  <stop offset="0" stopColor="#2DD4BF" stopOpacity="0.35"/>
                  <stop offset="1" stopColor="#2DD4BF" stopOpacity="0"/>
                </linearGradient>
                <clipPath id="revealClip">
                  <rect x={padL} y={padT} width={inView ? w : 0} height={h}>
                    {inView && <animate attributeName="width" from="0" to={w} dur="2s" begin="0s" fill="freeze" calcMode="spline" keySplines="0.22 0.61 0.36 1"/>}
                  </rect>
                </clipPath>
              </defs>
              {/* grid */}
              {[0, 30, 60, 90, 120].map(v => (
                <g key={v}>
                  <line x1={padL} x2={W-padR} y1={yFor(v)} y2={yFor(v)} stroke="rgba(255,255,255,.05)"/>
                  <text x={padL-10} y={yFor(v)+4} textAnchor="end" fontSize="10.5" fill="rgba(255,255,255,.4)" fontFamily="JetBrains Mono">{v}</text>
                </g>
              ))}
              <text x={padL-30} y={padT+4} fontSize="9" fill="rgba(255,255,255,.4)" fontFamily="Inter">GW</text>
              <g clipPath="url(#revealClip)">
                <path d={renArea} fill="url(#trendArea)"/>
                <path d={renPath} fill="none" stroke="#2DD4BF" strokeWidth="2.5" strokeLinecap="round"/>
                <path d={totalPath} fill="none" stroke="rgba(255,255,255,.65)" strokeWidth="1.8" strokeDasharray="5 4" strokeLinecap="round"/>
              </g>
              {/* endpoints */}
              {inView && data.map((d, i) => i === data.length - 1 && (
                <g key={i}>
                  <circle cx={xFor(i)} cy={yFor(d.renewable)} r="5" fill="#2DD4BF" stroke="#06080C" strokeWidth="2.5"/>
                  <text x={xFor(i)+12} y={yFor(d.renewable)+4} fontSize="13" fill="#2DD4BF" fontFamily="JetBrains Mono" fontWeight="600">{d.renewable.toFixed(1)} GW</text>
                  <circle cx={xFor(i)} cy={yFor(d.total)} r="4" fill="rgba(255,255,255,.95)" stroke="#06080C" strokeWidth="2.5"/>
                  <text x={xFor(i)+12} y={yFor(d.total)-3} fontSize="13" fill="rgba(255,255,255,.95)" fontFamily="JetBrains Mono" fontWeight="600">{d.total.toFixed(1)} GW</text>
                </g>
              ))}
              {/* x labels */}
              {data.map((d, i) => (i % 2 === 0 || i === data.length-1) && (
                <text key={i} x={xFor(i)} y={padT+h+22} textAnchor="middle" fontSize="10.5" fill="rgba(255,255,255,.5)" fontFamily="JetBrains Mono">{d.year}</text>
              ))}
            </svg>
          </div>
        </Reveal>
      </div>
    </section>
  );
};

// ============================================================================
// Section 7 — CO2 / Impact manifesto
// ============================================================================
const ImpactSection = () => {
  const [ref, inView] = useInView();
  const co2 = useCounter(105.2, { start: inView, duration: 2400, decimals: 1 });
  const trees = useCounter(4780, { start: inView, duration: 2400, decimals: 0 });
  const cars = useCounter(12.5, { start: inView, duration: 2400, decimals: 1 });

  return (
    <section ref={ref} style={{ padding: '160px 48px 160px', position: 'relative', overflow: 'hidden' }}>
      <div className="drift1" style={{ position: 'absolute', width: 800, height: 800, right: '-20%', top: '-30%', borderRadius: '50%', background: 'radial-gradient(circle, rgba(45,212,191,.10), transparent 60%)', filter: 'blur(50px)', pointerEvents: 'none' }}/>

      <div style={{ maxWidth: 1500, margin: '0 auto', position: 'relative' }}>
        <Reveal>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 24, marginBottom: 56 }}>
            <span className="mono" style={{ fontSize: 11, letterSpacing: '.18em', color: 'rgba(255,255,255,.4)', textTransform: 'uppercase' }}>06 — Etki</span>
            <span style={{ flex: 1, height: 1, background: 'rgba(255,255,255,.1)' }}/>
          </div>
        </Reveal>

        <Reveal>
          <h2 className="serif" style={{ margin: 0, font: '400 clamp(48px, 8vw, 140px)/0.95 "Instrument Serif", serif', letterSpacing: '-.025em', maxWidth: 1400 }}>
            <span style={{ color: 'rgba(255,255,255,.5)' }}>Her yıl atmosfere girmeyen</span><br/>
            <span style={{ color: '#fff' }}>{co2.toFixed(1)} milyon ton</span> <span style={{ fontStyle: 'italic', color: '#2DD4BF' }}>karbondioksit.</span>
          </h2>
        </Reveal>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 64, marginTop: 96 }}>
          <Reveal delay={0}>
            <div>
              <div className="mono" style={{ fontSize: 10, letterSpacing: '.14em', color: 'rgba(255,255,255,.4)', textTransform: 'uppercase', marginBottom: 16 }}>≈ Eşdeğer</div>
              <div className="serif display" style={{ font: '400 80px/1 "Instrument Serif", serif', letterSpacing: '-.03em' }}>{cars.toFixed(1)}<span style={{ fontSize: 20, color: 'rgba(255,255,255,.5)', marginLeft: 6 }}>milyon</span></div>
              <div style={{ font: '400 14px/1.5 Inter', color: 'rgba(255,255,255,.55)', marginTop: 16 }}>Yoldan çekilmiş binek otomobil.</div>
            </div>
          </Reveal>
          <Reveal delay={120}>
            <div>
              <div className="mono" style={{ fontSize: 10, letterSpacing: '.14em', color: 'rgba(255,255,255,.4)', textTransform: 'uppercase', marginBottom: 16 }}>≈ Eşdeğer</div>
              <div className="serif display" style={{ font: '400 80px/1 "Instrument Serif", serif', letterSpacing: '-.03em', color: '#2DD4BF' }}>{Math.round(trees).toLocaleString('tr-TR')}<span style={{ fontSize: 20, color: 'rgba(255,255,255,.5)', marginLeft: 6 }}>milyon</span></div>
              <div style={{ font: '400 14px/1.5 Inter', color: 'rgba(255,255,255,.55)', marginTop: 16 }}>Yıllık karbon emen olgun ağaç.</div>
            </div>
          </Reveal>
          <Reveal delay={240}>
            <div>
              <div className="mono" style={{ fontSize: 10, letterSpacing: '.14em', color: 'rgba(255,255,255,.4)', textTransform: 'uppercase', marginBottom: 16 }}>2035 hedefine</div>
              <div className="serif display" style={{ font: '400 80px/1 "Instrument Serif", serif', letterSpacing: '-.03em', color: '#F5C77E' }}>+88<span style={{ fontSize: 20, color: 'rgba(255,255,255,.5)', marginLeft: 6 }}>%</span></div>
              <div style={{ font: '400 14px/1.5 Inter', color: 'rgba(255,255,255,.55)', marginTop: 16 }}>%75 yenilenebilir pay için bugünden hızlanmak.</div>
            </div>
          </Reveal>
        </div>
      </div>
    </section>
  );
};

// ============================================================================
// Section 8 — Drill-down access cards
// ============================================================================
const DrillCards = () => {
  const cards = [
    { id: 'region',   kicker: '02', title: 'Bölge Analizi',    sub: '7 coğrafi bölge · iklim profili · yatırım fırsatları', meta: '7 bölge', col: '#A855F7', img: 'card-region', ph: 'Coğrafi harita / topografya' },
    { id: 'province', kicker: '03', title: 'İl Analizi',       sub: '81 il · ilçe potansiyel haritası · en iyi sahalar',  meta: '81 il',   col: '#3B82F6', img: 'card-province', ph: 'Şehir silueti / gece manzarası' },
    { id: 'scenario', kicker: '04', title: 'Senaryo Raporu',   sub: 'Çoklu pin · portföy düzeyinde NPV / IRR / geri ödeme', meta: '4 senaryo', col: '#2DD4BF', img: 'card-scenario', ph: 'Veri / grafik / soyut görsel' },
    { id: 'plant',    kicker: '05', title: 'Santral Analizi',  sub: 'Pin bazlı · teknik + finans + risk profili',         meta: '14 santral', col: '#F59E0B', img: 'card-plant', ph: 'Yakın çekim türbin / panel' },
  ];
  return (
    <section id="senaryolar" style={{ padding: '120px 48px 120px' }}>
      <div style={{ maxWidth: 1500, margin: '0 auto' }}>
        <Reveal>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 24, marginBottom: 56 }}>
            <span className="mono" style={{ fontSize: 11, letterSpacing: '.18em', color: 'rgba(255,255,255,.4)', textTransform: 'uppercase' }}>07 — Derine in</span>
            <span style={{ flex: 1, height: 1, background: 'rgba(255,255,255,.1)' }}/>
          </div>
        </Reveal>
        <Reveal>
          <h2 className="serif" style={{ margin: '0 0 56px', font: '400 clamp(36px, 5vw, 72px)/1.05 "Instrument Serif", serif', letterSpacing: '-.02em', maxWidth: 1100 }}>
            Atlas'ı bir kez gör, sonra <span style={{ fontStyle: 'italic', color: 'rgba(255,255,255,.55)' }}>kendi sorularını sor.</span>
          </h2>
        </Reveal>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 1, background: 'rgba(255,255,255,.06)', border: '1px solid rgba(255,255,255,.08)' }}>
          {cards.map((c, i) => (
            <Reveal key={c.id} delay={i * 110}>
              <a href="#" style={{ textDecoration: 'none', color: 'inherit' }}>
                <div className="lift" style={{
                  padding: '32px 28px 36px', background: '#06080C', minHeight: 280,
                  display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
                  cursor: 'pointer', position: 'relative', overflow: 'hidden',
                }} data-cursor="hover">
                  <div className="card-img">
                    <image-slot id={c.img} placeholder={c.ph} shape="rect"></image-slot>
                  </div>
                  <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: 2, background: c.col, transform: 'scaleY(0)', transformOrigin: 'top', transition: 'transform .5s cubic-bezier(.22,.61,.36,1)', zIndex: 2 }} className="card-accent"/>
                  <div>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
                      <span className="mono" style={{ fontSize: 11, letterSpacing: '.14em', color: 'rgba(255,255,255,.35)' }}>{c.kicker}</span>
                      <span className="mono" style={{ fontSize: 10.5, color: c.col, padding: '4px 8px', background: c.col + '14', border: `1px solid ${c.col}44` }}>{c.meta}</span>
                    </div>
                    <h3 className="serif" style={{ margin: '32px 0 14px', font: '400 34px/1.05 "Instrument Serif", serif', letterSpacing: '-.02em' }}>{c.title}</h3>
                    <p style={{ margin: 0, font: '400 13.5px/1.55 Inter', color: 'rgba(255,255,255,.55)' }}>{c.sub}</p>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, font: '500 12px/1 Inter', color: c.col, marginTop: 24 }}>
                    Aç
                    <svg className="mag-arrow" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><path d="M5 12h14M13 5l7 7-7 7"/></svg>
                  </div>
                </div>
              </a>
            </Reveal>
          ))}
        </div>
        <style>{`.lift:hover .card-accent { transform: scaleY(1) !important; }`}</style>
      </div>
    </section>
  );
};

// ============================================================================
// Marquee data ticker
// ============================================================================
const Marquee = () => {
  const items = [
    `TÜRKİYE 2024 · ${(TR_STATS.totalInstalledMw/1000).toFixed(1)} GW KURULU`,
    `YENİLENEBİLİR · %${(TR_STATS.renewableShare*100).toFixed(0)}`,
    `HİDRO · ${(TR_STATS.hydroMw/1000).toFixed(1)} GW`,
    `GÜNEŞ · ${(TR_STATS.solarMw/1000).toFixed(1)} GW`,
    `RÜZGÂR · ${(TR_STATS.windMw/1000).toFixed(1)} GW`,
    `JEOTERMAL + BİYOKÜTLE · ${((TR_STATS.geothermalMw + TR_STATS.biomassMw)/1000).toFixed(1)} GW`,
    `CO₂ ÖNLENMESİ · ${(TR_STATS.co2AvoidedKtPerYear/1000).toFixed(1)} MT/YIL`,
    `HEDEF 2035 · ${TR_STATS.target2035Mw/1000} GW · %${TR_STATS.target2035RenewableShare*100}`,
    `KAYNAK · TEİAŞ · EPDK · PVGIS · ERA-5 · DSİ · MGM`,
  ];
  const all = [...items, ...items];
  return (
    <div style={{ borderTop: '1px solid rgba(255,255,255,.08)', borderBottom: '1px solid rgba(255,255,255,.08)', padding: '28px 0', overflow: 'hidden', background: '#080A10' }}>
      <div className="marquee-track">
        {all.map((t, i) => (
          <span key={i} className="mono" style={{ fontSize: 14, letterSpacing: '.06em', color: i % 2 === 0 ? 'rgba(255,255,255,.85)' : '#2DD4BF' }}>
            {t} <span style={{ color: 'rgba(255,255,255,.3)', margin: '0 30px' }}>◆</span>
          </span>
        ))}
      </div>
    </div>
  );
};

// ============================================================================
// Footer
// ============================================================================
const Footer = () => (
  <footer style={{ padding: '96px 48px 56px', position: 'relative' }}>
    <div style={{ maxWidth: 1500, margin: '0 auto' }}>
      <div style={{ display: 'grid', gridTemplateColumns: '1.6fr 1fr 1fr 1fr', gap: 48, marginBottom: 80 }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 24 }}>
            <div style={{ width: 32, height: 32, borderRadius: 8, background: 'linear-gradient(135deg, #F59E0B, #2DD4BF 55%, #3B82F6)', display: 'grid', placeItems: 'center' }}>
              <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="#06080C" strokeWidth="2.6" strokeLinecap="round"><path d="M12 3v18M3 12h18"/></svg>
            </div>
            <span style={{ font: '700 16px/1 Inter' }}>SRRP</span>
          </div>
          <p className="serif" style={{ margin: 0, font: '400 30px/1.2 "Instrument Serif", serif', letterSpacing: '-.015em', maxWidth: 420 }}>
            Türkiye'nin yenilenebilir <span style={{ fontStyle: 'italic', color: '#2DD4BF' }}>enerji atlası.</span>
          </p>
        </div>
        {[
          { title: 'Veri', items: ['TEİAŞ — şebeke verileri', 'EPDK — lisanslar', 'MGM — meteoroloji', 'PVGIS · ERA-5 — küresel ışınım/rüzgâr', 'DSİ — hidroloji'] },
          { title: 'Atlas', items: ['Bölgeler', 'İller', 'Senaryolar', 'Santraller', 'Hava analizi'] },
          { title: 'Kurum', items: ['Hakkında', 'Yöntem', 'Açık veri', 'İletişim', 'Basın'] },
        ].map(col => (
          <div key={col.title}>
            <div className="mono" style={{ fontSize: 10, letterSpacing: '.16em', color: 'rgba(255,255,255,.4)', textTransform: 'uppercase', marginBottom: 18 }}>{col.title}</div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              {col.items.map(i => (
                <a key={i} href="#" className="ul-link" style={{ font: '400 13.5px/1.4 Inter', color: 'rgba(255,255,255,.65)', textDecoration: 'none' }}>{i}</a>
              ))}
            </div>
          </div>
        ))}
      </div>

      <div style={{ paddingTop: 36, borderTop: '1px solid rgba(255,255,255,.08)', display: 'flex', alignItems: 'center', gap: 24 }}>
        <span className="mono" style={{ fontSize: 11, color: 'rgba(255,255,255,.4)', letterSpacing: '.06em' }}>© 2026 SRRP · Sürdürülebilir Enerji Atlası</span>
        <span style={{ flex: 1 }}/>
        <span className="mono" style={{ fontSize: 11, color: 'rgba(255,255,255,.4)', letterSpacing: '.06em' }}>{Math.round(TR_STATS.totalInstalledMw).toLocaleString('tr-TR')} MW · 2024 sonu</span>
        <span className="chip-live"><span className="pulse-dot" style={{ width: 6, height: 6, borderRadius: '50%', background: '#2DD4BF' }}/>Veri akıyor</span>
      </div>
    </div>
  </footer>
);

// ============================================================================
// Tweaks
// ============================================================================
const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "accent": "#2DD4BF",
  "showCursor": true,
  "showGrain": true,
  "intensity": "cinematic"
}/*EDITMODE-END*/;

const TweaksUI = () => {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);

  useLayoutEffect(() => {
    document.body.classList.toggle('has-custom-cursor', !!t.showCursor);
    document.body.classList.toggle('grain', !!t.showGrain);
    document.documentElement.style.setProperty('--accent', t.accent);
  }, [t.showCursor, t.showGrain, t.accent]);

  return (
    <TweaksPanel>
      <TweakSection title="Aksan rengi">
        <TweakColor value={t.accent} onChange={v => setTweak('accent', v)} options={['#2DD4BF', '#F59E0B', '#3B82F6', '#A855F7', '#F5C77E', '#EF4444']}/>
      </TweakSection>
      <TweakSection title="Sahne efektleri">
        <TweakToggle label="Özel imleç" value={t.showCursor} onChange={v => setTweak('showCursor', v)}/>
        <TweakToggle label="Film granı" value={t.showGrain} onChange={v => setTweak('showGrain', v)}/>
      </TweakSection>
    </TweaksPanel>
  );
};

// ============================================================================
// App
// ============================================================================
const App = () => (
  <>
    <FlowingBackground/>
    <Hero/>
    <NumbersSection/>
    <RegionMap/>
    <TopProvinces/>
    <PotentialMoment/>
    <TrendSection/>
    <ImpactSection/>
    <DrillCards/>
    <Marquee/>
    <Footer/>
    <TweaksUI/>
  </>
);

ReactDOM.createRoot(document.getElementById('root')).render(<App/>);
