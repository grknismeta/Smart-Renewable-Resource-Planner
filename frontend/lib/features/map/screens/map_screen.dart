import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre/maplibre.dart' as ml;

import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'package:frontend/features/map/models/map_models.dart' show ChoroplethModeExt;
import 'package:frontend/core/theme/theme_view_model.dart';
import 'package:frontend/features/scenarios/viewmodels/scenario_viewmodel.dart';

import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/features/map/widgets/map_view_maplibre.dart';
import 'package:frontend/features/map/widgets/panels/map_overlays.dart';
import 'package:frontend/features/map/widgets/panels/recommendations/recommendations_side_panel.dart';
import 'package:frontend/features/map/widgets/panels/province_info_card.dart';
import 'package:frontend/features/map/widgets/panels/map_bottom_sheet.dart';
import 'package:frontend/features/map/widgets/map_widgets.dart';
import 'package:frontend/features/scenarios/widgets/scenario_side_panel.dart';
import 'package:frontend/features/reports/report_screen.dart';
import 'package:frontend/features/scenarios/widgets/scenario_mini_report_panel.dart';
import 'package:frontend/features/map/widgets/panels/time_slider_panel.dart';
import 'package:frontend/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:frontend/features/map/widgets/wind_particle_overlay.dart';


class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _showLayersPanel = false;
  bool _showScenariosPanel = false;

  // Pin ekleme koruması: aynı anda birden fazla dialog açılmasını önler
  bool _isProcessingGeoCheck = false;

  // Pin modu debounce: "Pin Ekle" butonuna basınca harita click event'i
  // de tetikleniyor. 600ms içinde gelen map tap'i ignore et.
  DateTime? _pinModeActivatedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<MapViewModel>(context, listen: false).loadWeatherForTime(
        DateTime.now().subtract(const Duration(hours: 1)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeViewModel>(context);
    final authVM = Provider.of<AuthViewModel>(context);
    final isAuthenticated = authVM.isLoggedIn == true;
    return Consumer2<MapViewModel, ScenarioViewModel>(
      builder: (context, mapViewModel, scenarioVM, child) {
        // Tema değişiminde harita stilini otomatik senkronize et
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) mapViewModel.syncBaseStyleWithTheme(theme.isDarkMode);
        });
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // 1. MapLibre harita motoru
              MapViewMapLibre(
                onMapTap: (ml.Position p) => _handleMapTap(
                  mapViewModel,
                  LatLng(p.lat.toDouble(), p.lng.toDouble()),
                ),
                onPinTap: (Pin pin) => _showPinDialog(pin),
              ),

              // Rüzgar parçacık animasyonu — sadece native'de (web JS canvas kullanır)
              if (!kIsWeb && mapViewModel.showWindParticles)
                Positioned.fill(
                  child: WindParticleOverlay(
                    vectors: mapViewModel.windVectors,
                    active: mapViewModel.showWindParticles,
                  ),
                ),

              // Aşağıdaki tüm kontroller sadece giriş yapıldığında gösterilir
              if (isAuthenticated) ...[

              // 2. Overlay'ler (Dashboard, Açıklama, Lejandlar)
              // Dashboard — sol üst köşe
              Builder(builder: (ctx) {
                final isMobile = MediaQuery.of(ctx).size.width < 600;
                final pad = isMobile ? 10.0 : 20.0;
                final scale = isMobile ? 0.85 : 1.0;
                final dashboardBottom = isMobile ? 88.0 : 120.0; // tooltip top

                return Stack(
                  children: [
                    if (!mapViewModel.showGlobe)
                      Positioned(
                        top: pad,
                        left: pad,
                        child: PointerInterceptor(
                          child: Transform.scale(
                            scale: scale,
                            alignment: Alignment.topLeft,
                            child: MapDashboard(theme: theme),
                          ),
                        ),
                      ),
                    if (mapViewModel.showGlobe)
                      Positioned(
                        top: pad,
                        left: pad,
                        child: PointerInterceptor(
                          child: Transform.scale(
                            scale: scale,
                            alignment: Alignment.topLeft,
                            child: GlobeInfoCard(theme: theme),
                          ),
                        ),
                      ),
                    // Choropleth ilçe tooltip — dashboard'un altında
                    if (mapViewModel.choroplethTapDistrict != null)
                      Positioned(
                        top: dashboardBottom,
                        left: pad,
                        child: PointerInterceptor(
                          child: Transform.scale(
                            scale: scale,
                            alignment: Alignment.topLeft,
                            child: _ChoroplethTooltip(
                              districtLabel: mapViewModel.choroplethTapDistrict!,
                              data: mapViewModel.choroplethTapData,
                              mode: mapViewModel.choroplethMode,
                              matchColor: mapViewModel.choroplethTapColor,
                              theme: theme,
                              onClose: () => mapViewModel.clearChoroplethTap(),
                              dataTimestamp: mapViewModel.choroplethDataTimestamp,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              }),
              // Layers Panel — sağ üst (butonların altında)
              if (_showLayersPanel)
                Positioned(
                  top: 90,
                  right: 20,
                  child: PointerInterceptor(
                    child: LayersPanel(
                      theme: theme,
                      mapViewModel: mapViewModel,
                      onClearMapSelection: () =>
                          MapViewMapLibre.clearSelectionMode(),
                    ),
                  ),
                ),
              // Choropleth & Heatmap legends
              ..._buildLegends(mapViewModel, theme),

              // 3. Kayan Kontroller (Butonlar)
              // Add Pin — sağ üst
              Positioned(
                top: 20,
                right: 20,
                child: PointerInterceptor(
                  child: Column(
                    children: [
                      MapControlButton(
                        icon: Icons.add_location_alt_outlined,
                        tooltip: "Kaynak Ekle",
                        onTap: () {
                          mapViewModel.startPlacingMarker('Güneş Paneli');
                          _pinModeActivatedAt = DateTime.now();
                        },
                        color: Colors.blueAccent,
                        theme: theme,
                      ),
                      const SizedBox(height: 16),
                      MapControlButton(
                        icon: Icons.layers_outlined,
                        tooltip: "Katmanlar",
                        onTap: () =>
                            setState(() => _showLayersPanel = !_showLayersPanel),
                        color: _showLayersPanel ? Colors.greenAccent : theme.textColor,
                        theme: theme,
                      ),
                    ],
                  ),
                ),
              ),
              // Zoom butonları — sol alt
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                bottom: mapViewModel.choroplethMode != ChoroplethMode.none ? 155 : 40,
                left: 20,
                child: PointerInterceptor(
                  child: Column(
                    children: [
                      _buildZoomButton(Icons.add, MapViewMapLibre.zoomIn, theme),
                      const SizedBox(height: 8),
                      _buildZoomButton(Icons.remove, MapViewMapLibre.zoomOut, theme),
                    ],
                  ),
                ),
              ),

              // 5. Eylem Göstergeleri (pin yerleştirme, bölge seçimi)
              if (mapViewModel.placingPinType != null)
                Positioned(
                  bottom: MediaQuery.of(context).size.height * 0.22,
                  left: 0,
                  right: mapViewModel.isRecommendationsPanelOpen ? 380 : 0,
                  child: PointerInterceptor(
                    child: PlacementIndicator(
                      placingPinType: mapViewModel.placingPinType,
                      onCancel: mapViewModel.stopPlacingMarker,
                    ),
                  ),
                ),

              if (mapViewModel.isSelectingRegion)
                Positioned(
                  bottom: mapViewModel.placingPinType != null
                      ? MediaQuery.of(context).size.height * 0.22 + 100
                      : MediaQuery.of(context).size.height * 0.22,
                  left: 0,
                  right: mapViewModel.isRecommendationsPanelOpen ? 380 : 0,
                  child: PointerInterceptor(
                    child: RegionSelectionIndicator(
                      points: mapViewModel.selectionPoints,
                      onCancel: mapViewModel.clearRegionSelection,
                    ),
                  ),
                ),

              // 6. Öneri Paneli (sağdan kayar)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCubic,
                top: 0,
                bottom: 0,
                right: mapViewModel.isRecommendationsPanelOpen ? 0 : -380,
                width: 380,
                child: PointerInterceptor(
                  child: RecommendationsSidePanel(
                    theme: theme,
                    mapViewModel: mapViewModel,
                    onCityNavigate: (lat, lon) =>
                        MapViewMapLibre.flyTo(lat, lon, zoom: 10.0),
                  ),
                ),
              ),

              // 6b. Zaman Simülasyonu Paneli
              if (mapViewModel.isAnimationMode)
                Positioned(
                  bottom: 12,
                  left: 20,
                  right: mapViewModel.isRecommendationsPanelOpen ? 400 : 20,
                  child: PointerInterceptor(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: TimeSliderPanel(
                        theme: theme,
                        mapViewModel: mapViewModel,
                      ),
                    ),
                  ),
                ),

              // 6c. Coğrafi Seçim Bilgi Kartı
              if (mapViewModel.isProvinceModeActive &&
                  (mapViewModel.selectedRegionName != null ||
                      mapViewModel.selectedProvinceName != null ||
                      mapViewModel.selectedDistrictName != null))
                Positioned(
                  // Zaman simülasyonu açıksa panel (~220px) üstüne çıkar
                  bottom: mapViewModel.isAnimationMode ? 260 : 100,
                  left: 20,
                  child: PointerInterceptor(child: ProvinceInfoCard(
                    provinceName: mapViewModel.selectedProvinceName ?? '',
                    summary: mapViewModel.selectedProvinceSummary,
                    districtSummary: mapViewModel.selectedDistrictSummary,
                    isLoadingDistrictSummaries: mapViewModel.isLoadingDistrictSummaries,
                    allPins: mapViewModel.pins,
                    theme: theme,
                    selectionLevel: mapViewModel.selectionLevel,
                    regionName: mapViewModel.selectedRegionName,
                    districtName: mapViewModel.selectedDistrictName,
                    onClose: () => mapViewModel.clearAllSelection(),
                    onBack: (mapViewModel.selectedRegionName != null ||
                            mapViewModel.selectedProvinceName != null ||
                            mapViewModel.selectedDistrictName != null)
                        ? () {
                            if (mapViewModel.selectedDistrictName != null) {
                              mapViewModel.clearSelectedDistrict();
                            } else if (mapViewModel.selectedProvinceName !=
                                null) {
                              mapViewModel.clearSelectedProvince();
                            } else {
                              mapViewModel.clearRegionFilter();
                            }
                          }
                        : null,
                    onViewReport: mapViewModel.selectedProvinceName != null
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReportScreen(
                                  initialProvince:
                                      mapViewModel.selectedProvinceName,
                                ),
                              ),
                            )
                        : null,
                  )),
                ),

              // 7. Senaryo Paneli (soldan kayar)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCubic,
                top: 0,
                bottom: 0,
                left: _showScenariosPanel ? 0 : -330,
                width: 320,
                child: PointerInterceptor(
                  child: ScenarioSidePanel(
                    theme: theme,
                    onClose: () =>
                        setState(() => _showScenariosPanel = false),
                  ),
                ),
              ),

              // 8. Senaryo Mini Rapor Paneli
              if (scenarioVM.hasSelection)
                Positioned(
                  bottom: 180,
                  right: 20,
                  child: PointerInterceptor(
                    child: ScenarioMiniReportPanel(
                      theme: theme,
                      scenarioVM: scenarioVM,
                    ),
                  ),
                ),

              // 9. Alt Sheet — en sonda: diğer tüm widget'ların üstünde
              MapBottomSheet(
                onScenariosTap: () =>
                    setState(() => _showScenariosPanel = !_showScenariosPanel),
              ),

              ], // if (isAuthenticated) sonu
            ],
          ),
        );
      },
    );
  }

  void _handleMapTap(MapViewModel viewModel, LatLng point) {
    if (viewModel.isSelectingRegion) {
      viewModel.recordSelectionPoint(point);
      return;
    }

    if (viewModel.placingPinType != null) {
      if (_pinModeActivatedAt != null &&
          DateTime.now().difference(_pinModeActivatedAt!) <
              const Duration(milliseconds: 600)) {
        return;
      }
      _checkGeoSuitability(viewModel, point);
    }
  }

  /// Pin dialog'unu açar — açılmadan önce click guard aktifleştirilir,
  /// dialog kapanınca devre dışı bırakılır.
  void _showPinDialog(Pin pin) {
    MapViewMapLibre.setClickGuard(true);
    MapDialogs.showPinActionsDialog(context, pin);
    // Click guard dialog kapanınca sıfırlanmalı — dialog kendi yaşam döngüsünde yönetir
    Future.delayed(const Duration(milliseconds: 300), () {
      MapViewMapLibre.setClickGuard(false);
    });
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onTap, ThemeViewModel theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        border: Border.all(color: theme.secondaryTextColor.withValues(alpha: 0.1)),
      ),
      child: IconButton(
        icon: Icon(icon, color: theme.textColor),
        onPressed: onTap,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }

  List<Widget> _buildLegends(MapViewModel vm, ThemeViewModel theme) {
    final legends = <Widget>[];
    // Zaman simülasyonu açıksa legend'lar panelin üstüne çıksın
    final legendBottom = vm.isAnimationMode ? 240.0 : 40.0;

    // Heatmap legends (sağ alt)
    Widget? heatLegend;
    if (vm.currentLayer == MapLayerType.irradiance) {
      heatLegend = LegendWidget(
        theme: theme, title: 'Işınım Yoğunluğu', titleFontSize: 11,
        unit: 'kWh/m²/yıl',
        gradientColors: [Colors.black.withValues(alpha: 0.5), Colors.deepOrangeAccent, Colors.redAccent.shade700, Colors.orangeAccent, Colors.white],
        minLabel: '0', maxLabel: '2200',
        tickLabels: const ['0', '550', '1100', '1650', '2200'],
      );
    } else if (vm.currentLayer == MapLayerType.wind) {
      heatLegend = LegendWidget(
        theme: theme, title: 'Rüzgar Hızı', unit: 'm/s',
        gradientColors: [Colors.black.withValues(alpha: 0.5), Colors.blueAccent.shade700, Colors.cyanAccent, Colors.white],
        minLabel: '0', maxLabel: '15+',
        tickLabels: const ['0', '3', '6', '9', '12', '15+'],
      );
    } else if (vm.currentLayer == MapLayerType.temp) {
      heatLegend = LegendWidget(
        theme: theme, title: 'Sıcaklık', unit: '°C',
        gradientColors: [Colors.indigo, Colors.cyan, Colors.yellow, Colors.red.shade900],
        minLabel: '-10', maxLabel: '40+',
        tickLabels: const ['-10', '5', '20', '35', '40+'],
      );
    }
    if (heatLegend != null) {
      legends.add(Positioned(bottom: legendBottom, right: 20, child: PointerInterceptor(child: heatLegend)));
    }

    // Choropleth legends (sol alt)
    Widget? choroLegend;
    if (vm.choroplethMode == ChoroplethMode.solar) {
      // Palet: 0 W/m² (gece/lacivert) → 50 (soluk sarı) → 800 (bordo).
      // Sıralama index.html _choroplethBuildStops('solar') ve
      // map_view_maplibre_native.dart solar stop listesiyle BİREBİR aynı olmalı.
      choroLegend = LegendWidget(
        theme: theme, title: 'Güneş Işınımı (İlçe)', titleFontSize: 10, unit: 'W/m²', width: 210,
        gradientColors: const [
          Color(0xFF1A1A2E), // 0 — gece / lacivert
          Color(0xFFFFFFCC), // 50 — soluk sarı
          Color(0xFFFFEDA0), // 150
          Color(0xFFFED976), // 250
          Color(0xFFFEB24C), // 350
          Color(0xFFFD8D3C), // 450
          Color(0xFFFC4E2A), // 550
          Color(0xFFE31A1C), // 650
          Color(0xFFBD0026), // 750
          Color(0xFF4D0014), // 800 — maksimum / bordo
        ],
        minLabel: '0', maxLabel: '800',
        tickLabels: const ['0', '200', '400', '600', '800'],
      );
    } else if (vm.choroplethMode == ChoroplethMode.wind) {
      choroLegend = LegendWidget(
        theme: theme, title: 'Rüzgar Hızı (İlçe)', titleFontSize: 10, unit: 'm/s', width: 190,
        gradientColors: const [Color(0xFFF7FBFF), Color(0xFFDEEBF7), Color(0xFFC6DBEF), Color(0xFF9ECAE1), Color(0xFF6BAED6), Color(0xFF4292C6), Color(0xFF2171B5), Color(0xFF08519C), Color(0xFF083D7F), Color(0xFF08306B)],
        minLabel: '0', maxLabel: '12',
        tickLabels: const ['0', '2', '4', '6', '8', '10', '12'],
      );
    } else if (vm.choroplethMode == ChoroplethMode.temperature) {
      choroLegend = LegendWidget(
        theme: theme, title: 'Sıcaklık (İlçe)', titleFontSize: 10, unit: '°C', width: 210,
        gradientColors: const [Color(0xFF08306B), Color(0xFF2171B5), Color(0xFF6BAED6), Color(0xFFC6DBEF), Color(0xFFD9F0A3), Color(0xFF78C679), Color(0xFF31A354), Color(0xFF006837), Color(0xFF31A354), Color(0xFFFED976), Color(0xFFFEB24C), Color(0xFFFD8D3C), Color(0xFFE31A1C), Color(0xFFBD0026), Color(0xFF800026)],
        minLabel: '-15', maxLabel: '45',
        tickLabels: const ['-15', '0', '10', '20', '30', '40', '45'],
      );
    }
    if (choroLegend != null) {
      legends.add(Positioned(bottom: legendBottom, left: 12, child: PointerInterceptor(child: choroLegend)));
    }

    return legends;
  }

  /// Türkiye sınırları içinde mi? (lat 35-43, lon 25-46)
  static bool _isInTurkey(LatLng p) =>
      p.latitude >= 35 && p.latitude <= 43 && p.longitude >= 25 && p.longitude <= 46;

  Future<void> _checkGeoSuitability(
      MapViewModel viewModel, LatLng point) async {
    if (_isProcessingGeoCheck) return;
    _isProcessingGeoCheck = true;

    // Dialog açılınca click guard aktifleştir
    MapViewMapLibre.setClickGuard(true);

    final theme = Provider.of<ThemeViewModel>(context, listen: false);
    final isGlobe = viewModel.showGlobe;
    final outsideTurkey = !_isInTurkey(point);

    // Globe modunda ve Türkiye dışındaysa → geo check atla, direkt dialog aç
    if (isGlobe && outsideTurkey) {
      try {
        await showDialog(
          context: context,
          builder: (ctx) => AddPinDialog(
            point: point,
            initialPinType: viewModel.placingPinType ?? 'Güneş Paneli',
          ),
        );
        viewModel.stopPlacingMarker();
      } finally {
        _isProcessingGeoCheck = false;
        MapViewMapLibre.setClickGuard(false);
      }
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: theme.cardColor,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text('Analiz ediliyor...',
                  style: TextStyle(color: theme.textColor)),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await viewModel.geoCheck(point);
      if (!mounted) return;
      Navigator.pop(context);

      if (result != null) {
        await showDialog(
          context: context,
          builder: (ctx) => AddPinDialog(
            point: point,
            initialPinType: viewModel.placingPinType ?? 'Güneş Paneli',
          ),
        );
        viewModel.stopPlacingMarker();
      }
    } catch (e) {
      debugPrint('Geo Check Exception: $e');
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    } finally {
      _isProcessingGeoCheck = false;
      MapViewMapLibre.setClickGuard(false);
    }
  }
}



