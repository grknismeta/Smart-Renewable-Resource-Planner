import 'package:flutter/material.dart';
import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/core/theme/theme_view_model.dart';
import 'package:intl/intl.dart';

class FinancialOutputWidget extends StatelessWidget {
  final PinCalculationResponse result;
  final ThemeViewModel theme;

  const FinancialOutputWidget({
    super.key,
    required this.result,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final FinancialAnalysis? financials = result.solarCalculation?.financials ??
        result.windCalculation?.financials;

    if (financials == null) return const SizedBox.shrink();

    final currencyFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2, locale: 'en_US');

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.9),
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
              Icon(Icons.monetization_on, color: Colors.green.shade400, size: 28),
              const SizedBox(width: 12),
              Text(
                'Finansal ve Çevresel Etki',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // LCOE Ana Kartı
          _buildInfoCard(
            label: 'Levelized Cost of Energy (LCOE)',
            value: '\$${financials.lcoeUsdKwh.toStringAsFixed(4)} / kWh',
            icon: Icons.price_check,
            color: Colors.amber.shade600,
            isLarge: true,
          ),
          const SizedBox(height: 12),

          // CAPEX / Geri Dönüş Yan Yana
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  label: 'Amortisman Süresi',
                  value: '${financials.paybackPeriodYears.toStringAsFixed(1)} Yıl',
                  icon: Icons.timelapse,
                  color: Colors.blue.shade400,
                  isLarge: false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  label: 'Yıllık ROI',
                  value: '%${financials.roiPercentage.toStringAsFixed(1)}',
                  icon: Icons.trending_up,
                  color: Colors.purple.shade400,
                  isLarge: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Çevresel Etki Kartı
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.teal.shade700.withValues(alpha: 0.2),
                  Colors.teal.shade900.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.shade500.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade500.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.eco, color: Colors.teal.shade400, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yıllık Karbon Tasarrufu',
                        style: TextStyle(fontSize: 13, color: theme.secondaryTextColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${financials.carbonSavingsTonsAnnual.toStringAsFixed(1)} Ton CO₂',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ek Karbon Geliri: ${currencyFormatter.format(financials.carbonCreditIncomeUsdAnnual)}',
                        style: TextStyle(fontSize: 13, color: Colors.teal.shade300, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isLarge,
  }) {
    return Container(
      padding: EdgeInsets.all(isLarge ? 16 : 12),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: isLarge
          ? Row(
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 14, color: theme.secondaryTextColor)),
                    const SizedBox(height: 4),
                    Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 8),
                Text(label, style: TextStyle(fontSize: 12, color: theme.secondaryTextColor)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
    );
  }
}
