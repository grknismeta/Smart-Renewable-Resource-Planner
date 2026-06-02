// lib/features/reports/widgets/tabs/province_drill_tab.dart
//
// İL ANALİZİ TAB — Sprint R1 v3 (eski 1286 satırlık versiyon değiştirildi)
//
// İçerik:
//   • İl seçici (81 il dropdown)
//   • 2 sub-tab: Potansiyel | Hava
//   • Potansiyel:
//       - 3 kolon "En İyi GES/RES/HES İlçeleri" (BestSpotCard)
//       - İlçe karşılaştırma tablosu (ilçe × 3 score + best + MW)
//   • Hava:
//       - 4 WeatherStrip + Wind Rose + Nehir Debisi (shared climate widget'lar)
//
// Veri: GET /analysis/province/{name}/districts + /climate
// Mockup ref: designhtml/reports-province.jsx

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/features/reports/pages/compare_page.dart';
import 'package:frontend/features/reports/pages/district_detail_page.dart';
import 'package:frontend/features/reports/viewmodels/province_drill_viewmodel.dart';
import 'package:frontend/features/reports/viewmodels/report_nav_controller.dart';
import 'package:frontend/features/reports/widgets/climate/climate_widgets.dart';
import 'package:frontend/features/reports/widgets/common/report_mini_map.dart';
import 'package:frontend/features/reports/widgets/common/report_ui.dart';
import 'package:frontend/features/reports/widgets/tabs/projection_tab.dart';
import 'package:maplibre/maplibre.dart' as ml;

class ProvinceDrillTab extends StatelessWidget {
  final String? initialProvince;
  const ProvinceDrillTab({super.key, this.initialProvince});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => ProvinceDrillViewModel(
        Provider.of<ApiService>(ctx, listen: false),
      )..init(initialProvince: initialProvince),
      child: const _ProvinceDrillBody(),
    );
  }
}

class _ProvinceDrillBody extends StatelessWidget {
  const _ProvinceDrillBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProvinceDrillViewModel>();

    // Drill-down: Bölge tab'ından gelen pendingProvince varsa o ili seç.
    // İl listesi yüklenene kadar bekle (contains false → tekrar dener).
    final nav = context.watch<ReportNavController>();
    final pendingProv = nav.pendingProvince;
    if (pendingProv != null && vm.allProvinces.contains(pendingProv)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nav.consumeProvince();
        vm.selectProvince(pendingProv);
      });
    }

    if (vm.isBusy && vm.allProvinces.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 2),
      );
    }
    if (vm.hasError && vm.allProvinces.isEmpty) {
      return _ErrorView(message: vm.errorMessage ?? '', onRetry: () => vm.init());
    }

    return LayoutBuilder(builder: (lctx, cs) {
      // 2026-05-25 (Fix5): Geniş ekranda (≥1100) Potansiyel + Hava view'ları
      // yan yana — sub-tab gereksiz olur; her ikisi de aynı anda görünür.
      // Toolbar sub-tab toggle'ı bu durumda gizlenir (showSubTab=false).
      final wide = cs.maxWidth >= 1100;
      // 2026-05-27 (P2.5): Projeksiyon sub-tab eklendi. Projeksiyon her
      // ekran genişliğinde tam alan ister (chart + KPI grid sıkışmasın);
      // bu yüzden projection seçiliyse yan-yana layout devre dışı.
      final showSideBySide =
          wide && vm.subTab != ProvinceDrillSubTab.projection;
      // Sub-tab toggle: dar ekranda zaten gerekli; geniş ekranda da
      // projection seçilebilsin diye gösterilir (Potansiyel/Hava yan-yana
      // gösteriliyorsa da kullanıcı 3.'ye geçebilsin).
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Toolbar(vm: vm, showSubTab: true, hideOnSideBySide: showSideBySide),
          Expanded(
            child: vm.detailLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.cyanAccent,
                      strokeWidth: 2,
                    ),
                  )
                : (vm.districts == null
                    ? const Center(
                        child: Text('İl seç',
                            style: TextStyle(color: Colors.white54)))
                    : (showSideBySide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _PotentialView(
                                  districts: vm.districts!,
                                  province: vm.selectedProvince ?? '',
                                ),
                              ),
                              Container(
                                width: 1,
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                              Expanded(
                                flex: 2,
                                child: _WeatherView(
                                  climate: vm.climate,
                                  province: vm.selectedProvince ?? '',
                                ),
                              ),
                            ],
                          )
                        : (switch (vm.subTab) {
                            ProvinceDrillSubTab.potential => _PotentialView(
                                districts: vm.districts!,
                                province: vm.selectedProvince ?? '',
                              ),
                            ProvinceDrillSubTab.weather => _WeatherView(
                                climate: vm.climate,
                                province: vm.selectedProvince ?? '',
                              ),
                            ProvinceDrillSubTab.projection =>
                              ProvinceProjectionView(
                                province: vm.selectedProvince ?? '',
                              ),
                          }))),
          ),
        ],
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOOLBAR — il seçici + sub-tab
// ─────────────────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  final ProvinceDrillViewModel vm;
  /// 2026-05-25 (Fix5): Geniş ekranda sub-tab gereksiz (her iki view yan yana).
  final bool showSubTab;

  /// 2026-05-27 (P2.5): Geniş ekranda Potansiyel+Hava yan yana gösteriliyor;
  /// bu durumda sadece "Projeksiyon" segmenti görünür çünkü diğer 2'si zaten
  /// aynı anda ekranda. Kullanıcı projection'a geçince layout otomatik full-width
  /// olur.
  final bool hideOnSideBySide;
  const _Toolbar({
    required this.vm,
    this.showSubTab = true,
    this.hideOnSideBySide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          // İl seçici — Expanded ile uzun il adlarında bile sığacak.
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Colors.cyanAccent.withValues(alpha: 0.30)),
              ),
              child: DropdownButton<String>(
                value: vm.selectedProvince,
                isDense: true,
                isExpanded: true,
                dropdownColor: const Color(0xFF1C2533),
                underline: const SizedBox.shrink(),
                icon: const Icon(Icons.keyboard_arrow_down,
                    color: Colors.cyanAccent, size: 18),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                items: vm.allProvinces
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (p) {
                  if (p != null) vm.selectProvince(p);
                },
              ),
            ),
          ),
          if (showSubTab) ...[
            const SizedBox(width: 8),
            _SubTabToggle(
              active: vm.subTab,
              onChange: vm.setSubTab,
              compact: hideOnSideBySide,
            ),
          ],
        ],
      ),
    );
  }
}

