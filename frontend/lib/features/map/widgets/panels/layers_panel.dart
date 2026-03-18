import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:frontend/core/theme/theme_view_model.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'package:frontend/features/map/models/map_models.dart';

/// Katmanlar paneli — Standart | 3D Harita (MapLibre) sekmeli yapı.
class LayersPanel extends StatelessWidget {
  final ThemeViewModel theme;
  final MapViewModel mapViewModel;
  final String selectedBaseMap;
  final ValueChanged<String> onBaseMapChanged;

  const LayersPanel({
    super.key,
    required this.theme,
    required this.mapViewModel,
    required this.selectedBaseMap,
    required this.onBaseMapChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isMapLibre = mapViewModel.mapMode == MapMode.maplibre3d;
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ModeSwitcher(
                isMapLibre: isMapLibre,
                theme: theme,
                onChanged: (ml) => mapViewModel.setMapMode(
                  ml ? MapMode.maplibre3d : MapMode.standard,
                ),
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: theme.secondaryTextColor.withValues(alpha: 0.12)),
              const SizedBox(height: 10),
              if (isMapLibre)
                _MapLibreSection(theme: theme, vm: mapViewModel)
              else
                _StandardSection(
                  theme: theme,
                  vm: mapViewModel,
                  selectedBaseMap: selectedBaseMap,
                  onBaseMapChanged: onBaseMapChanged,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mod Seçici ───────────────────────────────────────────────────────────────

class _ModeSwitcher extends StatelessWidget {
  final bool isMapLibre;
  final ThemeViewModel theme;
  final ValueChanged<bool> onChanged;

  const _ModeSwitcher({
    required this.isMapLibre,
    required this.theme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: theme.secondaryTextColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          _ModeTab(
            label: 'Standart', icon: Icons.map_outlined,
            active: !isMapLibre, activeColor: Colors.blueAccent,
            theme: theme, onTap: () => onChanged(false),
          ),
          _ModeTab(
            label: '3D Harita', icon: Icons.view_in_ar_rounded,
            active: isMapLibre, activeColor: Colors.deepPurpleAccent,
            theme: theme, onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final ThemeViewModel theme;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label, required this.icon, required this.active,
    required this.activeColor, required this.theme, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: active ? activeColor.withValues(alpha: 0.85) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: active ? Colors.white : theme.secondaryTextColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : theme.secondaryTextColor,
                  fontSize: 11,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Standart Bölüm ───────────────────────────────────────────────────────────

class _StandardSection extends StatelessWidget {
  final ThemeViewModel theme;
  final MapViewModel vm;
  final String selectedBaseMap;
  final ValueChanged<String> onBaseMapChanged;

  const _StandardSection({
    required this.theme, required this.vm,
    required this.selectedBaseMap, required this.onBaseMapChanged,
  });

  Widget _lbl(String text) => Text(
    text,
    style: TextStyle(color: theme.secondaryTextColor, fontSize: 11, fontWeight: FontWeight.w700),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _lbl('Harita Stili'),
        const SizedBox(height: 6),
        _baseOpt('Koyu Mod', 'dark', Icons.dark_mode_outlined),
        _baseOpt('Uydu', 'satellite', Icons.satellite_alt_outlined),
        _baseOpt('Sokak', 'street', Icons.map_outlined),

        const SizedBox(height: 12),
        _lbl('Veri Katmanları'),
        const SizedBox(height: 6),
        _layerOpt('Rüzgar Hızı', MapLayerType.wind),
        _layerOpt('Sıcaklık', MapLayerType.temp),
        _layerOpt('Güneş Işınımı', MapLayerType.irradiance),

        if (vm.currentLayer == MapLayerType.irradiance)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4),
            child: Row(children: [
              Icon(Icons.info_outline, size: 10, color: Colors.orangeAccent.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Flexible(child: Text('Yıllık ortalama güneş potansiyeli',
                style: TextStyle(color: theme.secondaryTextColor.withValues(alpha: 0.6), fontSize: 9.5, fontStyle: FontStyle.italic))),
            ]),
          ),

        if (vm.currentLayer != MapLayerType.none) ...[
          const SizedBox(height: 10),
          _timePeriodRow(),
        ],

        const SizedBox(height: 12),
        _lbl('Katman Efektleri'),
        const SizedBox(height: 6),
        _effectRow('Rüzgar Akışı', Icons.air, vm.showWindParticles,
          (v) => vm.toggleWindParticles(v), Colors.cyanAccent, isLoading: vm.isWindLoading),
        if (vm.showWindParticles) ...[
          const SizedBox(height: 4),
          _qualityRow(),
          const SizedBox(height: 4),
        ],
        _effectRow('Yükseklik Haritası', Icons.terrain, vm.showElevation,
          (v) => vm.toggleElevation(v), Colors.greenAccent),

        const SizedBox(height: 12),
        _lbl('Görünüm'),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Veri Noktaları (Neon)', style: TextStyle(color: theme.textColor, fontSize: 12)),
          Switch(
            value: vm.showDataPoints,
            onChanged: (v) => vm.toggleDataPoints(v),
            activeColor: Colors.cyanAccent,
            activeTrackColor: Colors.cyan.withValues(alpha: 0.3),
            inactiveThumbColor: theme.secondaryTextColor,
            inactiveTrackColor: theme.secondaryTextColor.withValues(alpha: 0.1),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ]),
      ],
    );
  }

  Widget _baseOpt(String title, String value, IconData icon) {
    final active = selectedBaseMap == value;
    return InkWell(
      onTap: () => onBaseMapChanged(value),
      borderRadius: BorderRadius.circular(6),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(icon, size: 14, color: active ? Colors.blueAccent : theme.secondaryTextColor),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: active ? theme.textColor : theme.secondaryTextColor, fontSize: 12)),
          const Spacer(),
          if (active) const Icon(Icons.check_rounded, size: 13, color: Colors.blueAccent),
        ])),
    );
  }

  Widget _layerOpt(String title, MapLayerType layer) {
    final active = vm.currentLayer == layer;
    return InkWell(
      onTap: () => vm.setLayer(active ? MapLayerType.none : layer),
      borderRadius: BorderRadius.circular(6),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(active ? Icons.check_circle : Icons.radio_button_unchecked,
            color: active ? Colors.greenAccent : theme.secondaryTextColor.withValues(alpha: 0.5), size: 15),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: TextStyle(
            color: active ? theme.textColor : theme.secondaryTextColor, fontSize: 12), overflow: TextOverflow.ellipsis)),
        ])),
    );
  }

  Widget _timePeriodRow() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.secondaryTextColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        _timeOpt('Anlık', MapTimePeriod.current),
        _timeOpt('Aylık', MapTimePeriod.monthly),
        _timeOpt('Yıllık', MapTimePeriod.annual),
      ]),
    );
  }

  Widget _timeOpt(String title, MapTimePeriod period) {
    final sel = vm.selectedPeriod == period;
    return Expanded(child: InkWell(
      onTap: () => vm.setPeriod(period),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: sel ? theme.cardColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(title, style: TextStyle(
          color: sel ? theme.textColor : theme.secondaryTextColor,
          fontSize: 10, fontWeight: sel ? FontWeight.bold : FontWeight.normal,
        )),
      ),
    ));
  }

  Widget _effectRow(String title, IconData icon, bool active,
      ValueChanged<bool> onChange, Color color, {bool isLoading = false}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(icon, size: 14, color: active ? color : theme.secondaryTextColor),
        const SizedBox(width: 6),
        Expanded(child: Text(title, style: TextStyle(
          color: active ? theme.textColor : theme.secondaryTextColor, fontSize: 12))),
        if (isLoading)
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
        else
          Switch(value: active, onChanged: onChange, activeColor: color,
            activeTrackColor: color.withValues(alpha: 0.3),
            inactiveThumbColor: theme.secondaryTextColor,
            inactiveTrackColor: theme.secondaryTextColor.withValues(alpha: 0.1),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ]));
  }

  Widget _qualityRow() {
    return Container(
      margin: const EdgeInsets.only(left: 20),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.secondaryTextColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        _qualOpt('Hafif', WindParticleQuality.light),
        _qualOpt('Dengeli', WindParticleQuality.balanced),
        _qualOpt('Yoğun', WindParticleQuality.heavy),
      ]),
    );
  }

  Widget _qualOpt(String title, WindParticleQuality q) {
    final sel = vm.windQuality == q;
    return Expanded(child: InkWell(
      onTap: () => vm.setWindQuality(q),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: sel ? theme.cardColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(title, style: TextStyle(
          color: sel ? Colors.cyanAccent : theme.secondaryTextColor,
          fontSize: 9.5, fontWeight: sel ? FontWeight.bold : FontWeight.normal,
        )),
      ),
    ));
  }
}

