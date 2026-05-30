// reports-views.jsx — Reports module: toolbar, TOC, section content, responsive shells

const { useState: useStateR, useMemo: useMemoR } = React;

// ===== Resource type color resolver (avoid CSS-var-in-SVG issues) =====
const TC = { solar: '#F59E0B', wind: '#3B82F6', hydro: '#06B6D4' };
const TLabel = { solar: 'Güneş', wind: 'Rüzgar', hydro: 'Hidro' };

// ===== Number formatters =====
const fmtMoney = (n) => {
  const m = n / 1e6;
  if (Math.abs(m) >= 1) return `$${m.toFixed(1)}M`;
  return `$${(n/1e3).toFixed(0)}K`;
};
const fmtNum = (n, d = 0) => n.toLocaleString('tr-TR', { maximumFractionDigits: d, minimumFractionDigits: d });

// ===== Section header =====
const SectionHeader = ({ num, title, subtitle, action }) => (
  <div style={{ display: 'flex', alignItems: 'flex-end', gap: 14, padding: '0 0 14px', borderBottom: '1px solid var(--border-2)', marginBottom: 18 }}>
    <div style={{ display: 'flex', alignItems: 'baseline', gap: 10, flex: 1, minWidth: 0 }}>
      <span style={{ font: '600 10.5px/1 var(--font-mono)', color: 'var(--accent)', letterSpacing: '.10em' }}>{num}</span>
      <h2 style={{ margin: 0, font: '700 22px/1.1 var(--font)', letterSpacing: '-.02em', color: 'var(--text)' }}>{title}</h2>
      {subtitle && <span style={{ font: '500 12px/1 var(--font)', color: 'var(--text-3)' }}>· {subtitle}</span>}
    </div>
    {action}
  </div>
);

// ===== Card =====
const ReportCard = ({ children, title, action, padding = 16, style }) => (
  <div style={{
    background: 'var(--card)',
    border: '1px solid var(--border)',
    borderRadius: 14,
    padding,
    ...style,
  }}>
    {title && (
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14 }}>
        <span className="label" style={{ flex: 1 }}>{title}</span>
        {action}
      </div>
    )}
    {children}
  </div>
);

// ===== Hero KPI tile =====
const HeroKpi = ({ label, value, unit, hint, accent = 'var(--text)', delta, deltaPositiveGood = true }) => (
  <div style={{
    padding: '18px 18px 16px',
    background: 'linear-gradient(180deg, rgba(255,255,255,.025), transparent)',
    border: '1px solid var(--border)',
    borderRadius: 14,
    minHeight: 120,
    display: 'flex', flexDirection: 'column', gap: 8,
  }}>
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
      <span className="label">{label}</span>
      {delta !== undefined && <Delta value={delta} positiveGood={deltaPositiveGood}/>}
    </div>
    <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
      <span className="tnum" style={{ font: '700 32px/1 var(--font)', color: accent, letterSpacing: '-.02em' }}>{value}</span>
      <span style={{ font: '500 13px/1 var(--font)', color: 'var(--text-3)' }}>{unit}</span>
    </div>
    {hint && <div style={{ font: '500 11px/1.4 var(--font)', color: 'var(--text-3)', marginTop: 'auto' }}>{hint}</div>}
  </div>
);

// ===== Shared report-tabs row (Landing / Bölge / İl / Senaryo / Santral) =====
const ReportTabsRow = ({ active }) => (
  <div style={{ display: 'flex', alignItems: 'center', gap: 4, padding: '0 24px', background: 'rgba(0,0,0,.18)', borderBottom: '1px solid var(--border-2)', flexShrink: 0 }}>
    {[
      { id: 'landing', label: 'Genel Bakış',     icon: 'globe' },
      { id: 'bolge',   label: 'Bölge Analizi',   icon: 'layers' },
      { id: 'il',      label: 'İl Analizi',      icon: 'pin' },
      { id: 'senaryo', label: 'Senaryo Raporu',  icon: 'cal' },
      { id: 'santral', label: 'Santral Analizi', icon: 'eq' },
    ].map(t => {
      const on = t.id === active;
      return (
        <button key={t.id} style={{
          padding: '12px 14px',
          background: 'transparent', border: 'none',
          borderBottom: on ? '2px solid var(--accent)' : '2px solid transparent',
          cursor: 'pointer',
          display: 'flex', alignItems: 'center', gap: 7,
          font: on ? '600 12.5px/1 var(--font)' : '500 12.5px/1 var(--font)',
          color: on ? 'var(--text)' : 'var(--text-3)',
          transition: 'color .15s, border-color .15s',
        }}>
          <Icon name={t.icon} size={13} color={on ? 'var(--accent)' : 'var(--text-3)'}/>{t.label}
        </button>
      );
    })}
  </div>
);

