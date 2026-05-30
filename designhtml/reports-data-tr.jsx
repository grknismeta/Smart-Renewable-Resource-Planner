// reports-data-tr.jsx — Türkiye geographic & energy data (regions, provinces, stats)

// ============================================================================
// 7 COĞRAFİ BÖLGE
// ============================================================================
const TR_REGIONS = [
  {
    id: 'marmara', name: 'Marmara', color: '#3B82F6',
    area: 67000, populationM: 26.0, provincesCount: 11,
    climateNote: 'Yarı-nemli geçiş iklimi · ılıman sıcaklıklar · orta düzey ışınım',
    bestFor: ['wind', 'solar'],
    topResource: 'wind',
    annualGwh: 28400, capacityMw: 8920,
    irradiance: 4.4, windSpeed: 7.8, precipitation: 720,
    description: 'Sahillerinde güçlü rüzgar potansiyeli (Bandırma, Çanakkale, Tekirdağ). İç kesimlerde orta düzey güneş kaynağı.',
  },
  {
    id: 'ege', name: 'Ege', color: '#F59E0B',
    area: 79000, populationM: 11.0, provincesCount: 8,
    climateNote: 'Akdeniz iklimi · sıcak/kurak yaz · yağışlı kış · yüksek ışınım',
    bestFor: ['solar', 'wind'],
    topResource: 'solar',
    annualGwh: 22100, capacityMw: 7140,
    irradiance: 5.4, windSpeed: 7.2, precipitation: 640,
    description: 'Türkiye\'nin rüzgar enerjisi başkenti (Çeşme, Aliağa). Yüksek güneş ışınımı, geniş tarım alanları.',
  },
  {
    id: 'akdeniz', name: 'Akdeniz', color: '#EF4444',
    area: 88000, populationM: 10.7, provincesCount: 8,
    climateNote: 'Akdeniz iklimi · sıcak yaz · ılıman kış · çok yüksek ışınım',
    bestFor: ['solar', 'hydro'],
    topResource: 'solar',
    annualGwh: 18900, capacityMw: 6320,
    irradiance: 5.6, windSpeed: 5.9, precipitation: 580,
    description: 'En yüksek güneş ışınımı bölgesi. Toros dağlarından beslenen güçlü akarsu sistemi (Manavgat, Göksu).',
  },
  {
    id: 'icanadolu', name: 'İç Anadolu', color: '#A855F7',
    area: 151000, populationM: 13.5, provincesCount: 13,
    climateNote: 'Karasal iklim · sıcak/kurak yaz · soğuk kış · çok yüksek ışınım',
    bestFor: ['solar'],
    topResource: 'solar',
    annualGwh: 31200, capacityMw: 10840,
    irradiance: 5.5, windSpeed: 6.1, precipitation: 380,
    description: 'Türkiye\'nin güneş enerjisi merkezi. Karapınar, Eskil, Cihanbeyli platosu en uygun GES bölgeleri.',
  },
  {
    id: 'karadeniz', name: 'Karadeniz', color: '#06B6D4',
    area: 109000, populationM: 8.0, provincesCount: 18,
    climateNote: 'Karadeniz iklimi · yüksek yağış · bol akarsu · düşük ışınım',
    bestFor: ['hydro'],
    topResource: 'hydro',
    annualGwh: 24600, capacityMw: 7290,
    irradiance: 3.6, windSpeed: 5.4, precipitation: 1240,
    description: 'Türkiye\'nin hidroelektrik kalbi. Çoruh, Yeşilırmak, Kızılırmak havzaları. Yüksek yağış ve eğim.',
  },
  {
    id: 'doguanadolu', name: 'Doğu Anadolu', color: '#10B981',
    area: 171000, populationM: 5.9, provincesCount: 14,
    climateNote: 'Karasal sert iklim · uzun soğuk kış · ışınım orta-yüksek · değişken rüzgar',
    bestFor: ['hydro', 'wind', 'solar'],
    topResource: 'hydro',
    annualGwh: 19800, capacityMw: 6180,
    irradiance: 4.8, windSpeed: 6.8, precipitation: 580,
    description: 'Yüksek rakım · Fırat ve Aras havzaları HES için uygun. Erzurum, Ağrı bölgesi rüzgar potansiyeli.',
  },
  {
    id: 'gdanadolu', name: 'Güneydoğu Anadolu', color: '#EAB308',
    area: 75000, populationM: 8.7, provincesCount: 9,
    climateNote: 'Karasal/yarı kurak · çok sıcak yaz · ılık kış · çok yüksek ışınım',
    bestFor: ['solar'],
    topResource: 'solar',
    annualGwh: 16800, capacityMw: 5240,
    irradiance: 5.7, windSpeed: 5.2, precipitation: 420,
    description: 'Yüksek güneş ışınımı, geniş düz arazi (Şanlıurfa Viranşehir, Mardin). GAP sayesinde hidroelektrik altyapısı.',
  },
];

