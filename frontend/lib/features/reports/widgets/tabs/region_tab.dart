// lib/features/reports/widgets/tabs/region_tab.dart
//
// BÖLGE TAB — Sprint R1 (v3 mockup'a uygun)
//
// İçerik:
//   1. Bölge seçici chip bar (7 bölge)
//   2. Bölge başlık kartı (ad + lider kaynak + KPI sayıları)
//   3. 4 WeatherStrip mini chart (ışınım/rüzgar/yağış/sıcaklık) — climate'ten
//   4. Wind rose (8 yön histogramı) — climate.wind_rose'tan
//   5. Bölgenin illeri grid (ProvinceCard, climatology score'larıyla)
//   6. Yatırım fırsatları paneli (yüksek skorlu ilçeler)
//
// Veri: GET /analysis/region/{id}  → RegionDetailData (climate dahil)
// Mock fallback otomatik (climate_aggregate_service backend tarafı yapıyor).
//
// Mockup ref: designhtml/reports-region.jsx

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:maplibre/maplibre.dart' as ml;

import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/features/reports/viewmodels/region_viewmodel.dart';
import 'package:frontend/features/reports/viewmodels/report_nav_controller.dart';
import 'package:frontend/features/reports/widgets/climate/climate_widgets.dart';
import 'package:frontend/features/reports/widgets/common/report_mini_map.dart';

/// 2026-05-25 (F4): Marker listesinden bbox hesapla. Bölge sınırı GeoJSON
/// burada yok; il merkezlerinin bbox'u + padding bölgenin yaklaşık sınırı.
ml.LngLatBounds? _boundsFromMarkers(List<ReportMapMarker> markers) {
  if (markers.length < 2) return null;
  double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;
  for (final m in markers) {
    if (m.lat < minLat) minLat = m.lat;
    if (m.lat > maxLat) maxLat = m.lat;
    if (m.lon < minLon) minLon = m.lon;
    if (m.lon > maxLon) maxLon = m.lon;
  }
  return ml.LngLatBounds(
    longitudeWest: minLon,
    latitudeSouth: minLat,
    longitudeEast: maxLon,
    latitudeNorth: maxLat,
  );
}

class RegionTab extends StatelessWidget {
  const RegionTab({super.key});

  @override
  Widget build(BuildContext context) {
    // 2026-06-01: Genel Bakış'tan gelen bölge (pendingRegionId) İLK seçim olsun.
    // Eskiden init() koşulsuz ilk bölgeyi (Marmara) yüklüyordu; landing'den gelen
    // bölge _RegionBody'de postFrame ile seçiliyordu → iki yarışan _loadRegion
    // (Marmara default + Ege pending), Marmara fetch'i sonra dönüp seçimi eziyordu.
    // Pending'i doğrudan init'e vererek default Marmara yükü hiç oluşmaz.
    // (Burada consume ETME — _RegionBody tüketir; ayrıca tab canlıyken yeniden
    // yönlendirmeleri de o yönetir.)
    final pending = context.read<ReportNavController>().pendingRegionId;
    return ChangeNotifierProvider(
      create: (ctx) =>
          RegionViewModel(Provider.of<ApiService>(ctx, listen: false))
            ..init(initialRegionId: pending),
      child: const _RegionBody(),
    );
  }
}

class _RegionBody extends StatelessWidget {
  const _RegionBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RegionViewModel>();