class _SubTabToggle extends StatelessWidget {
  final ProvinceDrillSubTab active;
  final ValueChanged<ProvinceDrillSubTab> onChange;

  /// Geniş ekranda Potansiyel+Hava yan yana zaten gösterildiği için
  /// sadece "Projeksiyon" segmenti gösterilir (P2.5).
  final bool compact;
  const _SubTabToggle({
    required this.active,
    required this.onChange,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact)
            _seg('Potansiyel', Icons.analytics_outlined,
                ProvinceDrillSubTab.potential),
          if (!compact)
            _seg('Hava', Icons.cloud_outlined, ProvinceDrillSubTab.weather),
          _seg('Projeksiyon', Icons.auto_graph_rounded,
              ProvinceDrillSubTab.projection),
        ],
      ),
    );
  }

  Widget _seg(String label, IconData icon, ProvinceDrillSubTab tab) {
    final isActive = active == tab;
    return GestureDetector(
      onTap: () => onChange(tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.cyanAccent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: isActive ? Colors.cyanAccent : Colors.white54),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.cyanAccent : Colors.white54,
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POTANSİYEL VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _PotentialView extends StatelessWidget {
  final ProvinceDistrictsData districts;
  final String province;
  const _PotentialView({required this.districts, required this.province});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$province · ${districts.districtCount} ilçe',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'İlçe bazlı potansiyel analizi · 3 kaynak için en iyi sahalar',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),

          // İlçe haritası — ilçeler en iyi skoruna göre renkli marker.
          // F4: İlin sınırına hapsedildi; ilçe merkezleri bbox + 0.3° padding
          // → kullanıcı il dışına pan yapamaz.
          // 2026-05-26 (J1): Marker'a tıklayınca H4 inline kart açılır;
          // "Detay" tuşu → `DistrictDetailPage` (İl=>İlçe raporu ile aynı).
          Builder(builder: (mctx) {
            final markers = districts.districts
                .map((d) => ReportMapMarker(
                      lat: d.lat,
                      lon: d.lon,
                      label: d.name,
                      score: d.bestScore,
                    ))
                .toList();
            ml.LngLatBounds? bounds;
            if (markers.length >= 2) {
              double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;
              for (final m in markers) {
                if (m.lat < minLat) minLat = m.lat;
                if (m.lat > maxLat) maxLat = m.lat;
                if (m.lon < minLon) minLon = m.lon;
                if (m.lon > maxLon) maxLon = m.lon;
              }
              bounds = ml.LngLatBounds(
                longitudeWest: minLon,
                latitudeSouth: minLat,
                longitudeEast: maxLon,
                latitudeNorth: maxLat,
              );
            }
            return ReportMiniMap(
              height: 280,
              markers: markers,
              bounds: bounds,
              // N4: bounds size'ın %20'si padding. Küçük ilde dar, büyük ilde
              // geniş — kullanıcı seçili ile odaklı kalır.
              boundsPaddingRatio: 0.20,
              districtProvinceFilter: province,
              // 2026-06-01: ilçe sınırlarına ek olarak il (province) sınırı da.
              showProvinceBorders: true,
              markerSize: ReportMarkerSize.compact,
              onMarkerTap: (m) {
                // Marker label → DistrictScore (isim üzerinden eşle)
                final match = districts.districts.firstWhere(
                  (d) => d.name == m.label,
                  orElse: () => districts.districts.first,
                );
                Navigator.of(mctx).push(
                  MaterialPageRoute(
                    builder: (_) => DistrictDetailPage(
                      district: match,
                      provinceName: province,
                    ),
                  ),
                );
              },
            );
          }),
          const SizedBox(height: 8),
          Row(
            children: [
              _mapLegendDot(const Color(0xFF10B981), 'Yüksek ≥65'),
              const SizedBox(width: 12),
              _mapLegendDot(const Color(0xFFF59E0B), 'Orta 45-65'),
              const SizedBox(width: 12),
              _mapLegendDot(const Color(0xFFEF4444), 'Düşük <45'),
            ],
          ),
          const SizedBox(height: 16),

          // 3 kolon best spots
          LayoutBuilder(builder: (ctx, c) {
            final cols = [
              _BestSpotColumn(
                title: 'En İyi Güneş İlçeleri',
                resource: 'solar',
                color: const Color(0xFFF59E0B),
                icon: Icons.wb_sunny_rounded,
                spots: districts.bestSpots['solar'] ?? const [],
              ),
              _BestSpotColumn(
                title: 'En İyi Rüzgar İlçeleri',
                resource: 'wind',
                color: const Color(0xFF3B82F6),
                icon: Icons.air_rounded,
                spots: districts.bestSpots['wind'] ?? const [],
              ),
              _BestSpotColumn(
                title: 'En İyi Hidro İlçeleri',
                resource: 'hydro',
                color: const Color(0xFF06B6D4),
                icon: Icons.water_drop_rounded,
                spots: districts.bestSpots['hydro'] ?? const [],
              ),
            ];
            if (c.maxWidth >= 880) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cols[0]),
                    const SizedBox(width: 10),
                    Expanded(child: cols[1]),
                    const SizedBox(width: 10),
                    Expanded(child: cols[2]),
                  ],
                ),
              );
            }
            return Column(
              children: [
                cols[0],
                const SizedBox(height: 10),
                cols[1],
                const SizedBox(height: 10),
                cols[2],
              ],
            );
          }),

          const SizedBox(height: 20),

          // İlçe karşılaştırma tablosu — G4: provinceName drill-down için.
          _DistrictComparisonTable(
            districts: districts.districts,
            provinceName: province,
          ),
        ],
      ),
    );
  }

  Widget _mapLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _BestSpotColumn extends StatelessWidget {
  final String title;
  final String resource;
  final Color color;
  final IconData icon;
  final List<BestSpot> spots;

  const _BestSpotColumn({
    required this.title,
    required this.resource,
    required this.color,
    required this.icon,
    required this.spots,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (spots.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Uygun saha yok',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.40),
                    fontSize: 11,
                  ),
                ),
              ),
            )
          else
            ...spots.asMap().entries.map(
                  (e) => _BestSpotCard(
                    rank: e.key + 1,
                    spot: e.value,
                    resource: resource,
                    color: color,
                  ),
                ),
        ],
      ),
    );
  }
}

