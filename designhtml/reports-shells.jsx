// reports-shells.jsx — Desktop / Tablet / Mobile shells for the Reports module + Pin-level report

const { useState: useStateS } = React;

// ============================================================================
// DESKTOP — Scenario Report (full view)
// ============================================================================
const DesktopReportApp = () => {
  const [active, setActive] = useStateS('ozet');
  const [template, setTemplate] = useStateS('Yatırımcı');
  const [period, setPeriod] = useStateS('25Y');
  const [scrollProgress, setScrollProgress] = useStateS(0);
  const totals = SCENARIO_TOTALS;
  const meta = SCENARIO_META;
  const scrollRef = React.useRef(null);

  const jump = (id) => {
    setActive(id);
    const el = document.querySelector(`[data-toc="${id}"]`);
    const scrollEl = scrollRef.current;
    if (el && scrollEl) scrollEl.scrollTo({ top: el.offsetTop - 16, behavior: 'smooth' });
  };

  // scroll-spy
  React.useEffect(() => {
    const scrollEl = scrollRef.current;
    if (!scrollEl) return;
    const onScroll = () => {
      const top = scrollEl.scrollTop;
      const h = scrollEl.scrollHeight - scrollEl.clientHeight;
      setScrollProgress(h > 0 ? Math.min(100, (top / h) * 100) : 0);
      // find which section is most visible
      const sections = scrollEl.querySelectorAll('[data-toc]');
      let activeId = null;
      let closest = Infinity;
      sections.forEach(s => {
        const d = Math.abs(s.offsetTop - top - 80);
        if (d < closest) { closest = d; activeId = s.getAttribute('data-toc'); }
      });
      if (activeId) setActive(activeId);
    };
    scrollEl.addEventListener('scroll', onScroll, { passive: true });
    return () => scrollEl.removeEventListener('scroll', onScroll);
  }, []);

  return (
    <div style={{ width: 1280, height: 1700, background: 'var(--bg)', display: 'flex', borderRadius: 12, overflow: 'hidden', border: '1px solid var(--border)', position: 'relative' }}>
      {/* nav rail (matches main app) */}
      <div style={{ width: 56, background: 'var(--bg-2)', borderRight: '1px solid var(--border)', display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '14px 0', gap: 6, flexShrink: 0 }}>
        <div style={{ width: 32, height: 32, borderRadius: 9, background: 'linear-gradient(135deg, var(--solar), var(--wind))', display: 'grid', placeItems: 'center', marginBottom: 8 }}>
          <Icon name="globe" size={16} color="white"/>
        </div>
        {[
          { i: 'globe', lbl: 'Harita' },
          { i: 'list',  lbl: 'Liste' },
          { i: 'roi',   lbl: 'Raporlar', on: true },
          { i: 'finance', lbl: 'Finans' },
        ].map((it, i) => (
          <button key={i} className="btn btn-icon btn-ghost" style={{ width: 40, height: 40, padding: 0, background: it.on ? 'rgba(20,184,166,.10)' : 'transparent', border: it.on ? '1px solid rgba(20,184,166,.4)' : '1px solid transparent' }}>
            <Icon name={it.i} size={17} color={it.on ? 'var(--accent)' : 'var(--text-3)'}/>
          </button>
        ))}
        <div style={{ flex: 1 }}/>
        <button className="btn btn-icon btn-ghost" style={{ width: 40, height: 40, padding: 0 }}><Icon name="gear" size={16} color="var(--text-3)"/></button>
      </div>

      {/* TOC (left) */}
      <div style={{ width: 240, flexShrink: 0 }}>
        <ReportTOC active={active} onJump={jump} totals={totals} progress={scrollProgress}/>
      </div>

      {/* Main column */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minWidth: 0 }}>
        <ReportToolbar template={template} onTemplate={setTemplate} period={period} onPeriod={setPeriod} scenario={meta.name}/>
        <ReportTabsRow active="senaryo"/>
        {/* top progress bar */}
        <div style={{ height: 2, background: 'rgba(255,255,255,.04)', position: 'relative', flexShrink: 0 }}>
          <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: `${scrollProgress}%`, background: 'linear-gradient(90deg, var(--accent), #2DD4BF)', transition: 'width .15s' }}/>
        </div>
        {/* status / context strip */}
        <div style={{ padding: '8px 22px', borderBottom: '1px solid var(--border-2)', display: 'flex', alignItems: 'center', gap: 10, background: 'rgba(0,0,0,.12)', flexShrink: 0 }}>
          <span className="chip"><span style={{ width: 6, height: 6, borderRadius: '50%', background: '#10B981' }}/>Canlı veri · 2 dk önce</span>
          <span className="chip">{template} · {period === '12A' ? '12 Aylık' : period === '5Y' ? '5 Yıllık' : '25 Yıllık'}</span>
          <div style={{ flex: 1 }}/>
          <span style={{ font: '500 10.5px/1 var(--font-mono)', color: 'var(--text-4)', letterSpacing: '.04em' }}>RPT-2026-0117</span>
        </div>

        {/* scroll content */}
        <div ref={scrollRef} data-report-scroll="desktop" className="scroll" style={{ flex: 1, overflow: 'auto', padding: '22px 28px 60px', background: 'var(--bg)' }}>
          {/* Report cover/header */}
          <div style={{ padding: '28px 30px', background: 'linear-gradient(135deg, rgba(20,184,166,.10), transparent 65%)', border: '1px solid rgba(20,184,166,.25)', borderRadius: 16, marginBottom: 22, position: 'relative', overflow: 'hidden' }}>
            <div style={{ position: 'absolute', right: -40, top: -40, width: 240, height: 240, borderRadius: '50%', background: 'radial-gradient(circle, rgba(20,184,166,.18), transparent 60%)', pointerEvents: 'none' }}/>
            <div style={{ position: 'relative', display: 'flex', alignItems: 'flex-end', gap: 24 }}>
              <div style={{ flex: 1 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 9, marginBottom: 8 }}>
                  <span style={{ font: '600 10.5px/1 var(--font-mono)', color: 'var(--accent)', textTransform: 'uppercase', letterSpacing: '.10em' }}>SENARYO RAPORU · {template.toUpperCase()}</span>
                  <span style={{ width: 4, height: 4, borderRadius: '50%', background: 'var(--text-4)' }}/>
                  <span style={{ font: '500 11px/1 var(--font)', color: 'var(--text-3)' }}>{period === '12A' ? '12 Aylık' : period === '5Y' ? '5 Yıllık' : '25 Yıllık'} projeksiyon</span>
                </div>
                <h1 style={{ margin: 0, font: '700 38px/1.05 var(--font)', letterSpacing: '-.03em', color: 'var(--text)' }}>{meta.name}</h1>
                <p style={{ margin: '10px 0 0', font: '500 13.5px/1.5 var(--font)', color: 'var(--text-2)', maxWidth: 620 }}>
                  {meta.description}. Bu rapor, sahada konumlandırılmış {SCENARIO_TOTALS.totalCap.toFixed(0)} MW kurulu güçlü yenilenebilir kaynak portföyünün
                  teknik performansını, finansal getirisini ve çevresel etkilerini özetler.
                </p>
                <div style={{ marginTop: 16, display: 'flex', gap: 22, font: '500 12px/1.4 var(--font)' }}>
                  <div>
                    <div style={{ color: 'var(--text-3)', font: '500 10.5px/1 var(--font)', textTransform: 'uppercase', letterSpacing: '.06em' }}>Hazırlayan</div>
                    <div style={{ color: 'var(--text)', fontWeight: 600, marginTop: 5 }}>{meta.createdBy}</div>
                  </div>
                  <div>
                    <div style={{ color: 'var(--text-3)', font: '500 10.5px/1 var(--font)', textTransform: 'uppercase', letterSpacing: '.06em' }}>Oluşturuldu</div>
                    <div style={{ color: 'var(--text)', fontWeight: 600, marginTop: 5 }} className="tnum">{meta.createdAt}</div>
                  </div>
                  <div>
                    <div style={{ color: 'var(--text-3)', font: '500 10.5px/1 var(--font)', textTransform: 'uppercase', letterSpacing: '.06em' }}>Güncellendi</div>
                    <div style={{ color: 'var(--text)', fontWeight: 600, marginTop: 5 }} className="tnum">{meta.updatedAt}</div>
                  </div>
                  <div>
                    <div style={{ color: 'var(--text-3)', font: '500 10.5px/1 var(--font)', textTransform: 'uppercase', letterSpacing: '.06em' }}>Rapor No</div>
                    <div style={{ color: 'var(--text)', fontWeight: 600, marginTop: 5, fontFamily: 'var(--font-mono)' }}>RPT-2026-0117</div>
                  </div>
                </div>
              </div>
              {/* small status panel */}
              <div style={{ width: 220, padding: 14, background: 'rgba(0,0,0,.30)', border: '1px solid var(--border-2)', borderRadius: 12 }}>
                <div className="label" style={{ marginBottom: 9 }}>Onay Durumu</div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 7 }}>
                  {[
                    ['Veri doğrulama', 'tam',    '#10B981'],
                    ['Mühendislik onayı', 'tam', '#10B981'],
                    ['Finans incelemesi', 'beklemede', '#F59E0B'],
                    ['Yönetim onayı', 'beklemede', '#F59E0B'],
                  ].map(([l, s, c]) => (
                    <div key={l} style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
                      <div style={{ width: 6, height: 6, borderRadius: '50%', background: c }}/>
                      <span style={{ font: '500 11.5px/1.2 var(--font)', color: 'var(--text-2)', flex: 1 }}>{l}</span>
                      <span style={{ font: '600 9.5px/1 var(--font)', color: c, textTransform: 'uppercase', letterSpacing: '.05em' }}>{s}</span>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>

          <SmartInsights totals={totals} pins={REPORT_PINS} meta={meta}/>
          <Section01_Ozet totals={totals} pins={REPORT_PINS} meta={meta}/>
          <Section02_Uretim totals={totals} pins={REPORT_PINS}/>
          <Section03_Finans totals={totals} meta={meta}/>
          <SensitivitySection totals={totals} meta={meta}/>
          <Section05_Cevre totals={totals}/>
          <Section06_Config meta={meta}/>

          {/* footer */}
          <div style={{ marginTop: 40, paddingTop: 18, borderTop: '1px dashed var(--border-2)', display: 'flex', alignItems: 'center', gap: 14, font: '500 11px/1.4 var(--font)', color: 'var(--text-3)' }}>
            <div style={{ width: 24, height: 24, borderRadius: 6, background: 'linear-gradient(135deg, var(--solar), var(--wind))', display: 'grid', placeItems: 'center' }}>
              <Icon name="globe" size={12} color="white"/>
            </div>
            <span><b style={{ color: 'var(--text-2)' }}>SRRP</b> · Smart Renewable Resource Planner</span>
            <span>·</span>
            <span>Bu rapor otomatik üretildi ve sayfaya bağlanmış canlı veri kaynaklarından hesaplandı.</span>
            <div style={{ flex: 1 }}/>
            <span className="tnum" style={{ fontFamily: 'var(--font-mono)' }}>Sayfa 1 / 1</span>
          </div>
        </div>
      </div>
    </div>
  );
};

// ============================================================================
// PIN REPORT (focused single-resource — entered from pin detail "Rapor" button)
// ============================================================================
const PinReportApp = ({ pinId = 2 }) => {
  const pin = REPORT_PINS.find(p => p.id === pinId);
  const c = TC[pin.type];
  const annualGwh = pin.annualKwh / 1e6;
  const capex = pin.capacityMw * SCENARIO_META.capexPerMw[pin.type];
  const annualRev = pin.annualKwh * 0.072;
  const co2 = annualGwh * 1e3 * 0.689; // tons

  return (
    <div style={{ width: 1280, height: 1300, background: 'var(--bg)', display: 'flex', flexDirection: 'column', borderRadius: 12, overflow: 'hidden', border: '1px solid var(--border)' }}>
      {/* breadcrumb / mini toolbar */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '12px 22px', borderBottom: '1px solid var(--border)', background: 'rgba(20,24,34,.92)' }}>
        <button className="btn" style={{ padding: '6px 10px' }}>
          <Icon name="chevL" size={11} color="var(--text-2)"/> Pin detayına dön
        </button>
        <div style={{ font: '500 11.5px/1 var(--font)', color: 'var(--text-3)', display: 'flex', alignItems: 'center', gap: 6 }}>
          <span>Pinlerim</span>
          <Icon name="chevR" size={10} color="var(--text-4)"/>
          <span style={{ color: c, fontWeight: 600 }}>{pin.name}</span>
          <Icon name="chevR" size={10} color="var(--text-4)"/>
          <span style={{ color: 'var(--text)', fontWeight: 600 }}>Rapor</span>
        </div>
        <div style={{ flex: 1 }}/>
        <button className="btn" style={{ padding: '6px 10px' }}><Icon name="ext" size={11}/> PDF</button>
        <button className="btn" style={{ padding: '6px 10px' }}><Icon name="ext" size={11}/> Excel</button>
        <button className="btn btn-primary" style={{ padding: '6px 12px' }}><Icon name="ext" size={11} color="#06201E"/> Paylaş</button>
      </div>

      {/* report content */}
      <div className="scroll" style={{ flex: 1, overflow: 'auto', padding: '24px 28px 40px' }}>
        {/* hero */}
        <div style={{
          padding: '26px 30px', borderRadius: 16, marginBottom: 18,
          background: `linear-gradient(135deg, ${c}15, transparent 60%)`,
          border: `1px solid ${c}33`, position: 'relative', overflow: 'hidden'
        }}>
          <div style={{ position: 'absolute', right: -40, top: -40, width: 220, height: 220, borderRadius: '50%', background: `radial-gradient(circle, ${c}22, transparent 60%)` }}/>
          <div style={{ position: 'relative', display: 'flex', alignItems: 'center', gap: 18 }}>
            <div style={{ width: 64, height: 64, borderRadius: 14, background: `${c}22`, border: `1px solid ${c}55`, display: 'grid', placeItems: 'center' }}>
              <TypeIcon type={pin.type} size={30} color={c}/>
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
                <span style={{ font: '600 10.5px/1 var(--font-mono)', color: c, textTransform: 'uppercase', letterSpacing: '.10em' }}>KAYNAK RAPORU · {TLabel[pin.type].toUpperCase()}</span>
                <span style={{ width: 4, height: 4, borderRadius: '50%', background: 'var(--text-4)' }}/>
                <span style={{ font: '500 11px/1 var(--font)', color: 'var(--text-3)' }}>Tek saha analizi</span>
              </div>
              <h1 style={{ margin: 0, font: '700 32px/1.1 var(--font)', letterSpacing: '-.025em' }}>{pin.name}</h1>
              <div style={{ marginTop: 8, display: 'flex', gap: 14, font: '500 12.5px/1.3 var(--font)', color: 'var(--text-2)' }}>
                <span><Icon name="pin" size={12} color="var(--text-3)"/> {pin.district} / {pin.city}</span>
                <span className="tnum" style={{ fontFamily: 'var(--font-mono)', color: 'var(--text-3)' }}>{pin.lat?.toFixed(4)}° · {pin.lng?.toFixed(4)}°</span>
                <span>Ekipman: <b style={{ color: 'var(--text)' }}>{pin.equipment}</b></span>
              </div>
            </div>
          </div>
          <div style={{ marginTop: 20, display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12 }}>
            <HeroKpi label="Kurulu Güç" value={pin.capacityMw.toFixed(1)} unit="MW" hint={`${pin.equipment}`} accent={c}/>
            <HeroKpi label="Yıllık Üretim" value={annualGwh.toFixed(1)} unit="GWh" hint={`Kapasite faktörü %${((pin.capacityFactor || 0.25)*100).toFixed(1)}`}/>
            <HeroKpi label="NPV (25y)" value={fmtMoney(capex * 1.6)} unit="" hint={`IRR ${(pin.roi > 7 ? 14.2 : 11.8).toFixed(1)}% · LCOE $${(pin.type === 'solar' ? 0.041 : pin.type === 'wind' ? 0.046 : 0.052).toFixed(3)}/kWh`} accent="var(--success)"/>
            <HeroKpi label="CO₂ Önlemesi" value={`${(co2/1000).toFixed(1)}K`} unit="ton/yıl" hint={`≈ ${Math.round(co2/4600/100)*100} araç eşdeğeri`} accent="#10B981"/>
          </div>
        </div>

        {/* production + financial side by side */}
        <div style={{ display: 'grid', gridTemplateColumns: '1.4fr 1fr', gap: 12, marginBottom: 12 }}>
          <ReportCard title="Aylık Üretim · 2025">
            <div style={{ display: 'flex', alignItems: 'flex-end', height: 200 }}>
              <MonthlyBars data={pin.monthly} color={c} width={620} height={180}/>
            </div>
            <div style={{ marginTop: 10, paddingTop: 12, borderTop: '1px dashed var(--border-2)', display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10 }}>
              {[
                ['Toplam', `${(pin.monthly.reduce((s,v)=>s+v,0)/1000).toFixed(0)}`, 'GWh'],
                ['Pik Ay', pin.type === 'solar' ? 'Tem' : pin.type === 'wind' ? 'Şub' : 'May', ''],
                ['Min Ay', pin.type === 'solar' ? 'Ara' : pin.type === 'wind' ? 'Tem' : 'Eyl', ''],
                ['Mevsimsellik', '1.42×', ''],
              ].map(([l, v, u]) => (
                <div key={l}>
                  <div className="label">{l}</div>
                  <div className="tnum" style={{ font: '700 16px/1 var(--font)', marginTop: 5 }}>{v}<span style={{ fontSize: 11, color: 'var(--text-3)', fontWeight: 500, marginLeft: 3 }}>{u}</span></div>
                </div>
              ))}
            </div>
          </ReportCard>
          <ReportCard title="Finansal Özet">
            <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
              <div style={{ padding: 12, background: 'rgba(0,0,0,.20)', borderRadius: 10, border: '1px solid var(--border-2)' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
                  <span className="label">Yatırım (CAPEX)</span>
                  <span className="tnum" style={{ font: '700 16px/1 var(--font)', color: 'var(--danger)' }}>−{fmtMoney(capex)}</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
                  <span className="label">Yıllık Gelir</span>
                  <span className="tnum" style={{ font: '700 16px/1 var(--font)', color: 'var(--success)' }}>+{fmtMoney(annualRev)}</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span className="label">Yıllık O&M</span>
                  <span className="tnum" style={{ font: '700 16px/1 var(--font)', color: 'var(--danger)' }}>−{fmtMoney(annualRev * 0.14)}</span>
                </div>
              </div>
              <div style={{ padding: 12, background: `${c}10`, border: `1px solid ${c}44`, borderRadius: 10 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
                  <div>
                    <div style={{ font: '600 11px/1 var(--font)', color: c, textTransform: 'uppercase', letterSpacing: '.06em' }}>Geri Ödeme Süresi</div>
                    <div className="tnum" style={{ font: '700 32px/1 var(--font)', marginTop: 6 }}>{pin.roi.toFixed(1)}<span style={{ fontSize: 14, color: 'var(--text-3)', fontWeight: 500, marginLeft: 3 }}>yıl</span></div>
                  </div>
                  <div style={{ textAlign: 'right' }}>
                    <div className="label">Kümülatif</div>
                    <div className="tnum" style={{ font: '700 18px/1 var(--font)', color: 'var(--success)', marginTop: 6 }}>+{fmtMoney(annualRev * 25 - capex)}</div>
                    <div style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)', marginTop: 4 }}>25 yıl</div>
                  </div>
                </div>
              </div>
            </div>
          </ReportCard>
        </div>

        {/* technical specs */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12 }}>
          <ReportCard title="Teknik Spesifikasyonlar">
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {(pin.type === 'solar' ? [
                ['Panel sayısı', '24,800'],
                ['Panel modeli', pin.equipment],
                ['Yıllık ışınım', `${pin.irradiance} kWh/m²·gün`],
                ['Panel alanı', `${(pin.panelArea/10000).toFixed(1)} ha`],
                ['Eğim açısı', '32°'],
                ['Azimut', '180° (Güney)'],
                ['Inverter verimi', '%98.4'],
                ['Yıllık dejenerasyon', '%0.55'],
              ] : pin.type === 'wind' ? [
                ['Türbin sayısı', '12'],
                ['Türbin modeli', pin.equipment],
                ['Ortalama rüzgar', `${pin.windSpeed} m/s @ 120m`],
                ['Kapasite faktörü', `%${(pin.capacityFactor*100).toFixed(1)}`],
                ['Hub yüksekliği', '125 m'],
                ['Rotor çapı', '150 m'],
                ['Cut-in / Cut-out', '3.5 / 25 m/s'],
                ['Yıllık dejenerasyon', '%0.40'],
              ] : [
                ['Türbin tipi', pin.equipment],
                ['Net düşü', `${pin.headHeight} m`],
                ['Tasarım debisi', `${pin.flowRate} m³/s`],
                ['Yıllık akış', '142M m³'],
                ['Verim eğrisi', '%93 max'],
                ['Çevre debisi', '12.5%'],
                ['Hizmet kullanımı', '%99.2'],
                ['Yıllık dejenerasyon', '%0.20'],
              ]).map(([k, v]) => (
                <div key={k} style={{ display: 'flex', justifyContent: 'space-between', font: '500 12px/1.3 var(--font)', padding: '4px 0', borderBottom: '1px dashed var(--border-2)' }}>
                  <span style={{ color: 'var(--text-3)' }}>{k}</span>
                  <span className="tnum" style={{ color: 'var(--text)', fontWeight: 600, fontFamily: 'var(--font-mono)' }}>{v}</span>
                </div>
              ))}
            </div>
          </ReportCard>

          <ReportCard title="Saha Koşulları">
            <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
              {[
                ['Yıllık ortalama sıcaklık',  '14.2°C',  0.72, '#3B82F6'],
                ['Yağış',                      '385 mm',  0.45, '#06B6D4'],
                ['Toz/aerosol indeksi',        'Düşük',   0.28, '#10B981'],
                ['Sismik bölge',               '3. derece', 0.55, '#F59E0B'],
                ['Şebeke mesafesi',            '4.2 km',  0.34, '#10B981'],
                ['Yol bağlantısı',             'Var',     0.10, '#10B981'],
              ].map(([k, v, ratio, col]) => (
                <div key={k}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 5 }}>
                    <span style={{ font: '500 11.5px/1 var(--font)', color: 'var(--text-2)', flex: 1 }}>{k}</span>
                    <span className="tnum" style={{ font: '600 11.5px/1 var(--font-mono)', color: 'var(--text)' }}>{v}</span>
                  </div>
                  <div style={{ height: 3, background: 'rgba(255,255,255,.05)', borderRadius: 2 }}>
                    <div style={{ height: '100%', width: `${ratio*100}%`, background: col, borderRadius: 2 }}/>
                  </div>
                </div>
              ))}
            </div>
          </ReportCard>

          <ReportCard title="Risk Profili" action={<span className="chip" style={{ borderColor: 'rgba(16,185,129,.4)', color: '#10B981' }}>DÜŞÜK</span>}>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {[
                ['Üretim Belirsizliği',   'P50 ile P90 arası: ±%12',  'düşük',   '#10B981'],
                ['Şebeke Bağlantısı',     'TEİAŞ kapasite onayı var', 'düşük',  '#10B981'],
                ['Çevresel Onay',         'ÇED süreci tamamlandı',    'düşük',  '#10B981'],
                ['Tarife/Regülasyon',     'YEKDEM mekanizması belirsiz', 'orta', '#F59E0B'],
                ['Ekipman Tedariki',      '18 ay teslimat süresi',     'orta',  '#F59E0B'],
                ['Finansman',             '%70 banka kredisi öngörüsü', 'düşük', '#10B981'],
              ].map(([k, sub, lvl, col]) => (
                <div key={k} style={{ display: 'flex', alignItems: 'flex-start', gap: 9, padding: '8px 0', borderBottom: '1px dashed var(--border-2)' }}>
                  <div style={{ width: 6, height: 6, borderRadius: '50%', background: col, marginTop: 6, flexShrink: 0 }}/>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ font: '600 12px/1.2 var(--font)', color: 'var(--text)' }}>{k}</div>
                    <div style={{ font: '500 10.5px/1.4 var(--font)', color: 'var(--text-3)', marginTop: 3 }}>{sub}</div>
                  </div>
                  <span style={{ font: '600 9.5px/1 var(--font)', color: col, textTransform: 'uppercase', letterSpacing: '.06em' }}>{lvl}</span>
                </div>
              ))}
            </div>
          </ReportCard>
        </div>

        {/* footer */}
        <div style={{ marginTop: 26, paddingTop: 18, borderTop: '1px dashed var(--border-2)', display: 'flex', alignItems: 'center', gap: 14, font: '500 11px/1.4 var(--font)', color: 'var(--text-3)' }}>
          <div style={{ width: 24, height: 24, borderRadius: 6, background: 'linear-gradient(135deg, var(--solar), var(--wind))', display: 'grid', placeItems: 'center' }}>
            <Icon name="globe" size={12} color="white"/>
          </div>
          <span><b style={{ color: 'var(--text-2)' }}>SRRP</b> · {pin.name} · Kaynak raporu</span>
          <div style={{ flex: 1 }}/>
          <span className="tnum" style={{ fontFamily: 'var(--font-mono)' }}>RPT-PIN-{pin.id.toString().padStart(4, '0')}</span>
        </div>
      </div>
    </div>
  );
};

