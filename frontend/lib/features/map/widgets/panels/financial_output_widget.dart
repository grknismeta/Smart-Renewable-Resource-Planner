import 'package:flutter/material.dart';
import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/core/theme/theme_view_model.dart';

class FinancialOutputWidget extends StatelessWidget {
  final PinCalculationResponse result;
  final ThemeViewModel theme;

  const FinancialOutputWidget({
    super.key,
    required this.result,
    required this.theme,
  });

  // ── Yardımcı formatters ──────────────────────────────────────────────────
  String _fmtUsd(double v) {
    if (v >= 1e9)  return '\$${(v / 1e9).toStringAsFixed(2)}B';
    if (v >= 1e6)  return '\$${(v / 1e6).toStringAsFixed(2)}M';
    if (v >= 1e3)  return '\$${(v / 1e3).toStringAsFixed(1)}K';
    return '\$${v.toStringAsFixed(0)}';
  }

  String _fmtPct(double v) => '%${v.toStringAsFixed(1)}';

  // NPV rengi: pozitif → yeşil, negatif → kırmızı, sıfır → gri
  Color _npvColor(double npv) {
    if (npv > 0)  return Colors.green.shade400;
    if (npv < 0)  return Colors.red.shade400;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    // Solar, Rüzgar veya HES financials — hangisi doluysa onu al
    final FinancialAnalysis? fin =
        result.solarCalculation?.financials ??
        result.windCalculation?.financials ??
        result.hydroCalculation?.financials;

    if (fin == null) return const SizedBox.shrink();

    final bool isYekdem    = fin.pricingMode == 'yekdem';
    final bool npvPositive = fin.npvUsd >= 0;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.secondaryTextColor.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Başlık + Fiyatlandırma Modu Etiketi ────────────────────────
          Row(
            children: [
              Icon(Icons.monetization_on, color: Colors.green.shade400, size: 26),
              const SizedBox(width: 10),
              Text(
                'Finansal Analiz',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
              const Spacer(),
              _PricingBadge(isYekdem: isYekdem, lifetimeYears: fin.lifetimeYears),
            ],
          ),
          const SizedBox(height: 16),

          // ── Toplam Yatırım (büyük kart) ─────────────────────────────────
          _LargeCard(
            icon: Icons.account_balance_wallet_outlined,
            color: Colors.amber.shade600,
            label: 'Toplam Yatırım',
            value: _fmtUsd(fin.initialInvestmentUsd),
            theme: theme,
          ),
          const SizedBox(height: 12),

          // ── NPV + IRR ───────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _SmallCard(
                  icon: Icons.trending_up_rounded,
                  color: _npvColor(fin.npvUsd),
                  label: 'Net Bugünkü Değer',
                  sublabel: 'NPV • %8 iskonto',
                  value: _fmtUsd(fin.npvUsd),
                  valueColor: _npvColor(fin.npvUsd),
                  theme: theme,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SmallCard(
                  icon: Icons.percent_rounded,
                  color: Colors.purple.shade400,
                  label: 'İç Verim Oranı',
                  sublabel: 'IRR',
                  value: _fmtPct(fin.irrPercentage),
                  theme: theme,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── LCOE + Amortisman ───────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _SmallCard(
                  icon: Icons.bolt_rounded,
                  color: Colors.cyan.shade400,
                  label: 'LCOE',
                  sublabel: 'Enerji maliyeti',
                  value: '\$${fin.lcoeUsdKwh.toStringAsFixed(4)}/kWh',
                  theme: theme,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SmallCard(
                  icon: Icons.timelapse_rounded,
                  color: Colors.blue.shade400,
                  label: 'Amortisman',
                  sublabel: 'Geri ödeme süresi',
                  value: '${fin.paybackPeriodYears.toStringAsFixed(1)} Yıl',
                  theme: theme,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Yıllık kazanç + Ömür boyu gelir ────────────────────────────
          _EarningsCard(
            annualEarnings: fin.annualEarningsUsd,
            lifetimeRevenue: fin.lifetimeRevenueUsd,
            pricePerKwh: fin.pricePerKwhUsd,
            lifetimeYears: fin.lifetimeYears,
            pricingMode: fin.pricingMode,
            isYekdem: isYekdem,
            npvPositive: npvPositive,
            fmtUsd: _fmtUsd,
            theme: theme,
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Alt bileşenler
// ────────────────────────────────────────────────────────────────────────────

class _PricingBadge extends StatelessWidget {
  final bool isYekdem;
  final int lifetimeYears;
  const _PricingBadge({required this.isYekdem, required this.lifetimeYears});

  @override
  Widget build(BuildContext context) {
    final color = isYekdem ? Colors.teal.shade400 : Colors.orange.shade400;
    final label = isYekdem ? 'YEKDEM 10Y' : 'Piyasa';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isYekdem ? Icons.verified_rounded : Icons.show_chart_rounded,
            color: color, size: 13,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(width: 4),
          Text(
            '• $lifetimeYears yıl',
            style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

class _LargeCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final ThemeViewModel theme;

  const _LargeCard({
    required this.icon, required this.color, required this.label,
    required this.value, required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 13, color: theme.secondaryTextColor)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String sublabel;
  final String value;
  final Color? valueColor;
  final ThemeViewModel theme;

  const _SmallCard({
    required this.icon, required this.color, required this.label,
    required this.sublabel, required this.value,
    this.valueColor, required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, color: theme.secondaryTextColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.bold,
              color: valueColor ?? color,
            ),
          ),
          Text(
            sublabel,
            style: TextStyle(fontSize: 10, color: theme.secondaryTextColor.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

class _EarningsCard extends StatelessWidget {
  final double annualEarnings;
  final double lifetimeRevenue;
  final double pricePerKwh;
  final int lifetimeYears;
  final String pricingMode;
  final bool isYekdem;
  final bool npvPositive;
  final String Function(double) fmtUsd;
  final ThemeViewModel theme;

  const _EarningsCard({
    required this.annualEarnings,
    required this.lifetimeRevenue,
    required this.pricePerKwh,
    required this.lifetimeYears,
    required this.pricingMode,
    required this.isYekdem,
    required this.npvPositive,
    required this.fmtUsd,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final earningColor  = annualEarnings >= 0 ? Colors.green.shade400 : Colors.red.shade400;
    final priceLabel    = isYekdem
        ? 'YEKDEM: \$${pricePerKwh.toStringAsFixed(3)}/kWh • İlk 10 Yıl'
        : 'Piyasa: \$${pricePerKwh.toStringAsFixed(3)}/kWh';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade800.withValues(alpha: 0.15),
            Colors.green.shade900.withValues(alpha: 0.07),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade600.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Yıllık kazanç ─────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: earningColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.attach_money_rounded, color: earningColor, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tahmini Yıllık Kazanç (O&M sonrası)',
                    style: TextStyle(fontSize: 12, color: theme.secondaryTextColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fmtUsd(annualEarnings),
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: earningColor),
                  ),
                  Text(priceLabel, style: TextStyle(fontSize: 10, color: theme.secondaryTextColor)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: 10),
          // ── Ömür boyu gelir ────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.timeline_rounded, size: 15, color: Colors.green.shade500),
                  const SizedBox(width: 5),
                  Text(
                    'Ömür Boyu Brüt Gelir ($lifetimeYears yıl)',
                    style: TextStyle(fontSize: 12, color: theme.secondaryTextColor),
                  ),
                ],
              ),
              Text(
                fmtUsd(lifetimeRevenue),
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold,
                  color: Colors.green.shade400,
                ),
              ),
            ],
          ),
          // ── Yatırım tavsiyesi ──────────────────────────────────────────
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: npvPositive
                  ? Colors.green.shade900.withValues(alpha: 0.25)
                  : Colors.red.shade900.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  npvPositive ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                  size: 13,
                  color: npvPositive ? Colors.green.shade400 : Colors.red.shade400,
                ),
                const SizedBox(width: 5),
                Text(
                  npvPositive
                      ? 'Pozitif NPV — Yatırım ekonomik olarak uygun'
                      : 'Negatif NPV — Risk değerlendirmesi yapın',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: npvPositive ? Colors.green.shade400 : Colors.red.shade400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