class _BestSpotCard extends StatelessWidget {
  final int rank;
  final BestSpot spot;
  final String resource;
  final Color color;

  const _BestSpotCard({
    required this.rank,
    required this.spot,
    required this.resource,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: rank == 1
            ? color.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: rank == 1
              ? color.withValues(alpha: 0.30)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '#$rank',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  spot.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                spot.score.toStringAsFixed(0),
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 10,
            runSpacing: 2,
            children: _detailChips(),
          ),
        ],
      ),
    );
  }

  List<Widget> _detailChips() {
    final chips = <Widget>[
      _chip('${spot.estimatedMw} MW'),
    ];
    if (resource == 'solar') {
      final irr = spot.extra['irradiance_kwh_m2_day'];
      final area = spot.extra['panel_area_m2'];
      if (irr != null) chips.add(_chip('$irr kWh/m²'));
      if (area != null) chips.add(_chip('$area m²'));
    } else if (resource == 'wind') {
      final ws = spot.extra['wind_speed_ms'];
      final hub = spot.extra['hub_height_m'];
      if (ws != null) chips.add(_chip('$ws m/s'));
      if (hub != null) chips.add(_chip('${hub}m hub'));
    } else if (resource == 'hydro') {
      final flow = spot.extra['flow_rate_m3s'];
      final head = spot.extra['head_m'];
      if (flow != null) chips.add(_chip('$flow m³/s'));
      if (head != null) chips.add(_chip('${head}m düşü'));
    }
    return chips;
  }

  Widget _chip(String text) => Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 10,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// İLÇE KARŞILAŞTIRMA TABLOSU
