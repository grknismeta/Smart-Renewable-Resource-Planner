// reports-extras.jsx — SmartInsights, Hassasiyet (Sensitivity), Comparison, Print modes

const { useState: useStateE, useEffect: useEffectE, useRef: useRefE } = React;

// ============================================================================
// SMART INSIGHTS — auto-generated narrative + recommendations
// ============================================================================
const SmartInsights = ({ totals, pins, meta, compact = false }) => {
  // Compute insights from the data
  const bestPin = [...pins].sort((a, b) => (b.capacityFactor || 0.25) - (a.capacityFactor || 0.25))[0];
  const worstPin = [...pins].sort((a, b) => a.roi - b.roi)[0]; // best roi (lowest payback)
  const riskiest = pins.find(p => p.type === 'hydro' && p.name.includes('Çoruh')) || pins[pins.length - 1];
  const dominantType = Object.entries(totals.byType).sort((a, b) => b[1] - a[1])[0][0];

  const insights = [
    {
      tone: 'positive',
      icon: 'check2',
      title: 'Portföy sağlığı güçlü',
      body: <>NPV <b className="tnum" style={{ color: '#10B981' }}>{fmtMoney(totals.npv)}</b> ile %<b>{(totals.irr*100).toFixed(1)}</b> IRR sunuyor. Geri ödeme <b>{totals.paybackYear} yıl</b>, sektör ortalaması <b>9.1 yıl</b>'ın altında.</>
    },
    {
      tone: 'info',
      icon: 'spark',
      title: `En verimli saha: ${bestPin.name}`,
      body: <>Kapasite faktörü <b className="tnum">%{((bestPin.capacityFactor || 0.25)*100).toFixed(1)}</b>. Bu sahanın profili referans alınarak benzer bölgelerde yeni yatırımlar değerlendirilebilir.</>
    },
    {
      tone: 'warn',
      icon: 'warn',
      title: `${dominantType === 'solar' ? 'Güneş' : dominantType === 'wind' ? 'Rüzgar' : 'Hidro'} ağırlıklı portföy`,
      body: <>Kurulu gücün %<b>{Math.round(totals.byType[dominantType] / totals.totalCap * 100)}</b>'i tek kaynak tipinde. Mevsimsel üretim çeşitlendirmesi için karma artırılabilir.</>
    },
    {
      tone: 'warn',
      icon: 'info',
      title: 'YEKDEM sonrası tarife belirsizliği',
      body: <>2028 sonrası elektrik satış mekanizması netleşmediği için <b>%18</b>'lik bir gelir senaryosu yelpazesi bulunuyor. Hassasiyet analizine bakınız.</>
    },
  ];

  if (compact) {
    return (
      <div style={{ padding: 14, background: 'linear-gradient(135deg, rgba(20,184,166,.10), rgba(20,184,166,.02))', border: '1px solid rgba(20,184,166,.3)', borderRadius: 12 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
          <Icon name="spark" size={13} color="var(--accent)"/>
          <span style={{ font: '600 11px/1 var(--font)', color: 'var(--accent)', textTransform: 'uppercase', letterSpacing: '.08em' }}>AKILLI ÖZET</span>
        </div>
        <div style={{ font: '500 12.5px/1.55 var(--font)', color: 'var(--text-2)' }}>
          {insights[0].body} {insights[2].body}
        </div>
      </div>
    );
  }

  const toneColors = {
    positive: { bg: 'rgba(16,185,129,.07)', border: 'rgba(16,185,129,.30)', icon: '#10B981' },
    info:     { bg: 'rgba(20,184,166,.07)', border: 'rgba(20,184,166,.30)', icon: '#2DD4BF' },
    warn:     { bg: 'rgba(245,158,11,.07)', border: 'rgba(245,158,11,.30)', icon: '#F59E0B' },
  };

  return (
    <div style={{
      padding: 18,
      background: 'linear-gradient(135deg, rgba(20,184,166,.06), rgba(20,184,166,.01) 55%, transparent)',
      border: '1px solid var(--border)',
      borderRadius: 14, marginBottom: 22, position: 'relative',
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14 }}>
        <div style={{ width: 28, height: 28, borderRadius: 8, background: 'rgba(20,184,166,.14)', border: '1px solid rgba(20,184,166,.35)', display: 'grid', placeItems: 'center' }}>
          <Icon name="spark" size={14} color="var(--accent)"/>
        </div>
        <div style={{ flex: 1 }}>
          <div style={{ font: '600 13px/1 var(--font)', color: 'var(--text)', letterSpacing: '-.01em' }}>Akıllı Özet</div>
          <div style={{ font: '500 10.5px/1.4 var(--font)', color: 'var(--text-3)', marginTop: 4 }}>Veriden otomatik üretilmiş içgörüler · {meta.updatedAt} itibariyle</div>
        </div>
        <button className="btn" style={{ padding: '5px 9px', font: '500 10.5px/1 var(--font)' }}>
          <Icon name="ext" size={10}/> Tüm içgörüler
        </button>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10 }}>
        {insights.map((it, i) => {
          const c = toneColors[it.tone];
          return (
            <div key={i} style={{ padding: 12, background: c.bg, border: `1px solid ${c.border}`, borderRadius: 10 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginBottom: 8 }}>
                <Icon name={it.icon} size={12} color={c.icon}/>
                <span style={{ font: '600 11.5px/1.2 var(--font)', color: 'var(--text)', flex: 1 }}>{it.title}</span>
              </div>
              <div style={{ font: '500 11.5px/1.5 var(--font)', color: 'var(--text-2)' }}>{it.body}</div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

// ============================================================================
// SECTION — HASSASİYET ANALİZİ (Sensitivity)
// ============================================================================
const SensitivitySection = ({ totals, meta }) => {
  const baselineNpv = totals.npv / 1e6; // M$
  const [discountRate, setDiscountRate] = useStateE(meta.discountRate * 100);
  const [elecPrice, setElecPrice] = useStateE(meta.electricityPrice);
  const [capexMul, setCapexMul] = useStateE(100);
  const [escalation, setEscalation] = useStateE(meta.escalation * 100);

  // Simple sensitivity model
  const dDR = (discountRate - meta.discountRate * 100) / 100;
  const dEP = (elecPrice - meta.electricityPrice) / meta.electricityPrice;
  const dCX = (capexMul - 100) / 100;
  const dES = (escalation - meta.escalation * 100) / 100;
  const adjustedNpv = baselineNpv * (1 - dDR * 4.2) * (1 + dEP * 0.85) * (1 - dCX * 0.55) * (1 + dES * 1.8);
  const deltaPct = ((adjustedNpv - baselineNpv) / baselineNpv) * 100;

  const tornadoItems = [
    { label: 'Elektrik Fiyatı',  lowDelta: -22.4, highDelta: +24.8, lowLabel: '1.10₺/kWh', highLabel: '1.75₺/kWh' },
    { label: 'İskonto Oranı',    lowDelta: +18.2, highDelta: -16.5, lowLabel: '%6.0',       highLabel: '%11.0' },
    { label: 'Kapasite Faktörü', lowDelta: -14.6, highDelta: +14.2, lowLabel: '−%10',       highLabel: '+%10' },
    { label: 'CAPEX',            lowDelta: +12.8, highDelta: -13.1, lowLabel: '−%15',       highLabel: '+%15' },
    { label: 'Enflasyon Etkisi', lowDelta:  -8.4, highDelta:  +9.1, lowLabel: '%1.5',       highLabel: '%4.0' },
    { label: 'O&M Maliyeti',     lowDelta:  +4.2, highDelta:  -4.5, lowLabel: '%10 gelir',  highLabel: '%18 gelir' },
    { label: 'Şebeke Kayıpları', lowDelta:  +2.8, highDelta:  -3.2, lowLabel: '%2',         highLabel: '%5' },
  ];

  const Slider = ({ label, value, onChange, min, max, step, format, baseline }) => {
    const pct = ((value - min) / (max - min)) * 100;
    const basePct = ((baseline - min) / (max - min)) * 100;
    const isBase = Math.abs(value - baseline) < step / 2;
    return (
      <div style={{ padding: 10, background: 'rgba(0,0,0,.18)', border: '1px solid var(--border-2)', borderRadius: 9 }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginBottom: 8 }}>
          <span style={{ font: '500 11px/1 var(--font)', color: 'var(--text-2)', flex: 1 }}>{label}</span>
          <span className="tnum" style={{ font: '700 14px/1 var(--font)', color: isBase ? 'var(--text)' : 'var(--accent)' }}>{format(value)}</span>
          {!isBase && (
            <button onClick={() => onChange(baseline)} style={{ background: 'transparent', border: 'none', color: 'var(--text-3)', cursor: 'pointer', font: '500 10px/1 var(--font)' }}>↺</button>
          )}
        </div>
        <div style={{ position: 'relative', height: 18 }}>
          <div style={{ position: 'absolute', left: 0, right: 0, top: 7, height: 4, background: 'rgba(255,255,255,.06)', borderRadius: 2 }}>
            {/* baseline tick */}
            <div style={{ position: 'absolute', left: `${basePct}%`, top: -2, width: 2, height: 8, background: 'rgba(255,255,255,.30)', transform: 'translateX(-50%)' }}/>
            <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: `${pct}%`, background: isBase ? 'rgba(255,255,255,.20)' : 'var(--accent)', borderRadius: 2 }}/>
          </div>
          <input type="range" min={min} max={max} step={step} value={value} onChange={e => onChange(+e.target.value)}
            style={{ position: 'absolute', left: 0, right: 0, top: 0, bottom: 0, width: '100%', opacity: 0, cursor: 'grab' }}/>
          <div style={{ position: 'absolute', left: `${pct}%`, top: 1, transform: 'translateX(-50%)', width: 14, height: 14, borderRadius: '50%', background: 'white', boxShadow: '0 1px 4px rgba(0,0,0,.45)', pointerEvents: 'none' }}/>
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 5, font: '500 9.5px/1 var(--font-mono)', color: 'var(--text-4)' }}>
          <span>{format(min)}</span><span>{format(max)}</span>
        </div>
      </div>
    );
  };

  return (
    <section data-toc="hassasiyet" data-screen-label="04 Hassasiyet" style={{ marginTop: 40 }}>
      <SectionHeader num="04" title="Hassasiyet Analizi" subtitle="NPV'yi hangi parametre, ne kadar etkiliyor?"
        action={<span className="chip" style={{ borderColor: 'rgba(20,184,166,.35)', color: 'var(--accent)' }}>İNTERAKTİF · slider'ları kaydır</span>}
      />
      <div style={{ display: 'grid', gridTemplateColumns: '1.5fr 1fr', gap: 12 }}>
        <ReportCard title="Tornado Analizi · Baseline'a göre etki" padding={16}
          action={<span style={{ font: '500 10.5px/1.3 var(--font)', color: 'var(--text-3)' }}>
            <span style={{ display: 'inline-block', width: 9, height: 9, borderRadius: 2, background: '#EF4444', marginRight: 4 }}/>aşağı senaryo
            &nbsp;
            <span style={{ display: 'inline-block', width: 9, height: 9, borderRadius: 2, background: '#10B981', marginRight: 4 }}/>yukarı senaryo
          </span>}>
          <TornadoChart items={tornadoItems} baseline={baselineNpv} height={250}/>
          <div style={{ marginTop: 8, padding: 10, background: 'rgba(0,0,0,.18)', borderRadius: 8, font: '500 11.5px/1.5 var(--font)', color: 'var(--text-2)' }}>
            <Icon name="info" size={11} color="var(--text-3)"/> En etkili parametre: <b style={{ color: '#10B981' }}>Elektrik fiyatı</b> — %25 değişim NPV'yi yaklaşık $13.7M etkiler.
            En az duyarlı: <b style={{ color: 'var(--text)' }}>Şebeke kayıpları</b> (±%3).
          </div>
        </ReportCard>

        <ReportCard title="What-if Simülasyonu" padding={16}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <Slider label="İskonto Oranı" value={discountRate} onChange={setDiscountRate} min={5} max={14} step={0.1} format={v => `%${v.toFixed(1)}`} baseline={meta.discountRate * 100}/>
            <Slider label="Elektrik Fiyatı" value={elecPrice} onChange={setElecPrice} min={0.80} max={2.20} step={0.01} format={v => `${v.toFixed(2)}₺`} baseline={meta.electricityPrice}/>
            <Slider label="CAPEX Çarpanı" value={capexMul} onChange={setCapexMul} min={80} max={130} step={1} format={v => `%${v.toFixed(0)}`} baseline={100}/>
            <Slider label="Yıllık Eskalasyon" value={escalation} onChange={setEscalation} min={1} max={5} step={0.1} format={v => `%${v.toFixed(1)}`} baseline={meta.escalation * 100}/>
          </div>
          {/* result */}
          <div style={{ marginTop: 12, padding: 14, background: deltaPct >= 0 ? 'rgba(16,185,129,.08)' : 'rgba(239,68,68,.08)', border: deltaPct >= 0 ? '1px solid rgba(16,185,129,.30)' : '1px solid rgba(239,68,68,.30)', borderRadius: 10 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end' }}>
              <div>
                <div className="label">YENİ NPV (25y)</div>
                <div className="tnum" style={{ font: '700 26px/1 var(--font)', color: deltaPct >= 0 ? '#10B981' : '#EF4444', marginTop: 6, letterSpacing: '-.02em' }}>
                  ${adjustedNpv.toFixed(1)}M
                </div>
              </div>
              <div style={{ textAlign: 'right' }}>
                <div style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)' }}>vs Baseline ${baselineNpv.toFixed(1)}M</div>
                <div className="tnum" style={{ font: '700 18px/1 var(--font)', color: deltaPct >= 0 ? '#10B981' : '#EF4444', marginTop: 5 }}>
                  {deltaPct >= 0 ? '+' : ''}{deltaPct.toFixed(1)}%
                </div>
              </div>
            </div>
          </div>
        </ReportCard>
      </div>
    </section>
  );
};

// ============================================================================
// COMPARISON VIEW — Senaryo A vs B
// ============================================================================
const ALT_SCENARIO = {
  id: 's2', name: 'İç Anadolu Solar Portföy', color: '#F59E0B',
  totalCap: 92, annualGwh: 198,
  byType: { solar: 92, wind: 0, hydro: 0 },
  annualByType: { solar: 198, wind: 0, hydro: 0 },
  investment: 71.8e6, npv: 23.4e6, irr: 0.118, lcoe: 0.052, paybackYear: 8, pinsCount: 6,
  co2Avoided: 136500, homesEquivalent: 56000, treesEquivalent: 6200,
  description: 'Konya, Aksaray, Niğde — yüksek ışınımlı düz arazi GES portföyü',
  monthly: { solar: MONTHLY_BY_TYPE.solar.map(v => v * 0.32), wind: Array(12).fill(0), hydro: Array(12).fill(0) },
};

const ComparisonReportApp = () => {
  const [active, setActive] = useStateE('finans');
  const A = { ...SCENARIO_TOTALS, name: SCENARIO_META.name, color: '#14B8A6', pinsCount: REPORT_PINS.length, description: SCENARIO_META.description, monthly: MONTHLY_BY_TYPE };
  const B = ALT_SCENARIO;

  const Pair = ({ label, valA, valB, unit, hint, better }) => {
    // better = 'high' | 'low' — which is better
    const numA = parseFloat(String(valA).replace(/[^\d.\-]/g, ''));
    const numB = parseFloat(String(valB).replace(/[^\d.\-]/g, ''));
    const aBetter = better === 'high' ? numA > numB : numA < numB;
    return (
      <div style={{ display: 'grid', gridTemplateColumns: '110px 1fr 60px 1fr', gap: 12, alignItems: 'center', padding: '10px 0', borderBottom: '1px solid var(--border-2)' }}>
        <div>
          <div style={{ font: '500 11px/1.2 var(--font)', color: 'var(--text-2)' }}>{label}</div>
          {hint && <div style={{ font: '500 10px/1.3 var(--font)', color: 'var(--text-4)', marginTop: 3 }}>{hint}</div>}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '8px 12px', background: aBetter ? 'rgba(20,184,166,.08)' : 'transparent', border: aBetter ? '1px solid rgba(20,184,166,.35)' : '1px solid var(--border-2)', borderRadius: 8 }}>
          <div className="tnum" style={{ font: '700 17px/1 var(--font)', color: aBetter ? 'var(--accent)' : 'var(--text)', letterSpacing: '-.01em', flex: 1 }}>{valA}<span style={{ fontSize: 11, color: 'var(--text-3)', fontWeight: 500, marginLeft: 3 }}>{unit}</span></div>
          {aBetter && <Icon name="check" size={11} color="var(--accent)"/>}
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2 }}>
          <span className="tnum" style={{ font: '700 11px/1 var(--font-mono)', color: aBetter ? 'var(--accent)' : '#F59E0B' }}>
            {numA > numB ? '+' : '−'}{Math.abs(((numA - numB) / Math.max(Math.abs(numB), 0.001)) * 100).toFixed(0)}%
          </span>
          <span style={{ font: '500 9px/1 var(--font)', color: 'var(--text-4)', textTransform: 'uppercase', letterSpacing: '.05em' }}>vs</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '8px 12px', background: !aBetter ? 'rgba(245,158,11,.07)' : 'transparent', border: !aBetter ? '1px solid rgba(245,158,11,.30)' : '1px solid var(--border-2)', borderRadius: 8 }}>
          <div className="tnum" style={{ font: '700 17px/1 var(--font)', color: !aBetter ? '#F59E0B' : 'var(--text)', letterSpacing: '-.01em', flex: 1 }}>{valB}<span style={{ fontSize: 11, color: 'var(--text-3)', fontWeight: 500, marginLeft: 3 }}>{unit}</span></div>
          {!aBetter && <Icon name="check" size={11} color="#F59E0B"/>}
        </div>
      </div>
    );
  };

  return (
    <div style={{ width: 1280, height: 1500, background: 'var(--bg)', display: 'flex', borderRadius: 12, overflow: 'hidden', border: '1px solid var(--border)' }}>
      {/* nav rail */}
      <div style={{ width: 56, background: 'var(--bg-2)', borderRight: '1px solid var(--border)', display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '14px 0', gap: 6, flexShrink: 0 }}>
        <div style={{ width: 32, height: 32, borderRadius: 9, background: 'linear-gradient(135deg, var(--solar), var(--wind))', display: 'grid', placeItems: 'center', marginBottom: 8 }}>
          <Icon name="globe" size={16} color="white"/>
        </div>
        {[
          { i: 'globe' }, { i: 'list' }, { i: 'roi', on: true }, { i: 'finance' },
        ].map((it, i) => (
          <button key={i} className="btn btn-icon btn-ghost" style={{ width: 40, height: 40, padding: 0, background: it.on ? 'rgba(20,184,166,.10)' : 'transparent', border: it.on ? '1px solid rgba(20,184,166,.4)' : '1px solid transparent' }}>
            <Icon name={it.i} size={17} color={it.on ? 'var(--accent)' : 'var(--text-3)'}/>
          </button>
        ))}
      </div>

      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minWidth: 0 }}>
      {/* toolbar */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '12px 22px', background: 'rgba(20,24,34,.92)', borderBottom: '1px solid var(--border)' }}>
        <button className="btn" style={{ padding: '6px 10px' }}><Icon name="chevL" size={11}/> Tek görünüm</button>
        <div style={{ font: '500 11.5px/1 var(--font)', color: 'var(--text-3)', display: 'flex', alignItems: 'center', gap: 6 }}>
          <span>Raporlar</span><Icon name="chevR" size={10} color="var(--text-4)"/>
          <span>Senaryo Raporu</span><Icon name="chevR" size={10} color="var(--text-4)"/>
          <span style={{ color: 'var(--text)', fontWeight: 600 }}>Karşılaştırma</span>
        </div>
        <div style={{ flex: 1 }}/>
        <div className="seg" style={{ padding: 2 }}>
          {[['ozet', 'Özet'], ['uretim', 'Üretim'], ['finans', 'Finans'], ['cevre', 'Çevresel']].map(([id, l]) => (
            <button key={id} className={active === id ? 'on' : ''} onClick={() => setActive(id)} style={{ padding: '6px 11px', font: '500 11.5px/1 var(--font)' }}>{l}</button>
          ))}
        </div>
        <button className="btn" style={{ padding: '6px 10px' }}><Icon name="ext" size={11}/> PDF</button>
      </div>
      <ReportTabsRow active="senaryo"/>

      {/* dual hero */}
      <div style={{ padding: '22px 24px 0', background: 'var(--bg)' }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr auto 1fr', gap: 20, alignItems: 'stretch' }}>
          {[A, B].map((s, idx) => (
            <React.Fragment key={s.name}>
              <div style={{
                padding: '20px 22px',
                background: `linear-gradient(135deg, ${s.color}15, transparent 60%)`,
                border: `1px solid ${s.color}33`,
                borderRadius: 14, position: 'relative', overflow: 'hidden',
              }}>
                <div style={{ position: 'absolute', right: -30, top: -30, width: 160, height: 160, borderRadius: '50%', background: `radial-gradient(circle, ${s.color}22, transparent 60%)` }}/>
                <div style={{ position: 'relative' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
                    <div style={{ width: 24, height: 24, borderRadius: 6, background: `${s.color}22`, border: `1px solid ${s.color}44`, display: 'grid', placeItems: 'center' }}>
                      <span style={{ font: '700 11px/1 var(--font)', color: s.color }}>{idx === 0 ? 'A' : 'B'}</span>
                    </div>
                    <span style={{ font: '600 10.5px/1 var(--font-mono)', color: s.color, textTransform: 'uppercase', letterSpacing: '.10em' }}>SENARYO {idx === 0 ? 'A' : 'B'}</span>
                  </div>
                  <div style={{ font: '700 22px/1.15 var(--font)', letterSpacing: '-.02em', marginTop: 6 }}>{s.name}</div>
                  <div style={{ font: '500 11.5px/1.4 var(--font)', color: 'var(--text-3)', marginTop: 6 }}>{s.description}</div>
                  <div style={{ display: 'flex', gap: 16, marginTop: 12 }}>
                    <div><span className="tnum" style={{ font: '700 18px/1 var(--font)', color: s.color }}>{(s.totalCap || 0).toFixed(0)}</span><span style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)', marginLeft: 3 }}>MW</span></div>
                    <div><span className="tnum" style={{ font: '700 18px/1 var(--font)' }}>{(s.annualGwh || 0).toFixed(0)}</span><span style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)', marginLeft: 3 }}>GWh</span></div>
                    <div><span className="tnum" style={{ font: '700 18px/1 var(--font)', color: '#10B981' }}>{fmtMoney(s.npv)}</span></div>
                  </div>
                </div>
              </div>
              {idx === 0 && (
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <div style={{ width: 36, height: 36, borderRadius: '50%', background: 'rgba(20,24,34,.95)', border: '1px solid var(--border)', display: 'grid', placeItems: 'center' }}>
                    <span style={{ font: '700 13px/1 var(--font-mono)', color: 'var(--text-3)' }}>VS</span>
                  </div>
                </div>
              )}
            </React.Fragment>
          ))}
        </div>
      </div>

      {/* comparison content */}
      <div className="scroll" style={{ flex: 1, overflow: 'auto', padding: '20px 24px 40px' }}>
        {active === 'finans' && (
          <>
            <ReportCard title="Finansal Karşılaştırma · Yan yana" padding={16} style={{ marginBottom: 12 }}>
              <Pair label="NPV (25y)"      valA={fmtMoney(A.npv)} valB={fmtMoney(B.npv)} unit="" hint="Net bugünkü değer" better="high"/>
              <Pair label="IRR"            valA={(A.irr*100).toFixed(1)} valB={(B.irr*100).toFixed(1)} unit="%" hint="İç verim oranı" better="high"/>
              <Pair label="LCOE"           valA={`$${A.lcoe.toFixed(3)}`} valB={`$${B.lcoe.toFixed(3)}`} unit="/kWh" hint="Düzleştirilmiş enerji maliyeti" better="low"/>
              <Pair label="Geri Ödeme"     valA={A.paybackYear} valB={B.paybackYear} unit="yıl" hint="Pozitif kümülatif nakit akışı" better="low"/>
              <Pair label="CAPEX"          valA={fmtMoney(A.investment)} valB={fmtMoney(B.investment)} unit="" hint="Toplam yatırım" better="low"/>
              <Pair label="$/MW"           valA={`$${(A.investment/A.totalCap/1e6).toFixed(2)}M`} valB={`$${(B.investment/B.totalCap/1e6).toFixed(2)}M`} unit="" hint="Birim yatırım verimliliği" better="low"/>
            </ReportCard>
            <ReportCard title="Üretim Karşılaştırma" padding={16}>
              <Pair label="Toplam Kapasite"  valA={A.totalCap.toFixed(0)} valB={B.totalCap.toFixed(0)} unit="MW" better="high"/>
              <Pair label="Yıllık Üretim"    valA={A.annualGwh.toFixed(0)} valB={B.annualGwh.toFixed(0)} unit="GWh" better="high"/>
              <Pair label="Saha Sayısı"      valA={A.pinsCount} valB={B.pinsCount} unit="" better="high"/>
              <Pair label="Kapasite Faktörü" valA="29.7" valB="24.5" unit="%" better="high"/>
              <Pair label="CO₂ Önlemesi"     valA={`${(A.co2Avoided/1000).toFixed(0)}K`} valB={`${(B.co2Avoided/1000).toFixed(0)}K`} unit="ton/y" better="high"/>
            </ReportCard>
            <div style={{ marginTop: 12, padding: 14, background: 'rgba(20,184,166,.08)', border: '1px solid rgba(20,184,166,.30)', borderRadius: 10, font: '500 12.5px/1.55 var(--font)', color: 'var(--text-2)' }}>
              <Icon name="check2" size={13} color="var(--accent)"/> <b style={{ color: 'var(--accent)' }}>Tavsiye:</b> <b>Senaryo A</b> daha yüksek NPV ve daha çeşitli kaynak karışımı ile uzun vadeli risk profilinde daha güçlü.
              Senaryo B daha hızlı başlangıç (düşük CAPEX) ama tek-kaynak risk yoğunluğu yüksek. Karma bir yaklaşım için B'nin solar pinlerini A'ya entegre etmek düşünülebilir.
            </div>
          </>
        )}
        {active === 'ozet' && (
          <>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 12 }}>
              <ReportCard title="Senaryo A · Coğrafi Dağılım" padding={0} style={{ overflow: 'hidden' }}>
                <div style={{ background: '#0E1219' }}><ReportMiniMap pins={REPORT_PINS} height={240}/></div>
              </ReportCard>
              <ReportCard title="Senaryo B · Coğrafi Dağılım" padding={0} style={{ overflow: 'hidden' }}>
                <div style={{ background: '#0E1219' }}><ReportMiniMap pins={REPORT_PINS.filter(p => p.type === 'solar').slice(0, 6)} height={240}/></div>
              </ReportCard>
            </div>
            <ReportCard title="Anahtar Metrikler" padding={16}>
              <Pair label="NPV (25y)" valA={fmtMoney(A.npv)} valB={fmtMoney(B.npv)} unit="" better="high"/>
              <Pair label="Toplam Kapasite" valA={A.totalCap.toFixed(0)} valB={B.totalCap.toFixed(0)} unit="MW" better="high"/>
              <Pair label="Kaynak Çeşitliliği" valA={3} valB={1} unit="tip" hint="Solar/Wind/Hydro" better="high"/>
              <Pair label="CO₂" valA={`${(A.co2Avoided/1000).toFixed(0)}K`} valB={`${(B.co2Avoided/1000).toFixed(0)}K`} unit="ton/y" better="high"/>
            </ReportCard>
          </>
        )}
        {active === 'uretim' && (
          <ReportCard title="Aylık Üretim · Yan yana" padding={16}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
              {[A, B].map((s, idx) => (
                <div key={s.name}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
                    <div style={{ width: 22, height: 22, borderRadius: 6, background: `${s.color}22`, border: `1px solid ${s.color}44`, display: 'grid', placeItems: 'center' }}>
                      <span style={{ font: '700 10px/1 var(--font)', color: s.color }}>{idx === 0 ? 'A' : 'B'}</span>
                    </div>
                    <span style={{ font: '600 12.5px/1 var(--font)' }}>{s.name}</span>
                  </div>
                  <StackedMonthlyBars data={s.monthly} height={200} width={520}/>
                </div>
              ))}
            </div>
          </ReportCard>
        )}
        {active === 'cevre' && (
          <ReportCard title="Çevresel Etki" padding={16}>
            <Pair label="CO₂ Önlemesi (yıllık)" valA={`${(A.co2Avoided/1000).toFixed(0)}K`} valB={`${(B.co2Avoided/1000).toFixed(0)}K`} unit="ton" better="high"/>
            <Pair label="Hane Eşdeğeri" valA={`${(A.homesEquivalent/1000).toFixed(0)}K`} valB={`${(B.homesEquivalent/1000).toFixed(0)}K`} unit="" better="high"/>
            <Pair label="Ağaç Eşdeğeri" valA={`${(A.treesEquivalent/1000).toFixed(0)}K`} valB={`${(B.treesEquivalent/1000).toFixed(0)}K`} unit="" better="high"/>
            <Pair label="25 Yıl Toplam CO₂" valA={`${(A.co2Avoided * 25 / 1e6).toFixed(1)}M`} valB={`${(B.co2Avoided * 25 / 1e6).toFixed(1)}M`} unit="ton" better="high"/>
          </ReportCard>
        )}
      </div>
      </div>
    </div>
  );
};

