// reports-landing-responsive.jsx — Tablet + Mobile versions of Landing page

// ============================================================================
// LANDING — Tablet (820×1180 portrait)
// ============================================================================
const LandingTablet = () => {
  const [resourceFilter, setResourceFilter] = useStateL('all');
  const stats = TR_STATS;
  const topProvinces = [...TR_PROVINCES].sort((a, b) => b.score - a.score).slice(0, 6);

  return (
    <div style={{ width: 820, height: 1180, background: 'var(--bg)', display: 'flex', flexDirection: 'column', borderRadius: 16, overflow: 'hidden', border: '1px solid var(--border)' }}>
      {/* slim toolbar */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '12px 16px', background: 'rgba(20,24,34,.92)', borderBottom: '1px solid var(--border)' }}>
        <div style={{ width: 24, height: 24, borderRadius: 7, background: 'rgba(20,184,166,.16)', display: 'grid', placeItems: 'center' }}>
          <Icon name="roi" size={12} color="var(--accent)"/>
        </div>
        <div>
          <div style={{ font: '700 13px/1 var(--font)' }}>Raporlar</div>
          <div style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)', marginTop: 3 }}>Türkiye yenilenebilir analiz merkezi</div>
        </div>
        <div style={{ flex: 1 }}/>
        <span className="chip"><span style={{ width: 5, height: 5, borderRadius: '50%', background: '#10B981' }}/>Canlı</span>
      </div>
      {/* tab strip */}
      <div style={{ display: 'flex', gap: 4, padding: '8px 14px', background: 'rgba(0,0,0,.18)', borderBottom: '1px solid var(--border-2)', overflowX: 'auto', whiteSpace: 'nowrap' }} className="scroll">
        {[
          ['landing', 'Genel Bakış', 'globe', true],
          ['bolge', 'Bölge', 'layers'],
          ['il', 'İl', 'pin'],
          ['senaryo', 'Senaryo', 'cal'],
          ['santral', 'Santral', 'eq'],
        ].map(([id, l, ic, on]) => (
          <button key={id} style={{
            padding: '8px 11px', borderRadius: 7, border: on ? '1px solid rgba(20,184,166,.4)' : '1px solid var(--border-2)',
            background: on ? 'rgba(20,184,166,.12)' : 'rgba(0,0,0,.18)', cursor: 'pointer',
            display: 'inline-flex', alignItems: 'center', gap: 6,
            font: on ? '600 11.5px/1 var(--font)' : '500 11.5px/1 var(--font)',
            color: on ? 'var(--text)' : 'var(--text-2)', flexShrink: 0,
          }}>
            <Icon name={ic} size={11} color={on ? 'var(--accent)' : 'var(--text-3)'}/>{l}
          </button>
        ))}
      </div>

      <div className="scroll" style={{ flex: 1, overflow: 'auto', padding: '16px 16px 40px' }}>
        {/* Hero KPIs */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 10, marginBottom: 14 }}>
          <div style={{ padding: 14, background: 'linear-gradient(160deg, rgba(20,184,166,.10), transparent 60%)', border: '1px solid rgba(20,184,166,.30)', borderRadius: 12 }}>
            <div className="label" style={{ marginBottom: 5 }}>Kurulu Güç</div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
              <span className="tnum" style={{ font: '700 28px/1 var(--font)', color: 'var(--accent)' }}>{(stats.totalInstalledMw/1000).toFixed(1)}</span>
              <span style={{ font: '500 12px/1 var(--font)', color: 'var(--text-3)' }}>GW</span>
            </div>
            <div style={{ marginTop: 8, font: '500 10px/1.3 var(--font)', color: 'var(--text-3)' }}>Yenilenebilir: <b className="tnum" style={{ color: 'var(--accent)' }}>%{(stats.renewableShare*100).toFixed(1)}</b></div>
          </div>
          <div style={{ padding: 14, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12 }}>
            <div className="label" style={{ marginBottom: 5 }}>Yıllık Üretim</div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
              <span className="tnum" style={{ font: '700 28px/1 var(--font)' }}>{Math.round(stats.annualProductionGwh/1000)}</span>
              <span style={{ font: '500 12px/1 var(--font)', color: 'var(--text-3)' }}>TWh</span>
            </div>
            <div style={{ marginTop: 8, font: '500 10px/1.3 var(--font)', color: 'var(--text-3)' }}>Yenil.: <b className="tnum">{Math.round(stats.renewableProductionGwh/1000)} TWh</b></div>
          </div>
          <div style={{ padding: 14, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12 }}>
            <div className="label" style={{ marginBottom: 5 }}>CO₂ Önlemesi</div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
              <span className="tnum" style={{ font: '700 28px/1 var(--font)', color: '#10B981' }}>{Math.round(stats.co2AvoidedKtPerYear/1000)}</span>
              <span style={{ font: '500 12px/1 var(--font)', color: 'var(--text-3)' }}>Mt/yıl</span>
            </div>
            <div style={{ marginTop: 8, font: '500 10px/1.3 var(--font)', color: 'var(--text-3)' }}>2035 hedefi yolda</div>
          </div>
          <div style={{ padding: 14, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12 }}>
            <div className="label" style={{ marginBottom: 5 }}>Hedef · 2035</div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
              <span className="tnum" style={{ font: '700 28px/1 var(--font)' }}>220</span>
              <span style={{ font: '500 12px/1 var(--font)', color: 'var(--text-3)' }}>GW</span>
            </div>
            <div style={{ marginTop: 8, font: '500 10px/1.3 var(--font)', color: 'var(--text-3)' }}>Yenil. payı: <b className="tnum" style={{ color: 'var(--accent)' }}>%75</b></div>
          </div>
        </div>

        {/* Map */}
        <div style={{ padding: 14, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12, marginBottom: 14 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
            <span className="label" style={{ flex: 1 }}>Türkiye Potansiyel Haritası</span>
            <ResourceFilterChips active={resourceFilter} onChange={setResourceFilter}/>
          </div>
          <TurkeyRegionMap byResource={resourceFilter} height={320}/>
        </div>

        {/* Region cards 2-col */}
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 10, marginBottom: 10 }}>
          <h2 style={{ margin: 0, font: '700 15px/1 var(--font)' }}>Coğrafi Bölgeler</h2>
          <span style={{ font: '500 11px/1 var(--font)', color: 'var(--text-3)' }}>· 7 bölge</span>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 8, marginBottom: 14 }}>
          {TR_REGIONS.map(r => <RegionCard key={r.id} region={r}/>)}
        </div>

        {/* Top 6 provinces */}
        <div style={{ padding: 14, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12, marginBottom: 14 }}>
          <div className="label" style={{ marginBottom: 10 }}>En Verimli 6 İl</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 5 }}>
            {topProvinces.map((p, i) => {
              const region = TR_REGIONS.find(r => r.id === p.region);
              const c = TC[p.topRes];
              return (
                <div key={p.id} style={{ display: 'grid', gridTemplateColumns: '20px 1fr 60px 60px 40px', gap: 8, alignItems: 'center', padding: '8px 8px', background: 'rgba(0,0,0,.18)', borderRadius: 7 }}>
                  <span className="tnum" style={{ font: '700 11px/1 var(--font-mono)', color: i < 3 ? c : 'var(--text-3)' }}>#{i+1}</span>
                  <div>
                    <div style={{ font: '600 12px/1 var(--font)' }}>{p.name}</div>
                    <div style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)', marginTop: 3 }}>{region.name}</div>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 4, padding: '2px 6px', background: `${c}22`, borderRadius: 4, justifySelf: 'start' }}>
                    <TypeIcon type={p.topRes} size={9} color={c}/>
                    <span style={{ font: '600 9.5px/1 var(--font)', color: c }}>{TLabel[p.topRes]}</span>
                  </div>
                  <span className="tnum" style={{ font: '600 11.5px/1 var(--font-mono)', textAlign: 'right' }}>{p.capacityMw}<span style={{ color: 'var(--text-3)', fontWeight: 500, fontSize: 9, marginLeft: 2 }}>MW</span></span>
                  <span className="tnum" style={{ font: '700 11px/1 var(--font-mono)', color: c, textAlign: 'right' }}>{p.score}</span>
                </div>
              );
            })}
          </div>
        </div>

        {/* Trend chart */}
        <div style={{ padding: 14, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 12, marginBottom: 14 }}>
          <div className="label" style={{ marginBottom: 10 }}>10 Yıllık Kurulu Güç Trendi</div>
          <TrendChart data={TR_STATS.capacityTrend} width={750} height={200}/>
        </div>

        {/* Quick access — stacked */}
        <h2 style={{ margin: '0 0 10px', font: '700 15px/1 var(--font)' }}>Detaylı Analiz</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 8 }}>
          <QuickAccessCard icon="layers" title="Bölge Analizi" sub="7 bölge · iklim profili" count="7" color="#A855F7"/>
          <QuickAccessCard icon="pin" title="İl Analizi" sub="81 il · ilçe potansiyeli" count="81" color="#3B82F6"/>
          <QuickAccessCard icon="cal" title="Senaryo Raporları" sub="Portföy analizi" count="4" color="var(--accent)"/>
          <QuickAccessCard icon="eq" title="Santral Analizi" sub="Pin bazlı analiz" count="14" color="#F59E0B"/>
        </div>
      </div>
    </div>
  );
};

