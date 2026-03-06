import 'package:flutter/material.dart';
import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/core/theme/theme_view_model.dart';

/// Enerji Bilgi Kartı — Bakım, temizlik ve ömür bilgilerini gösterir.
class EnergyInfoCard extends StatefulWidget {
  final PinCalculationResponse result;
  final ThemeViewModel theme;

  const EnergyInfoCard({
    super.key,
    required this.result,
    required this.theme,
  });

  @override
  State<EnergyInfoCard> createState() => _EnergyInfoCardState();
}

class _EnergyInfoCardState extends State<EnergyInfoCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final info = _getInfo();
    if (info == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: widget.theme.cardColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: info.accentColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // ── Başlık (tıklanabilir) ────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: _expanded
                ? const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  )
                : BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: info.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(info.icon, color: info.accentColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bakım & Ömür Bilgisi',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: widget.theme.textColor,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: widget.theme.secondaryTextColor,
                  ),
                ],
              ),
            ),
          ),

          // ── İçerik (genişletilebilir) ────────────────────────────────────
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // HES uyarısı varsa göster
                  if (widget.result.hydroCalculation?.economicViabilityWarning != null)
                    _WarningBanner(
                      message: widget.result.hydroCalculation!.economicViabilityWarning!,
                      theme: widget.theme,
                    ),

                  // HES plant type badge
                  if (widget.result.hydroCalculation?.plantType != null)
                    _PlantTypeBadge(
                      plantType: widget.result.hydroCalculation!.plantType!,
                      accentColor: info.accentColor,
                    ),

                  // Ömür çubuğu
                  _LifetimeBar(
                    systemLifetimeYears: info.systemLifetime,
                    componentLifetimes: info.componentLifetimes,
                    accentColor: info.accentColor,
                    theme: widget.theme,
                  ),
                  const SizedBox(height: 14),

                  // Bakım takvimi
                  Text(
                    'Bakım Takvimi',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.theme.textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...info.scheduleItems.map(
                    (item) => _ScheduleRow(item: item, theme: widget.theme),
                  ),
                  const SizedBox(height: 12),

                  // Faydalı notlar
                  if (info.tips.isNotEmpty) ...[
                    Text(
                      'Öneriler',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: widget.theme.textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...info.tips.map(
                      (tip) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.tips_and_updates_outlined,
                              size: 14,
                              color: info.accentColor,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                tip,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: widget.theme.secondaryTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  _ResourceInfo? _getInfo() {
    if (widget.result.solarCalculation != null) return _solarInfo();
    if (widget.result.windCalculation != null) return _windInfo();
    if (widget.result.hydroCalculation != null) return _hydroInfo();
    return null;
  }

  _ResourceInfo _solarInfo() => _ResourceInfo(
        icon: Icons.wb_sunny_outlined,
        accentColor: Colors.orange.shade400,
        systemLifetime: 25,
        componentLifetimes: const {
          'Panel': 25,
          'İnvertör': 12,
          'Montaj': 30,
        },
        scheduleItems: const [
          _ScheduleItem('Panel Temizliği', '2-3 ayda bir', Icons.cleaning_services, 'Toz/Kum azaltır; yaz kuru dönemde aylık önerilir'),
          _ScheduleItem('Performans Ölçümü', 'Yıllık', Icons.speed, 'Verim düşüşü (degradasyon) takibi'),
          _ScheduleItem('Bağlantı Kontrolü', 'Yıllık', Icons.cable, 'Oksitlenme, gevşeme kontrolü'),
          _ScheduleItem('İnvertör Bakımı', '5 yılda bir', Icons.memory, 'Fan, kondansatör kontrolü'),
          _ScheduleItem('İnvertör Değişimi', '10-15 yılda bir', Icons.swap_horiz, 'Ömür sonu yenileme gerekir'),
        ],
        tips: const [
          'Türkiye güneş kuşağında ortalama %0.5/yıl güç düşümü beklenir.',
          'Çatı üzeri kurulumda yapı yük hesabı mutlaka yaptırılmalı.',
          'YEKDEM sözleşmesi kapsamında sayaç doğruluğu 6 ayda bir denetlenmeli.',
        ],
      );

  _ResourceInfo _windInfo() => _ResourceInfo(
        icon: Icons.wind_power_outlined,
        accentColor: Colors.blue.shade400,
        systemLifetime: 20,
        componentLifetimes: const {
          'Kule': 30,
          'Bıçaklar': 20,
          'Şanzıman': 10,
          'Jeneratör': 20,
        },
        scheduleItems: const [
          _ScheduleItem('Bıçak Denetimi', '6 ayda bir', Icons.sailing, 'Çatlak, erozyon, buzlanma kontrolü'),
          _ScheduleItem('Şanzıman Yağ Değişimi', '6 ayda bir', Icons.oil_barrel, 'Viskozite ve katkı kontrolü'),
          _ScheduleItem('Kulele Cıvata Torku', 'Yıllık', Icons.build, 'Sallantı ve yorulma çatlağı tespiti'),
          _ScheduleItem('Fren Sistemi', 'Yıllık', Icons.stop_circle_outlined, 'Mekanik ve elektrik freni'),
          _ScheduleItem('Şanzıman Revizyonu', '10 yılda bir', Icons.settings, 'Major revizyon — dişli seti değişimi'),
        ],
        tips: const [
          'Kuş ve yarasa göç yollarına yakın alanlarda gece saati durdurma gerekebilir.',
          'Kış aylarında buz önleme sistemi (IPS) verimliliği artırır.',
          'Gürültü seviyesi mevzuat için 500m mesafede <40 dB olmalı.',
        ],
      );

  _ResourceInfo _hydroInfo() => _ResourceInfo(
        icon: Icons.water_drop_outlined,
        accentColor: Colors.teal.shade400,
        systemLifetime: 40,
        componentLifetimes: const {
          'Sivil Yapı': 50,
          'Türbin': 30,
          'Runner (Çark)': 25,
          'Otomasyon': 15,
        },
        scheduleItems: const [
          _ScheduleItem('Türbin Denetimi', 'Yıllık', Icons.water, 'Kavitasyon, titreşim, sızdırmazlık'),
          _ScheduleItem('İletim Kanalı Temizliği', 'Yıllık', Icons.waves, 'Tortu, bitki, çökme temizliği'),
          _ScheduleItem('Cebri Boru Kontrolü', 'Yıllık', Icons.plumbing, 'Korozyon, destekler, bağlantılar'),
          _ScheduleItem('Runner Revizyonu', '10 yılda bir', Icons.settings_suggest, 'Aşınma analizi, parça yenileme'),
          _ScheduleItem('Runner Değişimi', '25-30 yılda bir', Icons.swap_horiz, 'Komple çark yenileme'),
        ],
        tips: const [
          'Can suyu kesintisi (%15) tüm mevsimlerde uygulanmalı; yaz düşük debisinde kritik.',
          'Taşkın senaryosu için baypas/taşkın savağı kapasitesi hesaplanmalı.',
          'EPDK lisans süreci kucuk HES\u2019ler (<=10 kW muafiyet) icin farklidir.',
        ],
      );
}

// ────────────────────────────────────────────────────────────────────────────
// Veri Modelleri
// ────────────────────────────────────────────────────────────────────────────

class _ResourceInfo {
  final IconData icon;
  final Color accentColor;
  final int systemLifetime;
  final Map<String, int> componentLifetimes;
  final List<_ScheduleItem> scheduleItems;
  final List<String> tips;

  const _ResourceInfo({
    required this.icon,
    required this.accentColor,
    required this.systemLifetime,
    required this.componentLifetimes,
    required this.scheduleItems,
    required this.tips,
  });
}

class _ScheduleItem {
  final String label;
  final String frequency;
  final IconData icon;
  final String detail;
  const _ScheduleItem(this.label, this.frequency, this.icon, this.detail);
}

// ────────────────────────────────────────────────────────────────────────────
// Alt Bileşenler
// ────────────────────────────────────────────────────────────────────────────

class _WarningBanner extends StatelessWidget {
  final String message;
  final ThemeViewModel theme;
  const _WarningBanner({required this.message, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.shade900.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade600.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange.shade400),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 11, color: Colors.orange.shade300),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlantTypeBadge extends StatelessWidget {
  final String plantType;
  final Color accentColor;
  const _PlantTypeBadge({required this.plantType, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.category_outlined, size: 13, color: accentColor),
          const SizedBox(width: 5),
          Text(
            plantType,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accentColor),
          ),
        ],
      ),
    );
  }
}

