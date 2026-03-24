import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:frontend/core/theme/theme_view_model.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'package:frontend/features/map/models/map_models.dart';

/// Katmanlar paneli — MapLibre harita kontrolleri.
class LayersPanel extends StatelessWidget {
  final ThemeViewModel theme;
  final MapViewModel mapViewModel;

  const LayersPanel({
    super.key,
    required this.theme,
    required this.mapViewModel,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 252,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.secondaryTextColor.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.80,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MapLibreSection(theme: theme, vm: mapViewModel),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Bölüm Başlığı (daraltılabilir) ──────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final ThemeViewModel theme;

  const _SectionHeader({
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: theme.secondaryTextColor,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── MapLibre 3D Bölümü ───────────────────────────────────────────────────────

class _MapLibreSection extends StatefulWidget {
  final ThemeViewModel theme;
  final MapViewModel vm;

  const _MapLibreSection({required this.theme, required this.vm});

  @override
  State<_MapLibreSection> createState() => _MapLibreSectionState();
}

class _MapLibreSectionState extends State<_MapLibreSection> {
  bool _styleExpanded      = true;
  bool _projectionExpanded = true;
  bool _heatmapExpanded    = true;
  bool _pinExpanded        = true;
  bool _satelliteExpanded  = false;
  bool _windExpanded       = true;
  bool _effectsExpanded    = true;

  ThemeViewModel get theme => widget.theme;
  MapViewModel   get vm    => widget.vm;

  @override
  Widget build(BuildContext context) {
    final heatmapActive = vm.mlHeatmapMode != MlHeatmapMode.none;
    final globeActive   = vm.showGlobe;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Harita Stili ────────────────────────────────────────────────
        _SectionHeader(
          title: 'Harita Stili', expanded: _styleExpanded, theme: theme,
          onToggle: () => setState(() => _styleExpanded = !_styleExpanded),
        ),
        if (_styleExpanded) ...[
          const SizedBox(height: 6),
          ...MlBaseStyle.values.map(_styleOpt),
        ],

        const SizedBox(height: 10),
        // ── Projeksiyon ─────────────────────────────────────────────────
        _SectionHeader(
          title: 'Projeksiyon', expanded: _projectionExpanded, theme: theme,
          onToggle: () => setState(() => _projectionExpanded = !_projectionExpanded),
        ),
        if (_projectionExpanded) ...[
          const SizedBox(height: 6),
          _effectRow('Globe Projeksiyon', Icons.public_outlined,
              vm.showGlobe, Colors.deepPurpleAccent, vm.toggleShowGlobe),
          if (globeActive) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.deepPurpleAccent.withValues(alpha: 0.35)),
              ),
              child: Row(children: [
                const Icon(Icons.lock_outline_rounded, size: 13, color: Colors.deepPurpleAccent),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  'Globe projeksiyon açıkken diğer özellikler kullanılamaz. Yalnızca pinler görünür.',
                  style: TextStyle(color: Colors.deepPurpleAccent.withValues(alpha: 0.8), fontSize: 9.5),
                )),
              ]),
            ),
          ],
        ],

