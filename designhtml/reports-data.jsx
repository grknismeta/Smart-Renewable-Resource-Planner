// reports-data.jsx — synthetic but coherent data for the SRRP scenario report
// Build on top of SAMPLE_PINS from shared.jsx; extend to 14 pins for the active scenario.

const EXTRA_PINS = [
  { id: 6,  type: 'solar', name: 'Aksaray Eskil GES',  city: 'Aksaray', district: 'Eskil',     capacityMw: 22.0, annualKwh: 47.2e6, roi: 6.0, capacityFactor: 0.245, equipment: 'Trina Vertex 660W' },
  { id: 7,  type: 'solar', name: 'Şanlıurfa Viranşehir',city: 'Şanlıurfa',district: 'Viranşehir',capacityMw: 35.0, annualKwh: 78.0e6, roi: 5.7, capacityFactor: 0.255, equipment: 'JA Solar 580W' },
  { id: 8,  type: 'solar', name: 'Niğde Bor GES',       city: 'Niğde',   district: 'Bor',       capacityMw: 8.5,  annualKwh: 18.6e6, roi: 6.4, capacityFactor: 0.250, equipment: 'Trina Vertex 660W' },
  { id: 9,  type: 'wind',  name: 'Çanakkale Bozcaada', city: 'Çanakkale',district: 'Bozcaada',  capacityMw: 32.0, annualKwh: 98.4e6, roi: 7.6, capacityFactor: 0.351, equipment: 'Vestas V150 4.5MW' },
  { id: 10, type: 'wind',  name: 'Hatay Belen RES',    city: 'Hatay',   district: 'Belen',     capacityMw: 26.0, annualKwh: 76.1e6, roi: 7.9, capacityFactor: 0.334, equipment: 'Enercon E-138' },
  { id: 11, type: 'wind',  name: 'Manisa Soma',        city: 'Manisa',  district: 'Soma',      capacityMw: 14.0, annualKwh: 39.2e6, roi: 8.2, capacityFactor: 0.319, equipment: 'Nordex N149' },
  { id: 12, type: 'hydro', name: 'Rize İkizdere',      city: 'Rize',    district: 'İkizdere',  capacityMw: 11.0, annualKwh: 42.8e6, roi: 9.8, capacityFactor: 0.445, equipment: 'Francis Tipi' },
  { id: 13, type: 'hydro', name: 'Gümüşhane Torul',    city: 'Gümüşhane',district: 'Torul',    capacityMw: 18.5, annualKwh: 72.3e6, roi: 9.1, capacityFactor: 0.446, equipment: 'Kaplan Tipi' },
  { id: 14, type: 'solar', name: 'Karaman Ermenek',    city: 'Karaman', district: 'Ermenek',   capacityMw: 9.7,  annualKwh: 21.2e6, roi: 6.1, capacityFactor: 0.249, equipment: 'Trina Vertex 660W' },
];

// Synthesize monthly profiles
const profileFor = (type, capMw, seed = 1) => {
  // base shape by type, multiplied by approximate monthly capacity * hours
  const shapes = {
    solar: [0.55,0.62,0.78,0.92,1.05,1.18,1.22,1.18,1.05,0.85,0.62,0.50],
    wind:  [1.16,1.18,1.22,1.05,0.86,0.78,0.74,0.78,0.92,1.10,1.20,1.18],
    hydro: [0.62,0.65,0.92,1.30,1.55,1.42,1.05,0.78,0.65,0.78,0.84,0.82],
  };
  const cf = type === 'solar' ? 0.25 : type === 'wind' ? 0.33 : 0.45;
  const annualMwh = capMw * 8760 * cf;
  const avg = annualMwh / 12;
  return shapes[type].map((s, i) => Math.round(avg * s * (1 + ((seed + i) % 7 - 3) * 0.015)));
};

const REPORT_PINS = [
  ...SAMPLE_PINS,
  ...EXTRA_PINS.map(p => ({ ...p, monthly: profileFor(p.type, p.capacityMw, p.id) })),
];

// Aggregate totals
const SCENARIO_META = {
  id: 's1',
  name: 'Türkiye 2030 Yenilenebilir',
  description: 'Çok kaynaklı portföy — 14 saha · 7 il · 25 yıl projeksiyon',
  createdBy: 'Ayşe Demir',
  createdAt: '14 Mart 2026',
  updatedAt: '11 Mayıs 2026',
  horizonYears: 25,
  discountRate: 0.085,
  electricityPrice: 1.42, // TL/kWh equivalent → mock USD$0.072
  escalation: 0.025,
  capexPerMw: { solar: 0.78e6, wind: 1.32e6, hydro: 2.10e6 }, // $/MW
  opexPctOfRevenue: 0.14,
};

