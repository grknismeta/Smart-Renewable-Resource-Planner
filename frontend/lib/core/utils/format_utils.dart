import 'package:intl/intl.dart';

/// Türkçe sayı / para / enerji formatlama yardımcısı.
/// Tüm sayısal çıktılar bu sınıftan geçmelidir.
class FormatUtils {
  FormatUtils._();

  // --- Türkçe locale formatterlar (const değil, NumberFormat lazy-init) ---
  static final _trInt = NumberFormat('#,##0', 'tr_TR');
  static final _trDec1 = NumberFormat('#,##0.#', 'tr_TR');
  static final _trDec2 = NumberFormat('#,##0.##', 'tr_TR');

  // -----------------------------------------------------------------------
  // ENERJİ
  // -----------------------------------------------------------------------

  /// kWh → otomatik birim (kWh / MWh / GWh), Türkçe nokta/virgül
  /// Örnek: 1_234_567.8 → "1.234,6 MWh"
  static String formatEnergy(double kwh) {
    if (kwh >= 1e9) {
      return '${_trDec1.format(kwh / 1e9)} TWh';
    } else if (kwh >= 1e6) {
      return '${_trDec1.format(kwh / 1e6)} GWh';
    } else if (kwh >= 1e3) {
      return '${_trDec1.format(kwh / 1e3)} MWh';
    } else {
      return '${_trDec1.format(kwh)} kWh';
    }
  }

  /// kWh değerini MWh cinsinden formatla
  static String formatEnergyMwh(double kwh) =>
      '${_trDec2.format(kwh / 1000)} MWh';

  /// Grafik Y ekseni için kısa etiket: 1_500_000 → "1,5M" (İngilizce kısa)
  static String formatEnergyShort(double kwh) {
    if (kwh >= 1e9) return '${(kwh / 1e9).toStringAsFixed(1)}G';
    if (kwh >= 1e6) return '${(kwh / 1e6).toStringAsFixed(1)}M';
    if (kwh >= 1e3) return '${(kwh / 1e3).toStringAsFixed(0)}k';
    if (kwh == 0)   return '0';
    return kwh.toStringAsFixed(0);
  }

  /// Watt → otomatik birim (W / kW / MW / GW)
  static String formatPower(double kw) {
    if (kw >= 1e6) return '${_trDec2.format(kw / 1e6)} GW';
    if (kw >= 1e3) return '${_trDec2.format(kw / 1e3)} MW';
    return '${_trDec2.format(kw)} kW';
  }

  // -----------------------------------------------------------------------
  // PARA
  // -----------------------------------------------------------------------

  /// Dolar para birimi  →  "$1.234.567"
  static String formatUsd(double usd) =>
      '\$${_trInt.format(usd.round())}';

  /// Dolar, ondalıklı  →  "$1.234,56"
  static String formatUsdFull(double usd) =>
      '\$${_trDec2.format(usd)}';

  /// Yüzde  →  "%8,50"
  static String formatPercent(double percent, {int decimals = 2}) {
    final fmt = NumberFormat('#,##0.${'0' * decimals}', 'tr_TR');
    return '%${fmt.format(percent)}';
  }

  // -----------------------------------------------------------------------
  // GENEL SAYILAR
  // -----------------------------------------------------------------------

  /// Tam sayı Türkçe  →  "1.234.567"
  static String formatInt(num value) => _trInt.format(value);

  /// Ondalıklı, 1 hane  →  "3,7"
  static String formatDec1(double value) => _trDec1.format(value);

  /// Ondalıklı, 2 hane  →  "3,75"
  static String formatDec2(double value) => _trDec2.format(value);

  // -----------------------------------------------------------------------
  // ÖZEL
  // -----------------------------------------------------------------------

  /// m³/s debi  →  "12,5 m³/s"
  static String formatFlow(double m3s) => '${_trDec1.format(m3s)} m³/s';

  /// metre  →  "125,3 m"
  static String formatMeters(double m) => '${_trDec1.format(m)} m';

  /// km²  →  "45,2 km²"
  static String formatKm2(double km2) => '${_trDec1.format(km2)} km²';

  /// Yıl  →  "12,3 yıl"
  static String formatYears(double years) => '${_trDec1.format(years)} yıl';
}