// ===== Toolbar (sticky top) =====
const ReportToolbar = ({ template, onTemplate, period, onPeriod, scenario, onScenario, compact = false }) => (
  <div style={{
    display: 'flex', alignItems: 'center', gap: 10,
    padding: compact ? '10px 14px' : '12px 20px',
    background: 'rgba(20,24,34,.92)',
    backdropFilter: 'blur(14px)',
    borderBottom: '1px solid var(--border)',
    flexShrink: 0,
  }}>
    {!compact && (
      <>
        <div style={{ display: 'flex', alignItems: 'center', gap: 7, font: '500 11.5px/1 var(--font)', color: 'var(--text-3)' }}>
          <Icon name="roi" size={12} color="var(--accent)"/>
          <span>Raporlar</span>
          <Icon name="chevR" size={10} color="var(--text-4)"/>
          <span>Senaryo Raporu</span>
          <Icon name="chevR" size={10} color="var(--text-4)"/>
          <span style={{ color: 'var(--text)', fontWeight: 600 }}>{scenario || 'Türkiye 2030 Yenilenebilir'}</span>
        </div>
        <div style={{ width: 1, height: 20, background: 'var(--border-2)', margin: '0 4px' }}/>
      </>
    )}
    {/* template */}
    <div className="seg" style={{ padding: 2 }}>
      {['Yatırımcı', 'Teknik', 'Yönetici'].map(t => (
        <button key={t} className={template === t ? 'on' : ''} onClick={() => onTemplate(t)} style={{ padding: '6px 10px', font: '500 11.5px/1 var(--font)' }}>{t}</button>
      ))}
    </div>
    {/* period */}
    <div className="seg" style={{ padding: 2 }}>
      {['12A', '5Y', '25Y'].map(t => (
        <button key={t} className={period === t ? 'on' : ''} onClick={() => onPeriod(t)} style={{ padding: '6px 10px', font: '500 11.5px/1 var(--font-mono)' }}>{t}</button>
      ))}
    </div>
    <div style={{ flex: 1 }}/>
    <button className="btn" style={{ padding: '7px 11px' }}><Icon name="cal" size={12} color="var(--text-2)"/> 2025 — 2050</button>
    <button className="btn" style={{ padding: '7px 11px' }}><Icon name="filter" size={12} color="var(--text-2)"/></button>
    <button className="btn" style={{ padding: '7px 11px' }}><Icon name="ext" size={12} color="var(--text-2)"/> PDF</button>
    <button className="btn btn-primary" style={{ padding: '7px 13px' }}>
      <Icon name="ext" size={12} color="#06201E"/> Paylaş
    </button>
  </div>
);

// ===== Left TOC =====
const TOC_ITEMS = [
  { id: 'ozet',        num: '01', label: 'Özet',           icon: 'spark' },
  { id: 'uretim',      num: '02', label: 'Üretim',          icon: 'eq' },
  { id: 'finans',      num: '03', label: 'Finans',          icon: 'finance' },
  { id: 'hassasiyet',  num: '04', label: 'Hassasiyet',      icon: 'roi' },
  { id: 'cevre',       num: '05', label: 'Çevresel Etki',   icon: 'water' },
  { id: 'config',      num: '06', label: 'Konfigürasyon',   icon: 'gear' },
];