const SCENARIO_TOTALS = (() => {
  const totalCap = REPORT_PINS.reduce((s, p) => s + p.capacityMw, 0);
  const totalAnnual = REPORT_PINS.reduce((s, p) => s + p.annualKwh, 0); // kWh
  const annualGwh = totalAnnual / 1e6;
  const byType = { solar: 0, wind: 0, hydro: 0 };
  const annualByType = { solar: 0, wind: 0, hydro: 0 };
  REPORT_PINS.forEach(p => {
    byType[p.type] += p.capacityMw;
    annualByType[p.type] += p.annualKwh / 1e6;
  });
  const investment = REPORT_PINS.reduce((s, p) => s + p.capacityMw * SCENARIO_META.capexPerMw[p.type], 0);
  const annualRevenue = (totalAnnual * SCENARIO_META.electricityPrice / 27); // mock TL→USD ~27
  const annualOpex = annualRevenue * SCENARIO_META.opexPctOfRevenue;
  const annualCashflow = annualRevenue - annualOpex;
  // Simple NPV
  let npv = -investment;
  let cumCash = [];
  let cum = -investment;
  cumCash.push(cum);
  for (let y = 1; y <= SCENARIO_META.horizonYears; y++) {
    const degradation = Math.pow(1 - 0.006, y);
    const escalated = Math.pow(1 + SCENARIO_META.escalation, y);
    const cf = annualCashflow * degradation * escalated;
    npv += cf / Math.pow(1 + SCENARIO_META.discountRate, y);
    cum += cf;
    cumCash.push(cum);
  }
  const paybackYear = cumCash.findIndex(v => v > 0);
  return {
    totalCap, annualGwh, byType, annualByType,
    investment, annualRevenue, annualOpex, annualCashflow,
    npv, paybackYear,
    irr: 0.142, lcoe: 0.045,
    co2Avoided: Math.round(annualGwh * 1e3 * 0.689), // kg/kWh → tons/year
    homesEquivalent: Math.round(annualGwh * 1e6 / 3500),
    treesEquivalent: Math.round(annualGwh * 1e3 * 0.689 / 22),
    cumCash,
  };
})();

// Aggregated monthly production by type (for the stacked chart)
const MONTHLY_BY_TYPE = (() => {
  const out = { solar: Array(12).fill(0), wind: Array(12).fill(0), hydro: Array(12).fill(0) };
  REPORT_PINS.forEach(p => {
    for (let i = 0; i < 12; i++) out[p.type][i] += p.monthly[i] || 0;
  });
  // mWh per month from kWh-ish numbers — normalize to GWh
  return {
    solar: out.solar.map(v => +(v / 1000).toFixed(1)),
    wind:  out.wind.map(v => +(v / 1000).toFixed(1)),
    hydro: out.hydro.map(v => +(v / 1000).toFixed(1)),
  };
})();

// 25-year cashflow series (already in cumCash)
const CASHFLOW_SERIES = SCENARIO_TOTALS.cumCash; // length = 26 (year 0..25)

// Daily-output heatmap data: 365 days, value 0..1 based on type-blend seasonal shape
const HEATMAP_DAYS = (() => {
  const data = [];
  for (let d = 0; d < 365; d++) {
    const month = Math.floor((d / 365) * 12);
    const solar = MONTHLY_BY_TYPE.solar[month];
    const wind  = MONTHLY_BY_TYPE.wind[month];
    const hydro = MONTHLY_BY_TYPE.hydro[month];
    const total = solar + wind + hydro;
    // Add day-of-week / weather variability
    const variability = 0.65 + 0.35 * Math.sin(d * 0.27 + 1.3) * Math.cos(d * 0.11);
    data.push(+(total * variability / 80).toFixed(2));
  }
  return data;
})();

// Pin positions on the report mini-map (approximate Türkiye coords on 1000x600 SVG)
const PIN_MAP_POS = {
  1: { x: 500, y: 410 }, 2: { x: 270, y: 270 }, 3: { x: 870, y: 240 },
  4: { x: 450, y: 470 }, 5: { x: 180, y: 350 }, 6: { x: 470, y: 380 },
  7: { x: 660, y: 460 }, 8: { x: 500, y: 380 }, 9: { x: 200, y: 240 },
  10:{ x: 660, y: 480 },11:{ x: 240, y: 320 },12:{ x: 760, y: 220 },
  13:{ x: 720, y: 250 },14:{ x: 460, y: 420 },
};

Object.assign(window, { REPORT_PINS, SCENARIO_META, SCENARIO_TOTALS, MONTHLY_BY_TYPE, CASHFLOW_SERIES, HEATMAP_DAYS, PIN_MAP_POS });