// ============================================================================
// İLLER (öne çıkanlar — gerçek potansiyel sıralaması)
// ============================================================================
const TR_PROVINCES = [
  // İç Anadolu
  { id: 'konya',      name: 'Konya',      region: 'icanadolu', topRes: 'solar', score: 96, capacityMw: 1840, annualGwh: 4250, lat: 37.87, lng: 32.49, districts: ['Karapınar', 'Cihanbeyli', 'Ereğli', 'Akşehir', 'Beyşehir', 'Merkez'] },
  { id: 'aksaray',    name: 'Aksaray',    region: 'icanadolu', topRes: 'solar', score: 91, capacityMw: 720,  annualGwh: 1680, lat: 38.37, lng: 34.03, districts: ['Eskil', 'Ortaköy', 'Merkez', 'Güzelyurt'] },
  { id: 'nigde',      name: 'Niğde',      region: 'icanadolu', topRes: 'solar', score: 88, capacityMw: 480,  annualGwh: 1120, lat: 37.97, lng: 34.68, districts: ['Bor', 'Çiftlik', 'Ulukışla', 'Merkez'] },
  { id: 'ankara',     name: 'Ankara',     region: 'icanadolu', topRes: 'solar', score: 78, capacityMw: 620,  annualGwh: 1420, lat: 39.93, lng: 32.86, districts: ['Polatlı', 'Bala', 'Haymana', 'Çubuk'] },
  { id: 'kayseri',    name: 'Kayseri',    region: 'icanadolu', topRes: 'solar', score: 82, capacityMw: 540,  annualGwh: 1220, lat: 38.73, lng: 35.48, districts: ['Sarıoğlan', 'Bünyan', 'Pınarbaşı', 'Develi'] },
  // Güneydoğu
  { id: 'sanliurfa',  name: 'Şanlıurfa',  region: 'gdanadolu', topRes: 'solar', score: 94, capacityMw: 1620, annualGwh: 3820, lat: 37.16, lng: 38.79, districts: ['Viranşehir', 'Siverek', 'Harran', 'Akçakale', 'Birecik'] },
  { id: 'mardin',     name: 'Mardin',     region: 'gdanadolu', topRes: 'solar', score: 90, capacityMw: 580,  annualGwh: 1380, lat: 37.31, lng: 40.74, districts: ['Kızıltepe', 'Nusaybin', 'Midyat', 'Ömerli'] },
  { id: 'gaziantep',  name: 'Gaziantep',  region: 'gdanadolu', topRes: 'solar', score: 85, capacityMw: 720,  annualGwh: 1640, lat: 37.07, lng: 37.38, districts: ['Şahinbey', 'Nizip', 'İslahiye', 'Nurdağı'] },
  // Akdeniz
  { id: 'antalya',    name: 'Antalya',    region: 'akdeniz',   topRes: 'solar', score: 89, capacityMw: 880,  annualGwh: 2020, lat: 36.89, lng: 30.71, districts: ['Korkuteli', 'Manavgat', 'Serik', 'Kumluca', 'Elmalı'] },
  { id: 'mersin',     name: 'Mersin',     region: 'akdeniz',   topRes: 'solar', score: 84, capacityMw: 640,  annualGwh: 1480, lat: 36.81, lng: 34.64, districts: ['Tarsus', 'Erdemli', 'Anamur', 'Silifke'] },
  { id: 'adana',      name: 'Adana',      region: 'akdeniz',   topRes: 'solar', score: 81, capacityMw: 580,  annualGwh: 1320, lat: 37.00, lng: 35.32, districts: ['Ceyhan', 'Yumurtalık', 'Pozantı', 'Karataş'] },
  { id: 'hatay',      name: 'Hatay',      region: 'akdeniz',   topRes: 'wind',  score: 86, capacityMw: 720,  annualGwh: 2080, lat: 36.20, lng: 36.16, districts: ['Belen', 'Samandağ', 'Antakya', 'Kırıkhan'] },
  // Ege
  { id: 'izmir',      name: 'İzmir',      region: 'ege',       topRes: 'wind',  score: 92, capacityMw: 1480, annualGwh: 4180, lat: 38.42, lng: 27.13, districts: ['Çeşme', 'Aliağa', 'Bergama', 'Karaburun', 'Kemalpaşa'] },
  { id: 'manisa',     name: 'Manisa',     region: 'ege',       topRes: 'wind',  score: 85, capacityMw: 680,  annualGwh: 1920, lat: 38.61, lng: 27.43, districts: ['Soma', 'Akhisar', 'Kırkağaç', 'Gördes'] },
  { id: 'aydin',      name: 'Aydın',      region: 'ege',       topRes: 'wind',  score: 83, capacityMw: 540,  annualGwh: 1520, lat: 37.85, lng: 27.85, districts: ['Söke', 'Didim', 'Çine', 'Kuşadası'] },
  // Marmara
  { id: 'balikesir',  name: 'Balıkesir',  region: 'marmara',   topRes: 'wind',  score: 93, capacityMw: 1280, annualGwh: 3620, lat: 39.65, lng: 27.89, districts: ['Bandırma', 'Erdek', 'Susurluk', 'Edremit', 'Ayvalık'] },
  { id: 'canakkale',  name: 'Çanakkale',  region: 'marmara',   topRes: 'wind',  score: 91, capacityMw: 1140, annualGwh: 3240, lat: 40.16, lng: 26.40, districts: ['Bozcaada', 'Gökçeada', 'Ezine', 'Lapseki', 'Çan'] },
  { id: 'tekirdag',   name: 'Tekirdağ',   region: 'marmara',   topRes: 'wind',  score: 84, capacityMw: 620,  annualGwh: 1740, lat: 40.98, lng: 27.51, districts: ['Şarköy', 'Marmara Ereğlisi', 'Saray', 'Hayrabolu'] },
  { id: 'bursa',      name: 'Bursa',      region: 'marmara',   topRes: 'wind',  score: 76, capacityMw: 420,  annualGwh: 1180, lat: 40.18, lng: 29.06, districts: ['Karacabey', 'Mustafakemalpaşa', 'Orhaneli', 'Keles'] },
  // Karadeniz
  { id: 'artvin',     name: 'Artvin',     region: 'karadeniz', topRes: 'hydro', score: 95, capacityMw: 1340, annualGwh: 5240, lat: 41.18, lng: 41.82, districts: ['Yusufeli', 'Borçka', 'Şavşat', 'Hopa', 'Murgul'] },
  { id: 'rize',       name: 'Rize',       region: 'karadeniz', topRes: 'hydro', score: 92, capacityMw: 920,  annualGwh: 3580, lat: 41.02, lng: 40.52, districts: ['İkizdere', 'Pazar', 'Çamlıhemşin', 'Fındıklı'] },
  { id: 'gumushane',  name: 'Gümüşhane',  region: 'karadeniz', topRes: 'hydro', score: 87, capacityMw: 640,  annualGwh: 2480, lat: 40.46, lng: 39.48, districts: ['Torul', 'Kürtün', 'Şiran', 'Kelkit'] },
  { id: 'trabzon',    name: 'Trabzon',    region: 'karadeniz', topRes: 'hydro', score: 84, capacityMw: 520,  annualGwh: 1960, lat: 41.00, lng: 39.72, districts: ['Maçka', 'Of', 'Sürmene', 'Çaykara'] },
  { id: 'samsun',     name: 'Samsun',     region: 'karadeniz', topRes: 'hydro', score: 78, capacityMw: 380,  annualGwh: 1380, lat: 41.29, lng: 36.33, districts: ['Bafra', 'Çarşamba', 'Vezirköprü', 'Havza'] },
  // Doğu Anadolu
  { id: 'erzurum',    name: 'Erzurum',    region: 'doguanadolu', topRes: 'wind',  score: 82, capacityMw: 480, annualGwh: 1340, lat: 39.90, lng: 41.27, districts: ['Pasinler', 'Horasan', 'Aşkale', 'Tekman'] },
  { id: 'agri',       name: 'Ağrı',       region: 'doguanadolu', topRes: 'wind',  score: 78, capacityMw: 320, annualGwh: 880, lat: 39.72, lng: 43.05, districts: ['Doğubayazıt', 'Patnos', 'Eleşkirt', 'Diyadin'] },
  { id: 'elazig',     name: 'Elazığ',     region: 'doguanadolu', topRes: 'hydro', score: 86, capacityMw: 580, annualGwh: 2140, lat: 38.68, lng: 39.22, districts: ['Karakoçan', 'Palu', 'Maden', 'Sivrice'] },
];