// ============================================================================
// TABLET — Scenario Report (compact)
// ============================================================================
const TabletReportApp = () => {
  const [active, setActive] = useStateS('ozet');
  const [tocOpen, setTocOpen] = useStateS(false);
  const totals = SCENARIO_TOTALS;
  const meta = SCENARIO_META;
  return (
    <div style={{ width: 820, height: 1180, background: 'var(--bg)', display: 'flex', flexDirection: 'column', borderRadius: 16, overflow: 'hidden', border: '1px solid var(--border)' }}>
      {/* slim toolbar */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '12px 16px', background: 'rgba(20,24,34,.92)', borderBottom: '1px solid var(--border)' }}>
        <button className="btn btn-icon" onClick={() => setTocOpen(!tocOpen)}><Icon name="list" size={14}/></button>
        <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
          <div style={{ width: 24, height: 24, borderRadius: 7, background: 'rgba(20,184,166,.16)', display: 'grid', placeItems: 'center' }}>
            <Icon name="roi" size={12} color="var(--accent)"/>
          </div>
          <div>
            <div style={{ font: '700 13px/1 var(--font)' }}>Raporlar</div>
            <div style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)', marginTop: 3 }}>{meta.name}</div>
          </div>
        </div>
        <div style={{ flex: 1 }}/>
        <div className="seg" style={{ padding: 2 }}>
          {['12A', '5Y', '25Y'].map(t => (
            <button key={t} className={t === '25Y' ? 'on' : ''} style={{ padding: '6px 9px', font: '500 11px/1 var(--font-mono)' }}>{t}</button>
          ))}
        </div>
        <button className="btn btn-icon"><Icon name="ext" size={13}/></button>
      </div>

      {/* segmented section nav */}
      <div style={{ display: 'flex', gap: 4, padding: '10px 14px', borderBottom: '1px solid var(--border-2)', background: 'rgba(0,0,0,.12)', overflowX: 'auto' }} className="scroll">
        {TOC_ITEMS.map(it => {
          const on = it.id === active;
          return (
            <button key={it.id} onClick={() => setActive(it.id)} style={{
              flexShrink: 0, padding: '8px 12px',
              background: on ? 'rgba(20,184,166,.12)' : 'rgba(0,0,0,.18)',
              border: on ? '1px solid rgba(20,184,166,.4)' : '1px solid var(--border-2)',
              borderRadius: 8, cursor: 'pointer',
              display: 'flex', alignItems: 'center', gap: 6,
            }}>
              <span className="tnum" style={{ font: '600 10px/1 var(--font-mono)', color: on ? 'var(--accent)' : 'var(--text-3)', letterSpacing: '.08em' }}>{it.num}</span>
              <span style={{ font: '500 12px/1 var(--font)', color: on ? 'var(--text)' : 'var(--text-2)' }}>{it.label}</span>
            </button>
          );
        })}
      </div>

      {/* content */}
      <div className="scroll" style={{ flex: 1, overflow: 'auto', padding: '18px 18px 40px' }}>
        {active === 'ozet' && (
          <>
            <div style={{ marginBottom: 14 }}>
              <div style={{ font: '600 10px/1 var(--font-mono)', color: 'var(--accent)', letterSpacing: '.10em', marginBottom: 6 }}>SENARYO RAPORU</div>
              <h1 style={{ margin: 0, font: '700 26px/1.1 var(--font)', letterSpacing: '-.025em' }}>{meta.name}</h1>
              <div style={{ marginTop: 8, font: '500 12px/1.4 var(--font)', color: 'var(--text-3)' }}>{meta.description}</div>
            </div>
            <div style={{ marginBottom: 14 }}>
              <SmartInsights totals={totals} pins={REPORT_PINS} meta={meta} compact/>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 10, marginBottom: 14 }}>
              <HeroKpi label="Toplam Kapasite" value={fmtNum(totals.totalCap, 0)} unit="MW" accent="var(--accent)" delta={+12.4}/>
              <HeroKpi label="Yıllık Üretim" value={fmtNum(totals.annualGwh, 0)} unit="GWh" delta={+3.2}/>
              <HeroKpi label="NPV" value={fmtMoney(totals.npv)} unit="25y" accent="#10B981" delta={+8.1}/>
              <HeroKpi label="CO₂" value={`${(totals.co2Avoided/1000).toFixed(0)}K`} unit="ton/y" accent="#10B981" delta={+5.8}/>
            </div>
            <ReportCard title="Coğrafi Dağılım" padding={0} style={{ marginBottom: 12, overflow: 'hidden' }}>
              <div style={{ background: '#0E1219' }}><ReportMiniMap pins={REPORT_PINS} height={230}/></div>
            </ReportCard>
            <ReportCard title="Kaynak Karışımı">
              <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
                <DonutChart segments={[
                  { value: totals.byType.solar, color: TC.solar },
                  { value: totals.byType.wind,  color: TC.wind },
                  { value: totals.byType.hydro, color: TC.hydro },
                ]} size={130} thickness={18} centerLabel="TOPLAM" centerValue={fmtNum(totals.totalCap, 0)} centerUnit="MW"/>
                <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 10 }}>
                  {[['solar','Güneş'], ['wind','Rüzgar'], ['hydro','Hidro']].map(([k, l]) => (
                    <div key={k}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginBottom: 4 }}>
                        <div style={{ width: 9, height: 9, borderRadius: 2, background: TC[k] }}/>
                        <span style={{ font: '500 11px/1 var(--font)', color: 'var(--text-2)', flex: 1 }}>{l}</span>
                        <span className="tnum" style={{ font: '700 12px/1 var(--font)' }}>{fmtNum(totals.byType[k], 0)}<span style={{ color: 'var(--text-3)', fontWeight: 500, fontSize: 10 }}>MW</span></span>
                      </div>
                      <div style={{ height: 3, background: 'rgba(255,255,255,.05)', borderRadius: 2 }}>
                        <div style={{ height: '100%', width: `${(totals.byType[k]/totals.totalCap)*100}%`, background: TC[k] }}/>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </ReportCard>
          </>
        )}
        {active === 'uretim' && (
          <>
            <ReportCard title="Aylık Üretim · Kaynak Tipine Göre" style={{ marginBottom: 12 }}>
              <StackedMonthlyBars data={MONTHLY_BY_TYPE} height={220}/>
            </ReportCard>
            <ReportCard title="Günlük Üretim · 2025">
              <HeatmapCalendar data={HEATMAP_DAYS} height={120}/>
            </ReportCard>
          </>
        )}
        {active === 'finans' && (
          <>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 10, marginBottom: 12 }}>
              {[['NPV', fmtMoney(totals.npv), '25y', 'var(--success)'],
                ['IRR', `${(totals.irr*100).toFixed(1)}%`, '', 'var(--text)'],
                ['LCOE', `$${totals.lcoe.toFixed(3)}`, '/kWh', 'var(--text)'],
                ['Geri Ödeme', `${totals.paybackYear}y`, '', 'var(--text)']
              ].map(([l, v, u, col]) => (
                <div key={l} style={{ padding: 12, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 10 }}>
                  <div className="label">{l}</div>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: 4, marginTop: 5 }}>
                    <span className="tnum" style={{ font: '700 20px/1 var(--font)', color: col }}>{v}</span>
                    {u && <span style={{ font: '500 11px/1 var(--font)', color: 'var(--text-3)' }}>{u}</span>}
                  </div>
                </div>
              ))}
            </div>
            <ReportCard title="Kümülatif Nakit Akışı · P50/P90">
              <FanAreaChart data={CASHFLOW_SERIES} paybackYear={totals.paybackYear} height={200} width={750}/>
            </ReportCard>
          </>
        )}
        {active === 'hassasiyet' && (
          <ReportCard title="Tornado · NPV Hassasiyeti">
            <TornadoChart items={[
              { label: 'Elektrik Fiyatı',  lowDelta: -22.4, highDelta: +24.8, lowLabel: '1.10₺',  highLabel: '1.75₺' },
              { label: 'İskonto Oranı',    lowDelta: +18.2, highDelta: -16.5, lowLabel: '%6.0',   highLabel: '%11.0' },
              { label: 'Kapasite Faktörü', lowDelta: -14.6, highDelta: +14.2, lowLabel: '−%10',   highLabel: '+%10' },
              { label: 'CAPEX',            lowDelta: +12.8, highDelta: -13.1, lowLabel: '−%15',   highLabel: '+%15' },
              { label: 'Enflasyon Etkisi', lowDelta:  -8.4, highDelta:  +9.1, lowLabel: '%1.5',   highLabel: '%4.0' },
              { label: 'O&M Maliyeti',     lowDelta:  +4.2, highDelta:  -4.5, lowLabel: '%10',    highLabel: '%18' },
            ]} baseline={totals.npv/1e6} height={240} width={750}/>
          </ReportCard>
        )}
        {active === 'cevre' && (
          <>
            <ReportCard padding={20} style={{ background: 'linear-gradient(160deg, rgba(16,185,129,.10), rgba(20,184,166,.04))', borderColor: 'rgba(16,185,129,.25)', marginBottom: 12 }}>
              <div className="label" style={{ marginBottom: 8 }}>Kaçınılan Sera Gazı</div>
              <div className="tnum" style={{ font: '700 40px/1 var(--font)', color: '#10B981', letterSpacing: '-.03em' }}>{(totals.co2Avoided/1000).toFixed(0)}K<span style={{ fontSize: 14, color: 'var(--text-2)', fontWeight: 500, marginLeft: 6 }}>ton CO₂/yıl</span></div>
            </ReportCard>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10 }}>
              {[
                ['Hane', `${(totals.homesEquivalent/1000).toFixed(0)}K`],
                ['Ağaç', `${(totals.treesEquivalent/1000).toFixed(0)}K`],
                ['Araç', `${(totals.co2Avoided/4.6/1000).toFixed(0)}K`],
              ].map(([l, v]) => (
                <div key={l} style={{ padding: 14, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 10 }}>
                  <div className="label">{l}</div>
                  <div className="tnum" style={{ font: '700 22px/1 var(--font)', marginTop: 5, color: '#10B981' }}>{v}</div>
                </div>
              ))}
            </div>
          </>
        )}
        {active === 'config' && <Section06_Config meta={meta}/>}
      </div>
    </div>
  );
};

