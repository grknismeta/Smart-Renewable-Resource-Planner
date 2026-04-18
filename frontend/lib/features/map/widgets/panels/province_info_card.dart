import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/models/weather_model.dart';
import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';

/// Coğrafi seçim bilgi kartı — Bölge / İl / İlçe seviyelerini destekler.
/// Harita üzerinde floating card olarak gösterilir.
class ProvinceInfoCard extends StatelessWidget {
  // Mevcut API (backward compat)
  final String provinceName;
  final ProvinceSummary? summary;
  final DistrictSummary? districtSummary; // ilçe seviyesi hava verisi
  final bool isLoadingDistrictSummaries; // yükleme durumu
  final List<Pin> allPins;
  final ThemeViewModel theme;
  final VoidCallback onClose;

  // Yeni hiyerarşi parametreleri (opsiyonel)
  final SelectionLevel selectionLevel;
  final String? regionName;
  final String? districtName;
  final VoidCallback? onBack; // Üst seviyeye geri dön
  final VoidCallback? onViewReport; // Raporlar sekmesine git

  const ProvinceInfoCard({
    super.key,
    required this.provinceName,
    required this.summary,
    required this.allPins,
    required this.theme,
    required this.onClose,
    this.districtSummary,
    this.isLoadingDistrictSummaries = false,
    this.selectionLevel = SelectionLevel.district,
    this.regionName,
    this.districtName,
    this.onBack,
    this.onViewReport,
  });

