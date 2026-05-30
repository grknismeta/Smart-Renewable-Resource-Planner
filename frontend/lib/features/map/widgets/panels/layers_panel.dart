import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import 'package:frontend/core/theme/theme_view_model.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'package:frontend/features/map/viewmodels/weather_time_mode.dart';
import 'package:frontend/features/map/animation/time_simulation_controller.dart';
import 'package:frontend/features/map/models/map_models.dart';

/// Katmanlar paneli — MapLibre harita kontrolleri.
class LayersPanel extends StatelessWidget {
  final ThemeViewModel theme;
  final MapViewModel mapViewModel;
  final VoidCallback? onClearMapSelection;

  const LayersPanel({
    super.key,
    required this.theme,
    required this.mapViewModel,
    this.onClearMapSelection,
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
              // Mobilde daha kısa panel (ekranın %65'i), masaüstünde %80
              maxHeight: MediaQuery.of(context).size.height *
                  (MediaQuery.of(context).size.width < 600 ? 0.60 : 0.80),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MapLibreSection(
                    theme: theme,
                    vm: mapViewModel,
                    onClearMapSelection: onClearMapSelection,
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
  final VoidCallback? onClearMapSelection;

  const _MapLibreSection({
    required this.theme,
    required this.vm,
    this.onClearMapSelection,
  });

  @override
  State<_MapLibreSection> createState() => _MapLibreSectionState();
}

class _MapLibreSectionState extends State<_MapLibreSection> {
  // Faz 3.4: Bulut katmanı demo dondurmasında devre dışı. Re-enable için
  // `true` yap; `[[INBOX]]` "Bulut düzeltme" bölümünde kalan TODO'lar var
  // (mobil port, zoom limit mesajı, yağmur/normal ayrımı, legend).
  static const bool _cloudLayerEnabled = false;

  // Aşama 3.B: 3D efektler aktif edildi.
  //   - 3D Türbinler: pin layer'ında genişletilmiş glow + halo stili
  //     (`_syncPins(is3D)` parametresi)
  //   - 3D Arazi (DEM): hillshade source (web+native) + gerçek terrain
  //     extrusion (web JS `srrpSetTerrain` shim) + pitch 55° + sky
  // İleri seviye glTF türbin modeli (custom WebGL layer) sonraki iterasyonda.
  static const bool _threeDEffectsEnabled = true;

  bool _toolsExpanded      = true;
  bool _styleExpanded      = true;
  bool _projectionExpanded = true;
  bool _choroplethExpanded = true;
  bool _pinExpanded        = true;
  bool _pinVisualExpanded  = true;
  bool _satelliteExpanded  = false;
  bool _windExpanded       = true;
  bool _effectsExpanded    = true;

  // 2026-05-17 — Pin görsel stili (gelecek özellik placeholder).
  // Şu an sadece 'Yuvarlak' aktif. V3 Tipi ve 3D Santral 'YAKINDA' badge'li.
  // İleride pin marker render'ı bu seçime göre değişir
  // (PinMarkerStyle enum + MapViewMapLibre.setPinMarkerStyle).
  int _pinVisualStyle = 0; // 0=Yuvarlak, 1=V3 Tipi, 2=3D Santral

  ThemeViewModel get theme => widget.theme;
  MapViewModel   get vm    => widget.vm;

  @override
  Widget build(BuildContext context) {
    final globeActive   = vm.showGlobe;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Araçlar ─────────────────────────────────────────────────────
        _SectionHeader(
          title: 'Araçlar', expanded: _toolsExpanded, theme: theme,
          onToggle: () => setState(() => _toolsExpanded = !_toolsExpanded),
        ),
        if (_toolsExpanded) ...[
          const SizedBox(height: 6),
          _toolButton(
            'Önerilen Bölgeler',
            Icons.auto_awesome_rounded,
            Colors.purpleAccent,
            vm.isRecommendationsPanelOpen,
            globeActive ? null : () => vm.toggleRecommendationsPanel(),
          ),
          _toolButton(
            'Bölge Modu',
            Icons.map_outlined,
            Colors.lightBlueAccent,
            vm.isRegionsModeActive,
            globeActive ? null : () {
              vm.openRegionMode();
              if (!vm.isProvinceModeActive) {
                widget.onClearMapSelection?.call();
              }
            },
          ),
          _toolButton(
            'İl Modu',
            Icons.apartment_rounded,
            Colors.tealAccent,
            vm.isProvincesModeActive,
            globeActive ? null : () {
              vm.openProvincesMode();
              if (!vm.isProvinceModeActive) {
                widget.onClearMapSelection?.call();
              }
            },
          ),
          _toolButton(
            'İlçe Modu',
            Icons.grid_view_rounded,
            Colors.orangeAccent,
            vm.isDistrictsModeActive,
            globeActive ? null : () {
              vm.openDistrictsMode();
              if (!vm.isProvinceModeActive) {
                widget.onClearMapSelection?.call();
              }
            },
          ),
          // 1.B (yeniden) — TimeSimulationController toggle.
          // Provider scope MapScreen'de açıldı; burada context.watch ile dinler.
          Builder(
            builder: (innerCtx) {
              final timeCtrl = innerCtx.watch<TimeSimulationController>();
              return _toolButton(
                'Zaman Simülasyonu',
                Icons.play_circle_outline_rounded,
                Colors.cyanAccent,
                timeCtrl.isOpen,
                globeActive
                    ? null
                    : () {
                        if (timeCtrl.isOpen) {
                          timeCtrl.close();
                        } else {
                          timeCtrl.open();
                        }
                      },
              );
            },
          ),
          // M-B.2/3 — ML İklim Projeksiyon Haritası (gelecek tahmini choropleth)
          _toolButton(
            'ML Projeksiyon',
            Icons.auto_graph_rounded,
            Colors.purpleAccent,
            vm.mlProjectionPanelOpen,
            globeActive ? null : vm.toggleMlProjectionPanel,
          ),
          // Aşama I — PostGIS MVT vektör katmanları (3 toggle)
          _toolButton(
            'Su Kaynakları',
            Icons.water_drop_rounded,
            Colors.lightBlueAccent,
            vm.showHydroLayer,
            globeActive ? null : vm.toggleHydroLayer,
          ),
          _toolButton(
            'Yasaklı Bölgeler',
            Icons.block_rounded,
            Colors.redAccent,
            vm.showRestrictedZoneLayer,
            globeActive ? null : vm.toggleRestrictedZoneLayer,
          ),
          // 2026-05-17 — 'İletim Hatları' butonu kaldırıldı (pin sistemi
          // refactor sırasında kullanıcı isteğiyle UI'dan çıkarıldı). VM
          // tarafındaki `toggleEnergyCorridorLayer`/`showEnergyCorridorLayer`
          // geriye uyum için durmaktadır.
        ],

        const SizedBox(height: 10),
        // ── Harita Stili ────────────────────────────────────────────────
        _SectionHeader(
          title: 'Harita Stili', expanded: _styleExpanded, theme: theme,
          onToggle: () => setState(() => _styleExpanded = !_styleExpanded),
        ),
        if (_styleExpanded) ...[
          const SizedBox(height: 6),
          // Tema ile otomatik eşitleme toggle
          InkWell(
            onTap: () => vm.setAutoMapStyleSync(!vm.autoMapStyleSync),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Icon(Icons.sync_rounded, size: 14,
                    color: vm.autoMapStyleSync ? Colors.deepPurpleAccent : theme.secondaryTextColor),
                const SizedBox(width: 8),
                Expanded(child: Text('Tema ile Eşitle', style: TextStyle(
                  color: vm.autoMapStyleSync ? theme.textColor : theme.secondaryTextColor, fontSize: 12))),
                if (vm.autoMapStyleSync)
                  const Icon(Icons.check_rounded, size: 13, color: Colors.deepPurpleAccent),
              ]),
            ),
          ),
          Divider(height: 1, color: theme.secondaryTextColor.withValues(alpha: 0.1)),
          const SizedBox(height: 4),
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
          _effectRow('Global Projeksiyon', Icons.public_outlined,
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
                  'Global projeksiyon açıkken Türkiye özellikleri devre dışı kalır. Kapattığınızda tüm ayarlar geri gelir.',
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
                // ── Tematik Harita (Choropleth) ─────────────────────
                _SectionHeader(
                  title: 'Tematik Harita', expanded: _choroplethExpanded, theme: theme,
                  onToggle: () => setState(() => _choroplethExpanded = !_choroplethExpanded),
                ),
                if (_choroplethExpanded) ...[
                  const SizedBox(height: 6),
                  // Zaman penceresi seçici — Anlık / Yıllık / Mevsim.
                  // Değişince hem provider hem viewmodel güncellenir; choropleth
                  // aktifse otomatik refetch olur.
                  _WeatherTimeModeSelector(vm: vm, theme: theme),
                  const SizedBox(height: 6),
                  _choroplethOpt('Güneş Işınımı', ChoroplethMode.solar, Colors.orangeAccent, Icons.wb_sunny_outlined),
                  _choroplethOpt('Rüzgar Hızı', ChoroplethMode.wind, Colors.cyanAccent, Icons.air),
                  _choroplethOpt('Sıcaklık', ChoroplethMode.temperature, Colors.deepOrangeAccent, Icons.thermostat_outlined),
                  if (vm.isChoroplethLoading)
                    Padding(
                      padding: const EdgeInsets.only(left: 36, top: 4),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(width: 12, height: 12, child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: theme.secondaryTextColor)),
                        const SizedBox(width: 6),
                        Text('Veri yükleniyor…',
                          style: TextStyle(fontSize: 10, color: theme.secondaryTextColor)),
                      ]),
                    ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(children: [
                      Icon(Icons.info_outline_rounded, size: 10,
                          color: theme.secondaryTextColor.withValues(alpha: 0.6)),
                      const SizedBox(width: 4),
                      Expanded(child: Text(
                        'İlçe poligonlarını güncel saat verisiyle renklendirir',
                        style: TextStyle(
                          color: theme.secondaryTextColor.withValues(alpha: 0.6),
                          fontSize: 9,
                        ),
                      )),
                    ]),
                  ),
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
                // ── Pin Görseli (gelecek özellik placeholder) ────────
                // 2026-05-17 — Kullanıcı isteği: pin marker stili seçimi.
                // Şu an sadece 'Yuvarlak' aktif; V3 Tipi ve 3D Santral
                // YAKINDA. PinMarkerStyle enum + harita widget sync
                // ilerideki sprint'te.
                _SectionHeader(
                  title: 'Pin Görseli',
                  expanded: _pinVisualExpanded,
                  theme: theme,
                  onToggle: () => setState(
                      () => _pinVisualExpanded = !_pinVisualExpanded),
                ),
                if (_pinVisualExpanded) ...[
                  const SizedBox(height: 6),
                  _pinVisualOpt(0, 'Yuvarlak', Icons.circle, Colors.tealAccent),
                  _pinVisualOpt(1, 'V3 Tipi', Icons.location_on_outlined,
                      Colors.amberAccent,
                      disabled: true, badge: 'YAKINDA'),
                  _pinVisualOpt(2, '3D Santral', Icons.view_in_ar_outlined,
                      Colors.deepPurpleAccent,
                      disabled: true, badge: 'YAKINDA'),
                ],

                const SizedBox(height: 10),
                // ── Uydu Katmanları ───────────────────────────────────
                _SectionHeader(
                  title: 'Uydu Katmanları', expanded: _satelliteExpanded, theme: theme,
                  onToggle: () => setState(() => _satelliteExpanded = !_satelliteExpanded),
                ),
                if (_satelliteExpanded) ...[
                  const SizedBox(height: 6),
                  // Bulut Örtüsü: Faz 3.4 (2026-04-22) — devre dışı.
                  // Kök sebepler henüz çözülmedi: telefonda görünmüyor, zoom
                  // limit uyarısı, yağmur/normal ayrımı yok, legend yok. Demo
                  // öncesi mobil parity riski büyük → toggle disable + "YAKINDA".
                  // Detaylı TODO: INBOX "Bulut düzeltme" bölümü.
                  // Re-enable için `_cloudLayerEnabled = true` yap (dosya başı).
                  _effectRow('Bulut Örtüsü', Icons.cloud_outlined,
                      _cloudLayerEnabled && vm.showCloudLayer,
                      const Color(0xFF90CAF9),
                      _cloudLayerEnabled ? vm.toggleShowCloudLayer : null,
                      badge: _cloudLayerEnabled ? 'SAT' : 'YAKINDA',
                      disabled: !_cloudLayerEnabled),
                  if (_cloudLayerEnabled && vm.showCloudLayer) ...[
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
                  if (vm.isWindLoading)
                    Padding(
                      padding: const EdgeInsets.only(left: 36, top: 4),
                      child: Text('Rüzgar verisi yükleniyor…',
                          style: TextStyle(fontSize: 11, color: theme.secondaryTextColor)),
                    ),
                  if (vm.showWindParticles && vm.windDataEmpty && !vm.isWindLoading)
                    Padding(
                      padding: const EdgeInsets.only(left: 36, top: 4),
                      child: Text('Rüzgar verisi mevcut değil',
                          style: TextStyle(fontSize: 11, color: Colors.orange.shade300)),
                    ),
                ],

                const SizedBox(height: 10),
                // ── 3D Efektler ───────────────────────────────────────
                _SectionHeader(
                  title: '3D Efektler', expanded: _effectsExpanded, theme: theme,
                  onToggle: () => setState(() => _effectsExpanded = !_effectsExpanded),
                ),
                if (_effectsExpanded) ...[
                  const SizedBox(height: 6),
                  // 3D Türbinler — demo dondurmasında devre dışı.
                  _effectRow(
                    '3D Türbinler',
                    Icons.wind_power_outlined,
                    _threeDEffectsEnabled && vm.show3DTurbines,
                    Colors.blueAccent,
                    _threeDEffectsEnabled ? vm.toggleShow3DTurbines : null,
                    badge: _threeDEffectsEnabled ? '3D' : 'YAKINDA',
                    disabled: !_threeDEffectsEnabled,
                  ),
                  // 3D Arazi — Sprint S2: AWS Terrarium CDN (terrarium PNG).
                  _effectRow(
                    '3D Arazi',
                    Icons.terrain_outlined,
                    _threeDEffectsEnabled && vm.show3DTerrain,
                    Colors.teal,
                    _threeDEffectsEnabled ? vm.toggleShow3DTerrain : null,
                    badge: _threeDEffectsEnabled ? 'DEM' : 'YAKINDA',
                    disabled: !_threeDEffectsEnabled,
                  ),
                  // 2026-05-17 S2 — Exaggeration slider: terrain aktifken
                  // dağların ne kadar abartılı görüneceğini ayarlar.
                  if (_threeDEffectsEnabled && vm.show3DTerrain) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.height, size: 12, color: theme.secondaryTextColor),
                      const SizedBox(width: 4),
                      Text('Yükseklik Abartısı',
                          style: TextStyle(color: theme.secondaryTextColor, fontSize: 10)),
                      const Spacer(),
                      Text('${vm.terrainExaggeration.toStringAsFixed(1)}×',
                          style: TextStyle(
                              color: Colors.teal,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ]),
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                        activeTrackColor: Colors.teal,
                        inactiveTrackColor: theme.secondaryTextColor.withValues(alpha: 0.2),
                        thumbColor: Colors.teal,
                        overlayColor: Colors.teal.withAlpha(40),
                      ),
                      child: Slider(
                        value: vm.terrainExaggeration,
                        min: 1.0,
                        max: 3.0,
                        divisions: 20,  // 0.1'lik adım
                        onChanged: vm.setTerrainExaggeration,
                      ),
                    ),
                    // 2026-05-19 — Hillshade gölge yoğunluğu slider.
                    // Dağların kabartma algısını arttırır (gölge/highlight).
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(Icons.invert_colors, size: 12, color: theme.secondaryTextColor),
                      const SizedBox(width: 4),
                      Text('Gölge Yoğunluğu',
                          style: TextStyle(color: theme.secondaryTextColor, fontSize: 10)),
                      const Spacer(),
                      Text(vm.hillshadeIntensity == 0
                              ? 'kapalı'
                              : '${(vm.hillshadeIntensity * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                              color: Colors.deepOrangeAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ]),
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                        activeTrackColor: Colors.deepOrangeAccent,
                        inactiveTrackColor: theme.secondaryTextColor.withValues(alpha: 0.2),
                        thumbColor: Colors.deepOrangeAccent,
                        overlayColor: Colors.deepOrangeAccent.withAlpha(40),
                      ),
                      child: Slider(
                        value: vm.hillshadeIntensity,
                        min: 0.0,
                        max: 1.5,
                        divisions: 15,  // 0.1'lik adım
                        onChanged: vm.setHillshadeIntensity,
                      ),
                    ),
                  ],
                ],

                // 2026-05-27 (O1): İzohips contour overlay toggle + opacity.
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: Text('İzohips (Kontur Çizgileri)',
                        style: TextStyle(color: theme.textColor, fontSize: 12)),
                  ),
                  Transform.scale(
                    scale: 0.75,
                    child: Switch(
                      value: vm.showContour,
                      onChanged: vm.setContourEnabled,
                      activeColor: const Color(0xFF8B4513), // toprak rengi
                    ),
                  ),
                ]),
                if (vm.showContour) ...[
                  Row(children: [
                    Text('Görünürlük',
                        style: TextStyle(
                            color: theme.secondaryTextColor, fontSize: 11)),
                    const Spacer(),
                    Text('${(vm.contourOpacity * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                            color: Color(0xFF8B4513),
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ]),
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 10),
                      activeTrackColor: const Color(0xFF8B4513),
                      inactiveTrackColor:
                          theme.secondaryTextColor.withValues(alpha: 0.2),
                      thumbColor: const Color(0xFF8B4513),
                      overlayColor: const Color(0xFF8B4513).withAlpha(40),
                    ),
                    child: Slider(
                      value: vm.contourOpacity,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      onChanged: vm.setContourOpacity,
                    ),
                  ),
                  // O2: Kaynak seçici — OpenTopoMap (raster) vs kendi MVT.
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Text('Kaynak',
                            style: TextStyle(
                                color: theme.secondaryTextColor,
                                fontSize: 11)),
                        const Spacer(),
                        _ContourSourceToggle(
                          value: vm.contourSource,
                          onChanged: vm.setContourSource,
                          theme: theme,
                        ),
                      ],
                    ),
                  ),
                  // O1.5/O2: Attribution chip — kaynağa göre.
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      vm.contourSource == 'self'
                          ? '© SRRP / SRTM (NASA)'
                          : '© OpenTopoMap (CC-BY-SA)',
                      style: TextStyle(
                        color: theme.secondaryTextColor.withValues(alpha: 0.55),
                        fontSize: 9,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
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

  /// Pin görsel stili seçim satırı (radio benzeri). Disabled olanlar tıklanmaz.
  Widget _pinVisualOpt(
    int value,
    String label,
    IconData icon,
    Color color, {
    bool disabled = false,
    String? badge,
  }) {
    final active = _pinVisualStyle == value;
    return Opacity(
      opacity: disabled ? 0.42 : 1.0,
      child: InkWell(
        onTap: disabled ? null : () => setState(() => _pinVisualStyle = value),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: active ? color.withValues(alpha: 0.18) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: active ? color : color.withValues(alpha: 0.3)),
              ),
              child: Icon(icon,
                  size: 13, color: active ? color : color.withValues(alpha: 0.5)),
            ),
            const SizedBox(width: 8),
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: active ? theme.textColor : theme.secondaryTextColor,
                        fontSize: 12))),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.secondaryTextColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(badge,
                    style: TextStyle(
                        color: theme.secondaryTextColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
              ),
            ],
            if (active && badge == null)
              Icon(Icons.check_circle_rounded, size: 14, color: color),
          ]),
        ),
      ),
    );
  }

  Widget _choroplethOpt(String label, ChoroplethMode mode, Color color, IconData icon) {
    final active = vm.choroplethMode == mode;
    return InkWell(
      onTap: () => vm.setChoroplethMode(active ? ChoroplethMode.none : mode),
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
          if (active) Icon(Icons.map_rounded, size: 12, color: color),
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

  /// Araçlar bölümündeki buton satırı — tıklanabilir, aktif durumda renk değişir
  Widget _toolButton(
    String label, IconData icon, Color color, bool active, VoidCallback? onTap,
  ) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.35 : 1.0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: active ? color.withValues(alpha: 0.18) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: active ? color : color.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(icon, size: 13,
                  color: active ? color : color.withValues(alpha: 0.5)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: TextStyle(
              color: active ? theme.textColor : theme.secondaryTextColor,
              fontSize: 12,
            ))),
            if (active)
              Icon(Icons.check_circle_rounded, size: 14, color: color),
          ]),
        ),
      ),
    );
  }
}

