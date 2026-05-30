// lib/features/reports/pages/district_detail_page.dart
//
// 2026-05-25 (G8): İlçe drill-down detay sayfası — `İl Analizi` tablosundan
// bir ilçe satırına tıklayınca açılır. Ana sistemdeki "İlçe modu" pattern'i:
// haritada ilçe lokasyonuna fly + bbox-bound (kullanıcı dışına çıkamaz).
//
// İçerik:
//   • Header: ilçe adı + il adı + best resource rozeti + skor
//   • Mini harita: ilçe merkezinde fly + bound (ReportMiniMap zaten G2 tap-
//     to-activate destekliyor)
//   • 3 kaynak skor satırı (büyük bar)
//   • İl'in iklim verisi (district-spesifik climate yok, il bazlı climate
//     fallback'i kullanılır — ilerde district-spesifik climate gelirse buraya)
//
// Back tuşu otomatik çalışır (Navigator.push).

import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart' as ml;

import 'package:frontend/core/network/analysis_service.dart';
import 'package:frontend/features/reports/widgets/common/report_mini_map.dart';
import 'package:frontend/features/reports/widgets/common/report_ui.dart';
import 'package:frontend/shared/widgets/app_background.dart';

class DistrictDetailPage extends StatelessWidget {
  final DistrictScore district;
  final String provinceName;

  const DistrictDetailPage({
    super.key,
    required this.district,
    required this.provinceName,
  });

  Color _resColor(String r) => switch (r) {
        'solar' => const Color(0xFFF59E0B),
        'wind' => const Color(0xFF3B82F6),
        'hydro' => const Color(0xFF06B6D4),
        _ => Colors.white54,
      };

  String _resLabel(String r) => switch (r) {
        'solar' => 'Güneş',
        'wind' => 'Rüzgar',
        'hydro' => 'Hidro',
        _ => '?',
      };

  IconData _resIcon(String r) => switch (r) {
        'solar' => Icons.wb_sunny_rounded,
        'wind' => Icons.air_rounded,
        'hydro' => Icons.water_drop_rounded,
        _ => Icons.help_outline,
      };

  @override
  Widget build(BuildContext context) {
    final bestColor = _resColor(district.bestResource);
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                district: district,
                provinceName: provinceName,
                accent: bestColor,
              ),
              const Divider(color: Colors.white12, height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero — best resource + score
                      ReportCard(
                        accentBorder: bestColor,
                        gradient: true,
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: bestColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: bestColor.withValues(alpha: 0.40),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                _resIcon(district.bestResource),
                                color: bestColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'En İyi Kaynak',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.50),
                                      fontSize: 10,
                                      letterSpacing: 0.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _resLabel(district.bestResource),
                                    style: TextStyle(
                                      color: bestColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'SKOR',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.50),
                                    fontSize: 10,
                                    letterSpacing: 0.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      district.bestScore.toStringAsFixed(0),
                                      style: TextStyle(
                                        color: bestColor,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures()
                                        ],
                                      ),
                                    ),
                                    Text(
                                      ' /100',
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.45),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 3 kaynak skor breakdown
                      ReportCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ReportSectionHeader(
                              title: 'Kaynak Skor Kırılımı',
                            ),
                            const SizedBox(height: 12),
                            _bigScoreBar('Güneş', district.solarScore,
                                const Color(0xFFF59E0B)),
                            const SizedBox(height: 10),
                            _bigScoreBar('Rüzgar', district.windScore,
                                const Color(0xFF3B82F6)),
                            const SizedBox(height: 10),
                            _bigScoreBar('Hidro', district.hydroScore,
                                const Color(0xFF06B6D4)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Mini harita — ilçe merkezi + 0.2° bound (yaklaşık
                      // ilçe sınırı; gerçek geojson olmadan tahmin)
                      ReportCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ReportSectionHeader(
                              title: 'Konum',
                              subtitle:
                                  'Haritayla etkileşim için dokun, bitirmek için sağ üstteki butona bas.',
                            ),
                            const SizedBox(height: 8),
                            ReportMiniMap(
                              height: 260,
                              markers: [
                                ReportMapMarker(
                                  lat: district.lat,
                                  lon: district.lon,
                                  label: district.name,
                                  score: district.bestScore,
                                  highlighted: true,
                                ),
                              ],
                              bounds: ml.LngLatBounds(
                                longitudeWest: district.lon - 0.2,
                                latitudeSouth: district.lat - 0.2,
                                longitudeEast: district.lon + 0.2,
                                latitudeNorth: district.lat + 0.2,
                              ),
                              // N4: %20 dynamic padding + ilin tüm ilçeleri
                              // (drill-down ilçe sayfasında il sınırları
                              // görünür kalır, kullanıcı çevre ilçelere
                              // bakabilir).
                              boundsPaddingRatio: 0.30,
                              districtProvinceFilter: provinceName,
                              markerSize: ReportMarkerSize.compact,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Tahmini Kurulu Güç
                      ReportCard(
                        child: Row(
                          children: [
                            Icon(Icons.bolt_rounded,
                                size: 16, color: Colors.greenAccent),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Tahmini Kurulu Güç Potansiyeli',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${district.estimatedMw} MW',
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Not: Bu ilçeye ait gözlenen iklim verisi henüz toplanmadı; '
                        'değerler il bazlı climatology + ilçe coğrafi konum ile '
                        'türetilmiştir.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.40),
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bigScoreBar(String label, double score, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 8,
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (score / 100).clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 38,
          child: Text(
            score.toStringAsFixed(0),
            textAlign: TextAlign.right,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final DistrictScore district;
  final String provinceName;
  final Color accent;
  const _Header({
    required this.district,
    required this.provinceName,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: Colors.white70,
            ),
            tooltip: 'Geri',
            onPressed: () => Navigator.of(context).pop(),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 4),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.location_on_rounded, size: 16, color: accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  district.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  provinceName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
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
