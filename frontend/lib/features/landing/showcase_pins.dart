// lib/features/landing/showcase_pins.dart
//
// 2026-06-04: Vitrin (showcase) pinleri — gerçek Türkiye YEK tesisleri, salt-
// gösterim GeoJSON. Hem landing arka-plan haritası hem de misafir "Keşfet"
// salt-okunur modu bunu kullanır (tek kaynak). DB pini DEĞİL.

String buildShowcaseGeoJson({bool isDark = true}) {
  final pins = <Map<String, dynamic>>[
    // ═══ GÜNEŞ PANELİ (Solar) ═══
    _pin(1, 'Karapınar GES', 'Güneş Paneli', 37.72, 33.55,
        city: 'Konya', district: 'Karapınar', mw: 200),
    _pin(2, 'Bor GES', 'Güneş Paneli', 37.88, 34.56,
        city: 'Niğde', district: 'Bor', mw: 50),
    _pin(3, 'Viranşehir GES', 'Güneş Paneli', 37.24, 39.77,
        city: 'Şanlıurfa', district: 'Viranşehir', mw: 100),
    _pin(4, 'Kalyon GES', 'Güneş Paneli', 39.58, 32.45,
        city: 'Ankara', district: 'Polatlı', mw: 75),
    _pin(5, 'Elmalı GES', 'Güneş Paneli', 36.74, 29.92,
        city: 'Antalya', district: 'Elmalı', mw: 60),
    _pin(6, 'Kızıltepe GES', 'Güneş Paneli', 37.19, 40.59,
        city: 'Mardin', district: 'Kızıltepe', mw: 45),
    _pin(7, 'Burdur GES', 'Güneş Paneli', 37.72, 30.29,
        city: 'Burdur', district: 'Merkez', mw: 85),
    _pin(8, 'Ceyhan GES', 'Güneş Paneli', 37.03, 35.82,
        city: 'Adana', district: 'Ceyhan', mw: 70),

    // ═══ RÜZGAR TÜRBİNİ (Wind) ═══
    _pin(10, 'Aliağa RES', 'Rüzgar Türbini', 38.80, 26.97,
        city: 'İzmir', district: 'Aliağa', mw: 150),
    _pin(11, 'Gelibolu RES', 'Rüzgar Türbini', 40.41, 26.67,
        city: 'Çanakkale', district: 'Gelibolu', mw: 120),
    _pin(12, 'Bandırma RES', 'Rüzgar Türbini', 40.35, 28.00,
        city: 'Balıkesir', district: 'Bandırma', mw: 90),
    _pin(13, 'İskenderun RES', 'Rüzgar Türbini', 36.59, 36.17,
        city: 'Hatay', district: 'İskenderun', mw: 80),
    _pin(14, 'Akhisar RES', 'Rüzgar Türbini', 38.92, 27.84,
        city: 'Manisa', district: 'Akhisar', mw: 100),
    _pin(15, 'Mut RES', 'Rüzgar Türbini', 36.65, 33.44,
        city: 'Mersin', district: 'Mut', mw: 55),
    _pin(16, 'Osmaniye RES', 'Rüzgar Türbini', 37.07, 36.25,
        city: 'Osmaniye', district: 'Merkez', mw: 60),
    _pin(17, 'Çatalca RES', 'Rüzgar Türbini', 41.14, 28.46,
        city: 'İstanbul', district: 'Çatalca', mw: 40),

    // ═══ HİDROELEKTRİK (HES) ═══
    _pin(20, 'Deriner HES', 'HES', 41.24, 41.62,
        city: 'Artvin', district: 'Yusufeli', mw: 670),
    _pin(21, 'Keban HES', 'HES', 38.80, 38.74,
        city: 'Elazığ', district: 'Keban', mw: 1330),
    _pin(22, 'Oymapınar HES', 'HES', 36.93, 31.49,
        city: 'Antalya', district: 'Manavgat', mw: 540),
    _pin(23, 'Seyhan HES', 'HES', 37.01, 35.33,
        city: 'Adana', district: 'Seyhan', mw: 54),
    _pin(24, 'Tortum HES', 'HES', 40.30, 41.54,
        city: 'Erzurum', district: 'Tortum', mw: 28),
    _pin(25, 'Altınkaya HES', 'HES', 41.38, 36.15,
        city: 'Samsun', district: 'Bafra', mw: 700),
  ];

  return '{"type":"FeatureCollection","features":[${pins.map((p) => '{"type":"Feature","geometry":{"type":"Point","coordinates":[${p['lon']},${p['lat']}]},"properties":${_propsJson(p, isDark: isDark)}}').join(',')}]}';
}

Map<String, dynamic> _pin(
  int id,
  String name,
  String type,
  double lat,
  double lon, {
  required String city,
  required String district,
  required int mw,
}) {
  return {
    'id': id, 'name': name, 'type': type, 'lat': lat, 'lon': lon,
    'city': city, 'district': district, 'mw': mw,
  };
}

String _propsJson(Map<String, dynamic> p, {bool isDark = true}) {
  final type = p['type'] as String;
  String color;
  switch (type.toLowerCase()) {
    case 'güneş paneli':
      color = '#FFA726';
      break;
    case 'rüzgar türbini':
      color = '#42A5F5';
      break;
    case 'hes':
    case 'hidroelektrik':
      color = '#1DB954';
      break;
    default:
      color = '#66BB6A';
  }
  final loc = '${p['district']} / ${p['city']}';
  return '{"id":${p['id']},"name":"${p['name']}","type":"$type","color":"$color","city":"${p['city']}","district":"${p['district']}","locationLabel":"$loc","lat":${p['lat']},"lon":${p['lon']},"capacityMw":${p['mw']}}';
}