// ─── Choropleth İlçe Tooltip ──────────────────────────────────────────────

class _ChoroplethTooltip extends StatelessWidget {
  final String districtLabel;       // "İstanbul / Kadıköy"
  final Map<String, dynamic>? data; // {wind, solar, temp}
  final ChoroplethMode mode;
  final Color? matchColor;          // Haritadaki dolgu rengiyle eşleşen renk
  final ThemeViewModel theme;
  final VoidCallback onClose;
  final String? dataTimestamp;      // Verinin toplandığı zaman (ISO 8601)

  const _ChoroplethTooltip({
    required this.districtLabel,
    required this.data,
    required this.mode,
    this.matchColor,
    required this.theme,
    required this.onClose,
    this.dataTimestamp,
  });

  @override
  Widget build(BuildContext context) {
    final d = data;
    final dataKey = mode.dataKey;
    final value = d != null ? (d[dataKey] as num?)?.toDouble() : null;
    final unit = switch (mode) {
      ChoroplethMode.solar => 'W/m²',
      ChoroplethMode.wind => 'm/s',
      ChoroplethMode.temperature => '°C',
      ChoroplethMode.none => '',
    };

    final accent = matchColor ?? mode.color;

    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withValues(alpha: 0.8),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(mode.icon, size: 14, color: mode.color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  districtLabel,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onClose,
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: theme.secondaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (value != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 0.8),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${mode.displayName}: ${value.toStringAsFixed(1)} $unit',
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            )
          else
            Text(
              'Veri yok',
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          if (d != null) ...[
            const SizedBox(height: 4),
            _secondaryMetrics(d, dataKey),
          ],
          if (dataTimestamp != null) ...[
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(dataTimestamp!),
              style: TextStyle(
                color: theme.secondaryTextColor.withValues(alpha: 0.7),
                fontSize: 9,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimestamp(String isoTimestamp) {
    try {
      final dt = DateTime.parse(isoTimestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) {
        return '${diff.inMinutes} dk once guncellendi';
      } else if (diff.inHours < 24) {
        return '${diff.inHours} saat once guncellendi';
      }
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} verisi';
    } catch (_) {
      return isoTimestamp;
    }
  }

  Widget _secondaryMetrics(Map<String, dynamic> d, String dataKey) {
    final parts = <String>[];
    if (dataKey != 'solar') {
      final v = (d['solar'] as num?)?.toDouble();
      if (v != null) parts.add('${v.toStringAsFixed(0)} W/m²');
    }
    if (dataKey != 'wind') {
      final v = (d['wind'] as num?)?.toDouble();
      if (v != null) parts.add('${v.toStringAsFixed(1)} m/s');
    }
    if (dataKey != 'temp') {
      final v = (d['temp'] as num?)?.toDouble();
      if (v != null) parts.add('${v.toStringAsFixed(1)}°C');
    }
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join('  ·  '),
      style: TextStyle(
        color: theme.secondaryTextColor,
        fontSize: 10,
      ),
    );
  }
}
