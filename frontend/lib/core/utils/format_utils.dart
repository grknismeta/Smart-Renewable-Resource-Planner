class FormatUtils {
  FormatUtils._();

  /// Formats energy value (kWh) to appropriate unit strings (kWh, MWh, GWh).
  static String formatEnergy(double kwh) {
    if (kwh >= 1000000) {
      return '${(kwh / 1000000).toStringAsFixed(2)} GWh';
    } else if (kwh >= 1000) {
      return '${(kwh / 1000).toStringAsFixed(2)} MWh';
    } else {
      return '${kwh.toStringAsFixed(2)} kWh';
    }
  }
}
