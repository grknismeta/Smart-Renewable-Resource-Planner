import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/models/scenario_model.dart';
import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'package:frontend/features/scenarios/viewmodels/scenario_viewmodel.dart';
import 'package:frontend/features/scenarios/dialogs/scenario_create_dialog.dart';
import 'package:frontend/features/pins/controllers/pin_flow_controller.dart';

/// Haritanın solundan kayan senaryo yönetim paneli.
class ScenarioSidePanel extends StatefulWidget {
  final ThemeViewModel theme;
  final VoidCallback onClose;

  const ScenarioSidePanel({
    super.key,
    required this.theme,
    required this.onClose,
  });

  @override
  State<ScenarioSidePanel> createState() => _ScenarioSidePanelState();
}

// Sprint 1.3 — Kütüphane panel iki sekmesi.
// Bkz: [[LibrarySidePanel]] (vault).
enum _LibraryTab { scenarios, pins }

class _ScenarioSidePanelState extends State<ScenarioSidePanel> {
  _LibraryTab _activeTab = _LibraryTab.scenarios;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = Provider.of<ScenarioViewModel>(context, listen: false);
      if (vm.scenarios.isEmpty && !vm.isBusy) {
        vm.loadScenarios();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(20),
        bottomRight: Radius.circular(20),
      ),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: 340,
          decoration: BoxDecoration(
            color: widget.theme.cardColor.withValues(alpha: 0.92),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            border: Border(
              right: BorderSide(
                color: Colors.blueAccent.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(4, 0),
              ),
            ],
          ),
          child: Consumer2<ScenarioViewModel, MapViewModel>(
            builder: (context, scenarioVM, mapVM, _) {
              return Column(
                children: [
                  _buildHeader(context, scenarioVM, mapVM),
                  // Sprint 1.3 — Segmented tab switcher (Senaryolar | Pinlerim)
                  _buildTabSwitcher(scenarioVM, mapVM),
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: widget.theme.secondaryTextColor.withValues(alpha: 0.15),
                  ),
                  Expanded(
                    child: _activeTab == _LibraryTab.scenarios
                        ? _buildList(context, scenarioVM, mapVM)
                        : _buildPinsList(context, mapVM),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ScenarioViewModel scenarioVM,
    MapViewModel mapVM,
  ) {
    // Sprint 1.3 — başlık "Kütüphane" (Senaryolar + Pinlerim ortak panel).
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
      child: Row(
        children: [
          const Icon(Icons.collections_bookmark_rounded, color: Colors.blueAccent, size: 20),
          const SizedBox(width: 10),
          Text(
            'Kütüphane',
            style: TextStyle(
              color: widget.theme.textColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          if (_activeTab == _LibraryTab.scenarios && scenarioVM.hasSelection) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
              ),
              child: Text(
                '${scenarioVM.selectedScenarioIds.length} aktif',
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (_activeTab == _LibraryTab.scenarios)
            _IconBtn(
              icon: Icons.add,
              color: Colors.blueAccent,
              tooltip: 'Yeni Senaryo',
              onTap: () => _showCreateDialog(context, mapVM),
            ),
          if (_activeTab == _LibraryTab.scenarios && scenarioVM.hasSelection) ...[
            const SizedBox(width: 6),
            _IconBtn(
              icon: Icons.deselect,
              color: Colors.orange,
              tooltip: 'Harita seçimini temizle',
              onTap: scenarioVM.clearAllSelections,
            ),
          ],
          const SizedBox(width: 6),
          GestureDetector(
            onTap: widget.onClose,
            child: Icon(
              Icons.close,
              color: widget.theme.secondaryTextColor,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  /// 2-segment tab switcher: [Senaryolar | Pinlerim], badge sayaçları ile.
  Widget _buildTabSwitcher(ScenarioViewModel scenarioVM, MapViewModel mapVM) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: widget.theme.backgroundColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: widget.theme.secondaryTextColor.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            _tabButton(
              label: 'Senaryolar',
              icon: Icons.layers_rounded,
              isActive: _activeTab == _LibraryTab.scenarios,
              count: scenarioVM.scenarios.length,
              onTap: () => setState(() => _activeTab = _LibraryTab.scenarios),
            ),
            _tabButton(
              label: 'Pinlerim',
              icon: Icons.location_on_rounded,
              isActive: _activeTab == _LibraryTab.pins,
              count: mapVM.pins.length,
              onTap: () => setState(() => _activeTab = _LibraryTab.pins),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required int count,
    required VoidCallback onTap,
  }) {
    final activeColor = isActive
        ? widget.theme.textColor
        : widget.theme.secondaryTextColor;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isActive ? widget.theme.cardColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: activeColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: activeColor,
                  fontSize: 12.5,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: widget.theme.backgroundColor.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: activeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pinlerim sekmesi — kaynak tipine göre gruplu liste (V5 mantığı).
  /// Her grup: ☀ Güneş / 💨 Rüzgar / 💧 HES başlığı altında pin'ler.
  /// Tıklama → `mapVM.openPinDetail` (V2 bottom card açılır).
  Widget _buildPinsList(BuildContext context, MapViewModel mapVM) {
    final pins = mapVM.pins;
    if (pins.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 44,
              color: widget.theme.secondaryTextColor.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 10),
            Text(
              'Henüz pin yok',
              style: TextStyle(
                color: widget.theme.secondaryTextColor,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Haritadan "Santral Kur" ile başla',
              style: TextStyle(
                color: widget.theme.secondaryTextColor.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    final solar = pins.where((p) => p.type == 'Güneş Paneli').toList();
    final wind = pins.where((p) => p.type == 'Rüzgar Türbini').toList();
    final hes = pins.where((p) => p.type == 'Hidroelektrik').toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      children: [
        if (solar.isNotEmpty) _pinGroup(mapVM, 'Güneş', Icons.wb_sunny_rounded, Colors.orange, solar),
        if (wind.isNotEmpty) _pinGroup(mapVM, 'Rüzgar', Icons.wind_power_rounded, Colors.blueAccent, wind),
        if (hes.isNotEmpty) _pinGroup(mapVM, 'HES', Icons.water_drop_rounded, const Color(0xFF1DB954), hes),
      ],
    );
  }

  Widget _pinGroup(MapViewModel mapVM, String label, IconData icon, Color color, List<Pin> pins) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(
                  '$label (${pins.length})',
                  style: TextStyle(
                    color: widget.theme.secondaryTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          ...pins.map((p) => _pinRow(mapVM, p, color)),
        ],
      ),
    );
  }

  Widget _pinRow(MapViewModel mapVM, Pin pin, Color accentColor) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // 2026-05-09 Strategic Reset: PinFlowController doğrudan tetiklenir.
          try {
            Provider.of<PinFlowController>(context, listen: false)
                .openPinDetail(pin);
          } catch (_) {
            mapVM.openPinDetail(pin); // fallback geriye uyum
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: widget.theme.backgroundColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accentColor.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pin.name,
                      style: TextStyle(
                        color: widget.theme.textColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${pin.capacityMw.toStringAsFixed(1)} MW'
                      '${(pin.city != null && pin.city!.isNotEmpty) ? " · ${pin.city}" : ""}',
                      style: TextStyle(
                        color: widget.theme.secondaryTextColor,
                        fontSize: 10.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: widget.theme.secondaryTextColor.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    ScenarioViewModel scenarioVM,
    MapViewModel mapVM,
  ) {
    if (scenarioVM.isBusy && scenarioVM.scenarios.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (scenarioVM.scenarios.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open,
              size: 48,
              color: widget.theme.secondaryTextColor.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Henüz senaryo yok',
              style: TextStyle(
                color: widget.theme.secondaryTextColor,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _showCreateDialog(context, mapVM),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('İlk senaryonu oluştur'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      itemCount: scenarioVM.scenarios.length,
      itemBuilder: (context, index) {
        final scenario = scenarioVM.scenarios[index];
        return _ScenarioCard(
          key: ValueKey(scenario.id),
          scenario: scenario,
          pins: mapVM.pins,
          theme: widget.theme,
          isActive: scenarioVM.isSelected(scenario.id),
          isVisible: scenarioVM.isVisible(scenario.id),
          onToggle: () => scenarioVM.toggleScenario(scenario.id),
          onToggleVisibility: () => scenarioVM.toggleScenarioVisibility(scenario.id),
          onEdit: () => _showEditDialog(context, scenario, mapVM),
          onUpdate: () => _handleUpdate(context, scenarioVM, scenario),
          onReport: () => Navigator.pushNamed(
            context,
            '/reports',
            arguments: {'scenarioId': scenario.id},
          ),
        );
      },
    );
  }

  Future<void> _handleUpdate(
    BuildContext context,
    ScenarioViewModel scenarioVM,
    Scenario scenario,
  ) async {
    // Smart update: sadece gelecek tarihli veya devam eden senaryolar güncellenir
    final endDate = scenario.endDate;
    final now = DateTime.now();
    if (endDate != null && endDate.isBefore(now) && scenario.resultData != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu senaryo güncel — yeni veri yok.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      await scenarioVM.calculateScenario(scenario.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Senaryo güncellendi!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Güncelleme hatası: $e')),
        );
      }
    }
  }

  void _showCreateDialog(BuildContext context, MapViewModel mapVM) {
    showDialog(
      context: context,
      builder: (ctx) => ScenarioCreateDialog(
        theme: widget.theme,
        scenarioToEdit: null,
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    Scenario scenario,
    MapViewModel mapVM,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => ScenarioCreateDialog(
        theme: widget.theme,
        scenarioToEdit: scenario,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scenario Card (Accordion)
// ─────────────────────────────────────────────────────────────────────────────

class _ScenarioCard extends StatefulWidget {
  final Scenario scenario;
  final List<Pin> pins;
  final ThemeViewModel theme;
  final bool isActive;
  final bool isVisible;
  final VoidCallback onToggle;
  final VoidCallback onToggleVisibility;
  final VoidCallback onEdit;
  final VoidCallback onUpdate;
  final VoidCallback onReport;

  const _ScenarioCard({
    super.key,
    required this.scenario,
    required this.pins,
    required this.theme,
    required this.isActive,
    required this.isVisible,
    required this.onToggle,
    required this.onToggleVisibility,
    required this.onEdit,
    required this.onUpdate,
    required this.onReport,
  });

  @override
  State<_ScenarioCard> createState() => _ScenarioCardState();
}

class _ScenarioCardState extends State<_ScenarioCard> {
  bool _expanded = false;
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    final scenarioPins =
        widget.pins.where((p) => widget.scenario.pinIds.contains(p.id)).toList();
    final solar = scenarioPins.where((p) => p.type == 'Güneş Paneli').length;
    final wind = scenarioPins.where((p) => p.type == 'Rüzgar Türbini').length;
    final hes = scenarioPins.where((p) => p.type == 'Hidroelektrik').length;

    final borderColor = widget.isActive
        ? Colors.blueAccent
        : widget.theme.secondaryTextColor.withValues(alpha: 0.12);
    final bgColor = widget.isActive
        ? Colors.blueAccent.withValues(alpha: 0.07)
        : widget.theme.backgroundColor.withValues(alpha: 0.3);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: widget.isActive ? 1.5 : 1,
        ),
        boxShadow: widget.isActive
            ? [
                BoxShadow(
                  color: Colors.blueAccent.withValues(alpha: 0.18),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          // ── Card Header ───────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Row(
                children: [
                  // Toggle (harita aktivasyon)
                  GestureDetector(
                    onTap: widget.onToggle,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.isActive
                            ? Colors.blueAccent
                            : Colors.transparent,
                        border: Border.all(
                          color: widget.isActive
                              ? Colors.blueAccent
                              : widget.theme.secondaryTextColor
                                  .withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: widget.isActive
                          ? const Icon(Icons.check, size: 12, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Senaryo adı
                  Expanded(
                    child: Text(
                      widget.scenario.name,
                      style: TextStyle(
                        color: widget.theme.textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Aksiyon butonları
                  // Haritada göster/gizle (Aşama 2)
                  _SmallBtn(
                    icon: widget.isVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: widget.isVisible
                        ? Colors.lightGreenAccent.withValues(alpha: 0.85)
                        : widget.theme.secondaryTextColor.withValues(alpha: 0.5),
                    tooltip: widget.isVisible
                        ? 'Haritada Gizle'
                        : 'Haritada Göster',
                    onTap: widget.onToggleVisibility,
                  ),
                  const SizedBox(width: 4),
                  _SmallBtn(
                    icon: Icons.edit_outlined,
                    color: widget.theme.secondaryTextColor.withValues(alpha: 0.7),
                    tooltip: 'Düzenle',
                    onTap: widget.onEdit,
                  ),
                  const SizedBox(width: 4),
                  _SmallBtn(
                    icon: _isUpdating ? Icons.hourglass_empty : Icons.sync,
                    color: _isUpdating ? Colors.orange : Colors.teal,
                    tooltip: 'Güncelle',
                    onTap: _isUpdating
                        ? null
                        : () async {
                            setState(() => _isUpdating = true);
                            await Future(() => widget.onUpdate());
                            if (mounted) setState(() => _isUpdating = false);
                          },
                  ),
                  const SizedBox(width: 4),
                  _SmallBtn(
                    icon: Icons.bar_chart_rounded,
                    color: Colors.purpleAccent.withValues(alpha: 0.7),
                    tooltip: 'Detaylı Rapor',
                    onTap: widget.onReport,
                  ),
                  const SizedBox(width: 6),

                  // Expand ok
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      size: 18,
                      color: widget.theme.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Source chips (always visible) ─────────────────────────────
          if (solar > 0 || wind > 0 || hes > 0)
            Padding(
              padding: const EdgeInsets.only(left: 40, right: 10, bottom: 8),
              child: Row(
                children: [
                  if (solar > 0) ...[
                    _SourceChip(
                        icon: Icons.wb_sunny, count: solar, color: Colors.orange),
                    const SizedBox(width: 5),
                  ],
                  if (wind > 0) ...[
                    _SourceChip(
                        icon: Icons.wind_power, count: wind, color: Colors.blue),
                    const SizedBox(width: 5),
                  ],
                  if (hes > 0)
                    _SourceChip(
                        icon: Icons.water_drop,
                        count: hes,
                        color: const Color(0xFF00BCD4)),
                  const Spacer(),
                  if (widget.scenario.resultData != null)
                    _EnergyBadge(resultData: widget.scenario.resultData!),
                ],
              ),
            ),

          // ── Accordion content ─────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _expanded ? _buildAccordionContent() : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildAccordionContent() {
    final theme = widget.theme;
    final scenario = widget.scenario;
    final scenarioPins =
        widget.pins.where((p) => scenario.pinIds.contains(p.id)).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.secondaryTextColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tarih aralığı
          if (scenario.startDate != null) ...[
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 12, color: theme.secondaryTextColor),
                const SizedBox(width: 6),
                Text(
                  _formatDateRange(scenario.startDate, scenario.endDate),
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Pin listesi
          if (scenarioPins.isEmpty)
            Text(
              'Pin eklenmemiş',
              style: TextStyle(
                color: theme.secondaryTextColor.withValues(alpha: 0.6),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            )
          else ...[
            Text(
              'Kaynaklar (${scenarioPins.length})',
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            // Cross-sheet navigation (A.5): pin satırı tıklanabilir → pin detay
            // bottom card overlay'i açılır. ScenarioSidePanel kapanmaz; harita
            // alanında card gösterilir, kullanıcı geri panel'e dönebilir.
            ...scenarioPins.take(5).map(
                  (p) => InkWell(
                    onTap: () {
                      Provider.of<MapViewModel>(context, listen: false)
                          .openPinDetail(p);
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Row(
                        children: [
                          Icon(
                            _pinIcon(p.type),
                            size: 11,
                            color: _pinColor(p.type),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              p.name,
                              style: TextStyle(
                                color: theme.textColor,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 12,
                            color: theme.secondaryTextColor.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            if (scenarioPins.length > 5)
              Text(
                '+ ${scenarioPins.length - 5} daha...',
                style: TextStyle(
                  color: theme.secondaryTextColor.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
          ],

          // Açıklama
          if (scenario.description != null && scenario.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              scenario.description!,
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Haritaya aç/kapat
          const SizedBox(height: 10),
          GestureDetector(
            onTap: widget.onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: widget.isActive
                    ? Colors.blueAccent.withValues(alpha: 0.15)
                    : theme.backgroundColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.isActive
                      ? Colors.blueAccent.withValues(alpha: 0.5)
                      : theme.secondaryTextColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isActive ? Icons.visibility : Icons.visibility_off,
                    size: 14,
                    color: widget.isActive
                        ? Colors.blueAccent
                        : theme.secondaryTextColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.isActive
                        ? 'Haritada gösteriliyor'
                        : 'Haritada göster',
                    style: TextStyle(
                      color: widget.isActive
                          ? Colors.blueAccent
                          : theme.secondaryTextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateRange(DateTime? start, DateTime? end) {
    if (start == null) return '';
    final s = '${start.day}/${start.month}/${start.year}';
    if (end == null) return '$s — devam ediyor';
    final e = '${end.day}/${end.month}/${end.year}';
    return '$s — $e';
  }

  IconData _pinIcon(String type) {
    switch (type) {
      case 'Güneş Paneli':
        return Icons.wb_sunny;
      case 'Rüzgar Türbini':
        return Icons.wind_power;
      case 'Hidroelektrik':
        return Icons.water_drop;
      default:
        return Icons.location_on;
    }
  }

  Color _pinColor(String type) {
    switch (type) {
      case 'Güneş Paneli':
        return Colors.orange;
      case 'Rüzgar Türbini':
        return Colors.blue;
      case 'Hidroelektrik':
        return const Color(0xFF00BCD4);
      default:
        return Colors.grey;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SmallBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  const _SmallBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;

  const _SourceChip({
    required this.icon,
    required this.count,
    required this.color,
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
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _EnergyBadge extends StatelessWidget {
  final Map<String, dynamic> resultData;

  const _EnergyBadge({required this.resultData});

  @override
  Widget build(BuildContext context) {
    final total = (resultData['total_energy_kwh'] as num?)?.toDouble();
    if (total == null) return const SizedBox.shrink();

    String label;
    if (total >= 1000000) {
      label = '${(total / 1000000).toStringAsFixed(1)} GWh';
    } else if (total >= 1000) {
      label = '${(total / 1000).toStringAsFixed(1)} MWh';
    } else {
      label = '${total.toStringAsFixed(0)} kWh';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt, size: 11, color: Colors.green),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.green,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