// ─────────────────────────────────────────────────────────────────────────────

/// 2026-05-25 (G3+G4): StatelessWidget → StatefulWidget.
/// - Satırlar score'a göre subtle bg renkli (6 ton: emerald/green/lime/amber/
///   orange/red, alpha 0.04-0.10)
/// - Her satırın başında checkbox; 2+ seçilince üstte "Karşılaştır (N)"
///   butonu görünür → `DistrictComparePage` route.
class _DistrictComparisonTable extends StatefulWidget {
  final List<DistrictScore> districts;
  final String? provinceName;
  const _DistrictComparisonTable({required this.districts, this.provinceName});

  @override
  State<_DistrictComparisonTable> createState() =>
      _DistrictComparisonTableState();
}

class _DistrictComparisonTableState extends State<_DistrictComparisonTable> {
  // 2026-05-25 (Fix3): 6 sütunlu tablo dar ekranda hücrelerin içeriği
  // birbirine taşıyordu (özellikle skor cell'in Bar+Text yatay row'u).
  // Çözüm: minTableWidth=560 sabit + dar ekranda SingleChildScrollView
  // (horizontal) ile yatay scroll. Geniş ekranda doğal genişlikte kalır.
  // G4: Checkbox eklendi → minTableWidth 560 → 600.
  static const double _minTableWidth = 600;

  final Set<String> _selected = {};

  /// 2026-05-26 (J2): İlçeleri her seferinde **Tahmini MW azalan** sıralı
  /// göster — kullanıcı kapasiteye göre kıyaslamak istiyor.
  /// Eşit MW'de bestScore desc → isim asc.
  List<DistrictScore> get _sortedDistricts {
    final copy = [...widget.districts];
    copy.sort((a, b) {
      final mw = b.estimatedMw.compareTo(a.estimatedMw);
      if (mw != 0) return mw;
      final score = b.bestScore.compareTo(a.bestScore);
      if (score != 0) return score;
      return a.name.compareTo(b.name);
    });
    return copy;
  }

  void _toggle(String name) {
    setState(() {
      if (_selected.contains(name)) {
        _selected.remove(name);
      } else {
        _selected.add(name);
      }
    });
  }