  @override
  Widget build(BuildContext context) {
    // Gösterilecek başlık + ikon + renk seçim seviyesine göre değişir
    final bool showingDistrict = districtName != null && districtName!.isNotEmpty;
    final bool showingRegion = (provinceName.isEmpty) &&
        (regionName != null && regionName!.isNotEmpty);

    // Başlık: ilçe > il > bölge
    final String title = showingDistrict
        ? districtName!
        : showingRegion
            ? regionName!
            : provinceName;
    // Alt başlık: bağlam bilgisi
    final String? subtitle = showingDistrict
        ? provinceName
        : showingRegion
            ? '7 Coğrafi Bölge'
            : regionName;

    final IconData headerIcon = showingDistrict
        ? Icons.place_rounded
        : showingRegion
            ? Icons.map_rounded
            : Icons.location_city_rounded;

    final Color accentColor = showingDistrict
        ? Colors.purpleAccent
        : showingRegion
            ? Colors.greenAccent
            : Colors.tealAccent;

    // İl'e ait pinler
    final provincePins = allPins.where((p) {
      final city = p.city ?? '';
      return city.toLowerCase() == provinceName.toLowerCase();
    }).toList();

    final windCount  = provincePins.where((p) => p.type == 'Rüzgar Türbini').length;
    final solarCount = provincePins.where((p) => p.type == 'Güneş Paneli').length;
    final hesCount   = provincePins.where((p) => p.type == 'Hidroelektrik').length;

    return Container(
      width: 290,
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Başlık ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.10),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                bottom: BorderSide(color: accentColor.withValues(alpha: 0.15)),
              ),
            ),
            child: Row(
              children: [
                // Geri butonu (üst seviye varsa)
                if (onBack != null)
                  GestureDetector(
                    onTap: onBack,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 14,
                        color: accentColor,
                      ),
                    ),
                  ),
                Icon(headerIcon, color: accentColor, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: theme.secondaryTextColor,
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: theme.secondaryTextColor.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

          // ── Bölge seçilince yönlendirme mesajı ────────────────────
          if (showingRegion)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Text(
                'İllere göz atmak için haritada\nbir ile tıklayın.',
                style: TextStyle(
                  color: theme.secondaryTextColor,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ),

          // ── Hava İstatistikleri (il seviyesinde) ──────────────────
          if (summary != null && !showingDistrict && !showingRegion)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  _StatChip(
                    icon: Icons.air,
                    color: Colors.cyanAccent,
                    label: 'Rüzgar',
                    value: summary!.avgWindSpeed != null
                        ? '${summary!.avgWindSpeed!.toStringAsFixed(1)} m/s'
                        : '—',
                    theme: theme,
                  ),
                  const SizedBox(width: 6),
                  _StatChip(
                    icon: Icons.wb_sunny,
                    color: Colors.amber,
                    label: 'Işınım',
                    value: summary!.avgRadiation != null
                        ? '${summary!.avgRadiation!.toStringAsFixed(0)} W/m²'
                        : '—',
                    theme: theme,
                  ),
                  const SizedBox(width: 6),
                  _StatChip(
                    icon: Icons.thermostat,
                    color: Colors.orangeAccent,
                    label: 'Sıcaklık',
                    value: summary!.avgTemperature != null
                        ? '${summary!.avgTemperature!.toStringAsFixed(1)} °C'
                        : '—',
                    theme: theme,
                  ),
                ],
              ),
            )
          else if (summary == null && !showingDistrict && !showingRegion && provinceName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Text(
                'Hava durumu verisi yükleniyor...',
                style: TextStyle(color: theme.secondaryTextColor, fontSize: 11),
              ),
            ),

          // ── Pin Sayıları ───────────────────────────────────────────
          if (provincePins.isNotEmpty && !showingDistrict && !showingRegion) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  const Icon(Icons.push_pin_rounded, size: 12, color: Colors.white54),
                  const SizedBox(width: 4),
                  Text(
                    'Kayıtlı Kaynaklar:',
                    style: TextStyle(color: theme.secondaryTextColor, fontSize: 10),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Wrap(
                spacing: 5,
                runSpacing: 3,
                children: [
                  if (windCount > 0)
                    _PinBadge(
                      icon: Icons.wind_power,
                      color: const Color(0xFF29B6F6),
                      label: '$windCount Rüzgar',
                      theme: theme,
                    ),
                  if (solarCount > 0)
                    _PinBadge(
                      icon: Icons.wb_sunny,
                      color: const Color(0xFFFFA726),
                      label: '$solarCount Güneş',
                      theme: theme,
                    ),
                  if (hesCount > 0)
                    _PinBadge(
                      icon: Icons.water_rounded,
                      color: const Color(0xFF42A5F5),
                      label: '$hesCount HES',
                      theme: theme,
                    ),
                ],
              ),
            ),
          ],

          // ── İlçe seçilince hava istatistikleri ────────────────────
          if (showingDistrict) ...[
            if (districtSummary != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  children: [
                    _StatChip(
                      icon: Icons.air,
                      color: Colors.cyanAccent,
                      label: 'Rüzgar',
                      value: districtSummary!.avgWindSpeed != null
                          ? '${districtSummary!.avgWindSpeed!.toStringAsFixed(1)} m/s'
                          : '—',
                      theme: theme,
                    ),
                    const SizedBox(width: 6),
                    _StatChip(
                      icon: Icons.wb_sunny,
                      color: Colors.amber,
                      label: 'Işınım',
                      value: districtSummary!.avgRadiation != null
                          ? '${districtSummary!.avgRadiation!.toStringAsFixed(0)} W/m²'
                          : '—',
                      theme: theme,
                    ),
                    const SizedBox(width: 6),
                    _StatChip(
                      icon: Icons.thermostat,
                      color: Colors.orangeAccent,
                      label: 'Sıcaklık',
                      value: districtSummary!.avgTemperature != null
                          ? '${districtSummary!.avgTemperature!.toStringAsFixed(1)} °C'
                          : '—',
                      theme: theme,
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Text(
                  isLoadingDistrictSummaries
                      ? 'Hava durumu verisi yükleniyor...'
                      : 'Bu ilçe için hava verisi bulunamadı.',
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: 11,
                  ),
                ),
              ),
          ],

          // ── İl Raporu Butonu ───────────────────────────────────────
          if (!showingDistrict && !showingRegion && provinceName.isNotEmpty && onViewReport != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: GestureDetector(
                onTap: onViewReport,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.tealAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.assessment_rounded,
                        size: 13,
                        color: Colors.tealAccent,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'İl Raporunu Görüntüle',
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final ThemeViewModel theme;

  const _StatChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                color: theme.textColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: TextStyle(color: theme.secondaryTextColor, fontSize: 9),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PinBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final ThemeViewModel theme;

  const _PinBadge({
    required this.icon,
    required this.color,
    required this.label,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
