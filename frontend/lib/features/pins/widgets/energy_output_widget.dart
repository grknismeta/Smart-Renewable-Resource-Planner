// lib/presentation/widgets/map/energy_output_widget.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/utils/format_utils.dart';

/// Modern enerji çıktısı gösterimi (Yıllık, Aylık, Haftalık)
class EnergyOutputWidget extends StatelessWidget {
  final PinCalculationResponse result;
  final ThemeViewModel theme;

  const EnergyOutputWidget({
    super.key,
    required this.result,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    // HES sonucu varsa ayrı bir HES görselü göster
    if (result.hydroCalculation != null) {
      return _buildHydroOutput(result.hydroCalculation!);
    }

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
      // L3 (2026-05-26): padding 20 → 14, başlık fontSize 20 → 15, Text
      // Expanded'a alındı + ellipsis. 300px kart genişliğinde Row taşıyordu
      // ("Enerji Üretim Tahmini" çok uzun + 28px ikon + 40px padding).
      padding: const EdgeInsets.all(14),
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
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Enerji Üretim Tahmini',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

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

  // --- HES ÖZEL GÖRSEL ---
  Widget _buildHydroOutput(HydroCalculationResponse hydro) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.cardColor, theme.cardColor.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.4), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.teal.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.water_drop, color: Colors.teal, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HES Üretim Tahmini',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textColor),
                    ),
                    Text(
                      '${hydro.turbineType} Türbini — ${FormatUtils.formatPercent(hydro.turbineEfficiency * 100, decimals: 0)} verim',
                      style: const TextStyle(fontSize: 12, color: Colors.teal),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Can Suyu (Environmental Flow) bilgi rozeti
          if (hydro.environmentalFlowDeducted)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.eco, color: Colors.teal, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Can Suyu (Çevresel Akış) kesintisi: ',
                            style: TextStyle(fontSize: 11, color: Colors.teal),
                          ),
                          TextSpan(
                            text: '%15 düşüldü',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal),
                          ),
                          if (hydro.grossFlowRateM3s != null)
                            TextSpan(
                              text: '  (Brüt: ${FormatUtils.formatFlow(hydro.grossFlowRateM3s!)} → Net: ${FormatUtils.formatFlow(hydro.avgFlowRateM3s)})',
                              style: TextStyle(fontSize: 10, color: theme.secondaryTextColor),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          _buildPrimaryOutputCard('Yıllık Üretim', hydro.predictedAnnualProductionKwh, Icons.calendar_today, Colors.teal),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSecondaryOutputCard('Aylık Ortalama', hydro.potentialKwhMonthly, Icons.calendar_month, Colors.cyan),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSecondaryOutputCard('Kapasite Faktörü', hydro.capacityFactor * 100, Icons.battery_charging_full, Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          _buildInfoRow('Ortalama Debi', FormatUtils.formatFlow(hydro.avgFlowRateM3s), Icons.water),
          _buildInfoRow('Düşü Yüksekliği', FormatUtils.formatMeters(hydro.headHeightM), Icons.height),
          _buildInfoRow('Kapasite Faktörü', FormatUtils.formatPercent(hydro.capacityFactor * 100, decimals: 1), Icons.battery_charging_full),
          _buildInfoRow('Türbin Açıklaması', hydro.turbineDescription, Icons.info_outline),
          if (hydro.monthlyProduction != null && hydro.monthlyProduction!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildMonthlyBarChart(
              title: 'Aylık Üretim (kWh)',
              data: hydro.monthlyProduction!,
              barColor: Colors.teal,
              icon: Icons.bolt,
            ),
          ],
          if (hydro.monthlyFlowRates != null && hydro.monthlyFlowRates!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildMonthlyBarChart(
              title: 'Aylık Net Debi (m³/s)',
              data: hydro.monthlyFlowRates!,
              barColor: Colors.cyan,
              icon: Icons.water,
              valueFormat: 'm³/s',
            ),
          ],
        ],
      ),
    );
  }

  // --- AYLIK BAR CHART (fl_chart) ---
  Widget _buildMonthlyBarChart({
    required String title,
    required Map<String, double> data,
    required Color barColor,
    required IconData icon,
    String valueFormat = 'kWh',
  }) {
    final entries = data.entries.toList();
    final maxVal = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    // Kısa ay isimleri
    final shortNames = entries.map((e) {
      final name = e.key;
      return name.length > 3 ? name.substring(0, 3) : name;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: barColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: barColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w600, color: theme.textColor, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.15,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final monthName = entries[group.x.toInt()].key;
                      final value = rod.toY;
                      String formattedValue;
                      if (valueFormat == 'kWh') {
                        formattedValue = _formatEnergy(value);
                      } else {
                        formattedValue = '${value.toStringAsFixed(3)} $valueFormat';
                      }
                      return BarTooltipItem(
                        '$monthName\n$formattedValue',
                        const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= shortNames.length) return const SizedBox();
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 4,
                          child: Text(
                            shortNames[idx],
                            style: TextStyle(fontSize: 9, color: theme.secondaryTextColor),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxVal > 0 ? maxVal / 4 : 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: theme.secondaryTextColor.withValues(alpha: 0.1),
                    strokeWidth: 1,
                  ),
                ),
                barGroups: List.generate(entries.length, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: entries[i].value,
                        color: barColor,
                        width: 14,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxVal * 1.15,
                          color: barColor.withValues(alpha: 0.05),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
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
      // L3: padding 16 → 12, ikon 32 → 22, sayı 28 → 20 (300px karta uysun)
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.secondaryTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatEnergy(value),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
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
      // L3: secondary kartlar yan yana 2 sütun → her biri ~125px.
      // padding 14 → 10, ikon 24 → 18, label/sayı font'u küçük.
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: theme.secondaryTextColor),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            _formatEnergy(value),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
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
          FormatUtils.formatPercent(solar.panelEfficiency * 100, decimals: 1),
          Icons.solar_power,
        ),
        _buildInfoRow(
          'Performans Oranı',
          FormatUtils.formatPercent(solar.performanceRatio * 100, decimals: 1),
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
          FormatUtils.formatPercent(wind.capacityFactor * 100, decimals: 1),
          Icons.battery_charging_full,
        ),
        _buildInfoRow(
          'Rüzgar Hızı',
          '${FormatUtils.formatDec1(wind.windSpeedMS)} m/s',
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
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.textColor,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  /// Enerji değerini formatla — FormatUtils üzerinden Türkçe format
  String _formatEnergy(double kWh) => FormatUtils.formatEnergy(kWh);
}