// Add district potential scores (synthetic but reasonable)
TR_PROVINCES.forEach(p => {
  p.districtsData = p.districts.map((d, i) => ({
    name: d,
    // Higher score for first districts in list
    solarScore: Math.max(20, p.topRes === 'solar' ? 92 - i * 4 + (i % 2 ? -2 : 2) : 70 - i * 5),
    windScore:  Math.max(20, p.topRes === 'wind'  ? 90 - i * 5 + (i % 2 ? -3 : 1) : 55 - i * 4),
    hydroScore: Math.max(15, p.topRes === 'hydro' ? 93 - i * 4 + (i % 2 ? -2 : 2) : 30 + i * 2),
    availableMw: Math.round((80 - i * 12) * (1 + Math.sin(i) * 0.3)),
  }));
});

// ============================================================================
// TÜRKİYE GENEL İSTATİSTİKLERİ (gerçek, 2024 sonu yaklaşık)
// ============================================================================
const TR_STATS = {
  totalInstalledMw: 116800,        // 2024 sonu yaklaşık
  renewableMw: 65420,              // %56
  renewableShare: 0.560,
  solarMw: 19340,                  // güneş
  windMw: 12940,                   // rüzgar
  hydroMw: 31980,                  // hidro (en büyük)
  geothermalMw: 1750,
  biomassMw: 2410,
  annualProductionGwh: 326500,     // 2024 yıllık toplam
  renewableProductionGwh: 152800,  // %46.8 yenilenebilirden
  co2AvoidedKtPerYear: 105200,     // kton/yıl

  // Hedefler (Türkiye 2035 vizyonu)
  target2035Mw: 220000,            // toplam kurulu güç hedefi
  target2035RenewableShare: 0.75,  // %75 yenilenebilir

  // Potansiyel
  technicalPotentialMw: 480000,    // teknik potansiyel
  solarPotentialMw: 380000,        // güneş teknik potansiyel
  windPotentialMw: 88000,          // karasal rüzgar potansiyel
  hydroPotentialMw: 36000,         // hidroelektrik potansiyel (kalan)

  // Trend (son 10 yıl, GW)
  capacityTrend: [
    { year: 2015, total: 73.1, renewable: 31.5 },
    { year: 2016, total: 78.5, renewable: 34.4 },
    { year: 2017, total: 85.2, renewable: 38.8 },
    { year: 2018, total: 88.6, renewable: 42.3 },
    { year: 2019, total: 91.3, renewable: 45.9 },
    { year: 2020, total: 95.9, renewable: 49.3 },
    { year: 2021, total: 99.8, renewable: 53.7 },
    { year: 2022, total: 103.8, renewable: 57.6 },
    { year: 2023, total: 109.5, renewable: 60.9 },
    { year: 2024, total: 116.8, renewable: 65.4 },
  ],
};

