import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../presentation/viewmodels/report_view_model.dart';
import '../../presentation/viewmodels/theme_view_model.dart';
import '../../presentation/viewmodels/scenario_view_model.dart';
import '../../presentation/viewmodels/map_view_model.dart';
import '../../data/models/system_data_models.dart';
import '../widgets/map/map_constants.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final MapController _mapController = MapController();
  String _region = 'Tümü';
  String _type = 'Wind';
  int? _selectedScenarioId; // Yeni: Seçili senaryo

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final rp = Provider.of<ReportViewModel>(context, listen: false);
      rp.fetchReport(region: _region, type: _type);
      // Senaryoları da yükle
      Provider.of<ScenarioViewModel>(context, listen: false).loadScenarios();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeViewModel = Provider.of<ThemeViewModel>(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0E1621), Color(0xFF111827), Color(0xFF0B1220)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildHeader(themeViewModel),
                const SizedBox(height: 16),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 1100;
                      return Row(
                        children: [
                          Expanded(
                            flex: isWide ? 2 : 1,
                            child: _buildGlass(
                              _selectedScenarioId == null
                                  ? _ReportMap(
                                      mapController: _mapController,
                                      type: _type,
                                      onSiteFocused: _onSiteFocused,
                                    )
                                  : _ScenarioMap(
                                      mapController: _mapController,
                                      scenarioId: _selectedScenarioId!,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: _buildGlass(
                              _selectedScenarioId == null
                                  ? _ReportListPanel(
                                      onSiteSelected: _onSiteFocused,
                                    )
                                  : _ScenarioListPanel(
                                      scenarioId: _selectedScenarioId!,
                                    ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeViewModel theme) {
    final scenarioViewModel = Provider.of<ScenarioViewModel>(context);
    final scenarios = scenarioViewModel.scenarios;

    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pushReplacementNamed('/map'),
          icon: const Icon(Icons.arrow_back),
          color: Colors.white,
        ),
        const SizedBox(width: 8),
        Text(
          'Bölgesel Potansiyel Raporu',
          style: TextStyle(
            color: theme.textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        // Yeni: Senaryo seçici
        if (scenarios.isNotEmpty) ...[
          _buildDropdown(
            value: _selectedScenarioId?.toString() ?? 'Bölgesel',
            items: ['Bölgesel', ...scenarios.map((s) => s.id.toString())],
            displayBuilder: (val) {
              if (val == 'Bölgesel') return 'Bölgesel Rapor';
              // Check if scenario exists
              try {
                final sc = scenarios.firstWhere((s) => s.id.toString() == val);
                return sc.name;
              } catch (e) {
                return 'Bilinmeyen Senaryo';
              }
            },
            onChanged: (val) {
              if (val == null) return;
              setState(() {
                if (val == 'Bölgesel') {
                  _selectedScenarioId = null;
                  // Bölgesel raporu yükle
                  Provider.of<ReportViewModel>(
                    context,
                    listen: false,
                  ).fetchReport(region: _region, type: _type);
                } else {
                  _selectedScenarioId = int.parse(val);
                  // Senaryo seçildi - rapor ekranı güncellenir
                }
              });
            },
          ),
          const SizedBox(width: 12),
        ],
        _buildDropdown(
          value: _region,
          items: const [
            'Tümü',
            'Marmara',
            'Ege',
            'Akdeniz',
            'İç Anadolu',
            'Karadeniz',
            'Doğu Anadolu',
            'Güneydoğu Anadolu',
          ],
          onChanged: (val) {
            if (val == null || _selectedScenarioId != null) return;
            setState(() => _region = val);
            Provider.of<ReportViewModel>(
              context,
              listen: false,
            ).fetchReport(region: val, type: _type);
          },
        ),
        const SizedBox(width: 12),
        _buildDropdown(
          value: _type,
          items: const ['Wind', 'Solar'],
          onChanged: (val) {
            if (val == null || _selectedScenarioId != null) return;
            setState(() => _type = val);
            Provider.of<ReportViewModel>(
              context,
              listen: false,
            ).fetchReport(region: _region, type: val);
          },
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String Function(String)? displayBuilder,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: DropdownButton<String>(
        value: value,
        dropdownColor: const Color(0xFF1C2533),
        underline: const SizedBox.shrink(),
        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
        style: const TextStyle(color: Colors.white),
        onChanged: onChanged,
        items: items
            .map(
              (e) => DropdownMenuItem<String>(
                value: e,
                child: Text(displayBuilder != null ? displayBuilder(e) : e),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildGlass(Widget child) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  void _onSiteFocused(RegionalSite site) {
    _mapController.move(LatLng(site.latitude, site.longitude), 8.0);
  }
}

class _ReportMap extends StatelessWidget {
  final MapController mapController;
  final String type;
  final ValueChanged<RegionalSite> onSiteFocused;

  const _ReportMap({
    required this.mapController,
    required this.type,
    required this.onSiteFocused,
  });

  Color _colorForRank(int index, int total) {
    if (total <= 1) return Colors.greenAccent;
    final t = index / (total - 1);
    return Color.lerp(Colors.greenAccent, Colors.redAccent, t) ??
        Colors.greenAccent;
  }

  @override
  Widget build(BuildContext context) {
    final reportViewModel = Provider.of<ReportViewModel>(context);
    final report = reportViewModel.report;

    final markers = <Marker>[];
    if (report != null) {
      for (var i = 0; i < report.items.length; i++) {
        final site = report.items[i];
        final color = _colorForRank(i, report.items.length);
        markers.add(
          Marker(
            point: LatLng(site.latitude, site.longitude),
            width: 28,
            height: 28,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () => onSiteFocused(site),
              child: Tooltip(
                message:
                    '${site.city}${site.district != null ? ' / ${site.district}' : ''}\nSkor: ${site.overallScore.toStringAsFixed(1)}',
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.8),
                    border: Border.all(color: Colors.white70, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Text(
                report != null
                    ? '${report.region} • ${report.type}'
                    : 'Yükleniyor...',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (reportViewModel.isBusy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: LatLngBounds(
                    const LatLng(
                      MapConstants.turkeyMinLat,
                      MapConstants.turkeyMinLon,
                    ),
                    const LatLng(
                      MapConstants.turkeyMaxLat,
                      MapConstants.turkeyMaxLon,
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                ),
                maxZoom: MapConstants.maxZoom,
                minZoom: 5.5,
                onPositionChanged: (pos, hasGesture) {
                  if (!hasGesture) return;
                  _constrainToTurkey(pos.center);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: MapConstants.getTileUrl('dark'),
                  tileProvider: CancellableNetworkTileProvider(),
                  userAgentPackageName: 'frontend',
                ),
                if (markers.isNotEmpty) MarkerLayer(markers: markers),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _constrainToTurkey(LatLng? center) {
    if (center == null) return;
    double lat = center.latitude;
    double lon = center.longitude;
    bool changed = false;
    if (lat < MapConstants.turkeyMinLat) {
      lat = MapConstants.turkeyMinLat;
      changed = true;
    } else if (lat > MapConstants.turkeyMaxLat) {
      lat = MapConstants.turkeyMaxLat;
      changed = true;
    }
    if (lon < MapConstants.turkeyMinLon) {
      lon = MapConstants.turkeyMinLon;
      changed = true;
    } else if (lon > MapConstants.turkeyMaxLon) {
      lon = MapConstants.turkeyMaxLon;
      changed = true;
    }
    if (changed) {
      mapController.move(LatLng(lat, lon), mapController.camera.zoom);
    }
  }
}

class _ReportListPanel extends StatelessWidget {
  final ValueChanged<RegionalSite> onSiteSelected;

  const _ReportListPanel({required this.onSiteSelected});

  @override
  Widget build(BuildContext context) {
    final reportViewModel = Provider.of<ReportViewModel>(context);
    final report = reportViewModel.report;

    if (reportViewModel.isBusy && report == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (report == null || report.items.isEmpty) {
      return const Center(
        child: Text(
          'Bu bölge için veri bulunamadı.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${report.region} Özet',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (report.stats != null)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatChip(
                      'Maks Skor',
                      report.stats!.maxScore.toStringAsFixed(1),
                    ),
                    _StatChip(
                      'Ortalama',
                      report.stats!.avgScore.toStringAsFixed(1),
                    ),
                    _StatChip(
                      'Min Skor',
                      report.stats!.minScore.toStringAsFixed(1),
                    ),
                    _StatChip('Alan', report.stats!.siteCount.toString()),
                  ],
                ),
            ],
          ),
        ),
        const Divider(color: Colors.white24, height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: report.items.length,
            itemBuilder: (context, index) {
              final site = report.items[index];
              final t = report.items.length > 1
                  ? index / (report.items.length - 1)
                  : 0.0;
              final color =
                  Color.lerp(Colors.greenAccent, Colors.redAccent, t) ??
                  Colors.greenAccent;

              return GestureDetector(
                onTap: () {
                  Provider.of<ReportViewModel>(
                    context,
                    listen: false,
                  ).setFocusedSite(site);
                  onSiteSelected(site);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: color.withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '#${index + 1}',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${site.city}${site.district != null ? ' / ${site.district}' : ''}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            'Skor ${site.overallScore.toStringAsFixed(1)}',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (site.annualSolarIrradianceKwhM2 != null)
                            _MetricChip(
                              label: 'Güneş (kWh/m²-yıl)',
                              value: site.annualSolarIrradianceKwhM2!
                                  .toStringAsFixed(0),
                            ),
                          if (site.avgWindSpeedMs != null)
                            _MetricChip(
                              label: 'Rüzgar (m/s)',
                              value: site.avgWindSpeedMs!.toStringAsFixed(1),
                            ),
                          _MetricChip(label: 'Tip', value: site.type),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SENARYO HARITASI VE LİSTE PANELLERİ
// ============================================================

class _ScenarioMap extends StatelessWidget {
  final MapController mapController;
  final int scenarioId;

  const _ScenarioMap({required this.mapController, required this.scenarioId});

  @override
  Widget build(BuildContext context) {
    final scenarioViewModel = Provider.of<ScenarioViewModel>(context);
    final mapViewModel = Provider.of<MapViewModel>(context);
    final scenario = scenarioViewModel.scenarios.firstWhere(
      (s) => s.id == scenarioId,
      orElse: () => scenarioViewModel.scenarios.first,
    );

    // Senaryodaki pinleri bul
    final scenarioPins = mapViewModel.pins
        .where((p) => scenario.pinIds.contains(p.id))
        .toList();

    final markers = <Marker>[];
    for (var pin in scenarioPins) {
      final color = pin.type == 'Güneş Paneli'
          ? Colors.orangeAccent
          : Colors.blueAccent;
      markers.add(
        Marker(
          point: LatLng(pin.latitude, pin.longitude),
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Tooltip(
            message: '${pin.name} (${pin.type})',
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.9),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                pin.type == 'Güneş Paneli' ? Icons.wb_sunny : Icons.wind_power,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      );
    }

    // Harita merkezi hesapla
    LatLng center = const LatLng(39.0, 35.0);
    double zoom = 6.0;
    if (scenarioPins.isNotEmpty) {
      double avgLat =
          scenarioPins.map((p) => p.latitude).reduce((a, b) => a + b) /
          scenarioPins.length;
      double avgLon =
          scenarioPins.map((p) => p.longitude).reduce((a, b) => a + b) /
          scenarioPins.length;
      center = LatLng(avgLat, avgLon);
      zoom = scenarioPins.length == 1 ? 9.0 : 7.0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Text(
                '${scenario.name} - Harita',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Text(
                '${scenarioPins.length} kaynak',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: zoom,
                maxZoom: MapConstants.maxZoom,
                minZoom: 5.5,
              ),
              children: [
                TileLayer(
                  urlTemplate: MapConstants.getTileUrl('dark'),
                  tileProvider: CancellableNetworkTileProvider(),
                  userAgentPackageName: 'frontend',
                ),
                if (markers.isNotEmpty) MarkerLayer(markers: markers),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScenarioListPanel extends StatelessWidget {
  final int scenarioId;

  const _ScenarioListPanel({required this.scenarioId});

  @override
  Widget build(BuildContext context) {
    final scenarioViewModel = Provider.of<ScenarioViewModel>(context);
    final mapViewModel = Provider.of<MapViewModel>(context);
    final scenario = scenarioViewModel.scenarios.firstWhere(
      (s) => s.id == scenarioId,
      orElse: () => scenarioViewModel.scenarios.first,
    );

    final scenarioPins = mapViewModel.pins
        .where((p) => scenario.pinIds.contains(p.id))
        .toList();

    // Sonuç verisini parse et
    final resultData = scenario.resultData;
    // resultData is Map<String, dynamic>?
    // Use clear safe access
    final totalSolarKwh = resultData?['total_solar_kwh'] ?? 0.0;
    final totalWindKwh = resultData?['total_wind_kwh'] ?? 0.0;
    final totalKwh = resultData?['total_kwh'] ?? 0.0;
    // ignore: unused_local_variable
    final solarCount = resultData?['solar_count'] ?? 0;
    // ignore: unused_local_variable
    final windCount = resultData?['wind_count'] ?? 0;

    String formatEnergy(double kwh) {
      if (kwh >= 1000000) {
        return '${(kwh / 1000000).toStringAsFixed(2)} GWh';
      } else if (kwh >= 1000) {
        return '${(kwh / 1000).toStringAsFixed(2)} MWh';
      } else {
        return '${kwh.toStringAsFixed(2)} kWh';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Senaryo Sonucu (7 Gün)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (scenario.startDate != null)
                Text(
                  '${scenario.startDate?.day}/${scenario.startDate?.month} - ${scenario.endDate?.day}/${scenario.endDate?.month}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              const SizedBox(height: 12),

              if (resultData != null)
                Column(
                  children: [
                    _ResultCard(
                      label: 'Toplam Üretim',
                      value: formatEnergy((totalKwh as num).toDouble()),
                      icon: Icons.flash_on,
                      color: Colors.greenAccent,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _ResultCard(
                            label: 'Güneş',
                            value: formatEnergy((totalSolarKwh as num).toDouble()),
                            icon: Icons.wb_sunny,
                            color: Colors.orangeAccent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ResultCard(
                            label: 'Rüzgar',
                            value: formatEnergy((totalWindKwh as num).toDouble()),
                            icon: Icons.wind_power,
                            color: Colors.lightBlueAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Text(
                    'Bu senaryo için henüz hesaplanmış sonuç yok.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
            ],
          ),
        ),
        const Divider(color: Colors.white24, height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: scenarioPins.length,
            itemBuilder: (context, index) {
              final pin = scenarioPins[index];
              final isSolar = pin.type == 'Güneş Paneli';
              final color = isSolar ? Colors.orangeAccent : Colors.blueAccent;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSolar ? Icons.wb_sunny : Icons.wind_power,
                      color: color,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pin.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${pin.capacityMw} MW',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ResultCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