/// Tematik harita zaman penceresi seçici.
///
/// Tek dropdown 7 mod gösterir (Anlık / Hafta / Ay / 3 Ay / 6 Ay / Yıllık / Mevsim).
/// `custom` mod buradan görünmez — animasyon panelinin kendi tarih seçicisi var.
/// Mevsim seçilince altında 4 chip (Kış/İlkbahar/Yaz/Sonbahar) açılır.
class _WeatherTimeModeSelector extends StatelessWidget {
  final MapViewModel vm;
  final ThemeViewModel theme;

  const _WeatherTimeModeSelector({required this.vm, required this.theme});

  // Dropdown'da gösterilecek modlar — sıralama kullanıcıya alışkın olduğu yönde:
  // anlık → kısa vade → uzun vade → mevsim.
  static const List<WeatherTimeWindow> _menuModes = [
    WeatherTimeWindow.current,
    WeatherTimeWindow.week,
    WeatherTimeWindow.month,
    WeatherTimeWindow.threeMonth,
    WeatherTimeWindow.sixMonth,
    WeatherTimeWindow.yearly,
    WeatherTimeWindow.season,
    // 2026-05-28: Uzun pencereler (ayda bir precompute). "⚡" subtitle ile işaretli.
    WeatherTimeWindow.twoYear,
    WeatherTimeWindow.fiveYear,
    WeatherTimeWindow.tenYear,
  ];