const ReportTOC = ({ active, onJump, totals, progress = 0 }) => (
  <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: 'var(--bg-2)', borderRight: '1px solid var(--border)' }}>
    <div style={{ padding: '16px 16px 12px', borderBottom: '1px solid var(--border-2)' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
        <div className="label">İçindekiler</div>
        <span className="tnum" style={{ font: '500 10px/1 var(--font-mono)', color: 'var(--text-3)' }}>{Math.round(progress)}%</span>
      </div>
      {/* progress bar */}
      <div style={{ height: 3, background: 'rgba(255,255,255,.05)', borderRadius: 2, marginBottom: 12, overflow: 'hidden' }}>
        <div style={{ height: '100%', width: `${progress}%`, background: 'var(--accent)', borderRadius: 2, transition: 'width .15s' }}/>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
        {TOC_ITEMS.map(it => {
          const on = it.id === active;
          return (
            <button key={it.id} onClick={() => onJump(it.id)} style={{
              display: 'flex', alignItems: 'center', gap: 10,
              padding: '8px 10px',
              background: on ? 'rgba(20,184,166,.10)' : 'transparent',
              border: on ? '1px solid rgba(20,184,166,.35)' : '1px solid transparent',
              borderRadius: 8, cursor: 'pointer', textAlign: 'left',
              color: on ? 'var(--text)' : 'var(--text-2)',
              transition: 'background .15s',
              position: 'relative',
            }}>
              {on && <div style={{ position: 'absolute', left: -1, top: 4, bottom: 4, width: 2, background: 'var(--accent)', borderRadius: 1 }}/>}
              <span className="tnum" style={{ font: '600 10px/1 var(--font-mono)', color: on ? 'var(--accent)' : 'var(--text-3)', letterSpacing: '.08em', width: 18 }}>{it.num}</span>
              <span style={{ font: '500 12.5px/1 var(--font)', flex: 1 }}>{it.label}</span>
              {on && <Icon name="chevR" size={11} color="var(--accent)"/>}
            </button>
          );
        })}
      </div>
    </div>
    <div style={{ padding: 16, flex: 1 }}>
      <div className="label" style={{ marginBottom: 10 }}>Hızlı Bakış</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        <div>
          <div style={{ font: '500 10.5px/1 var(--font)', color: 'var(--text-3)' }}>NPV (25y)</div>
          <div className="tnum" style={{ font: '700 18px/1 var(--font)', color: 'var(--success)', marginTop: 4 }}>{fmtMoney(totals.npv)}</div>
        </div>
        <div>
          <div style={{ font: '500 10.5px/1 var(--font)', color: 'var(--text-3)' }}>Kapasite</div>
          <div className="tnum" style={{ font: '700 18px/1 var(--font)', color: 'var(--text)', marginTop: 4 }}>{fmtNum(totals.totalCap, 0)} <span style={{ font: '500 11px/1 var(--font)', color: 'var(--text-3)' }}>MW</span></div>
        </div>
        <div>
          <div style={{ font: '500 10.5px/1 var(--font)', color: 'var(--text-3)' }}>Yıllık Üretim</div>
          <div className="tnum" style={{ font: '700 18px/1 var(--font)', color: 'var(--text)', marginTop: 4 }}>{fmtNum(totals.annualGwh, 0)} <span style={{ font: '500 11px/1 var(--font)', color: 'var(--text-3)' }}>GWh</span></div>
        </div>
        <div style={{ marginTop: 4 }}>
          <div style={{ font: '500 10.5px/1 var(--font)', color: 'var(--text-3)', marginBottom: 6 }}>Kaynak Dağılımı</div>
          <MixBar segments={[
            { value: totals.byType.solar, color: TC.solar },
            { value: totals.byType.wind,  color: TC.wind  },
            { value: totals.byType.hydro, color: TC.hydro },
          ]}/>
          <div style={{ display: 'flex', gap: 8, marginTop: 6, font: '500 10px/1 var(--font)', color: 'var(--text-3)' }}>
            <span><span style={{ display: 'inline-block', width: 6, height: 6, borderRadius: '50%', background: TC.solar, marginRight: 4 }}/>{Math.round(totals.byType.solar/totals.totalCap*100)}%</span>
            <span><span style={{ display: 'inline-block', width: 6, height: 6, borderRadius: '50%', background: TC.wind, marginRight: 4 }}/>{Math.round(totals.byType.wind/totals.totalCap*100)}%</span>
            <span><span style={{ display: 'inline-block', width: 6, height: 6, borderRadius: '50%', background: TC.hydro, marginRight: 4 }}/>{Math.round(totals.byType.hydro/totals.totalCap*100)}%</span>
          </div>
        </div>
      </div>
    </div>
    <div style={{ padding: 12, borderTop: '1px solid var(--border-2)', display: 'flex', flexDirection: 'column', gap: 6 }}>
      <div style={{ font: '500 10px/1.3 var(--font)', color: 'var(--text-4)' }}>Son güncelleme</div>
      <div className="tnum" style={{ font: '500 11px/1 var(--font-mono)', color: 'var(--text-2)' }}>11 May 2026 · 14:32</div>
    </div>
  </div>
);

// ============================================================================
// SECTION 01 — ÖZET
// ============================================================================
const Section01_Ozet = ({ totals, pins, meta }) => {
  return (
    <section data-toc="ozet" data-screen-label="01 Özet">
      <SectionHeader num="01" title="Özet" subtitle={meta.description}
        action={<button className="btn" style={{ padding: '6px 11px' }}><Icon name="ext" size={11}/> Bu bölümü dışa aktar</button>}
      />
      {/* hero KPI row */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 16 }}>
        <HeroKpi label="Toplam Kapasite" value={fmtNum(totals.totalCap, 0)} unit="MW" hint={`${pins.length} saha · 7 il`} accent="var(--accent)" delta={+12.4}/>
        <HeroKpi label="Yıllık Üretim" value={fmtNum(totals.annualGwh, 0)} unit="GWh" hint={`${(totals.homesEquivalent/1000).toFixed(0)}K hane eşdeğeri`} delta={+3.2}/>
        <HeroKpi label="Net Bugünkü Değer" value={fmtMoney(totals.npv)} unit="25y" hint={`IRR ${(totals.irr*100).toFixed(1)}% · Geri ödeme ${totals.paybackYear}y`} accent="#10B981" delta={+8.1}/>
        <HeroKpi label="Kaçınılan CO₂" value={`${(totals.co2Avoided/1000).toFixed(0)}K`} unit="ton/yıl" hint={`≈ ${(totals.treesEquivalent/1000).toFixed(0)}K ağaç eşdeğeri`} accent="#10B981" delta={+5.8}/>
      </div>
      {/* map + mix */}
      <div style={{ display: 'grid', gridTemplateColumns: '1.55fr 1fr', gap: 12 }}>
        <ReportCard title="Coğrafi Dağılım" action={
          <div style={{ display: 'flex', gap: 6, fontFamily: 'var(--font-mono)', fontSize: 10.5 }}>
            <span className="chip">7 İL</span>
            <span className="chip">14 SAHA</span>
          </div>
        } padding={0} style={{ overflow: 'hidden' }}>
          <div style={{ position: 'relative', background: '#0E1219' }}>
            <ReportMiniMap pins={pins} height={300}/>
            {/* legend overlay */}
            <div style={{ position: 'absolute', left: 12, bottom: 12, display: 'flex', gap: 6, padding: '6px 10px', background: 'rgba(20,24,34,.85)', border: '1px solid var(--border)', borderRadius: 999, backdropFilter: 'blur(8px)' }}>
              {Object.entries(TC).map(([k, c]) => (
                <div key={k} style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
                  <div style={{ width: 8, height: 8, borderRadius: '50%', background: c }}/>
                  <span style={{ font: '500 10.5px/1 var(--font)', color: 'var(--text-2)' }}>{TLabel[k]}</span>
                </div>
              ))}
              <span style={{ font: '500 10px/1 var(--font)', color: 'var(--text-4)', marginLeft: 6 }}>· çap = kapasite</span>
            </div>
          </div>
        </ReportCard>

        <ReportCard title="Kaynak Karışımı">
          <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
            <DonutChart
              segments={[
                { value: totals.byType.solar, color: TC.solar },
                { value: totals.byType.wind,  color: TC.wind },
                { value: totals.byType.hydro, color: TC.hydro },
              ]}
              size={150} thickness={20}
              centerLabel="TOPLAM" centerValue={fmtNum(totals.totalCap, 0)} centerUnit="MW"
            />
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 12 }}>
              {[
                ['solar', 'Güneş Paneli', totals.byType.solar, totals.annualByType.solar],
                ['wind', 'Rüzgar Türbini', totals.byType.wind, totals.annualByType.wind],
                ['hydro', 'Hidroelektrik', totals.byType.hydro, totals.annualByType.hydro],
              ].map(([k, l, cap, gwh]) => (
                <div key={k}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 5 }}>
                    <div style={{ width: 9, height: 9, borderRadius: 2, background: TC[k] }}/>
                    <span style={{ font: '500 12px/1 var(--font)', color: 'var(--text-2)', flex: 1 }}>{l}</span>
                    <span className="tnum" style={{ font: '700 13px/1 var(--font)', color: 'var(--text)' }}>{fmtNum(cap, 0)}<span style={{ color: 'var(--text-3)', fontWeight: 500, fontSize: 10, marginLeft: 2 }}>MW</span></span>
                  </div>
                  <div style={{ height: 4, background: 'rgba(255,255,255,.06)', borderRadius: 2 }}>
                    <div style={{ height: '100%', width: `${(cap/totals.totalCap)*100}%`, background: TC[k], borderRadius: 2 }}/>
                  </div>
                  <div className="tnum" style={{ font: '500 10px/1 var(--font-mono)', color: 'var(--text-3)', marginTop: 4 }}>{fmtNum(gwh, 0)} GWh/yıl</div>
                </div>
              ))}
            </div>
          </div>
          <div style={{ marginTop: 14, paddingTop: 12, borderTop: '1px dashed var(--border-2)', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
            <div>
              <div style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)' }}>LCOE</div>
              <div className="tnum" style={{ font: '700 16px/1 var(--font)', marginTop: 4 }}>${totals.lcoe.toFixed(3)}<span style={{ fontSize: 10, color: 'var(--text-3)', fontWeight: 500, marginLeft: 2 }}>/kWh</span></div>
            </div>
            <div>
              <div style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)' }}>Kapasite Faktörü</div>
              <div className="tnum" style={{ font: '700 16px/1 var(--font)', marginTop: 4 }}>%29.7</div>
            </div>
          </div>
        </ReportCard>
      </div>
    </section>
  );
};