// ============================================================================
// MOBILE — Scenario Report (compact accordion)
// ============================================================================
const MobileReportApp = () => {
  const [active, setActive] = useStateS('ozet');
  const totals = SCENARIO_TOTALS;
  const meta = SCENARIO_META;
  return (
    <div style={{ width: 390, height: 844, background: 'var(--bg)', position: 'relative', overflow: 'hidden' }}>
      <div style={{ height: 47 }}/>
      <div style={{ position: 'absolute', left: 0, right: 0, top: 47, padding: '12px 14px 10px', display: 'flex', alignItems: 'center', gap: 9, background: 'rgba(20,24,34,.95)', backdropFilter: 'blur(14px)', borderBottom: '1px solid var(--border)', zIndex: 5 }}>
        <button className="btn btn-icon" style={{ padding: 6 }}><Icon name="chevL" size={14}/></button>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ font: '700 14px/1 var(--font)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>Raporlar</div>
          <div style={{ font: '500 10.5px/1 var(--font)', color: 'var(--text-3)', marginTop: 3 }}>{meta.name}</div>
        </div>
        <button className="btn btn-icon" style={{ padding: 6 }}><Icon name="ext" size={14}/></button>
      </div>
      {/* horizontal section chips */}
      <div style={{ position: 'absolute', left: 0, right: 0, top: 110, padding: '8px 14px', borderBottom: '1px solid var(--border-2)', background: 'rgba(0,0,0,.18)', zIndex: 4, overflowX: 'auto', whiteSpace: 'nowrap' }} className="scroll">
        {TOC_ITEMS.map(it => {
          const on = it.id === active;
          return (
            <button key={it.id} onClick={() => setActive(it.id)} style={{
              display: 'inline-flex', alignItems: 'center', gap: 5, padding: '6px 10px',
              marginRight: 5,
              background: on ? 'rgba(20,184,166,.14)' : 'transparent',
              border: on ? '1px solid rgba(20,184,166,.4)' : '1px solid var(--border-2)',
              borderRadius: 7, cursor: 'pointer',
            }}>
              <span className="tnum" style={{ font: '600 9.5px/1 var(--font-mono)', color: on ? 'var(--accent)' : 'var(--text-3)' }}>{it.num}</span>
              <span style={{ font: '500 11px/1 var(--font)', color: on ? 'var(--text)' : 'var(--text-2)' }}>{it.label}</span>
            </button>
          );
        })}
      </div>
      <div className="scroll" style={{ position: 'absolute', left: 0, right: 0, top: 156, bottom: 0, overflow: 'auto', padding: '14px 14px 30px' }}>
        {active === 'ozet' && (
          <>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8, marginBottom: 12 }}>
              <div style={{ padding: 12, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 10 }}>
                <div className="label">Kapasite</div>
                <div className="tnum" style={{ font: '700 22px/1 var(--font)', color: 'var(--accent)', marginTop: 4 }}>{fmtNum(totals.totalCap, 0)}<span style={{ fontSize: 11, color: 'var(--text-3)', fontWeight: 500, marginLeft: 3 }}>MW</span></div>
              </div>
              <div style={{ padding: 12, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 10 }}>
                <div className="label">Üretim</div>
                <div className="tnum" style={{ font: '700 22px/1 var(--font)', marginTop: 4 }}>{fmtNum(totals.annualGwh, 0)}<span style={{ fontSize: 11, color: 'var(--text-3)', fontWeight: 500, marginLeft: 3 }}>GWh</span></div>
              </div>
              <div style={{ padding: 12, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 10 }}>
                <div className="label">NPV</div>
                <div className="tnum" style={{ font: '700 22px/1 var(--font)', color: 'var(--success)', marginTop: 4 }}>{fmtMoney(totals.npv)}</div>
              </div>
              <div style={{ padding: 12, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 10 }}>
                <div className="label">CO₂</div>
                <div className="tnum" style={{ font: '700 22px/1 var(--font)', color: '#10B981', marginTop: 4 }}>{(totals.co2Avoided/1000).toFixed(0)}K<span style={{ fontSize: 10, color: 'var(--text-3)', fontWeight: 500, marginLeft: 3 }}>t/y</span></div>
              </div>
            </div>
            <ReportCard title="Coğrafi Dağılım" padding={0} style={{ overflow: 'hidden', marginBottom: 10 }}>
              <div style={{ background: '#0E1219' }}><ReportMiniMap pins={REPORT_PINS} height={180}/></div>
            </ReportCard>
            <ReportCard title="Kaynak Karışımı">
              <div style={{ display: 'flex', justifyContent: 'center' }}>
                <DonutChart segments={[
                  { value: totals.byType.solar, color: TC.solar },
                  { value: totals.byType.wind,  color: TC.wind },
                  { value: totals.byType.hydro, color: TC.hydro },
                ]} size={130} thickness={18} centerLabel="TOPLAM" centerValue={fmtNum(totals.totalCap, 0)} centerUnit="MW"/>
              </div>
              <div style={{ marginTop: 12, display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 6 }}>
                {[['solar','Güneş'], ['wind','Rüzgar'], ['hydro','Hidro']].map(([k, l]) => (
                  <div key={k} style={{ padding: 8, background: 'rgba(0,0,0,.20)', borderRadius: 7 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
                      <div style={{ width: 6, height: 6, borderRadius: '50%', background: TC[k] }}/>
                      <span style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)' }}>{l}</span>
                    </div>
                    <div className="tnum" style={{ font: '700 14px/1 var(--font)', marginTop: 4 }}>{fmtNum(totals.byType[k], 0)}<span style={{ fontSize: 9, color: 'var(--text-3)', fontWeight: 500, marginLeft: 2 }}>MW</span></div>
                  </div>
                ))}
              </div>
            </ReportCard>
          </>
        )}
        {active === 'uretim' && (
          <>
            <ReportCard title="Aylık Üretim" style={{ marginBottom: 10 }}>
              <StackedMonthlyBars data={MONTHLY_BY_TYPE} height={180}/>
            </ReportCard>
            <ReportCard title="Günlük 2025">
              <HeatmapCalendar data={HEATMAP_DAYS} height={110}/>
            </ReportCard>
          </>
        )}
        {active === 'finans' && (
          <>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8, marginBottom: 10 }}>
              {[['NPV', fmtMoney(totals.npv), 'var(--success)'],
                ['IRR', `${(totals.irr*100).toFixed(1)}%`, 'var(--text)'],
                ['LCOE', `$${totals.lcoe.toFixed(3)}`, 'var(--text)'],
                ['Geri Öd.', `${totals.paybackYear}y`, 'var(--text)']
              ].map(([l, v, col]) => (
                <div key={l} style={{ padding: 11, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 9 }}>
                  <div className="label">{l}</div>
                  <div className="tnum" style={{ font: '700 18px/1 var(--font)', color: col, marginTop: 4 }}>{v}</div>
                </div>
              ))}
            </div>
            <ReportCard title="Nakit Akışı · 25y">
              <FanAreaChart data={CASHFLOW_SERIES} paybackYear={totals.paybackYear} height={180} width={360}/>
            </ReportCard>
          </>
        )}
        {active === 'hassasiyet' && (
          <ReportCard title="Tornado · Hassasiyet">
            <TornadoChart items={[
              { label: 'Elektrik',     lowDelta: -22.4, highDelta: +24.8, lowLabel: '−', highLabel: '+' },
              { label: 'İskonto',      lowDelta: +18.2, highDelta: -16.5, lowLabel: '−', highLabel: '+' },
              { label: 'Kap. Faktörü', lowDelta: -14.6, highDelta: +14.2, lowLabel: '−', highLabel: '+' },
              { label: 'CAPEX',        lowDelta: +12.8, highDelta: -13.1, lowLabel: '−', highLabel: '+' },
            ]} baseline={totals.npv/1e6} height={220} width={360}/>
          </ReportCard>
        )}
        {active === 'cevre' && (
          <>
            <ReportCard padding={16} style={{ background: 'linear-gradient(160deg, rgba(16,185,129,.10), rgba(20,184,166,.04))', borderColor: 'rgba(16,185,129,.25)', marginBottom: 10 }}>
              <div className="label" style={{ marginBottom: 6 }}>Kaçınılan CO₂</div>
              <div className="tnum" style={{ font: '700 32px/1 var(--font)', color: '#10B981' }}>{(totals.co2Avoided/1000).toFixed(0)}K<span style={{ fontSize: 12, color: 'var(--text-2)', fontWeight: 500, marginLeft: 4 }}>ton/yıl</span></div>
            </ReportCard>
            {[
              ['Hane Eşdeğeri', `${(totals.homesEquivalent/1000).toFixed(0)}K`, 'globe'],
              ['Ağaç Eşdeğeri', `${(totals.treesEquivalent/1000).toFixed(0)}K`, 'water'],
              ['Araç Eşdeğeri', `${(totals.co2Avoided/4.6/1000).toFixed(0)}K`, 'roi'],
            ].map(([l, v, ic]) => (
              <div key={l} style={{ padding: 12, marginBottom: 8, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 10, display: 'flex', alignItems: 'center', gap: 12 }}>
                <div style={{ width: 32, height: 32, borderRadius: 8, background: 'rgba(16,185,129,.10)', border: '1px solid rgba(16,185,129,.3)', display: 'grid', placeItems: 'center' }}>
                  <Icon name={ic} size={14} color="#10B981"/>
                </div>
                <div style={{ flex: 1 }}>
                  <div className="label">{l}</div>
                  <div className="tnum" style={{ font: '700 18px/1 var(--font)', marginTop: 4 }}>{v}</div>
                </div>
              </div>
            ))}
          </>
        )}
        {active === 'config' && <Section06_Config meta={meta}/>}
      </div>
      {/* tab bar */}
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: 84, background: 'rgba(20,24,34,.95)', backdropFilter: 'blur(20px)', borderTop: '1px solid var(--border)', display: 'flex', paddingBottom: 24 }}>
        {[
          { i: 'globe', l: 'Harita' },
          { i: 'list', l: 'Liste' },
          { i: 'roi', l: 'Rapor', on: true },
          { i: 'gear', l: 'Ayarlar' },
        ].map(t => (
          <button key={t.i} style={{ flex: 1, background: 'transparent', border: 'none', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, padding: '10px 0', cursor: 'pointer' }}>
            <Icon name={t.i} size={20} color={t.on ? 'var(--accent)' : 'var(--text-3)'}/>
            <span style={{ font: '600 10px/1 var(--font)', color: t.on ? 'var(--accent)' : 'var(--text-3)' }}>{t.l}</span>
          </button>
        ))}
      </div>
    </div>
  );
};

Object.assign(window, { DesktopReportApp, PinReportApp, TabletReportApp, MobileReportApp });