  void _openCompare() {
    final selectedDistricts = _sortedDistricts
        .where((d) => _selected.contains(d.name))
        .toList();
    if (selectedDistricts.length < 2) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ComparePage(
          title: 'İlçe Karşılaştırması',
          subtitle: widget.provinceName ?? '',
          items: selectedDistricts
              .map((d) => CompareItem(
                    name: d.name,
                    subtitle: widget.provinceName ?? '',
                    bestResource: d.bestResource,
                    bestScore: d.bestScore,
                    solarScore: d.solarScore,
                    windScore: d.windScore,
                    hydroScore: d.hydroScore,
                    estimatedMw: d.estimatedMw.toDouble(),
                  ))
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'İlçe Karşılaştırma Tablosu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              // G4: 2+ seçilince "Karşılaştır (N)" butonu görünür.
              if (_selected.length >= 2)
                GestureDetector(
                  onTap: _openCompare,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.cyanAccent.withValues(alpha: 0.50),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.compare_arrows_rounded,
                            size: 12, color: Colors.cyanAccent),
                        const SizedBox(width: 4),
                        Text(
                          'Karşılaştır (${_selected.length})',
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const Spacer(),
              LayoutBuilder(builder: (lctx, c) {
                if (c.maxWidth >= _minTableWidth) return const SizedBox.shrink();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swipe_rounded,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.40)),
                    const SizedBox(width: 4),
                    Text(
                      'yatay kaydır',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.40),
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (lctx, c) {
            final needsScroll = c.maxWidth < _minTableWidth;
            final table = SizedBox(
              width: needsScroll ? _minTableWidth : c.maxWidth,
              child: Column(
                children: [
                  _tableRow(
                    isHeader: true,
                    cells: ['', 'İlçe', 'Güneş', 'Rüzgar', 'Hidro', 'En İyi', 'MW'],
                  ),
                  const SizedBox(height: 4),
                  // J2: Her seferinde MW azalan sıralı.
                  ..._sortedDistricts.map((d) => _DistrictRow(
                        district: d,
                        selected: _selected.contains(d.name),
                        onToggle: () => _toggle(d.name),
                        provinceName: widget.provinceName,
                      )),
                ],
              ),
            );
            if (!needsScroll) return table;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: table,
            );
          }),
        ],
      ),
    );
  }

  // G4: 7 sütun (checkbox + 6 mevcut). flex: 1+3+2+2+2+2+2 = 14, 600px /
  // 14 ≈ 42px/birim.
  static Widget _tableRow({
    required bool isHeader,
    required List<String> cells,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 28, child: _cell(cells[0], isHeader, center: true)),
          Expanded(flex: 3, child: _cell(cells[1], isHeader)),
          Expanded(flex: 2, child: _cell(cells[2], isHeader, center: true)),
          Expanded(flex: 2, child: _cell(cells[3], isHeader, center: true)),
          Expanded(flex: 2, child: _cell(cells[4], isHeader, center: true)),
          Expanded(flex: 2, child: _cell(cells[5], isHeader, center: true)),
          Expanded(flex: 2, child: _cell(cells[6], isHeader, center: true)),
        ],
      ),
    );
  }

  static Widget _cell(String text, bool isHeader, {bool center = false}) {
    return Text(
      text,
      textAlign: center ? TextAlign.center : TextAlign.left,
      style: TextStyle(
        color: isHeader
            ? Colors.white.withValues(alpha: 0.45)
            : Colors.white,
        fontSize: isHeader ? 9.5 : 12,
        fontWeight: isHeader ? FontWeight.w600 : FontWeight.w500,
        letterSpacing: isHeader ? 0.5 : 0,
      ),
    );
  }
}

class _DistrictRow extends StatelessWidget {
  final DistrictScore district;
  final bool selected;
  final VoidCallback onToggle;
  final String? provinceName;
  const _DistrictRow({
    required this.district,
    required this.selected,
    required this.onToggle,
    this.provinceName,
  });

  static const _resColors = {
    'solar': Color(0xFFF59E0B),
    'wind': Color(0xFF3B82F6),
    'hydro': Color(0xFF06B6D4),
  };

  /// 2026-05-25 (G3): Skora göre 6 ton subtle bg. Kullanıcı isteği: "satırları
  /// çok hafif renklerle renklendir, 6-7 renk".
  Color _rowBgColor() {
    if (selected) {
      return Colors.cyanAccent.withValues(alpha: 0.10);
    }
    final s = district.bestScore;
    if (s >= 80) return const Color(0xFF10B981).withValues(alpha: 0.08); // emerald
    if (s >= 70) return const Color(0xFF22C55E).withValues(alpha: 0.06); // green
    if (s >= 60) return const Color(0xFFA3E635).withValues(alpha: 0.05); // lime
    if (s >= 50) return const Color(0xFFFBBF24).withValues(alpha: 0.05); // amber
    if (s >= 40) return const Color(0xFFF59E0B).withValues(alpha: 0.05); // orange
    return const Color(0xFFEF4444).withValues(alpha: 0.04);              // red
  }