    // Drill-down: Landing'den gelen pendingRegionId varsa o bölgeyi seç.
    final nav = context.watch<ReportNavController>();
    final pendingRegion = nav.pendingRegionId;
    if (pendingRegion != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nav.consumeRegion();
        vm.selectRegion(pendingRegion);
      });
    }

    if (vm.isBusy && vm.regions.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 2),
      );
    }
    if (vm.hasError && vm.regions.isEmpty) {
      return _ErrorView(message: vm.errorMessage ?? '', onRetry: () => vm.init());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RegionChipBar(
          regions: vm.regions,
          active: vm.selectedRegionId,
          onTap: (id) => vm.selectRegion(id),
        ),
        Expanded(
          child: vm.selectedRegion == null
              ? const Center(
                  child: Text('Bölge seç',
                      style: TextStyle(color: Colors.white54)))
              : _RegionDetail(detail: vm.selectedRegion!, isLoading: vm.isBusy),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHIP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _RegionChipBar extends StatelessWidget {
  final List<RegionMeta> regions;
  final String? active;
  final ValueChanged<String> onTap;

  const _RegionChipBar({
    required this.regions,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: regions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (ctx, i) {
          final r = regions[i];
          final selected = r.id == active;
          final color = _hexColor(r.color);
          return GestureDetector(
            onTap: () => onTap(r.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: selected
                      ? color.withValues(alpha: 0.50)
                      : Colors.white.withValues(alpha: 0.10),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3.5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    r.name,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: 11.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

Color _hexColor(String hex) {
  final h = hex.replaceAll('#', '');
  return Color(int.parse('ff$h', radix: 16));
}

// ─────────────────────────────────────────────────────────────────────────────
// REGION DETAIL
// ─────────────────────────────────────────────────────────────────────────────

class _RegionDetail extends StatelessWidget {
  final RegionDetailData detail;
  final bool isLoading;

  const _RegionDetail({required this.detail, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final r = detail.region;
    final color = _hexColor(r.color);

    // 2026-05-25 (F3): Geniş ekranda (≥1100px) master-detail split.
    // Sol kolon: header + il listesi (master). Sağ kolon: harita + climate.
    // Dar ekran (mobile/tablet): mevcut tek kolon stack (değişmedi).
    return LayoutBuilder(builder: (lctx, cs) {
      final wide = cs.maxWidth >= 1100;
      if (wide) {
        return _buildWideLayout(r, color);
      }
      return _buildNarrowLayout(r, color);
    });
  }

  Widget _buildWideLayout(RegionMeta r, Color color) {
    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SOL — Master (header + iller)
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RegionHeader(region: r, climate: detail.climate, color: color),
                    const SizedBox(height: 16),
                    Text(
                      'Bölgenin İlleri (${detail.provinces.length})',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ProvinceGrid(provinces: detail.provinces),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: detail.climate.source.startsWith('mock')
                            ? Colors.orange.withValues(alpha: 0.10)
                            : Colors.green.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: detail.climate.source.startsWith('mock')
                              ? Colors.orange.withValues(alpha: 0.30)
                              : Colors.green.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            detail.climate.source.startsWith('mock')
                                ? Icons.construction_rounded
                                : Icons.cloud_done_rounded,
                            size: 12,
                            color: detail.climate.source.startsWith('mock')
                                ? Colors.orange
                                : Colors.green,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'İklim verisi kaynağı: ${detail.climate.source}',
                            style: TextStyle(
                              color: detail.climate.source.startsWith('mock')
                                  ? Colors.orange
                                  : Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1, color: Colors.white12),
            // SAĞ — Detail (mini harita + climate)
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bölge Haritası',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Builder(builder: (mctx) {
                      final markers = detail.provinces
                          .where((p) => p.lat != null && p.lon != null)
                          .map((p) => ReportMapMarker(
                                lat: p.lat!,
                                lon: p.lon!,
                                label: p.provinceName,
                                score: p.bestScore,
                              ))
                          .toList();
                      return ReportMiniMap(
                        height: 340,
                        markers: markers,
                        bounds: _boundsFromMarkers(markers),
                        // N4: %20 dinamik padding + bölgenin ilçeleri çizilir
                        // + küçük marker (sadece il merkez noktası).
                        boundsPaddingRatio: 0.20,
                        districtRegionFilter: r.name,
                        markerSize: ReportMarkerSize.compact,
                        onMarkerTap: (m) {
                          mctx
                              .read<ReportNavController>()
                              .requestProvince(m.label);
                          DefaultTabController.of(mctx).animateTo(2);
                        },
                      );
                    }),
                    const SizedBox(height: 16),
                    Text(
                      'Aylık Meteorolojik Göstergeler',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 2.0,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      children: [
                        WeatherStripCard(
                          label: 'Güneş Işınımı',
                          unit: 'kWh/m²·gün',
                          data: detail.climate.irradiance,
                          color: const Color(0xFFF59E0B),
                        ),
                        WeatherStripCard(
                          label: 'Rüzgar Hızı',
                          unit: 'm/s @100m',
                          data: detail.climate.windSpeed,
                          color: const Color(0xFF3B82F6),
                        ),
                        WeatherStripCard(
                          label: 'Yağış',
                          unit: 'mm/ay',
                          data: detail.climate.precipitation,
                          color: const Color(0xFF06B6D4),
                        ),
                        WeatherStripCard(
                          label: 'Sıcaklık',
                          unit: '°C',
                          data: detail.climate.temperature,
                          color: const Color(0xFFEF4444),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: WindRoseCard(rose: detail.climate.windRose)),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: RiverDischargeCard(
                              discharge: detail.climate.riverDischarge,
                              color: const Color(0xFF06B6D4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (isLoading) _loadingChip(),
      ],
    );
  }

  Widget _loadingChip() => Positioned(
        top: 4,
        right: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.cyanAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.cyanAccent,
                ),
              ),
              SizedBox(width: 6),
              Text('Yükleniyor',
                  style: TextStyle(color: Colors.cyanAccent, fontSize: 10)),
            ],
          ),
        ),
      );

  Widget _buildNarrowLayout(RegionMeta r, Color color) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RegionHeader(region: r, climate: detail.climate, color: color),
              const SizedBox(height: 16),

              // 4 WeatherStrip
              Text(
                'Aylık Meteorolojik Göstergeler',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(builder: (ctx, c) {
                final cross = c.maxWidth >= 760 ? 4 : (c.maxWidth >= 500 ? 2 : 1);
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
                      data: detail.climate.irradiance,
                      color: const Color(0xFFF59E0B),
                    ),
                    WeatherStripCard(
                      label: 'Rüzgar Hızı',
                      unit: 'm/s @100m',
                      data: detail.climate.windSpeed,
                      color: const Color(0xFF3B82F6),
                    ),
                    WeatherStripCard(
                      label: 'Yağış',
                      unit: 'mm/ay',
                      data: detail.climate.precipitation,
                      color: const Color(0xFF06B6D4),
                    ),
                    WeatherStripCard(
                      label: 'Sıcaklık',
                      unit: '°C',
                      data: detail.climate.temperature,
                      color: const Color(0xFFEF4444),
                    ),
                  ],
                );
              }),

              const SizedBox(height: 18),

              // Wind rose + region info
              LayoutBuilder(builder: (ctx, c) {
                final wide = c.maxWidth >= 700;
                final rose = WindRoseCard(rose: detail.climate.windRose);
                final discharge = RiverDischargeCard(
                  discharge: detail.climate.riverDischarge,
                  color: const Color(0xFF06B6D4),
                );
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

              const SizedBox(height: 18),

              // Provinces grid
              Text(
                'Bölgenin İlleri (${detail.provinces.length})',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              // Bölge haritası — iller en iyi kaynak skoruna göre renkli marker.
              // F4: Bölge sınırına hapsedilmiş + il'e tıklayınca drill-down.
              Builder(builder: (mctx) {
                final markers = detail.provinces
                    .where((p) => p.lat != null && p.lon != null)
                    .map((p) => ReportMapMarker(
                          lat: p.lat!,
                          lon: p.lon!,
                          label: p.provinceName,
                          score: p.bestScore,
                        ))
                    .toList();
                return ReportMiniMap(
                  height: 300,
                  markers: markers,
                  bounds: _boundsFromMarkers(markers),
                  // N4 (narrow layout — mobile)
                  boundsPaddingRatio: 0.20,
                  districtRegionFilter: r.name,
                  markerSize: ReportMarkerSize.compact,
                  onMarkerTap: (m) {
                    mctx
                        .read<ReportNavController>()
                        .requestProvince(m.label);
                    DefaultTabController.of(mctx).animateTo(2);
                  },
                );
              }),
              const SizedBox(height: 12),
              _ProvinceGrid(provinces: detail.provinces),

              const SizedBox(height: 18),

              // Source indicator (mock vs db)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: detail.climate.source.startsWith('mock')
                      ? Colors.orange.withValues(alpha: 0.10)
                      : Colors.green.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: detail.climate.source.startsWith('mock')
                        ? Colors.orange.withValues(alpha: 0.30)
                        : Colors.green.withValues(alpha: 0.30),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      detail.climate.source.startsWith('mock')
                          ? Icons.construction_rounded
                          : Icons.cloud_done_rounded,
                      size: 12,
                      color: detail.climate.source.startsWith('mock')
                          ? Colors.orange
                          : Colors.green,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'İklim verisi kaynağı: ${detail.climate.source}',
                      style: TextStyle(
                        color: detail.climate.source.startsWith('mock')
                            ? Colors.orange
                            : Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (isLoading)
          Positioned(
            top: 4,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.cyanAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Colors.cyanAccent,
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Yükleniyor',
                    style: TextStyle(color: Colors.cyanAccent, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REGION HEADER (ad + lider + climate notu + KPI özet)
// ─────────────────────────────────────────────────────────────────────────────

class _RegionHeader extends StatelessWidget {
  final RegionMeta region;
  final ClimateSeries climate;
  final Color color;

  const _RegionHeader({
    required this.region,
    required this.climate,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final yearlyPrecip = climate.precipitation.fold<double>(0, (s, v) => s + v);
    final yearlyIrr = climate.irradiance.isEmpty
        ? 0
        : climate.irradiance.reduce((a, b) => a + b) / climate.irradiance.length;
    final yearlyWind = climate.windSpeed.isEmpty
        ? 0
        : climate.windSpeed.reduce((a, b) => a + b) / climate.windSpeed.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.10), Colors.transparent],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: color.withValues(alpha: 0.40)),
                ),
                child: Center(
                  child: Text(
                    region.name[0],
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      region.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      region.climateNote,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _ResourceBadge(type: region.topResource, large: true),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            region.description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.10), height: 1),
          const SizedBox(height: 10),
          // 2026-05-25 (F2): 6 KPI tek Row'da dar ekranda 60dp/KPI'ya düşüp
          // okunamaz oluyordu — geniş ekran tek satır, dar (<560) ekran 3×2
          // grid yap.
          LayoutBuilder(builder: (lctx, c) {
            final kpis = <Widget>[
              _HeaderKpi(
                label: 'İl Sayısı',
                value: '${region.provincesCount}',
                color: color,
              ),
              _HeaderKpi(
                label: 'Kapasite',
                value: '${(region.capacityMw / 1000).toStringAsFixed(1)} GW',
                color: color,
              ),
              _HeaderKpi(
                label: 'Üretim',
                value: '${(region.annualGwh / 1000).toStringAsFixed(1)} TWh',
                color: Colors.cyanAccent,
              ),
              _HeaderKpi(
                label: 'Yıllık Yağış',
                value: '${yearlyPrecip.toStringAsFixed(0)} mm',
                color: const Color(0xFF06B6D4),
              ),
              _HeaderKpi(
                label: 'Ort. Işınım',
                value: '${yearlyIrr.toStringAsFixed(1)} kWh',
                color: const Color(0xFFF59E0B),
              ),
              _HeaderKpi(
                label: 'Ort. Rüzgar',
                value: '${yearlyWind.toStringAsFixed(1)} m/s',
                color: const Color(0xFF3B82F6),
              ),
            ];
            if (c.maxWidth >= 560) {
              return Row(children: kpis);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: kpis.sublist(0, 3)),
                const SizedBox(height: 10),
                Row(children: kpis.sublist(3, 6)),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _HeaderKpi extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _HeaderKpi({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.40),
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceBadge extends StatelessWidget {
  final String type;
  final bool large;
  const _ResourceBadge({required this.type, this.large = false});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (type) {
      'solar' => ('Güneş', const Color(0xFFF59E0B), Icons.wb_sunny_rounded),
      'wind' => ('Rüzgar', const Color(0xFF3B82F6), Icons.air_rounded),
      'hydro' => ('Hidro', const Color(0xFF06B6D4), Icons.water_drop_rounded),
      _ => ('?', Colors.white54, Icons.help_outline),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 9 : 6,
        vertical: large ? 4 : 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: large ? 12 : 9),
          const SizedBox(width: 4),
          Text(
            'Lider · $label',
            style: TextStyle(
              color: color,
              fontSize: large ? 11 : 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVINCE GRID
// ─────────────────────────────────────────────────────────────────────────────

class _ProvinceGrid extends StatelessWidget {
  final List<RegionProvinceItem> provinces;
  const _ProvinceGrid({required this.provinces});

  @override
  Widget build(BuildContext context) {
    // Score'a göre azalan sırala
    final sorted = [...provinces]
      ..sort((a, b) => b.bestScore.compareTo(a.bestScore));
    return LayoutBuilder(
      builder: (ctx, c) {
        final cross = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 600 ? 3 : 2);
        return GridView.count(
          crossAxisCount: cross,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.6,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: sorted.map((p) => _ProvinceCard(province: p)).toList(),
        );
      },
    );
  }
}

class _ProvinceCard extends StatelessWidget {
  final RegionProvinceItem province;
  const _ProvinceCard({required this.province});

  @override
  Widget build(BuildContext context) {
    final best = province.bestResource;
    final color = switch (best) {
      'solar' => const Color(0xFFF59E0B),
      'wind' => const Color(0xFF3B82F6),
      'hydro' => const Color(0xFF06B6D4),
      _ => Colors.white54,
    };
    return GestureDetector(
      onTap: () {
        // İl Analizi tab'ına geç + bu ili seç
        context.read<ReportNavController>().requestProvince(province.provinceName);
        DefaultTabController.of(context).animateTo(2);
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    province.provinceName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MiniScore(
                  label: 'G', value: province.solarScore, color: const Color(0xFFF59E0B)),
              _MiniScore(
                  label: 'R', value: province.windScore, color: const Color(0xFF3B82F6)),
              _MiniScore(
                  label: 'H', value: province.hydroScore, color: const Color(0xFF06B6D4)),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

class _MiniScore extends StatelessWidget {
  final String label;
  final double? value;
  final Color color;
  const _MiniScore({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final disabled = value == null || value! < 0.1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: disabled ? 0.20 : 0.55),
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          disabled ? '—' : value!.toStringAsFixed(0),
          style: TextStyle(
            color: disabled ? Colors.white24 : color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

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
            style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
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