        // ── Kilit altındaki içerik ─────────────────────────────────────
        Opacity(
          opacity: globeActive ? 0.3 : 1.0,
          child: AbsorbPointer(
            absorbing: globeActive,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                // ── Isı Haritası ──────────────────────────────────────
                _SectionHeader(
                  title: 'Isı Haritası', expanded: _heatmapExpanded, theme: theme,
                  onToggle: () => setState(() => _heatmapExpanded = !_heatmapExpanded),
                ),
                if (_heatmapExpanded) ...[
                  const SizedBox(height: 6),
                  _heatmapOpt('Güneş Potansiyeli', MlHeatmapMode.solar, Colors.orangeAccent, Icons.wb_sunny_outlined),
                  _heatmapOpt('Rüzgar Potansiyeli', MlHeatmapMode.wind, Colors.cyanAccent, Icons.air),
                  _heatmapOpt('Sıcaklık', MlHeatmapMode.temperature, Colors.deepOrangeAccent, Icons.thermostat_outlined),
                  if (heatmapActive && !globeActive) ...[
                    const SizedBox(height: 10),
                    _heatmapControls(context),
                  ],
                ],

                const SizedBox(height: 10),
                // ── Pin Filtresi ──────────────────────────────────────
                _SectionHeader(
                  title: 'Pin Filtresi', expanded: _pinExpanded, theme: theme,
                  onToggle: () => setState(() => _pinExpanded = !_pinExpanded),
                ),
                if (_pinExpanded) ...[
                  const SizedBox(height: 6),
                  _effectRow('Pin Kümeleme', Icons.bubble_chart_outlined,
                      vm.showPinClusters, Colors.tealAccent,
                      vm.togglePinClustering, badge: 'JS'),
                  const SizedBox(height: 4),
                  _pinFilterSection(),
                ],

                const SizedBox(height: 10),
                // ── Uydu Katmanları ───────────────────────────────────
                _SectionHeader(
                  title: 'Uydu Katmanları', expanded: _satelliteExpanded, theme: theme,
                  onToggle: () => setState(() => _satelliteExpanded = !_satelliteExpanded),
                ),
                if (_satelliteExpanded) ...[
                  const SizedBox(height: 6),
                  _effectRow('Bulut Örtüsü', Icons.cloud_outlined,
                      vm.showCloudLayer, const Color(0xFF90CAF9),
                      vm.toggleShowCloudLayer, badge: 'SAT'),
                  if (vm.showCloudLayer) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.opacity_outlined, size: 12, color: theme.secondaryTextColor),
                      const SizedBox(width: 4),
                      Text('Şeffaflık', style: TextStyle(color: theme.secondaryTextColor, fontSize: 10)),
                      const Spacer(),
                      Text('${(vm.cloudOpacity * 100).round()}%',
                          style: TextStyle(color: theme.textColor, fontSize: 10, fontWeight: FontWeight.w600)),
                    ]),
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                        activeTrackColor: const Color(0xFF90CAF9),
                        inactiveTrackColor: theme.secondaryTextColor.withValues(alpha: 0.2),
                        thumbColor: const Color(0xFF90CAF9),
                        overlayColor: const Color(0xFF90CAF9).withAlpha(40),
                      ),
                      child: Slider(
                        value: vm.cloudOpacity, min: 0.1, max: 1.0, divisions: 9,
                        onChanged: vm.setCloudOpacity,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        Icon(Icons.info_outline_rounded, size: 10, color: theme.secondaryTextColor.withValues(alpha: 0.6)),
                        const SizedBox(width: 4),
                        Expanded(child: Text(
                          'RainViewer infrared uydu — ~10 dk güncelleme',
                          style: TextStyle(color: theme.secondaryTextColor.withValues(alpha: 0.6), fontSize: 9),
                        )),
                      ]),
                    ),
                  ],
                ],

                const SizedBox(height: 10),
                // ── Rüzgar Partikülleri ───────────────────────────────
                _SectionHeader(
                  title: 'Rüzgar Partikülleri', expanded: _windExpanded, theme: theme,
                  onToggle: () => setState(() => _windExpanded = !_windExpanded),
                ),
                if (_windExpanded) ...[
                  const SizedBox(height: 6),
                  _effectRow('Canlı Akış', Icons.air_rounded,
                      vm.showWindParticles, Colors.cyanAccent,
                      () => vm.toggleWindParticles(!vm.showWindParticles), badge: 'LIVE'),
                ],

                const SizedBox(height: 10),
                // ── 3D Efektler ───────────────────────────────────────
                _SectionHeader(
                  title: '3D Efektler', expanded: _effectsExpanded, theme: theme,
                  onToggle: () => setState(() => _effectsExpanded = !_effectsExpanded),
                ),
                if (_effectsExpanded) ...[
                  const SizedBox(height: 6),
                  _effectRow('3D Türbinler', Icons.wind_power_outlined,
                      vm.show3DTurbines, Colors.blueAccent,
                      vm.toggleShow3DTurbines, badge: '3D'),
                  _effectRow('3D Arazi', Icons.terrain_outlined,
                      vm.show3DTerrain, Colors.teal, vm.toggleShow3DTerrain, badge: 'DEM'),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Isı haritası parametre kontrolleri (radius, intensity, palette)
  Widget _heatmapControls(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.secondaryTextColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Yarıçap (Radius)
          Row(children: [
            Icon(Icons.blur_on_outlined, size: 12, color: theme.secondaryTextColor),
            const SizedBox(width: 4),
            Text('Yarıçap', style: TextStyle(color: theme.secondaryTextColor, fontSize: 10)),
            const Spacer(),
            Text('${vm.heatmapRadius.round()}', style: TextStyle(color: theme.textColor, fontSize: 10, fontWeight: FontWeight.bold)),
          ]),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: Colors.orangeAccent,
              inactiveTrackColor: theme.secondaryTextColor.withValues(alpha: 0.2),
              thumbColor: Colors.orangeAccent,
              overlayColor: Colors.orangeAccent.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: vm.heatmapRadius,
              min: 10, max: 100,
              onChanged: vm.setHeatmapRadius,
            ),
          ),

          // Yoğunluk (Intensity)
          Row(children: [
            Icon(Icons.brightness_6_outlined, size: 12, color: theme.secondaryTextColor),
            const SizedBox(width: 4),
            Text('Yoğunluk', style: TextStyle(color: theme.secondaryTextColor, fontSize: 10)),
            const Spacer(),
            Text(vm.heatmapIntensity.toStringAsFixed(1), style: TextStyle(color: theme.textColor, fontSize: 10, fontWeight: FontWeight.bold)),
          ]),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: Colors.cyanAccent,
              inactiveTrackColor: theme.secondaryTextColor.withValues(alpha: 0.2),
              thumbColor: Colors.cyanAccent,
              overlayColor: Colors.cyanAccent.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: vm.heatmapIntensity,
              min: 0.2, max: 5.0,
              onChanged: vm.setHeatmapIntensity,
            ),
          ),

          // Palet seçimi
          const SizedBox(height: 4),
          Row(children: HeatmapPalette.values.map((p) {
            final active = vm.heatmapPalette == p;
            return Expanded(child: GestureDetector(
              onTap: () => vm.setHeatmapPalette(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: active ? Colors.orangeAccent.withValues(alpha: 0.18) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: active ? Colors.orangeAccent : theme.secondaryTextColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(p.icon, size: 11, color: active ? Colors.orangeAccent : theme.secondaryTextColor),
                  const SizedBox(height: 2),
                  Text(p.displayName, style: TextStyle(
                    color: active ? Colors.orangeAccent : theme.secondaryTextColor,
                    fontSize: 8.5, fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  ), textAlign: TextAlign.center),
                ]),
              ),
            ));
          }).toList()),
        ],
      ),
    );
  }

  /// Pin türü filtreleme bölümü
  Widget _pinFilterSection() {
    final pinTypes = [
      ('Güneş Paneli',    Colors.orangeAccent,    Icons.wb_sunny_outlined),
      ('Rüzgar Türbini',  Colors.cyanAccent,       Icons.air),
      ('Hidroelektrik',   Colors.blueAccent,       Icons.water_outlined),
    ];
    final hasFilter = vm.hasPinFilter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tür filtreleri
        Row(children: [
          ...pinTypes.map((entry) {
            final (type, color, icon) = entry;
            final active = vm.pinTypeFilter.contains(type);
            return Expanded(child: GestureDetector(
              onTap: () => vm.togglePinTypeFilter(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: active ? color.withValues(alpha: 0.18) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: active ? color : theme.secondaryTextColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 12, color: active ? color : theme.secondaryTextColor),
                  const SizedBox(height: 2),
                  Text(
                    type == 'Güneş Paneli' ? 'Güneş' : type == 'Rüzgar Türbini' ? 'Rüzgar' : 'HES',
                    style: TextStyle(
                      color: active ? color : theme.secondaryTextColor,
                      fontSize: 8.5, fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    ), textAlign: TextAlign.center,
                  ),
                ]),
              ),
            ));
          }),
        ]),
        // Filtre aktifse "Temizle" butonu
        if (hasFilter) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: vm.clearPinFilter,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.filter_alt_off_outlined, size: 11, color: Colors.redAccent.withValues(alpha: 0.8)),
              const SizedBox(width: 4),
              Text('Filtreyi Temizle', style: TextStyle(
                color: Colors.redAccent.withValues(alpha: 0.8), fontSize: 10,
              )),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _styleOpt(MlBaseStyle style) {
    final active = vm.mlBaseStyle == style;
    return InkWell(
      onTap: () => vm.setMlBaseStyle(style),
      borderRadius: BorderRadius.circular(6),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(style.icon, size: 14,
              color: active ? Colors.deepPurpleAccent : theme.secondaryTextColor),
          const SizedBox(width: 8),
          Expanded(child: Text(style.displayName, style: TextStyle(
            color: active ? theme.textColor : theme.secondaryTextColor, fontSize: 12))),
          if (active) const Icon(Icons.check_rounded, size: 13, color: Colors.deepPurpleAccent),
        ])),
    );
  }

  Widget _heatmapOpt(String label, MlHeatmapMode mode, Color color, IconData icon) {
    final active = vm.mlHeatmapMode == mode;
    return InkWell(
      onTap: () => vm.setMlHeatmapMode(active ? MlHeatmapMode.none : mode),
      borderRadius: BorderRadius.circular(6),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 26, height: 26,
            decoration: BoxDecoration(
              color: active ? color.withValues(alpha: 0.18) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: active ? color : color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, size: 13, color: active ? color : color.withValues(alpha: 0.5)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(
            color: active ? theme.textColor : theme.secondaryTextColor, fontSize: 12))),
          if (active) Icon(Icons.layers_rounded, size: 12, color: color),
        ])),
    );
  }

  Widget _effectRow(
    String label, IconData icon, bool active, Color color, VoidCallback? onTap, {
    String? badge, bool isLoading = false, bool disabled = false,
  }) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 3),
      child: Opacity(opacity: disabled ? 0.42 : 1.0,
        child: Row(children: [
          Icon(icon, size: 14, color: active ? color : theme.secondaryTextColor),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: TextStyle(
            color: active ? theme.textColor : theme.secondaryTextColor, fontSize: 12))),
          // Badge (dekoratif etiket) — her zaman göster, switch'i ENGELLEMEZ
          if (badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: active ? color.withValues(alpha: 0.15) : theme.secondaryTextColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(badge, style: TextStyle(
                color: active ? color : theme.secondaryTextColor,
                fontSize: 9, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 4),
          ],
          // Switch veya spinner — devre dışı değilse HEP göster (badge olsa bile)
          if (!disabled) ...[
            if (isLoading)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Switch(
                value: active,
                onChanged: onTap != null ? (_) => onTap() : null,
                activeColor: color,
                activeTrackColor: color.withValues(alpha: 0.3),
                inactiveThumbColor: theme.secondaryTextColor,
                inactiveTrackColor: theme.secondaryTextColor.withValues(alpha: 0.1),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ]),
      ),
    );
  }
}