  @override
  Widget build(BuildContext context) {
    final bestColor = _resColors[district.bestResource] ?? Colors.white54;
    // G8: Satır tıklama → DistrictDetailPage; checkbox kendi alanında toggle.
    void openDetail() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DistrictDetailPage(
            district: district,
            provinceName: provinceName ?? '',
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      decoration: BoxDecoration(
        color: _rowBgColor(),
        borderRadius: BorderRadius.circular(6),
        border: selected
            ? Border.all(
                color: Colors.cyanAccent.withValues(alpha: 0.55),
                width: 1,
              )
            : null,
      ),
      child: Row(
        children: [
          // G4: Checkbox — kendi tap target'ı, satır tap'ine yayılmaz.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: SizedBox(
              width: 28,
              height: 32,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    value: selected,
                    onChanged: (_) => onToggle(),
                    visualDensity:
                        const VisualDensity(horizontal: -4, vertical: -4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    activeColor: Colors.cyanAccent,
                    checkColor: Colors.black,
                  ),
                ),
              ),
            ),
          ),
          // G8: Diğer alan tap → DistrictDetailPage. InkWell tap propagation
          // yutar.
          Expanded(
            child: InkWell(
              onTap: openDetail,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 7),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        district.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                        flex: 2,
                        child: _scoreCell(
                            district.solarScore, _resColors['solar']!)),
                    Expanded(
                        flex: 2,
                        child: _scoreCell(
                            district.windScore, _resColors['wind']!)),
                    Expanded(
                        flex: 2,
                        child: _scoreCell(
                            district.hydroScore, _resColors['hydro']!)),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: bestColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _resLabel(district.bestResource),
                            style: TextStyle(
                              color: bestColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${district.estimatedMw}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreCell(double score, Color color) {
    // 2026-05-25 (Fix3): Bar width 32→24, sb 5→4 — Expanded(flex:2) içinde
    // sığsın (mobile'da yatay scroll'la zaten min 560 garanti).
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            child: Stack(
              children: [
                Container(
                  height: 3,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: (score / 100).clamp(0.0, 1.0),
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            score.toStringAsFixed(0),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String _resLabel(String r) => switch (r) {
        'solar' => 'Güneş',
        'wind' => 'Rüzgar',
        'hydro' => 'Hidro',
        _ => r,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// HAVA VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _WeatherView extends StatelessWidget {
  final ClimateSeries? climate;
  final String province;
  const _WeatherView({required this.climate, required this.province});

  @override
  Widget build(BuildContext context) {
    if (climate == null) {
      return const Center(
        child: Text('İklim verisi yok',
            style: TextStyle(color: Colors.white54)),
      );
    }
    final c = climate!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$province · Hava Analizi',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              // Q3: Climate (aylık 10y) — Reports'ta gösterilen aylık
              // grafikler climatology.monthly_* JSON kolonlarından gelir.
              ReportSourceBadge(
                source: c.source,
                freq: c.source.startsWith('mock')
                    ? ReportDataFreq.mockTypical
                    : ReportDataFreq.monthly10y,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '3 kaynak tipi için meteorolojik göstergeler · 10 yıl ortalaması',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 14),

          // 4 WeatherStrip
          LayoutBuilder(builder: (ctx, cc) {
            final cross = cc.maxWidth >= 760 ? 4 : (cc.maxWidth >= 500 ? 2 : 1);
            return GridView.count(
              crossAxisCount: cross,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.0,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                WeatherStripCard(
                  label: 'Güneş Işınımı',
                  unit: 'kWh/m²·gün',
                  data: c.irradiance,
                  color: const Color(0xFFF59E0B),
                ),
                WeatherStripCard(
                  label: 'Rüzgar Hızı',
                  unit: 'm/s @100m',
                  data: c.windSpeed,
                  color: const Color(0xFF3B82F6),
                ),
                WeatherStripCard(
                  label: 'Yağış',
                  unit: 'mm/ay',
                  data: c.precipitation,
                  color: const Color(0xFF06B6D4),
                ),
                WeatherStripCard(
                  label: 'Sıcaklık',
                  unit: '°C',
                  data: c.temperature,
                  color: const Color(0xFFEF4444),
                ),
              ],
            );
          }),

          const SizedBox(height: 16),

          // Wind rose + river discharge
          LayoutBuilder(builder: (ctx, cc) {
            final wide = cc.maxWidth >= 700;
            final rose = WindRoseCard(rose: c.windRose);
            final discharge = RiverDischargeCard(discharge: c.riverDischarge);
            if (wide) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: rose),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: discharge),
                  ],
                ),
              );
            }
            return Column(children: [
              rose,
              const SizedBox(height: 10),
              discharge,
            ]);
          }),
        ],
      ),
    );
  }
}

// 2026-05-25 (P2/7): Eski inline `_SourceBadge` shared `ReportSourceBadge`
// ile değişti — Region/Province/Santral'da tek widget kullanılıyor.

// ─────────────────────────────────────────────────────────────────────────────
// ERROR
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.white38, size: 36),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 14),
            label: const Text('Tekrar dene'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent.withValues(alpha: 0.15),
              foregroundColor: Colors.cyanAccent,
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