// ─── MapLibre 3D Bölümü ───────────────────────────────────────────────────────

class _MapLibreSection extends StatelessWidget {
  final ThemeViewModel theme;
  final MapViewModel vm;

  const _MapLibreSection({required this.theme, required this.vm});

  Widget _lbl(String text) => Text(
    text,
    style: TextStyle(color: theme.secondaryTextColor, fontSize: 11, fontWeight: FontWeight.w700),
  );

  @override
  Widget build(BuildContext context) {
    final heatmapActive = vm.mlHeatmapMode != MlHeatmapMode.none;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _lbl('Harita Stili'),
        const SizedBox(height: 6),
        ...MlBaseStyle.values.map(_styleOpt),

        const SizedBox(height: 12),
        _lbl('Isı Haritası'),
        const SizedBox(height: 6),
        _heatmapOpt('Güneş Potansiyeli', MlHeatmapMode.solar, Colors.orangeAccent, Icons.wb_sunny_outlined),
        _heatmapOpt('Rüzgar Potansiyeli', MlHeatmapMode.wind, Colors.cyanAccent, Icons.air),
        _heatmapOpt('Sıcaklık', MlHeatmapMode.temperature, Colors.deepOrangeAccent, Icons.thermostat_outlined),

        // Isı haritası parametreleri — sadece aktif modda göster
        if (heatmapActive) ...[
          const SizedBox(height: 10),
          _heatmapControls(context),
        ],

        const SizedBox(height: 12),
        _lbl('Pin Filtresi'),
        const SizedBox(height: 6),
        _effectRow('Pin Kümeleme', Icons.bubble_chart_outlined,
            vm.showPinClusters, Colors.tealAccent, vm.togglePinClustering, badge: 'JS'),
        const SizedBox(height: 4),
        _pinFilterSection(),

        const SizedBox(height: 12),
        _lbl('3D Efektler'),
        const SizedBox(height: 6),
        _effectRow('3D Türbinler', Icons.wind_power_outlined,
            vm.show3DTurbines, Colors.blueAccent, vm.toggleShow3DTurbines, badge: '3D'),
        _effectRow('3D Binalar', Icons.location_city_outlined,
            vm.show3DBuildings, Colors.indigoAccent, vm.toggleShow3DBuildings, badge: '3D'),
        _effectRow('3D Arazi', Icons.terrain_outlined,
            vm.show3DTerrain, Colors.teal, vm.toggleShow3DTerrain, badge: 'DEM'),
        _effectRow('Globe Projeksiyon', Icons.public_outlined,
            vm.showGlobe, Colors.deepPurpleAccent, vm.toggleShowGlobe),
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
