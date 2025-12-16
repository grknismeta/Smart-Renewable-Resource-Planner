// lib/presentation/widgets/map/energy_output_widget.dart

import 'package:flutter/material.dart';
import '../../../data/models/pin_model.dart';
import '../../../providers/theme_provider.dart';

/// Modern enerji çıktısı gösterimi (Yıllık, Aylık, Haftalık)
class EnergyOutputWidget extends StatelessWidget {
  final PinCalculationResponse result;
  final ThemeProvider theme;

  const EnergyOutputWidget({
    super.key,
    required this.result,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    // Güneş veya Rüzgar verilerini al
    final double annualKwh =
        result.solarCalculation?.potentialKwhAnnual ??
        result.windCalculation?.potentialKwhAnnual ??
        0.0;
    final double monthlyKwh =
        result.solarCalculation?.potentialKwhMonthly ??
        result.windCalculation?.potentialKwhMonthly ??
        0.0;
    final double weeklyKwh =
        result.solarCalculation?.potentialKwhWeekly ??
        result.windCalculation?.potentialKwhWeekly ??
        0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.cardColor, theme.cardColor.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.secondaryTextColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          Row(
            children: [
              Icon(
                result.resourceType == 'Güneş Paneli'
                    ? Icons.wb_sunny
                    : Icons.wind_power,
                color: result.resourceType == 'Güneş Paneli'
                    ? Colors.orange
                    : Colors.blue,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Enerji Üretim Tahmini',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Yıllık Üretim (Ana Gösterge)
          _buildPrimaryOutputCard(
            'Yıllık Üretim',
            annualKwh,
            Icons.calendar_today,
            Colors.green,
          ),
          const SizedBox(height: 12),

          // Aylık ve Haftalık (Yan yana)
          Row(
            children: [
              Expanded(
                child: _buildSecondaryOutputCard(
                  'Aylık Ortalama',
                  monthlyKwh,
                  Icons.calendar_month,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSecondaryOutputCard(
                  'Haftalık Ortalama',
                  weeklyKwh,
                  Icons.calendar_view_week,
                  Colors.purple,
                ),
              ),
            ],
          ),

          // Ek Bilgiler (Kapasite faktörü, verim vb.)
          if (result.solarCalculation != null ||
              result.windCalculation != null) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _buildAdditionalInfo(),
          ],
        ],
      ),
    );
  }

  /// Ana çıktı kartı (Yıllık)
  Widget _buildPrimaryOutputCard(
    String label,
    double value,
    IconData icon,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.secondaryTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatEnergy(value),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// İkincil çıktı kartları (Aylık/Haftalık)
  Widget _buildSecondaryOutputCard(
    String label,
    double value,
    IconData icon,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: theme.backgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: theme.secondaryTextColor),
          ),
          const SizedBox(height: 4),
          Text(
            _formatEnergy(value),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Ek bilgiler (Verim, Kapasite Faktörü vb.)
  Widget _buildAdditionalInfo() {
    final widgets = <Widget>[];

    if (result.solarCalculation != null) {
      final solar = result.solarCalculation!;
      widgets.addAll([
        _buildInfoRow(
          'Panel Verimi',
          '${(solar.panelEfficiency * 100).toStringAsFixed(1)}%',
          Icons.solar_power,
        ),
        _buildInfoRow(
          'Performans Oranı',
          '${(solar.performanceRatio * 100).toStringAsFixed(1)}%',
          Icons.speed,
        ),
        _buildInfoRow('Panel Modeli', solar.panelModel, Icons.build_circle),
      ]);
    }

    if (result.windCalculation != null) {
      final wind = result.windCalculation!;
      widgets.addAll([
        _buildInfoRow(
          'Kapasite Faktörü',
          '${(wind.capacityFactor * 100).toStringAsFixed(1)}%',
          Icons.battery_charging_full,
        ),
        _buildInfoRow(
          'Rüzgar Hızı',
          '${wind.windSpeedMS.toStringAsFixed(1)} m/s',
          Icons.air,
        ),
        _buildInfoRow('Türbin Modeli', wind.turbineModel, Icons.build_circle),
      ]);
    }

    return Column(children: widgets);
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.secondaryTextColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: theme.secondaryTextColor),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.textColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Enerji değerini formatla (kWh → MWh dönüşümü)
  String _formatEnergy(double kWh) {
    if (kWh >= 1000000) {
      return '${(kWh / 1000000).toStringAsFixed(2)} GWh';
    } else if (kWh >= 1000) {
      return '${(kWh / 1000).toStringAsFixed(2)} MWh';
    } else {
      return '${kWh.toStringAsFixed(1)} kWh';
    }
  }
}