  IconData _iconFor(WeatherTimeWindow w) {
    switch (w) {
      case WeatherTimeWindow.current:
        return Icons.access_time;
      case WeatherTimeWindow.week:
      case WeatherTimeWindow.month:
      case WeatherTimeWindow.threeMonth:
      case WeatherTimeWindow.sixMonth:
        return Icons.date_range_outlined;
      case WeatherTimeWindow.yearly:
        return Icons.calendar_today;
      case WeatherTimeWindow.season:
        return Icons.eco_outlined;
      case WeatherTimeWindow.twoYear:
      case WeatherTimeWindow.fiveYear:
      case WeatherTimeWindow.tenYear:
        return Icons.history_toggle_off;
      case WeatherTimeWindow.custom:
        return Icons.edit_calendar;
    }
  }

  String _subtitleFor(WeatherTimeWindow w) {
    switch (w) {
      case WeatherTimeWindow.current:
        return 'son 1 saat';
      case WeatherTimeWindow.week:
        return 'son 7 gün';
      case WeatherTimeWindow.month:
        return 'son 30 gün';
      case WeatherTimeWindow.threeMonth:
        return 'son 90 gün';
      case WeatherTimeWindow.sixMonth:
        return 'son 180 gün ⚡';
      case WeatherTimeWindow.yearly:
        return 'son 365 gün ⚡';
      case WeatherTimeWindow.season:
        return '365 g + mevsim ⚡';
      case WeatherTimeWindow.twoYear:
        return 'son 2 yıl ⚡';
      case WeatherTimeWindow.fiveYear:
        return 'son 5 yıl ⚡';
      case WeatherTimeWindow.tenYear:
        return 'son 10 yıl ⚡';
      case WeatherTimeWindow.custom:
        return 'manuel aralık';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WeatherTimeModeProvider>(
      builder: (context, mode, _) {
        final selectedWindow = mode.window;
        final isSeasonMode = selectedWindow == WeatherTimeWindow.season;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dropdown trigger — selected mode + label + chevron
            PopupMenuButton<WeatherTimeWindow>(
              tooltip: 'Zaman penceresi seç',
              position: PopupMenuPosition.under,
              color: theme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: Colors.blueAccent.withValues(alpha: 0.3),
                  width: 0.6,
                ),
              ),
              onSelected: (w) {
                mode.setWindow(w);
                // mode.apiMode null olabilir (custom) ama menu'de custom yok →
                // güvenli cast.
                vm.setWeatherTimeMode(
                  mode.apiMode ?? 'current',
                  mode.apiSeason,
                );
              },
              itemBuilder: (_) => _menuModes.map((w) {
                final selected = w == selectedWindow;
                return PopupMenuItem<WeatherTimeWindow>(
                  value: w,
                  height: 36,
                  child: Row(
                    children: [
                      Icon(
                        _iconFor(w),
                        size: 14,
                        color: selected
                            ? Colors.blueAccent
                            : theme.secondaryTextColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        w.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          color: selected
                              ? Colors.blueAccent
                              : theme.textColor,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _subtitleFor(w),
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.secondaryTextColor
                              .withValues(alpha: 0.7),
                        ),
                      ),
                      if (selected) ...[
                        const Spacer(),
                        const Icon(Icons.check, size: 14, color: Colors.blueAccent),
                      ],
                    ],
                  ),
                );
              }).toList(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blueAccent.withValues(alpha: 0.55),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _iconFor(selectedWindow),
                      size: 13,
                      color: Colors.blueAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      mode.displayLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '· ${_subtitleFor(selectedWindow)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.secondaryTextColor,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: Colors.blueAccent.withValues(alpha: 0.85),
                    ),
                  ],
                ),
              ),
            ),
            if (isSeasonMode) ...[
              const SizedBox(height: 5),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: WeatherSeason.values.map((s) {
                  final selected = mode.season == s;
                  return GestureDetector(
                    onTap: () {
                      mode.setSeason(s);
                      vm.setWeatherTimeMode('season', s.apiValue);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.greenAccent.withValues(alpha: 0.22)
                            : theme.cardColor.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? Colors.greenAccent.withValues(alpha: 0.7)
                              : theme.secondaryTextColor.withValues(alpha: 0.25),
                          width: selected ? 1 : 0.6,
                        ),
                      ),
                      child: Text(
                        s.displayName,
                        style: TextStyle(
                          fontSize: 10,
                          color: selected
                              ? Colors.greenAccent
                              : theme.secondaryTextColor,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// O2 — İzohips kaynak seçici (OpenTopoMap raster vs self-hosted MVT).
/// Kompakt iki-segmentli toggle.
class _ContourSourceToggle extends StatelessWidget {
  final String value; // 'opentopo' | 'self'
  final ValueChanged<String> onChanged;
  final ThemeViewModel theme;

  const _ContourSourceToggle({
    required this.value,
    required this.onChanged,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: theme.secondaryTextColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seg('OpenTopo', 'opentopo'),
          _seg('Kendi', 'self'),
        ],
      ),
    );
  }

  Widget _seg(String label, String key) {
    final active = value == key;
    return GestureDetector(
      onTap: () => onChanged(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF8B4513).withValues(alpha: 0.85)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : theme.secondaryTextColor,
            fontSize: 9.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