// ============================================================================
// AYLIK İKLİM PROFİLLERİ — bölge bazlı (PVGIS/MGM/ERA-5'ten alınmış yaklaşık)
// ============================================================================
const REGION_WEATHER = {
  marmara: {
    irradiance:    [1.8, 2.5, 3.6, 4.9, 6.1, 6.8, 6.9, 6.2, 5.0, 3.4, 2.2, 1.6],
    windSpeed:     [8.2, 8.5, 7.8, 6.9, 6.4, 6.6, 7.1, 7.4, 7.0, 7.5, 8.0, 8.4],
    precipitation: [88, 70, 62, 48, 38, 28, 22, 18, 38, 65, 82, 94],
    temperature:   [4.8, 5.2, 7.4, 11.8, 16.4, 21.0, 23.6, 23.4, 19.8, 14.8, 9.6, 6.2],
    cloudCover:    [68, 64, 56, 48, 42, 32, 26, 28, 38, 52, 64, 72],
  },
  ege: {
    irradiance:    [2.0, 2.9, 4.2, 5.5, 6.8, 7.6, 7.7, 6.9, 5.5, 3.9, 2.5, 1.8],
    windSpeed:     [7.6, 7.4, 7.0, 6.5, 6.8, 7.4, 8.0, 8.2, 7.5, 6.8, 7.0, 7.6],
    precipitation: [98, 78, 62, 42, 28, 14, 8, 6, 16, 42, 78, 110],
    temperature:   [9.4, 10.0, 12.2, 15.8, 20.4, 25.2, 28.0, 27.6, 23.4, 18.6, 14.0, 10.8],
    cloudCover:    [58, 54, 46, 40, 32, 18, 12, 14, 22, 38, 52, 62],
  },
  akdeniz: {
    irradiance:    [2.2, 3.1, 4.4, 5.7, 7.0, 7.8, 7.9, 7.1, 5.7, 4.1, 2.7, 2.0],
    windSpeed:     [6.0, 6.2, 6.0, 5.8, 5.6, 6.0, 6.4, 6.6, 6.0, 5.8, 5.8, 6.0],
    precipitation: [120, 90, 70, 38, 22, 8, 4, 4, 18, 58, 90, 130],
    temperature:   [10.2, 11.0, 13.4, 16.8, 21.4, 26.0, 28.8, 28.6, 25.0, 20.4, 15.4, 11.8],
    cloudCover:    [56, 52, 44, 38, 28, 14, 8, 10, 18, 34, 48, 58],
  },
  icanadolu: {
    irradiance:    [2.4, 3.4, 4.7, 5.9, 7.0, 7.8, 8.0, 7.2, 5.6, 4.0, 2.8, 2.1],
    windSpeed:     [6.4, 6.6, 6.2, 5.8, 5.6, 6.2, 6.8, 6.6, 6.0, 5.8, 6.0, 6.4],
    precipitation: [42, 38, 38, 42, 48, 32, 12, 10, 18, 32, 36, 48],
    temperature:   [0.4, 1.8, 6.2, 11.6, 16.2, 20.4, 23.8, 23.4, 18.6, 12.8, 6.2, 2.0],
    cloudCover:    [62, 58, 50, 44, 36, 24, 16, 18, 28, 42, 56, 66],
  },
  karadeniz: {
    irradiance:    [1.5, 2.1, 3.0, 4.1, 5.2, 5.9, 5.7, 5.2, 4.2, 2.8, 1.8, 1.3],
    windSpeed:     [5.6, 5.8, 5.4, 4.8, 4.4, 4.6, 5.0, 5.2, 5.0, 5.4, 5.6, 5.8],
    precipitation: [82, 70, 80, 70, 60, 50, 40, 60, 88, 120, 100, 95],
    temperature:   [6.4, 6.8, 8.2, 11.4, 15.2, 19.4, 22.0, 22.2, 19.4, 16.0, 11.6, 8.2],
    cloudCover:    [72, 68, 64, 58, 52, 46, 42, 44, 50, 60, 70, 76],
  },
  doguanadolu: {
    irradiance:    [2.1, 3.0, 4.4, 5.6, 6.8, 7.6, 7.8, 7.0, 5.4, 3.8, 2.4, 1.8],
    windSpeed:     [7.0, 7.2, 6.8, 6.4, 6.0, 6.4, 7.0, 6.8, 6.2, 6.4, 6.8, 7.2],
    precipitation: [60, 60, 70, 80, 75, 50, 30, 25, 35, 60, 70, 65],
    temperature:   [-7.8, -6.2, -0.6, 6.0, 11.4, 15.6, 19.4, 19.8, 14.8, 8.4, 1.8, -4.6],
    cloudCover:    [60, 58, 56, 52, 46, 38, 30, 30, 36, 46, 56, 64],
  },
  gdanadolu: {
    irradiance:    [2.4, 3.5, 4.8, 6.1, 7.2, 8.0, 8.2, 7.4, 5.8, 4.2, 2.9, 2.2],
    windSpeed:     [5.2, 5.4, 5.4, 5.2, 5.2, 5.6, 6.0, 5.8, 5.2, 4.8, 5.0, 5.2],
    precipitation: [82, 70, 65, 52, 28, 6, 2, 2, 8, 38, 70, 90],
    temperature:   [5.4, 7.0, 11.4, 16.4, 22.2, 28.4, 32.2, 31.8, 26.4, 19.4, 12.4, 7.2],
    cloudCover:    [58, 54, 48, 42, 30, 14, 8, 10, 18, 32, 48, 60],
  },
};

