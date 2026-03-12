import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:frontend/data/models/system_data_models.dart';
import 'package:frontend/features/reports/viewmodels/report_view_model.dart';
import 'package:frontend/features/scenarios/viewmodels/scenario_viewmodel.dart';
import 'package:frontend/core/theme/theme_view_model.dart';
import 'package:frontend/core/widgets/app_background.dart';
import 'package:frontend/core/widgets/custom_app_bar.dart';
import 'package:frontend/core/widgets/glass_container.dart';
import 'package:frontend/features/reports/widgets/report_list_panel.dart';
import 'package:frontend/features/reports/widgets/report_map.dart';
import 'package:frontend/features/reports/widgets/scenario_map_in_report.dart';
import 'package:frontend/features/reports/widgets/scenario_result_panel.dart';
import 'package:frontend/features/reports/widgets/turkey_energy_panel.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final MapController _mapController = MapController();
  String _region = 'Tümü';
  String _type = 'Wind';
  String _timeInterval = 'Yıllık'; // Varsayılan: Yıllık
  int? _selectedScenarioId; // Yeni: Seçili senaryo
  bool _showTurkeyEnergy = false; // Türkiye enerji paneli

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
      body: AppBackground(
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
                            child: GlassContainer(
                              child: _selectedScenarioId == null
                                  ? ReportMap(
                                      mapController: _mapController,
                                      type: _type,
                                      onSiteFocused: _onSiteFocused,
                                    )
                                  : ScenarioMapInReport(
                                      mapController: _mapController,
                                      scenarioId: _selectedScenarioId!,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: GlassContainer(
                              child: _showTurkeyEnergy
                                  ? const TurkeyEnergyPanel()
                                  : _selectedScenarioId == null
                                      ? ReportListPanel(
                                          onSiteSelected: _onSiteFocused,
                                        )
                                      : ScenarioResultPanel(
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomAppBar(
          title: 'Bölgesel Potansiyel Raporu',
          textColor: theme.textColor,
          onBack: () => Navigator.of(context).pushReplacementNamed('/map'),
          // removed actions to prevent squeezing title
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
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
              // Yeni: Zaman Aralığı Seçici (Yıllık/Aylık/Anlık)
              _buildDropdown(
                value: _timeInterval,
                items: const ['Yıllık', 'Aylık', 'Anlık'],
                onChanged: (val) {
                  if (val == null) return;
                  setState(() => _timeInterval = val);
                  
                  // ViewModel üzerinden veriyi güncelle
                  Provider.of<ReportViewModel>(
                    context,
                    listen: false,
                  ).fetchReport(region: _region, type: _type, interval: val);
                },
              ),
              const SizedBox(width: 12),
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
              const SizedBox(width: 12),
              // Türkiye Enerji Verisi toggle
              _buildToggleChip(
                label: '🇹🇷 Türkiye Verisi',
                active: _showTurkeyEnergy,
                onTap: () => setState(
                  () => _showTurkeyEnergy = !_showTurkeyEnergy,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggleChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? Colors.redAccent.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? Colors.redAccent.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.redAccent : Colors.white70,
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
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

  void _onSiteFocused(RegionalSite site) {
    _mapController.move(LatLng(site.latitude, site.longitude), 8.0);
  }
}
