// lib/features/map/widgets/panels/unified_selection_card.dart
//
// 2026-05-08 — Unified Selection Card (Strateji C)
// ----------------------------------------------------------------------------
// Eski iki kartı birleştirir:
//   - `_ChoroplethTooltip` (sol üst, dashboard altı, mod-spesifik tek metrik)
//   - `ProvinceInfoCard`   (sol alt, zengin, pin sayıları + 3 metrik)
//
// Yeni davranış:
//   - Tek kart, sol üst dashboard altında.
//   - Başlık breadcrumb: Bölge · İl · İlçe — her segment tıklanabilir, ilgili
//     moda geçiş yapar (region/province/district).
//   - 3 metrik chip (rüzgar / ışınım / sıcaklık). Choropleth mode aktifse o
//     chip vurgulu (büyük + renkli border).
//   - "Raporu Görüntüle" butonu altta — `onViewReport` callback.
//   - "×" → tüm seçimi temizle + choropleth tap'ı kapat.
//   - Pin sayıları kaldı dashboard'a (KPI kartı zaten gösteriyor — tekrar yok).
//
// Render koşulu (caller belirler):
//   selectedProvinceName != null ||
//   selectedDistrictName != null ||
//   selectedRegionName  != null
//
// Çift kart desenkronu (choropleth tap state donması) bu birleşik tasarımla
// kökten gider — tek state kaynağı.

import 'package:flutter/material.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/models/weather_model.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';

class UnifiedSelectionCard extends StatelessWidget {
  final ThemeViewModel theme;

  // Hiyerarşi
  final String? regionName;
  final String? provinceName;
  final String? districtName;
  final SelectionLevel selectionLevel;

  // Veri
  final ProvinceSummary? provinceSummary;
  final DistrictSummary? districtSummary;
  /// 2026-05-08 Madde 4: Bölge seçildiğinde ortalama veriler. Bölge → İl → İlçe
  /// hiyerarşisinde fallback önceliği: district > province > region.
  final RegionSummary? regionSummary;
  final bool isLoadingDistrictSummaries;

  // Choropleth bağlamı (aktif metric vurgusu) — DistrictSummary/ProvinceSummary
  // henüz yüklenmediğinde fallback olarak choropleth tap verisi kullanılır.
  // Map yapısı: {'wind': double?, 'solar': double?, 'temp': double?}
  final ChoroplethMode choroplethMode;
  final Map<String, dynamic>? choroplethTapData;
  final String? choroplethTapDistrictLabel;

  // Eylemler
  final VoidCallback onClose;
  final VoidCallback? onViewReport;
  final void Function(String region)? onSelectRegion;
  final void Function(String province)? onSelectProvince;
  final void Function(String province, String district)? onSelectDistrict;
  /// 2026-05-08 Madde 3: Metric chip'lerine tıklayınca tematik harita o metriğe
  /// geçer (toggle: aynı metrik zaten aktifse kapat).
  final void Function(ChoroplethMode mode)? onMetricTap;