class _LifetimeBar extends StatelessWidget {
  final int systemLifetimeYears;
  final Map<String, int> componentLifetimes;
  final Color accentColor;
  final ThemeViewModel theme;

  const _LifetimeBar({
    required this.systemLifetimeYears,
    required this.componentLifetimes,
    required this.accentColor,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final maxYears = ([systemLifetimeYears, ...componentLifetimes.values].reduce(
      (a, b) => a > b ? a : b,
    )).toDouble();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sistem Ömrü — $systemLifetimeYears Yıl',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textColor),
          ),
          const SizedBox(height: 8),
          ...componentLifetimes.entries.map((entry) {
            final fraction = entry.value / maxYears;
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      entry.key,
                      style: TextStyle(fontSize: 10, color: theme.secondaryTextColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: theme.secondaryTextColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: fraction.clamp(0.0, 1.0),
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${entry.value}y',
                    style: TextStyle(fontSize: 10, color: theme.secondaryTextColor),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  final _ScheduleItem item;
  final ThemeViewModel theme;
  const _ScheduleRow({required this.item, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, size: 14, color: theme.secondaryTextColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.textColor,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.secondaryTextColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item.frequency,
                        style: TextStyle(fontSize: 10, color: theme.secondaryTextColor),
                      ),
                    ),
                  ],
                ),
                Text(
                  item.detail,
                  style: TextStyle(fontSize: 10, color: theme.secondaryTextColor.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