// ============================================================================
// SECTION 02 — ÜRETİM
// ============================================================================
const Section02_Uretim = ({ totals, pins }) => {
  const peakMonth = (() => {
    let max = 0, idx = 0;
    for (let i = 0; i < 12; i++) {
      const total = MONTHLY_BY_TYPE.solar[i] + MONTHLY_BY_TYPE.wind[i] + MONTHLY_BY_TYPE.hydro[i];
      if (total > max) { max = total; idx = i; }
    }
    return ['Ocak','Şubat','Mart','Nisan','Mayıs','Haziran','Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'][idx];
  })();
  return (
    <section data-toc="uretim" data-screen-label="02 Üretim" style={{ marginTop: 40 }}>
      <SectionHeader num="02" title="Üretim" subtitle="Aylık · günlük · saha bazında"
        action={
          <div style={{ display: 'flex', gap: 6 }}>
            <span className="chip">PVGIS · TS</span>
            <span className="chip">ERA-5 · Rüzgar</span>
          </div>
        }
      />
      <div style={{ display: 'grid', gridTemplateColumns: '1.55fr 1fr', gap: 12, marginBottom: 12 }}>
        <ReportCard title="Aylık Üretim · Kaynak Tipine Göre"
          action={<div style={{ display: 'flex', gap: 10, font: '500 11px/1 var(--font)' }}>
            {Object.entries(TC).map(([k, c]) => (
              <span key={k} style={{ display: 'inline-flex', alignItems: 'center', gap: 5, color: 'var(--text-2)' }}>
                <span style={{ width: 9, height: 9, borderRadius: 2, background: c }}/>{TLabel[k]}
              </span>
            ))}
          </div>}>
          <StackedMonthlyBars data={MONTHLY_BY_TYPE} height={240}/>
          <div style={{ marginTop: 10, paddingTop: 10, borderTop: '1px dashed var(--border-2)', display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10 }}>
            <div>
              <div className="label">Pik Ay</div>
              <div className="tnum" style={{ font: '700 14px/1 var(--font)', marginTop: 4 }}>{peakMonth}</div>
            </div>
            <div>
              <div className="label">Yaz / Kış Oranı</div>
              <div className="tnum" style={{ font: '700 14px/1 var(--font)', marginTop: 4 }}>1.42×</div>
            </div>
            <div>
              <div className="label">Yıllık Değişkenlik</div>
              <div className="tnum" style={{ font: '700 14px/1 var(--font)', marginTop: 4 }}>±8.6%</div>
            </div>
          </div>
        </ReportCard>
        <ReportCard title="Saha Bazlı Performans" padding={14}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6, maxHeight: 280, overflow: 'auto' }} className="scroll">
            {pins.slice(0, 9).map(p => {
              const c = TC[p.type];
              return (
                <div key={p.id} style={{ display: 'flex', alignItems: 'center', gap: 9, padding: '7px 8px', background: 'rgba(0,0,0,.18)', border: '1px solid var(--border-2)', borderRadius: 8 }}>
                  <div style={{ width: 22, height: 22, borderRadius: 6, background: `${c}22`, display: 'grid', placeItems: 'center', flexShrink: 0 }}>
                    <TypeIcon type={p.type} size={11} color={c}/>
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ font: '600 11.5px/1.2 var(--font)', color: 'var(--text)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{p.name}</div>
                    <div className="tnum" style={{ font: '500 10px/1.2 var(--font-mono)', color: 'var(--text-3)', marginTop: 2 }}>{p.capacityMw} MW · {(p.annualKwh/1e6).toFixed(0)} GWh</div>
                  </div>
                  <Sparkline data={p.monthly} color={c} width={42} height={16}/>
                </div>
              );
            })}
          </div>
        </ReportCard>
      </div>
      <ReportCard title="Günlük Üretim Takvimi · 2025"
        action={<div className="tnum" style={{ font: '500 11px/1 var(--font-mono)', color: 'var(--text-3)' }}>365 gün · normalize edilmiş</div>}>
        <HeatmapCalendar data={HEATMAP_DAYS} height={130}/>
        <div style={{ marginTop: 6, display: 'flex', justifyContent: 'space-between', font: '500 11px/1.4 var(--font)', color: 'var(--text-3)' }}>
          <span>En verimli sezon: <b style={{ color: 'var(--text)' }}>Mayıs — Temmuz</b> (yaz pik üretimi: güneş + hidro)</span>
          <span className="tnum" style={{ fontFamily: 'var(--font-mono)' }}>P90 ≥ 2.34 GWh/gün</span>
        </div>
      </ReportCard>
      {/* hourly profile + loss waterfall */}
      <div style={{ display: 'grid', gridTemplateColumns: '1.3fr 1fr', gap: 12, marginTop: 12 }}>
        <ReportCard title="Tipik Gün Profili · 24 Saat"
          action={<div style={{ display: 'flex', gap: 10, font: '500 10.5px/1 var(--font)' }}>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, color: '#F59E0B' }}><span style={{ width: 12, height: 2, background: '#F59E0B' }}/>Güneş</span>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, color: '#3B82F6' }}><span style={{ width: 12, height: 2, background: '#3B82F6' }}/>Rüzgar</span>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, color: '#06B6D4' }}><span style={{ width: 12, height: 1.5, borderTop: '1.5px dashed #06B6D4' }}/>Hidro</span>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, color: 'var(--text-3)' }}><span style={{ width: 12, height: 1.5, borderTop: '1.5px dashed currentColor' }}/>Talep</span>
          </div>}>
          <HourlyProfile height={220}/>
          <div style={{ marginTop: 8, padding: 9, background: 'rgba(0,0,0,.18)', borderRadius: 8, font: '500 11.5px/1.5 var(--font)', color: 'var(--text-2)' }}>
            <Icon name="info" size={11} color="var(--text-3)"/> Güneş üretimi 12:30'da pik yapar; rüzgar gece ve sabah erken saatlerde yüksektir. Hidro <b>baseload</b> sağlar. Bu profil portföyün geçici karakterini gösterir.
          </div>
        </ReportCard>
        <ReportCard title="Üretim Kayıpları · Teorik → Gerçek"
          action={<span className="chip" style={{ borderColor: 'rgba(16,185,129,.30)', color: '#10B981' }}>%89.7 PR</span>}>
          <LossWaterfall height={220} width={420}/>
        </ReportCard>
      </div>
    </section>
  );
};