// ============================================================================
// LANDING — Mobile (390×844)
// ============================================================================
const LandingMobile = () => {
  const [resourceFilter, setResourceFilter] = useStateL('all');
  const stats = TR_STATS;
  const topProvinces = [...TR_PROVINCES].sort((a, b) => b.score - a.score).slice(0, 5);

  return (
    <div style={{ width: 390, height: 844, background: 'var(--bg)', position: 'relative', overflow: 'hidden' }}>
      <div style={{ height: 47 }}/>
      <div style={{ position: 'absolute', left: 0, right: 0, top: 47, padding: '12px 14px 10px', display: 'flex', alignItems: 'center', gap: 9, background: 'rgba(20,24,34,.95)', backdropFilter: 'blur(14px)', borderBottom: '1px solid var(--border)', zIndex: 5 }}>
        <div style={{ width: 26, height: 26, borderRadius: 7, background: 'rgba(20,184,166,.16)', display: 'grid', placeItems: 'center' }}>
          <Icon name="roi" size={12} color="var(--accent)"/>
        </div>
        <div style={{ flex: 1 }}>
          <div style={{ font: '700 14px/1 var(--font)' }}>Raporlar</div>
          <div style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)', marginTop: 3 }}>Türkiye genel bakış</div>
        </div>
        <button className="btn btn-icon" style={{ padding: 6 }}><Icon name="filter" size={13}/></button>
      </div>
      {/* tab strip */}
      <div style={{ position: 'absolute', left: 0, right: 0, top: 110, padding: '8px 14px', background: 'rgba(0,0,0,.18)', borderBottom: '1px solid var(--border-2)', overflowX: 'auto', whiteSpace: 'nowrap', zIndex: 4 }} className="scroll">
        {[
          ['landing', 'Genel', 'globe', true],
          ['bolge', 'Bölge', 'layers'],
          ['il', 'İl', 'pin'],
          ['senaryo', 'Senaryo', 'cal'],
          ['santral', 'Santral', 'eq'],
        ].map(([id, l, ic, on]) => (
          <button key={id} style={{
            display: 'inline-flex', alignItems: 'center', gap: 5,
            padding: '7px 10px', marginRight: 5,
            borderRadius: 7, border: on ? '1px solid rgba(20,184,166,.4)' : '1px solid var(--border-2)',
            background: on ? 'rgba(20,184,166,.12)' : 'transparent', cursor: 'pointer',
            font: on ? '600 11.5px/1 var(--font)' : '500 11.5px/1 var(--font)',
            color: on ? 'var(--text)' : 'var(--text-2)',
          }}>
            <Icon name={ic} size={11} color={on ? 'var(--accent)' : 'var(--text-3)'}/>{l}
          </button>
        ))}
      </div>

      <div className="scroll" style={{ position: 'absolute', left: 0, right: 0, top: 158, bottom: 84, overflow: 'auto', padding: '14px 14px 30px' }}>
        {/* Hero card */}
        <div style={{ padding: 14, marginBottom: 12, background: 'linear-gradient(160deg, rgba(20,184,166,.12), transparent 60%)', border: '1px solid rgba(20,184,166,.30)', borderRadius: 12 }}>
          <div className="label" style={{ marginBottom: 6 }}>Kurulu Güç</div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 5 }}>
            <span className="tnum" style={{ font: '700 36px/1 var(--font)', color: 'var(--accent)', letterSpacing: '-.02em' }}>{(stats.totalInstalledMw/1000).toFixed(1)}</span>
            <span style={{ font: '600 14px/1 var(--font)', color: 'var(--text-2)' }}>GW</span>
          </div>
          <div style={{ marginTop: 10, paddingTop: 10, borderTop: '1px dashed var(--border-2)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', font: '500 10.5px/1 var(--font)', marginBottom: 5 }}>
              <span style={{ color: 'var(--text-3)' }}>Yenilenebilir</span>
              <span className="tnum" style={{ color: 'var(--accent)', fontWeight: 700 }}>%{(stats.renewableShare*100).toFixed(1)}</span>
            </div>
            <div style={{ height: 5, background: 'rgba(255,255,255,.05)', borderRadius: 3, overflow: 'hidden' }}>
              <div style={{ height: '100%', width: `${stats.renewableShare*100}%`, background: 'var(--accent)', borderRadius: 3 }}/>
            </div>
          </div>
        </div>

        {/* mini KPI grid */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 8, marginBottom: 12 }}>
          <div style={{ padding: 12, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 10 }}>
            <div className="label">Üretim</div>
            <div className="tnum" style={{ font: '700 20px/1 var(--font)', marginTop: 5 }}>{Math.round(stats.annualProductionGwh/1000)}<span style={{ fontSize: 10, color: 'var(--text-3)', fontWeight: 500, marginLeft: 2 }}>TWh</span></div>
          </div>
          <div style={{ padding: 12, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 10 }}>
            <div className="label">CO₂</div>
            <div className="tnum" style={{ font: '700 20px/1 var(--font)', color: '#10B981', marginTop: 5 }}>{Math.round(stats.co2AvoidedKtPerYear/1000)}<span style={{ fontSize: 10, color: 'var(--text-3)', fontWeight: 500, marginLeft: 2 }}>Mt/y</span></div>
          </div>
        </div>

        {/* Map */}
        <div style={{ padding: 12, marginBottom: 12, background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 10 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 8 }}>
            <span className="label" style={{ flex: 1 }}>Potansiyel</span>
            <ResourceFilterChips active={resourceFilter} onChange={setResourceFilter}/>
          </div>
          <TurkeyRegionMap byResource={resourceFilter} height={200}/>
        </div>

        {/* Top 5 provinces */}
        <div className="label" style={{ marginBottom: 8 }}>En Verimli 5 İl</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 5, marginBottom: 12 }}>
          {topProvinces.map((p, i) => {
            const region = TR_REGIONS.find(r => r.id === p.region);
            const c = TC[p.topRes];
            return (
              <div key={p.id} style={{ display: 'flex', alignItems: 'center', gap: 9, padding: '8px 10px', background: 'rgba(0,0,0,.18)', border: '1px solid var(--border-2)', borderRadius: 8 }}>
                <span className="tnum" style={{ font: '700 11px/1 var(--font-mono)', color: i < 3 ? c : 'var(--text-3)', minWidth: 18 }}>#{i+1}</span>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ font: '600 12.5px/1 var(--font)' }}>{p.name}</div>
                  <div style={{ font: '500 10px/1 var(--font)', color: 'var(--text-3)', marginTop: 3 }}>{region.name}</div>
                </div>
                <div style={{ width: 18, height: 18, borderRadius: 5, background: `${c}22`, display: 'grid', placeItems: 'center' }}>
                  <TypeIcon type={p.topRes} size={9} color={c}/>
                </div>
                <span className="tnum" style={{ font: '600 11px/1 var(--font-mono)' }}>{p.capacityMw}<span style={{ color: 'var(--text-3)', fontWeight: 500, fontSize: 9, marginLeft: 2 }}>MW</span></span>
              </div>
            );
          })}
        </div>

        {/* Regions list */}
        <div className="label" style={{ marginBottom: 8 }}>Bölgeler</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6, marginBottom: 12 }}>
          {TR_REGIONS.map(r => (
            <div key={r.id} style={{ padding: '10px 12px', background: 'var(--card)', border: '1px solid var(--border-2)', borderRadius: 9, position: 'relative', overflow: 'hidden' }}>
              <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: 3, background: r.color }}/>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span style={{ font: '600 12.5px/1 var(--font)', flex: 1 }}>{r.name}</span>
                <span className="tnum" style={{ font: '700 12px/1 var(--font-mono)', color: r.color }}>{(r.capacityMw/1000).toFixed(1)}<span style={{ color: 'var(--text-3)', fontWeight: 500, fontSize: 9 }}>GW</span></span>
                <Icon name="chevR" size={12} color="var(--text-3)"/>
              </div>
            </div>
          ))}
        </div>

        {/* Quick access */}
        <div className="label" style={{ marginBottom: 8 }}>Detaylı Analiz</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          <QuickAccessCard icon="layers" title="Bölge Analizi" sub="7 bölge · iklim profili" count="7" color="#A855F7"/>
          <QuickAccessCard icon="pin" title="İl Analizi" sub="81 il · ilçe potansiyeli" count="81" color="#3B82F6"/>
          <QuickAccessCard icon="cal" title="Senaryo Raporları" sub="Portföy analizi" count="4" color="var(--accent)"/>
          <QuickAccessCard icon="eq" title="Santral Analizi" sub="Pin bazlı analiz" count="14" color="#F59E0B"/>
        </div>
      </div>

      {/* bottom tab bar */}
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

Object.assign(window, { LandingTablet, LandingMobile });