// ============================================================================
// PRINT / A4 PREVIEW MODE
// ============================================================================
const A4_W = 794;  // 210mm at 96dpi
const A4_H = 1123; // 297mm at 96dpi

const PrintReportApp = () => {
  const totals = SCENARIO_TOTALS;
  const meta = SCENARIO_META;
  const PageHeader = ({ pageNum, pageOf }) => (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '24px 40px 14px', borderBottom: '1px solid #E5E7EB' }}>
      <div style={{ width: 28, height: 28, borderRadius: 7, background: 'linear-gradient(135deg, #F59E0B, #3B82F6)', display: 'grid', placeItems: 'center' }}>
        <Icon name="globe" size={14} color="white"/>
      </div>
      <div>
        <div style={{ font: '700 12px/1 var(--font)', color: '#0B0E14' }}>SRRP · Senaryo Raporu</div>
        <div style={{ font: '500 10px/1 var(--font)', color: '#6B7280', marginTop: 3 }}>{meta.name}</div>
      </div>
      <div style={{ flex: 1 }}/>
      <div className="tnum" style={{ font: '500 10px/1 var(--font-mono)', color: '#6B7280' }}>RPT-2026-0117 · Sayfa {pageNum}/{pageOf}</div>
    </div>
  );
  const PageFooter = () => (
    <div style={{ position: 'absolute', left: 40, right: 40, bottom: 22, display: 'flex', alignItems: 'center', gap: 8, paddingTop: 10, borderTop: '1px solid #E5E7EB' }}>
      <span style={{ font: '500 9px/1.3 var(--font)', color: '#9CA3AF' }}>Otomatik üretilmiştir · {meta.updatedAt} · Veri kaynakları: PVGIS, ERA-5, DSİ, TEİAŞ, EPDK</span>
      <div style={{ flex: 1 }}/>
      <span className="tnum" style={{ font: '500 9px/1 var(--font-mono)', color: '#9CA3AF' }}>srrp.app</span>
    </div>
  );
  const Page = ({ children, num, of }) => (
    <div style={{
      width: A4_W, height: A4_H, background: 'white', color: '#0B0E14',
      boxShadow: '0 8px 24px rgba(0,0,0,.30)', borderRadius: 4,
      position: 'relative', overflow: 'hidden',
    }}>
      <PageHeader pageNum={num} pageOf={of}/>
      <div style={{ padding: '20px 40px 50px' }}>{children}</div>
      <PageFooter/>
    </div>
  );

  return (
    <div style={{ width: 1280, padding: '20px 32px 32px', background: '#1A1F2B', minHeight: 2500, color: 'var(--text)' }}>
      {/* print toolbar */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '12px 16px', background: 'rgba(20,24,34,.92)', borderRadius: 12, border: '1px solid var(--border)', marginBottom: 22 }}>
        <button className="btn" style={{ padding: '6px 10px' }}><Icon name="chevL" size={11}/> Ekran görünümü</button>
        <div style={{ font: '600 13px/1 var(--font)', color: 'var(--text)' }}>Yazdırma Önizleme · A4 · 4 sayfa</div>
        <div style={{ flex: 1 }}/>
        <button className="btn" style={{ padding: '6px 10px' }}>Kenar boşlukları</button>
        <button className="btn" style={{ padding: '6px 10px' }}>Üst bilgi</button>
        <button className="btn btn-primary" style={{ padding: '6px 12px' }}><Icon name="ext" size={11} color="#06201E"/> PDF olarak indir</button>
      </div>

      {/* page stack */}
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 24 }}>
        {/* Page 1 — Cover */}
        <Page num={1} of={4}>
          <div style={{ marginTop: 60 }}>
            <div style={{ font: '600 11px/1 var(--font-mono)', color: '#14B8A6', letterSpacing: '.12em' }}>SENARYO RAPORU · YATIRIMCI</div>
            <h1 style={{ margin: '14px 0 0', font: '700 44px/1.05 var(--font)', letterSpacing: '-.03em', color: '#0B0E14' }}>{meta.name}</h1>
            <p style={{ margin: '14px 0 0', font: '500 14px/1.6 var(--font)', color: '#374151', maxWidth: 560 }}>
              {meta.description}. 14 saha · 7 il · 285 MW kurulu güç · 25 yıllık projeksiyon.
            </p>
          </div>
          {/* big KPI grid */}
          <div style={{ marginTop: 50, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
            {[
              ['Toplam Kapasite', `${totals.totalCap.toFixed(0)} MW`, '14 saha · 7 il'],
              ['Yıllık Üretim',    `${totals.annualGwh.toFixed(0)} GWh`, `${(totals.homesEquivalent/1000).toFixed(0)}K hane eşdeğeri`],
              ['Net Bugünkü Değer (25y)', `$${(totals.npv/1e6).toFixed(1)}M`, `IRR %${(totals.irr*100).toFixed(1)} · Geri ödeme ${totals.paybackYear}y`],
              ['Kaçınılan CO₂', `${(totals.co2Avoided/1000).toFixed(0)}K ton/yıl`, `25y toplam ${(totals.co2Avoided*25/1e6).toFixed(1)}M ton`],
            ].map(([l, v, s]) => (
              <div key={l} style={{ padding: '18px 20px', border: '1px solid #E5E7EB', borderRadius: 8, background: '#FAFAFA' }}>
                <div style={{ font: '500 10.5px/1 var(--font)', color: '#6B7280', textTransform: 'uppercase', letterSpacing: '.06em' }}>{l}</div>
                <div className="tnum" style={{ font: '700 28px/1 var(--font)', color: '#0B0E14', marginTop: 8, letterSpacing: '-.02em' }}>{v}</div>
                <div style={{ font: '500 10.5px/1.4 var(--font)', color: '#6B7280', marginTop: 6 }}>{s}</div>
              </div>
            ))}
          </div>
          <div style={{ marginTop: 'auto', position: 'absolute', left: 40, bottom: 90, right: 40, display: 'flex', gap: 30, paddingTop: 18, borderTop: '1px solid #E5E7EB' }}>
            <div>
              <div style={{ font: '500 10px/1 var(--font)', color: '#9CA3AF', textTransform: 'uppercase', letterSpacing: '.05em' }}>HAZIRLAYAN</div>
              <div style={{ font: '600 12px/1.3 var(--font)', color: '#0B0E14', marginTop: 6 }}>Ayşe Demir</div>
              <div style={{ font: '500 10.5px/1 var(--font)', color: '#6B7280', marginTop: 3 }}>Yatırım Analisti</div>
            </div>
            <div>
              <div style={{ font: '500 10px/1 var(--font)', color: '#9CA3AF', textTransform: 'uppercase', letterSpacing: '.05em' }}>OLUŞTURULDU</div>
              <div className="tnum" style={{ font: '600 12px/1.3 var(--font)', color: '#0B0E14', marginTop: 6 }}>{meta.createdAt}</div>
            </div>
            <div>
              <div style={{ font: '500 10px/1 var(--font)', color: '#9CA3AF', textTransform: 'uppercase', letterSpacing: '.05em' }}>RAPOR NO</div>
              <div className="tnum" style={{ font: '600 12px/1.3 var(--font)', color: '#0B0E14', marginTop: 6, fontFamily: 'var(--font-mono)' }}>RPT-2026-0117</div>
            </div>
          </div>
        </Page>

        {/* Page 2 — Üretim */}
        <Page num={2} of={4}>
          <div style={{ font: '600 10px/1 var(--font-mono)', color: '#14B8A6', letterSpacing: '.10em' }}>02 · ÜRETİM</div>
          <h2 style={{ margin: '8px 0 18px', font: '700 24px/1.1 var(--font)', color: '#0B0E14' }}>Aylık ve günlük üretim profili</h2>
          <div style={{ padding: 14, border: '1px solid #E5E7EB', borderRadius: 8, marginBottom: 14 }}>
            <div style={{ font: '600 10.5px/1 var(--font)', color: '#6B7280', textTransform: 'uppercase', letterSpacing: '.05em', marginBottom: 10 }}>Aylık Üretim · Kaynak Tipine Göre</div>
            <div style={{ background: '#0B0E14', borderRadius: 6, padding: 10 }}>
              <StackedMonthlyBars data={MONTHLY_BY_TYPE} height={200} width={680}/>
            </div>
          </div>
          <div style={{ padding: 14, border: '1px solid #E5E7EB', borderRadius: 8, marginBottom: 14 }}>
            <div style={{ font: '600 10.5px/1 var(--font)', color: '#6B7280', textTransform: 'uppercase', letterSpacing: '.05em', marginBottom: 10 }}>Tipik Gün Profili · 24 saat</div>
            <div style={{ background: '#0B0E14', borderRadius: 6, padding: 10 }}>
              <HourlyProfile height={180} width={680}/>
            </div>
          </div>
          <div style={{ padding: 14, border: '1px solid #E5E7EB', borderRadius: 8 }}>
            <div style={{ font: '600 10.5px/1 var(--font)', color: '#6B7280', textTransform: 'uppercase', letterSpacing: '.05em', marginBottom: 10 }}>Üretim Kayıpları · Teorik → Gerçek</div>
            <div style={{ background: '#0B0E14', borderRadius: 6, padding: 10 }}>
              <LossWaterfall height={200} width={680}/>
            </div>
          </div>
        </Page>

        {/* Page 3 — Finans */}
        <Page num={3} of={4}>
          <div style={{ font: '600 10px/1 var(--font-mono)', color: '#14B8A6', letterSpacing: '.10em' }}>03 · FİNANS</div>
          <h2 style={{ margin: '8px 0 14px', font: '700 24px/1.1 var(--font)', color: '#0B0E14' }}>Finansal performans ve hassasiyet</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 8, marginBottom: 16 }}>
            {[['NPV (25y)', `$${(totals.npv/1e6).toFixed(1)}M`, '#10B981'],
              ['IRR', `%${(totals.irr*100).toFixed(1)}`, '#0B0E14'],
              ['LCOE', `$${totals.lcoe.toFixed(3)}`, '#0B0E14'],
              ['Geri Öd.', `${totals.paybackYear} yıl`, '#0B0E14'],
              ['CAPEX', `$${(totals.investment/1e6).toFixed(0)}M`, '#0B0E14']
            ].map(([l, v, col]) => (
              <div key={l} style={{ padding: 10, background: '#FAFAFA', border: '1px solid #E5E7EB', borderRadius: 6 }}>
                <div style={{ font: '500 9.5px/1 var(--font)', color: '#9CA3AF', textTransform: 'uppercase' }}>{l}</div>
                <div className="tnum" style={{ font: '700 18px/1 var(--font)', color: col, marginTop: 5 }}>{v}</div>
              </div>
            ))}
          </div>
          <div style={{ padding: 14, border: '1px solid #E5E7EB', borderRadius: 8, marginBottom: 14 }}>
            <div style={{ font: '600 10.5px/1 var(--font)', color: '#6B7280', textTransform: 'uppercase', letterSpacing: '.05em', marginBottom: 10 }}>Kümülatif Nakit Akışı · P50/P90 Bantları</div>
            <div style={{ background: '#0B0E14', borderRadius: 6, padding: 10 }}>
              <FanAreaChart data={CASHFLOW_SERIES} paybackYear={totals.paybackYear} height={200} width={680}/>
            </div>
          </div>
          <div style={{ padding: 14, border: '1px solid #E5E7EB', borderRadius: 8 }}>
            <div style={{ font: '600 10.5px/1 var(--font)', color: '#6B7280', textTransform: 'uppercase', letterSpacing: '.05em', marginBottom: 10 }}>Hassasiyet Analizi · Tornado</div>
            <div style={{ background: '#0B0E14', borderRadius: 6, padding: 10 }}>
              <TornadoChart items={[
                { label: 'Elektrik Fiyatı',  lowDelta: -22.4, highDelta: +24.8, lowLabel: '1.10₺', highLabel: '1.75₺' },
                { label: 'İskonto Oranı',    lowDelta: +18.2, highDelta: -16.5, lowLabel: '%6.0',  highLabel: '%11.0' },
                { label: 'Kapasite Faktörü', lowDelta: -14.6, highDelta: +14.2, lowLabel: '−%10',  highLabel: '+%10' },
                { label: 'CAPEX',            lowDelta: +12.8, highDelta: -13.1, lowLabel: '−%15',  highLabel: '+%15' },
              ]} baseline={totals.npv/1e6} height={200} width={680}/>
            </div>
          </div>
        </Page>

        {/* Page 4 — Çevresel + Konfigürasyon */}
        <Page num={4} of={4}>
          <div style={{ font: '600 10px/1 var(--font-mono)', color: '#14B8A6', letterSpacing: '.10em' }}>04 · ÇEVRESEL ETKİ + 05 · KONFİGÜRASYON</div>
          <h2 style={{ margin: '8px 0 14px', font: '700 22px/1.1 var(--font)', color: '#0B0E14' }}>Sera gazı önlemesi ve hesaplama varsayımları</h2>
          <div style={{ padding: 22, background: '#F0FDF4', border: '1px solid #BBF7D0', borderRadius: 8, marginBottom: 14 }}>
            <div style={{ font: '500 10px/1 var(--font)', color: '#15803D', textTransform: 'uppercase', letterSpacing: '.06em' }}>KAÇINILAN SERA GAZI</div>
            <div className="tnum" style={{ font: '700 36px/1 var(--font)', color: '#15803D', marginTop: 8 }}>{(totals.co2Avoided/1000).toFixed(0)}K<span style={{ fontSize: 14, color: '#16A34A', fontWeight: 500, marginLeft: 6 }}>ton CO₂/yıl</span></div>
            <div style={{ marginTop: 10, font: '500 11.5px/1.5 var(--font)', color: '#374151' }}>
              25 yıl boyunca toplam <b className="tnum" style={{ color: '#15803D' }}>{(totals.co2Avoided*25/1e6).toFixed(1)}M ton</b> CO₂ önlenir. Bu, Türkiye'nin 2024 toplam elektrik sektörü emisyonunun ≈%0.31'i.
            </div>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10, marginBottom: 18 }}>
            {[
              ['Hane Eşdeğeri',  `${(totals.homesEquivalent/1000).toFixed(0)}K`, 'yıllık elektrik tüketimi'],
              ['Ağaç Eşdeğeri',  `${(totals.treesEquivalent/1000).toFixed(0)}K`, 'yıllık karbon yutağı'],
              ['Araç Eşdeğeri',  `${(totals.co2Avoided/4.6/1000).toFixed(0)}K`, 'yoldan kaldırılmış'],
            ].map(([l, v, s]) => (
              <div key={l} style={{ padding: 12, background: '#FAFAFA', border: '1px solid #E5E7EB', borderRadius: 6 }}>
                <div style={{ font: '500 9.5px/1 var(--font)', color: '#9CA3AF', textTransform: 'uppercase' }}>{l}</div>
                <div className="tnum" style={{ font: '700 20px/1 var(--font)', color: '#15803D', marginTop: 5 }}>{v}</div>
                <div style={{ font: '500 9.5px/1.3 var(--font)', color: '#6B7280', marginTop: 5 }}>{s}</div>
              </div>
            ))}
          </div>
          <div style={{ padding: 14, border: '1px solid #E5E7EB', borderRadius: 8 }}>
            <div style={{ font: '600 10.5px/1 var(--font)', color: '#6B7280', textTransform: 'uppercase', letterSpacing: '.05em', marginBottom: 12 }}>Konfigürasyon · Hesaplama Varsayımları</div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, fontSize: 11.5, lineHeight: 1.6, fontFamily: 'var(--font)' }}>
              <div>
                <div style={{ font: '600 11px/1 var(--font)', color: '#374151', marginBottom: 6 }}>Finansal</div>
                {[
                  ['İskonto oranı', `%${(meta.discountRate*100).toFixed(1)}`],
                  ['Elektrik fiyatı', `${meta.electricityPrice} ₺/kWh`],
                  ['Yıllık eskalasyon', `%${(meta.escalation*100).toFixed(1)}`],
                  ['O&M oranı', `%${(meta.opexPctOfRevenue*100).toFixed(0)} gelir`],
                  ['Projeksiyon', `${meta.horizonYears} yıl`],
                ].map(([k, v]) => (
                  <div key={k} style={{ display: 'flex', justifyContent: 'space-between', padding: '4px 0', borderBottom: '1px dashed #E5E7EB' }}>
                    <span style={{ color: '#6B7280' }}>{k}</span>
                    <span className="tnum" style={{ color: '#0B0E14', fontFamily: 'var(--font-mono)', fontWeight: 600 }}>{v}</span>
                  </div>
                ))}
              </div>
              <div>
                <div style={{ font: '600 11px/1 var(--font)', color: '#374151', marginBottom: 6 }}>Veri Kaynakları</div>
                {[
                  ['PVGIS · v5.2', 'Güneş ışınımı'],
                  ['ERA-5 · ECMWF', 'Rüzgar profili'],
                  ['DSİ · 2024', 'Hidrolojik veri'],
                  ['TEİAŞ · 2024', 'Grid karbon yoğunluğu'],
                  ['EPDK · 2025', 'Tarife'],
                ].map(([s, l]) => (
                  <div key={s} style={{ display: 'flex', justifyContent: 'space-between', padding: '4px 0', borderBottom: '1px dashed #E5E7EB' }}>
                    <span style={{ color: '#0B0E14', fontFamily: 'var(--font-mono)', fontWeight: 600 }}>{s}</span>
                    <span style={{ color: '#6B7280' }}>{l}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </Page>
      </div>
    </div>
  );
};

Object.assign(window, { SmartInsights, SensitivitySection, ComparisonReportApp, PrintReportApp, ALT_SCENARIO });
