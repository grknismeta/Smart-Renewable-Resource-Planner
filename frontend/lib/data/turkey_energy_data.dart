// Türkiye 10 Yıllık Enerji Üretim Verisi (2014-2023)
// Kaynak: TEAŞ / EPDK / IEA istatistiklerinden derlenen statik veri.
// Birimler: TWh (Terawatt saat)

class TurkeyYearlyData {
  final int year;
  final double totalTwh;
  final double hydroTwh;
  final double windTwh;
  final double solarTwh;
  final double naturalGasTwh;
  final double coalTwh;
  final double otherTwh;

  const TurkeyYearlyData({
    required this.year,
    required this.totalTwh,
    required this.hydroTwh,
    required this.windTwh,
    required this.solarTwh,
    required this.naturalGasTwh,
    required this.coalTwh,
    required this.otherTwh,
  });

  double get renewableTwh => hydroTwh + windTwh + solarTwh;
  double get fossilTwh => naturalGasTwh + coalTwh;
  double get renewableShare => totalTwh > 0 ? (renewableTwh / totalTwh) * 100 : 0;
  double get fossilShare => totalTwh > 0 ? (fossilTwh / totalTwh) * 100 : 0;
}

/// Türkiye elektrik üretim istatistikleri (2014-2023)
const List<TurkeyYearlyData> turkeyEnergyHistory = [
  TurkeyYearlyData(
    year: 2014,
    totalTwh: 251.9,
    hydroTwh: 76.3,
    windTwh: 9.4,
    solarTwh: 0.3,
    naturalGasTwh: 93.0,
    coalTwh: 68.6,
    otherTwh: 4.3,
  ),
  TurkeyYearlyData(
    year: 2015,
    totalTwh: 261.8,
    hydroTwh: 67.0,
    windTwh: 11.7,
    solarTwh: 1.0,
    naturalGasTwh: 97.1,
    coalTwh: 80.4,
    otherTwh: 4.6,
  ),
  TurkeyYearlyData(
    year: 2016,
    totalTwh: 274.4,
    hydroTwh: 76.5,
    windTwh: 15.5,
    solarTwh: 2.7,
    naturalGasTwh: 96.4,
    coalTwh: 79.3,
    otherTwh: 4.0,
  ),
  TurkeyYearlyData(
    year: 2017,
    totalTwh: 297.3,
    hydroTwh: 58.1,
    windTwh: 17.9,
    solarTwh: 6.8,
    naturalGasTwh: 109.1,
    coalTwh: 100.2,
    otherTwh: 5.2,
  ),
  TurkeyYearlyData(
    year: 2018,
    totalTwh: 303.9,
    hydroTwh: 61.4,
    windTwh: 19.8,
    solarTwh: 8.5,
    naturalGasTwh: 104.7,
    coalTwh: 104.9,
    otherTwh: 4.6,
  ),
  TurkeyYearlyData(
    year: 2019,
    totalTwh: 303.2,
    hydroTwh: 88.0,
    windTwh: 21.3,
    solarTwh: 10.3,
    naturalGasTwh: 87.0,
    coalTwh: 92.1,
    otherTwh: 4.5,
  ),
  TurkeyYearlyData(
    year: 2020,
    totalTwh: 306.7,
    hydroTwh: 82.1,
    windTwh: 23.5,
    solarTwh: 13.1,
    naturalGasTwh: 93.5,
    coalTwh: 89.3,
    otherTwh: 5.2,
  ),
  TurkeyYearlyData(
    year: 2021,
    totalTwh: 332.0,
    hydroTwh: 89.6,
    windTwh: 27.2,
    solarTwh: 17.3,
    naturalGasTwh: 102.9,
    coalTwh: 88.8,
    otherTwh: 6.2,
  ),
  TurkeyYearlyData(
    year: 2022,
    totalTwh: 330.4,
    hydroTwh: 73.9,
    windTwh: 32.6,
    solarTwh: 23.1,
    naturalGasTwh: 99.5,
    coalTwh: 95.7,
    otherTwh: 5.6,
  ),
  TurkeyYearlyData(
    year: 2023,
    totalTwh: 334.1,
    hydroTwh: 95.3,
    windTwh: 37.8,
    solarTwh: 30.6,
    naturalGasTwh: 87.1,
    coalTwh: 77.0,
    otherTwh: 6.3,
  ),
];

/// 2023 enerji karışımı (pasta grafik için)
const Map<String, double> turkey2023EnergyMix = {
  'Hidroelektrik': 95.3,
  'Doğal Gaz': 87.1,
  'Kömür': 77.0,
  'Rüzgar': 37.8,
  'Güneş': 30.6,
  'Diğer': 6.3,
};

/// 2023 renk eşleşmesi
const Map<String, int> turkey2023Colors = {
  'Hidroelektrik': 0xFF29B6F6,
  'Doğal Gaz': 0xFFFF7043,
  'Kömür': 0xFF78909C,
  'Rüzgar': 0xFF26C6DA,
  'Güneş': 0xFFFFCA28,
  'Diğer': 0xFF9E9E9E,
};

/// Türkiye yenilenebilir enerji hedefleri
class TurkeyRenewableTarget {
  final int year;
  final double targetGw; // Toplam kurulu güç hedefi (GW)
  final String description;

  const TurkeyRenewableTarget({
    required this.year,
    required this.targetGw,
    required this.description,
  });
}

const List<TurkeyRenewableTarget> renewableTargets = [
  TurkeyRenewableTarget(
    year: 2025,
    targetGw: 120.0,
    description: '120 GW kurulu güç',
  ),
  TurkeyRenewableTarget(
    year: 2030,
    targetGw: 150.0,
    description: '%30 yenilenebilir pay hedefi',
  ),
  TurkeyRenewableTarget(
    year: 2035,
    targetGw: 200.0,
    description: 'Net sıfır yolunda %50',
  ),
];