// ============================================================================
// SECTION 03 — FİNANS
// ============================================================================
const Section03_Finans = ({ totals, meta }) => {
  const waterfallItems = [
    { label: 'Yatırım',     note: 'CAPEX',     value: totals.investment,                  type: 'out' },
    { label: 'Brüt Gelir',  note: '25y · enflasyonlu', value: totals.annualRevenue * 25 * 1.34, type: 'in' },
    { label: 'O&M Gideri',  note: '14% rev.',  value: totals.annualOpex * 25 * 1.34,      type: 'out' },
    { label: 'Vergi/Sigorta', note: 'Tahmini', value: totals.annualRevenue * 25 * 0.08,   type: 'out' },
    { label: 'Hurda Değer', note: 'Yıl 25',    value: totals.investment * 0.08,           type: 'in' },
    { label: 'Net Akış',    note: 'İskontosuz', value: totals.cumCash[25],                type: 'total' },
  ];
  return (
    <section data-toc="finans" data-screen-label="03 Finans" style={{ marginTop: 40 }}>
      <SectionHeader num="03" title="Finans" subtitle={`İskonto: %${(meta.discountRate*100).toFixed(1)} · Süre: ${meta.horizonYears}y`}
        action={<div style={{ display: 'flex', gap: 6 }}><span className="chip">USD</span><span className="chip">$0.072/kWh</span></div>}
      />
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 10, marginBottom: 12 }}>
        {[
          ['NPV (25y)', fmtMoney(totals.npv), '$M', 'var(--success)'],
          ['IRR', `${(totals.irr*100).toFixed(1)}%`, '', 'var(--text)'],
          ['LCOE', `$${totals.lcoe.toFixed(3)}`, '/kWh', 'var(--text)'],
          ['Geri Ödeme', `${totals.paybackYear}`, 'yıl', 'var(--text)'],
          ['Yatırım', fmtMoney(totals.investment), 'CAPEX', 'var(--text)'],
        ].map(([l, v, u, col]) => (
          <div key={l} style={{ padding: '12px 14px', background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12 }}>
            <div className="label">{l}</div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 4, marginTop: 6 }}>
              <span className="tnum" style={{ font: '700 22px/1 var(--font)', color: col, letterSpacing: '-.02em' }}>{v}</span>
              {u && <span style={{ font: '500 11px/1 var(--font)', color: 'var(--text-3)' }}>{u}</span>}
            </div>
          </div>
        ))}
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
        <ReportCard title="Kümülatif Nakit Akışı · 25 Yıl (P50/P90 bantlı)">
          <FanAreaChart data={CASHFLOW_SERIES} paybackYear={totals.paybackYear} height={240}/>
        </ReportCard>
        <ReportCard title="Finansal Akış Dökümü · Waterfall">
          <Waterfall items={waterfallItems} height={220}/>
        </ReportCard>
      </div>
      <ReportCard title="Saha Bazlı Finansal Performans" padding={0} style={{ marginTop: 12 }}>
        <div style={{ overflow: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontFamily: 'var(--font)' }}>
            <thead>
              <tr style={{ background: 'rgba(0,0,0,.20)' }}>
                {['Saha', 'Tip', 'Konum', 'Kapasite', 'Yıllık Ür.', 'Yatırım', 'NPV', 'IRR', 'Geri Öd.'].map((h, i) => (
                  <th key={h} style={{ textAlign: i < 3 ? 'left' : 'right', padding: '10px 14px', font: '600 10.5px/1 var(--font)', color: 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '.06em', borderBottom: '1px solid var(--border-2)' }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {REPORT_PINS.map((p, i) => {
                const c = TC[p.type];
                const capex = p.capacityMw * meta.capexPerMw[p.type];
                const npv = capex * (1.5 + Math.sin(p.id) * 0.6);
                return (
                  <tr key={p.id} style={{ background: i % 2 ? 'rgba(255,255,255,.01)' : 'transparent' }}>
                    <td style={{ padding: '10px 14px', font: '500 12.5px/1.2 var(--font)', color: 'var(--text)', borderBottom: '1px solid var(--border-2)' }}>{p.name}</td>
                    <td style={{ padding: '10px 14px', borderBottom: '1px solid var(--border-2)' }}>
                      <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, padding: '3px 7px', background: `${c}22`, border: `1px solid ${c}44`, borderRadius: 999, font: '600 10px/1 var(--font)', color: c }}>
                        <TypeIcon type={p.type} size={9} color={c}/>{TLabel[p.type]}
                      </span>
                    </td>
                    <td style={{ padding: '10px 14px', font: '500 11.5px/1.2 var(--font)', color: 'var(--text-2)', borderBottom: '1px solid var(--border-2)' }}>{p.district}, {p.city}</td>
                    <td className="tnum" style={{ padding: '10px 14px', font: '500 12px/1 var(--font-mono)', color: 'var(--text)', textAlign: 'right', borderBottom: '1px solid var(--border-2)' }}>{p.capacityMw.toFixed(1)} MW</td>
                    <td className="tnum" style={{ padding: '10px 14px', font: '500 12px/1 var(--font-mono)', color: 'var(--text)', textAlign: 'right', borderBottom: '1px solid var(--border-2)' }}>{(p.annualKwh/1e6).toFixed(1)} GWh</td>
                    <td className="tnum" style={{ padding: '10px 14px', font: '500 12px/1 var(--font-mono)', color: 'var(--text-2)', textAlign: 'right', borderBottom: '1px solid var(--border-2)' }}>{fmtMoney(capex)}</td>
                    <td className="tnum" style={{ padding: '10px 14px', font: '600 12px/1 var(--font-mono)', color: npv > 0 ? 'var(--success)' : 'var(--danger)', textAlign: 'right', borderBottom: '1px solid var(--border-2)' }}>{fmtMoney(npv)}</td>
                    <td className="tnum" style={{ padding: '10px 14px', font: '500 12px/1 var(--font-mono)', color: 'var(--text)', textAlign: 'right', borderBottom: '1px solid var(--border-2)' }}>{(p.capacityFactor * 42 + 5).toFixed(1)}%</td>
                    <td className="tnum" style={{ padding: '10px 14px', font: '500 12px/1 var(--font-mono)', color: 'var(--text)', textAlign: 'right', borderBottom: '1px solid var(--border-2)' }}>{p.roi.toFixed(1)}y</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </ReportCard>
    </section>
  );
};

// ============================================================================
// SECTION 05 — ÇEVRESEL ETKİ
// ============================================================================
const Section05_Cevre = ({ totals }) => {
  return (
    <section data-toc="cevre" data-screen-label="05 Çevresel Etki" style={{ marginTop: 40 }}>
      <SectionHeader num="05" title="Çevresel Etki" subtitle="Yıllık · ulusal şebeke karbon yoğunluğuna göre (0.689 kg CO₂/kWh)"
        action={<span className="chip">Kaynak: TEİAŞ 2024</span>}
      />
      <div style={{ display: 'grid', gridTemplateColumns: '1.2fr 1fr 1fr 1fr', gap: 12 }}>
        <ReportCard title="Kaçınılan Sera Gazı" padding={20} style={{ background: 'linear-gradient(160deg, rgba(16,185,129,.10), rgba(20,184,166,.04))', borderColor: 'rgba(16,185,129,.25)' }}>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
            <span className="tnum" style={{ font: '700 44px/1 var(--font)', color: '#10B981', letterSpacing: '-.03em' }}>{(totals.co2Avoided/1000).toFixed(0)}K</span>
            <span style={{ font: '600 16px/1 var(--font)', color: 'var(--text-2)' }}>ton CO₂</span>
            <span style={{ font: '500 12px/1 var(--font)', color: 'var(--text-3)' }}>/yıl</span>
          </div>
          <div style={{ marginTop: 14, padding: '10px 0', borderTop: '1px dashed var(--border-2)', display: 'flex', alignItems: 'center', gap: 8, font: '500 12px/1.4 var(--font)', color: 'var(--text-2)' }}>
            <Icon name="check2" size={14} color="#10B981"/>
            <span>25 yıl boyunca toplam <b className="tnum" style={{ color: '#10B981' }}>{(totals.co2Avoided * 25 / 1e6).toFixed(1)}M ton</b> CO₂ önlenir</span>
          </div>
          <div style={{ marginTop: 12, font: '500 11px/1.4 var(--font)', color: 'var(--text-3)' }}>
            Türkiye'nin 2024 toplam elektrik sektörü emisyonunun yaklaşık <b className="tnum" style={{ color: 'var(--text-2)' }}>%0.31</b>'i.
          </div>
        </ReportCard>
        {[
          { icon: 'globe', val: `${(totals.homesEquivalent/1000).toFixed(0)}K`, lbl: 'Hane Eşdeğeri', sub: 'yıllık elektrik tüketimi' },
          { icon: 'water', val: `${(totals.treesEquivalent/1000).toFixed(0)}K`, lbl: 'Ağaç Eşdeğeri', sub: 'yıllık karbon yutağı' },
          { icon: 'roi',   val: `${(totals.co2Avoided/4.6/1000).toFixed(0)}K`, lbl: 'Araç Eşdeğeri', sub: 'yoldan kaldırılmış' },
        ].map(it => (
          <ReportCard key={it.lbl} padding={18}>
            <div style={{ display: 'flex', alignItems: 'flex-start', gap: 10 }}>
              <div style={{ width: 36, height: 36, borderRadius: 9, background: 'rgba(16,185,129,.10)', border: '1px solid rgba(16,185,129,.30)', display: 'grid', placeItems: 'center', flexShrink: 0 }}>
                <Icon name={it.icon} size={17} color="#10B981"/>
              </div>
              <div style={{ flex: 1 }}>
                <div className="label">{it.lbl}</div>
                <div className="tnum" style={{ font: '700 26px/1 var(--font)', marginTop: 6, letterSpacing: '-.02em' }}>{it.val}</div>
                <div style={{ font: '500 11px/1.3 var(--font)', color: 'var(--text-3)', marginTop: 5 }}>{it.sub}</div>
              </div>
            </div>
          </ReportCard>
        ))}
      </div>
      <ReportCard title="Şebeke Karşılaştırması" style={{ marginTop: 12 }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 18, alignItems: 'center' }}>
          <div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              {[
                ['Bu Senaryo',     '0.00', 'kg CO₂/kWh', 'var(--accent)', 0.00],
                ['Doğalgaz',       '0.42', 'kg CO₂/kWh', '#94A3B8',       0.42],
                ['Ulusal Şebeke',  '0.69', 'kg CO₂/kWh', '#94A3B8',       0.69],
                ['Linyit',         '1.21', 'kg CO₂/kWh', '#94A3B8',       1.21],
              ].map(([l, v, u, col, ratio]) => (
                <div key={l}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 5 }}>
                    <span style={{ font: '500 12px/1 var(--font)', color: l === 'Bu Senaryo' ? 'var(--text)' : 'var(--text-2)', fontWeight: l === 'Bu Senaryo' ? 600 : 500, flex: 1 }}>{l}</span>
                    <span className="tnum" style={{ font: '700 13px/1 var(--font)', color: col }}>{v}</span>
                    <span style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)' }}>{u}</span>
                  </div>
                  <div style={{ height: 6, background: 'rgba(255,255,255,.06)', borderRadius: 3, overflow: 'hidden' }}>
                    <div style={{ height: '100%', width: `${(ratio/1.21)*100}%`, background: col, borderRadius: 3 }}/>
                  </div>
                </div>
              ))}
            </div>
          </div>
          <div style={{ padding: 16, background: 'rgba(0,0,0,.18)', border: '1px solid var(--border-2)', borderRadius: 10 }}>
            <div style={{ font: '600 12px/1.3 var(--font)', color: 'var(--text-2)', marginBottom: 10 }}>SDG Uyum Profili</div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {[
                ['SDG 7',  'Erişilebilir Temiz Enerji', 'tam'],
                ['SDG 13', 'İklim Eylemi', 'tam'],
                ['SDG 9',  'Sanayi & Altyapı', 'kısmi'],
                ['SDG 11', 'Sürdürülebilir Şehirler', 'kısmi'],
                ['SDG 15', 'Karasal Yaşam', 'koruma'],
              ].map(([n, l, s]) => (
                <div key={n} style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
                  <span className="tnum" style={{ font: '700 10.5px/1 var(--font-mono)', color: 'var(--accent)', width: 38 }}>{n}</span>
                  <span style={{ font: '500 11.5px/1 var(--font)', color: 'var(--text-2)', flex: 1 }}>{l}</span>
                  <span style={{ font: '600 9.5px/1 var(--font)', color: s === 'tam' ? '#10B981' : s === 'kısmi' ? '#F59E0B' : 'var(--text-3)', textTransform: 'uppercase', letterSpacing: '.08em' }}>{s}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </ReportCard>
    </section>
  );
};

// ============================================================================
// SECTION 06 — KONFİGÜRASYON (short)
// ============================================================================
const Section06_Config = ({ meta }) => (
  <section data-toc="config" data-screen-label="06 Konfigürasyon" style={{ marginTop: 40 }}>
    <SectionHeader num="06" title="Konfigürasyon & Varsayımlar" subtitle="Hesaplamalarda kullanılan parametreler"/>
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12 }}>
      <ReportCard title="Finansal">
        <div style={{ display: 'flex', flexDirection: 'column', gap: 9 }}>
          {[
            ['İskonto oranı', `%${(meta.discountRate*100).toFixed(1)}`],
            ['Elektrik fiyatı', `${meta.electricityPrice} ₺/kWh`],
            ['Eskalasyon', `%${(meta.escalation*100).toFixed(1)}/y`],
            ['O&M oranı', `%${(meta.opexPctOfRevenue*100).toFixed(0)} gelir`],
            ['Projeksiyon', `${meta.horizonYears} yıl`],
          ].map(([k, v]) => (
            <div key={k} style={{ display: 'flex', justifyContent: 'space-between', font: '500 12px/1.3 var(--font)' }}>
              <span style={{ color: 'var(--text-3)' }}>{k}</span>
              <span className="tnum" style={{ color: 'var(--text)', fontFamily: 'var(--font-mono)', fontWeight: 600 }}>{v}</span>
            </div>
          ))}
        </div>
      </ReportCard>
      <ReportCard title="CAPEX Birim Maliyetleri">
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {Object.entries(meta.capexPerMw).map(([k, v]) => (
            <div key={k} style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
              <div style={{ width: 22, height: 22, borderRadius: 6, background: `${TC[k]}22`, display: 'grid', placeItems: 'center' }}>
                <TypeIcon type={k} size={11} color={TC[k]}/>
              </div>
              <span style={{ font: '500 12px/1 var(--font)', color: 'var(--text-2)', flex: 1 }}>{TLabel[k]}</span>
              <span className="tnum" style={{ font: '600 12px/1 var(--font-mono)', color: 'var(--text)' }}>${(v/1e6).toFixed(2)}M<span style={{ color: 'var(--text-3)', fontWeight: 500, marginLeft: 2 }}>/MW</span></span>
            </div>
          ))}
        </div>
      </ReportCard>
      <ReportCard title="Veri Kaynakları">
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {[
            ['PVGIS · v5.2', 'Güneş ışınımı'],
            ['ERA-5 · ECMWF', 'Rüzgar profili'],
            ['DSİ · 2024', 'Hidrolojik veri'],
            ['TEİAŞ · 2024', 'Grid karbon yoğunluğu'],
            ['EPDK · 2025', 'Tarife'],
          ].map(([s, l]) => (
            <div key={s} style={{ display: 'flex', alignItems: 'center', gap: 9, padding: '6px 0', borderBottom: '1px dashed var(--border-2)' }}>
              <span className="tnum" style={{ font: '600 10px/1 var(--font-mono)', color: 'var(--accent)', minWidth: 96 }}>{s}</span>
              <span style={{ font: '500 11.5px/1 var(--font)', color: 'var(--text-2)' }}>{l}</span>
            </div>
          ))}
        </div>
      </ReportCard>
    </div>
  </section>
);

Object.assign(window, { TC, TLabel, fmtMoney, fmtNum, ReportToolbar, ReportTabsRow, ReportTOC, TOC_ITEMS, Section01_Ozet, Section02_Uretim, Section03_Finans, Section05_Cevre, Section06_Config, SectionHeader, ReportCard, HeroKpi });