  const UnifiedSelectionCard({
    super.key,
    required this.theme,
    required this.selectionLevel,
    required this.choroplethMode,
    required this.onClose,
    this.regionName,
    this.provinceName,
    this.districtName,
    this.provinceSummary,
    this.districtSummary,
    this.regionSummary,
    this.isLoadingDistrictSummaries = false,
    this.choroplethTapData,
    this.choroplethTapDistrictLabel,
    this.onViewReport,
    this.onSelectRegion,
    this.onSelectProvince,
    this.onSelectDistrict,
    this.onMetricTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasDistrict = districtName != null && districtName!.isNotEmpty;
    final hasProvince = provinceName != null && provinceName!.isNotEmpty;
    final hasRegion = regionName != null && regionName!.isNotEmpty;

    // Genişlik mobil-responsive: ekran < 480 ise küçült
    final screenW = MediaQuery.of(context).size.width;
    final cardW = screenW < 480 ? screenW - 32.0 : 320.0;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: cardW,
        decoration: BoxDecoration(
          color: theme.cardColor.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.secondaryTextColor.withValues(alpha: 0.18)),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(hasRegion, hasProvince, hasDistrict),
              const SizedBox(height: 10),
              _buildMetricChips(),
              if (onViewReport != null && hasProvince) ...[
                const SizedBox(height: 10),
                _buildReportButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header (breadcrumb + close) ─────────────────────────────────────────

  Widget _buildHeader(bool hasRegion, bool hasProvince, bool hasDistrict) {
    final IconData icon = hasDistrict
        ? Icons.place_rounded
        : hasProvince
            ? Icons.location_city_rounded
            : Icons.map_rounded;
    final Color iconColor = hasDistrict
        ? Colors.purpleAccent
        : hasProvince
            ? Colors.tealAccent
            : Colors.greenAccent;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(child: _buildBreadcrumb(hasRegion, hasProvince, hasDistrict)),
        IconButton(
          icon: Icon(Icons.close, size: 16, color: theme.secondaryTextColor),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          onPressed: onClose,
          tooltip: 'Kapat',
        ),
      ],
    );
  }

  Widget _buildBreadcrumb(bool hasRegion, bool hasProvince, bool hasDistrict) {
    final parts = <Widget>[];

    if (hasRegion) {
      parts.add(_BreadcrumbSegment(
        label: regionName!,
        kind: 'Bölge',
        theme: theme,
        active: selectionLevel == SelectionLevel.region,
        onTap: onSelectRegion != null ? () => onSelectRegion!(regionName!) : null,
      ));
    }
    if (hasProvince) {
      if (parts.isNotEmpty) parts.add(_separator());
      parts.add(_BreadcrumbSegment(
        label: provinceName!,
        kind: 'İl',
        theme: theme,
        active: selectionLevel == SelectionLevel.province,
        onTap: onSelectProvince != null
            ? () => onSelectProvince!(provinceName!)
            : null,
      ));
    }
    if (hasDistrict) {
      if (parts.isNotEmpty) parts.add(_separator());
      parts.add(_BreadcrumbSegment(
        label: districtName!,
        kind: 'İlçe',
        theme: theme,
        active: selectionLevel == SelectionLevel.district,
        onTap: (onSelectDistrict != null && hasProvince)
            ? () => onSelectDistrict!(provinceName!, districtName!)
            : null,
      ));
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 0,
      runSpacing: 2,
      children: parts,
    );
  }

  Widget _separator() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          '·',
          style: TextStyle(
            color: theme.secondaryTextColor.withValues(alpha: 0.5),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  // ─── Metric chips ─────────────────────────────────────────────────────────

  Widget _buildMetricChips() {
    // Veri kaynağı önceliği: ilçe summary > il summary > bölge ortalaması > choropleth tap
    final wind = districtSummary?.avgWindSpeed
        ?? provinceSummary?.avgWindSpeed
        ?? regionSummary?.avgWindSpeed;
    final solar = districtSummary?.avgRadiation
        ?? provinceSummary?.avgRadiation
        ?? regionSummary?.avgRadiation;
    final temp = districtSummary?.avgTemperature
        ?? provinceSummary?.avgTemperature
        ?? regionSummary?.avgTemperature;

    // Choropleth tap fallback: tap verisi {wind, solar, temp} hepsini içerir,
    // summary'ler henüz yüklenmediyse kart boş kalmasın diye 3 metrik için de
    // kullan. dataKey adları `_ChoroplethTooltip`'tan miras: 'wind'/'solar'/'temp'.
    final tap = choroplethTapData;
    final windFallback = (tap?['wind'] as num?)?.toDouble();
    final solarFallback = (tap?['solar'] as num?)?.toDouble();
    final tempFallback = (tap?['temp'] as num?)?.toDouble();

    final loading = isLoadingDistrictSummaries &&
        districtSummary == null &&
        provinceSummary == null;
    if (loading) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        child: SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.secondaryTextColor,
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: _MetricChip(
            icon: Icons.air_rounded,
            label: 'Rüzgar',
            value: _fmtMs(wind ?? windFallback),
            iconColor: Colors.cyanAccent,
            highlighted: choroplethMode == ChoroplethMode.wind,
            theme: theme,
            onTap: onMetricTap == null
                ? null
                : () => onMetricTap!(choroplethMode == ChoroplethMode.wind
                    ? ChoroplethMode.none
                    : ChoroplethMode.wind),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _MetricChip(
            icon: Icons.wb_sunny_rounded,
            label: 'Işınım',
            value: _fmtWm2(solar ?? solarFallback),
            iconColor: Colors.amberAccent,
            highlighted: choroplethMode == ChoroplethMode.solar,
            theme: theme,
            onTap: onMetricTap == null
                ? null
                : () => onMetricTap!(choroplethMode == ChoroplethMode.solar
                    ? ChoroplethMode.none
                    : ChoroplethMode.solar),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _MetricChip(
            icon: Icons.thermostat_rounded,
            label: 'Sıcaklık',
            value: _fmtC(temp ?? tempFallback),
            iconColor: Colors.orangeAccent,
            highlighted: choroplethMode == ChoroplethMode.temperature,
            theme: theme,
            onTap: onMetricTap == null
                ? null
                : () => onMetricTap!(choroplethMode == ChoroplethMode.temperature
                    ? ChoroplethMode.none
                    : ChoroplethMode.temperature),
          ),
        ),
      ],
    );
  }

  String _fmtMs(double? v) => v == null ? '—' : '${v.toStringAsFixed(1)} m/s';
  String _fmtWm2(double? v) => v == null ? '—' : '${v.round()} W/m²';
  String _fmtC(double? v) => v == null ? '—' : '${v.toStringAsFixed(1)} °C';

  // ─── Report button ───────────────────────────────────────────────────────

  Widget _buildReportButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: onViewReport,
        icon: const Icon(Icons.bar_chart_rounded, size: 16),
        label: const Text('Raporu Görüntüle'),
        style: TextButton.styleFrom(
          foregroundColor: Colors.tealAccent,
          backgroundColor: Colors.tealAccent.withValues(alpha: 0.10),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ─── Breadcrumb segment ─────────────────────────────────────────────────────

class _BreadcrumbSegment extends StatelessWidget {
  final String label;
  final String kind; // "Bölge" | "İl" | "İlçe"
  final ThemeViewModel theme;
  final bool active;
  final VoidCallback? onTap;

  const _BreadcrumbSegment({
    required this.label,
    required this.kind,
    required this.theme,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? theme.textColor
        : theme.secondaryTextColor.withValues(alpha: 0.85);
    final fw = active ? FontWeight.w700 : FontWeight.w500;

    final text = Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 13.5,
        fontWeight: fw,
        decoration: onTap != null && !active ? TextDecoration.underline : null,
        decorationColor: theme.secondaryTextColor.withValues(alpha: 0.4),
        decorationStyle: TextDecorationStyle.dotted,
      ),
    );

    if (onTap == null) return text;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Tooltip(
        message: '$kind moduna geç',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          child: text,
        ),
      ),
    );
  }
}

// ─── Metric chip ────────────────────────────────────────────────────────────

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final bool highlighted;
  final ThemeViewModel theme;
  final VoidCallback? onTap;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    required this.highlighted,
    required this.theme,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted
            ? iconColor.withValues(alpha: 0.10)
            : theme.backgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlighted
              ? iconColor.withValues(alpha: 0.6)
              : theme.secondaryTextColor.withValues(alpha: 0.15),
          width: highlighted ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: iconColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: theme.textColor,
              fontSize: highlighted ? 14 : 13,
              fontWeight: highlighted ? FontWeight.w700 : FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Tooltip(
          message: highlighted
              ? '$label tematik haritasını kapat'
              : '$label tematik haritasını aç',
          child: content,
        ),
      ),
    );
  }
}