// ============================================================================
// TÜRKİYE BÖLGE SVG PATHS — schematic polygons for region map
// All sized to a 1000x600 viewBox matching shared MapBackdrop coastline
// ============================================================================
const REGION_PATHS = {
  marmara:     'M 130 230 L 290 220 L 320 260 L 290 290 L 150 285 Z',
  ege:         'M 130 285 L 280 290 L 290 360 L 130 365 Z',
  akdeniz:     'M 290 320 L 540 320 L 560 395 L 320 405 L 290 365 Z',
  icanadolu:   'M 290 250 L 540 240 L 590 285 L 600 330 L 540 320 L 290 320 Z',
  karadeniz:   'M 290 220 L 730 200 L 820 220 L 800 260 L 590 285 L 540 240 Z',
  doguanadolu: 'M 600 285 L 800 260 L 900 280 L 920 355 L 760 385 L 600 360 Z',
  gdanadolu:   'M 540 350 L 760 385 L 820 405 L 750 425 L 560 410 Z',
};

// ============================================================================
// İLLERDE EN İYİ BÖLGELER (per province, per type) — synthetic for prototype
// ============================================================================
const PROVINCE_BEST_SPOTS = {
  konya: {
    solar: [
      { id: 's1', name: 'Karapınar Plato Doğu',  district: 'Karapınar',  area: 2840, kwhMonthly: 168000, kwhAnnual: 2.0e6, irradiance: 5.6, slope: '0-3°', distance: '4.2 km',  potential: 96, lat: 37.72, lng: 33.55 },
      { id: 's2', name: 'Karapınar Plato Batı',  district: 'Karapınar',  area: 2280, kwhMonthly: 134000, kwhAnnual: 1.6e6, irradiance: 5.5, slope: '0-3°', distance: '6.0 km',  potential: 94, lat: 37.70, lng: 33.46 },
      { id: 's3', name: 'Cihanbeyli Tuz Gölü Doğu', district: 'Cihanbeyli', area: 1640, kwhMonthly: 96000,  kwhAnnual: 1.15e6, irradiance: 5.4, slope: '0-2°', distance: '8.5 km',  potential: 90, lat: 38.62, lng: 32.94 },
      { id: 's4', name: 'Ereğli Düzlüğü',         district: 'Ereğli',      area: 1820, kwhMonthly: 106000, kwhAnnual: 1.27e6, irradiance: 5.5, slope: '0-4°', distance: '12 km',   potential: 87, lat: 37.51, lng: 34.05 },
    ],
    wind: [
      { id: 'w1', name: 'Beyşehir Sırtları',     district: 'Beyşehir',    area: 380, kwhMonthly: 32000, kwhAnnual: 384e3, windSpeed: 6.4, hubHeight: '120 m', distance: '14 km', potential: 64, lat: 37.68, lng: 31.74 },
      { id: 'w2', name: 'Akşehir Tepeleri',      district: 'Akşehir',     area: 280, kwhMonthly: 24000, kwhAnnual: 288e3, windSpeed: 6.1, hubHeight: '120 m', distance: '8 km',  potential: 58, lat: 38.36, lng: 31.42 },
    ],
    hydro: [
      { id: 'h1', name: 'Çumra Sulama Kanalı',   district: 'Çumra',       flowRate: 8.2,  head: 22, kwhAnnual: 18.4e6, potential: 52, lat: 37.57, lng: 32.78 },
    ],
  },
  artvin: {
    hydro: [
      { id: 'h1', name: 'Çoruh Vadisi · Yusufeli',  district: 'Yusufeli', flowRate: 32.5, head: 145, kwhAnnual: 95e6, potential: 96, lat: 40.82, lng: 41.54 },
      { id: 'h2', name: 'Borçka Barajı Mansabı',     district: 'Borçka',   flowRate: 28.6, head: 110, kwhAnnual: 78e6, potential: 92, lat: 41.36, lng: 41.66 },
      { id: 'h3', name: 'Şavşat Berta Deresi',        district: 'Şavşat',   flowRate: 16.4, head: 162, kwhAnnual: 68e6, potential: 88, lat: 41.21, lng: 42.34 },
      { id: 'h4', name: 'Murgul Bakır Vadisi',        district: 'Murgul',   flowRate: 12.8, head: 138, kwhAnnual: 54e6, potential: 84, lat: 41.30, lng: 41.55 },
    ],
    solar: [
      { id: 's1', name: 'Şavşat Yaylası Güney',     district: 'Şavşat', area: 480, kwhMonthly: 22000, kwhAnnual: 264e3, irradiance: 4.2, slope: '5-12°', distance: '18 km', potential: 56, lat: 41.16, lng: 42.36 },
    ],
    wind: [
      { id: 'w1', name: 'Hopa Sahil Sırtları',       district: 'Hopa',   area: 220, kwhMonthly: 18000, kwhAnnual: 216e3, windSpeed: 6.2, hubHeight: '100 m', distance: '6 km',  potential: 60, lat: 41.40, lng: 41.43 },
    ],
  },
  // Geri kalan iller için generic profile generation:
};

// Default best-spots generator for provinces without explicit data
const generateSpotsForProvince = (province) => {
  const out = { solar: [], wind: [], hydro: [] };
  province.districtsData.forEach((d, i) => {
    if (i < 4 && d.solarScore > 50) {
      out.solar.push({
        id: `s${i+1}`, name: `${d.name} ${province.topRes === 'solar' ? 'Plato' : 'Bölgesi'} ${i % 2 ? 'Batı' : 'Doğu'}`,
        district: d.name, area: 800 + d.solarScore * 16, kwhMonthly: d.solarScore * 1200,
        kwhAnnual: d.solarScore * 14400, irradiance: 4.5 + d.solarScore / 50,
        slope: '0-5°', distance: `${(i+1) * 3} km`, potential: d.solarScore,
        lat: province.lat + (i % 2 ? 0.1 : -0.1) * (i+1)/4,
        lng: province.lng + (i % 2 ? -0.1 : 0.1) * (i+1)/4,
      });
    }
    if (i < 3 && d.windScore > 50) {
      out.wind.push({
        id: `w${i+1}`, name: `${d.name} Sırtları`, district: d.name,
        area: 200 + d.windScore * 4, kwhMonthly: d.windScore * 480,
        kwhAnnual: d.windScore * 5760, windSpeed: 5.5 + d.windScore / 25,
        hubHeight: '120 m', distance: `${(i+2) * 4} km`, potential: d.windScore,
        lat: province.lat + (i+1) * 0.08, lng: province.lng + (i % 2 ? 0.05 : -0.05),
      });
    }
    if (i < 3 && d.hydroScore > 50) {
      out.hydro.push({
        id: `h${i+1}`, name: `${d.name} ${province.topRes === 'hydro' ? 'Vadisi' : 'Deresi'}`,
        district: d.name, flowRate: 4 + d.hydroScore / 6, head: 30 + d.hydroScore,
        kwhAnnual: d.hydroScore * 600e3, potential: d.hydroScore,
        lat: province.lat - (i+1) * 0.06, lng: province.lng + (i+1) * 0.04,
      });
    }
  });
  return out;
};

// Populate all provinces with spots
TR_PROVINCES.forEach(p => {
  if (!PROVINCE_BEST_SPOTS[p.id]) {
    PROVINCE_BEST_SPOTS[p.id] = generateSpotsForProvince(p);
  }
});

Object.assign(window, { TR_REGIONS, TR_PROVINCES, TR_STATS, REGION_WEATHER, REGION_PATHS, PROVINCE_BEST_SPOTS });
