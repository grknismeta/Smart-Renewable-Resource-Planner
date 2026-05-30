import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/theme/theme_view_model.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/features/map/viewmodels/map_view_model.dart';

class MapDashboard extends StatefulWidget {
  final ThemeViewModel theme;

  const MapDashboard({super.key, required this.theme});

  @override
  State<MapDashboard> createState() => _MapDashboardState();
}

class _MapDashboardState extends State<MapDashboard> {
  Map<String, dynamic>? _status;
  Timer? _timer;

  /// 2026-05-25 (F1): Dar ekranlarda panel yatayda uzanıp sağ-üstteki "Pin Ekle"
  /// MapControlButton ile çakışıyordu (~55dp overlap, 1080×2340 cihazda). Şimdi
  /// kullanıcı toggle'layabilir; ilk açılışta ekran genişliğine göre default.
  /// `_userToggledCollapse` ile manuel seçim media query değişimini ezer.
  bool? _collapsed;
  bool _userToggledCollapse = false;

  // 2026-05-26 (M2): Layout toggle kullanıcıya bırakılmıyor; ekran genişliğine
  // göre otomatik (tall ↔ wide). Kullanıcı sadece pill (collapse) toggle eder.

  ThemeViewModel get theme => widget.theme;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final result = await api.weather.fetchCollectorStatus();
      if (mounted) setState(() => _status = result);
    } catch (_) {}
  }

  /// Türkiye sınırları içinde mi? (lat 35-43, lon 25-46)
  static bool _isInTurkey(double lat, double lon) {
    return lat >= 35.0 && lat <= 43.0 && lon >= 25.0 && lon <= 46.0;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MapViewModel>(
      builder: (context, mapViewModel, _) {
        final isGlobe = mapViewModel.showGlobe;
        final allPins = mapViewModel.pins;

        // Globe modunda tüm pinleri, normal modda sadece Türkiye pinlerini sayar
        final turkeyPins = allPins.where(
          (p) => _isInTurkey(p.latitude, p.longitude),
        ).toList();
        final globalPins = allPins.where(
          (p) => !_isInTurkey(p.latitude, p.longitude),
        ).toList();
        final activePins = isGlobe ? allPins : turkeyPins;

        // Pin sayılarını hesapla
        final windPins = activePins
            .where((p) => p.type == 'Rüzgar Türbini')
            .length;
        final solarPins = activePins
            .where((p) => p.type == 'Güneş Paneli')
            .length;
        final hesPins = activePins
            .where((p) => p.type == 'Hidroelektrik')
            .length;
        final totalCapacity = activePins.fold<double>(
          0,
          (sum, pin) => sum + pin.capacityMw,
        );

        // Globe modunda Türkiye dışı ekstra sayılar
        final globalWind = isGlobe
            ? globalPins.where((p) => p.type == 'Rüzgar Türbini').length
            : 0;
        final globalSolar = isGlobe
            ? globalPins.where((p) => p.type == 'Güneş Paneli').length
            : 0;
        final globalHes = isGlobe
            ? globalPins.where((p) => p.type == 'Hidroelektrik').length
            : 0;

        // Son güncelleme bilgisi
        final s = _status;
        final minutesAgo = s?['minutes_ago'] as int?;
        final healthy = s?['healthy'] == true;
        final updateLabel = minutesAgo == null
            ? null
            : minutesAgo <= 0
                ? 'az önce'
                : minutesAgo < 60
                    ? '$minutesAgo dk önce'
                    : '${(minutesAgo / 60).round()} sa önce';

        // Ekran genişliğine göre default collapse — kullanıcı manuel toggle
        // yapmışsa onun seçimi geçerli (toggleable across rebuilds).
        final screenW = MediaQuery.of(context).size.width;
        final autoCollapsed = screenW < 480;
        final collapsed = _userToggledCollapse
            ? (_collapsed ?? autoCollapsed)
            : autoCollapsed;
        // M2: Wide mode otomatik. Sağ üstte 3 buton var (~186-200px @ right:20).
        // Dashboard left:20. Wide ~360px ister. screenW ≥ 600 → wide sığar
        // ve "Santral Kur" butonuyla çakışmaz. <600 → tall (sığmayınca alta
        // katlanır anlamı: dikey yığılır).
        final wideMode = screenW >= 600;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 10 : (wideMode ? 12 : 16),
                vertical: collapsed ? 6 : (wideMode ? 10 : 16),
              ),
              decoration: BoxDecoration(
                color: theme.cardColor.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.secondaryTextColor.withValues(alpha: 0.1),
                ),
              ),
              child: collapsed
                  ? _collapsedView(
                      totalCapacity: totalCapacity,
                      pinCount: activePins.length,
                      onExpand: () => setState(() {
                        _collapsed = false;
                        _userToggledCollapse = true;
                      }),
                    )
                  : (wideMode
                      ? _wideView(
                          windPins: windPins,
                          solarPins: solarPins,
                          hesPins: hesPins,
                          globalWind: globalWind,
                          globalSolar: globalSolar,
                          globalHes: globalHes,
                          totalCapacity: totalCapacity,
                          updateLabel: updateLabel,
                          healthy: healthy,
                        )
                      : _expandedView(
                          windPins: windPins,
                          solarPins: solarPins,
                          hesPins: hesPins,
                          globalWind: globalWind,
                          globalSolar: globalSolar,
                          globalHes: globalHes,
                          totalCapacity: totalCapacity,
                          updateLabel: updateLabel,
                          healthy: healthy,
                          screenW: screenW,
                        )),
            ),
          ],
        );
      },
    );
  }

  void _doCollapse() {
    setState(() {
      _collapsed = true;
      _userToggledCollapse = true;
    });
  }

  /// M2 (2026-05-26): Sadece collapse butonu (kullanıcı toggle yok, layout
  /// auto). Eski "tall/wide toggle" ikonu kaldırıldı.
  Widget _collapseBtn() {
    return InkWell(
      onTap: _doCollapse,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: theme.secondaryTextColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.unfold_less_rounded,
          size: 14,
          color: theme.secondaryTextColor,
        ),
      ),
    );
  }

  /// L1 (2026-05-26): Wide mode — yatay 4 sütun.
  ///   ┌─────────┬─────────┬─────────┬──────────────┐
  ///   │ Rüzgar  │ Güneş   │ HES     │  KAPASİTE    │
  ///   │   6     │  12     │   3     │  142.5 MW    │
  ///   └─────────┴─────────┴─────────┴──────────────┘
  ///   sağ-altta layout toggle + collapse
  Widget _wideView({
    required int windPins,
    required int solarPins,
    required int hesPins,
    required int globalWind,
    required int globalSolar,
    required int globalHes,
    required double totalCapacity,
    required String? updateLabel,
    required bool healthy,
  }) {
    final divider = Container(
      width: 1,
      height: 38,
      color: theme.secondaryTextColor.withValues(alpha: 0.18),
    );
    // M2: IntrinsicWidth ile sar — alt Row'da MainAxisAlignment.spaceBetween
    // bounded width gerektirir. Eski Spacer() unbounded Row içinde Flutter
    // render exception fırlatıyordu (web'de capacity widget hiç görünmüyordu).
    return IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _wideStatItem(
                label: 'Rüzgar',
                count: windPins,
                color: windPins > 0
                    ? Colors.blueAccent
                    : theme.secondaryTextColor,
                globalExtra: globalWind > 0 ? '+$globalWind' : null,
              ),
              const SizedBox(width: 10),
              divider,
              const SizedBox(width: 10),
              _wideStatItem(
                label: 'Güneş',
                count: solarPins,
                color: solarPins > 0
                    ? Colors.orangeAccent
                    : theme.secondaryTextColor,
                globalExtra: globalSolar > 0 ? '+$globalSolar' : null,
              ),
              const SizedBox(width: 10),
              divider,
              const SizedBox(width: 10),
              _wideStatItem(
                label: 'HES',
                count: hesPins,
                color: hesPins > 0
                    ? const Color(0xFF29B6F6)
                    : theme.secondaryTextColor,
                globalExtra: globalHes > 0 ? '+$globalHes' : null,
              ),
              const SizedBox(width: 12),
              divider,
              const SizedBox(width: 12),
              // Kapasite — büyük yeşil
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KAPASİTE',
                    style: TextStyle(
                      color: theme.secondaryTextColor.withValues(alpha: 0.65),
                      fontSize: 9.5,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        totalCapacity.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'MW',
                        style: TextStyle(
                          color: Colors.greenAccent.withValues(alpha: 0.85),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (updateLabel != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color:
                            healthy ? Colors.greenAccent : Colors.orangeAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      updateLabel,
                      style: TextStyle(
                        color: theme.secondaryTextColor,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                )
              else
                const SizedBox.shrink(),
              _collapseBtn(),
            ],
          ),
        ],
      ),
    );
  }

  /// L1: Wide modda her stat item — dikey label + büyük sayı.
  Widget _wideStatItem({
    required String label,
    required int count,
    required Color color,
    String? globalExtra,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: theme.secondaryTextColor.withValues(alpha: 0.65),
            fontSize: 9.5,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
                height: 1.0,
              ),
            ),
            if (globalExtra != null) ...[
              const SizedBox(width: 3),
              Text(
                globalExtra,
                style: TextStyle(
                  color: color.withValues(alpha: 0.60),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// 2026-05-25 (G9): Expanded yeniden tasarım — 2 kolon kompakt layout.
  ///   Sol kolon: Rüzgar / Güneş / HES alt alta (font biraz büyük)
  ///   Sağ kolon: Kapasite (büyük yeşil, dikey ortada) + sağ üstte close (X)
  /// Widget boyutu küçüldü (~165dp) → "Santral Kur" butonuyla çakışmaz.
  /// Eski G1 layout (3 KPI Row + HES alt satır) silindi.
  Widget _expandedView({
    required int windPins,
    required int solarPins,
    required int hesPins,
    required int globalWind,
    required int globalSolar,
    required int globalHes,
    required double totalCapacity,
    required String? updateLabel,
    required bool healthy,
    required double screenW,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // SOL: Rüzgar / Güneş / HES — alt alta
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _compactStatRow(
                    'Rüzgar',
                    windPins,
                    windPins > 0
                        ? Colors.blueAccent
                        : theme.secondaryTextColor,
                    globalExtra: globalWind > 0 ? '+$globalWind' : null,
                  ),
                  const SizedBox(height: 6),
                  _compactStatRow(
                    'Güneş',
                    solarPins,
                    solarPins > 0
                        ? Colors.orangeAccent
                        : theme.secondaryTextColor,
                    globalExtra: globalSolar > 0 ? '+$globalSolar' : null,
                  ),
                  const SizedBox(height: 6),
                  _compactStatRow(
                    'HES',
                    hesPins,
                    hesPins > 0
                        ? const Color(0xFF29B6F6)
                        : theme.secondaryTextColor,
                    globalExtra: globalHes > 0 ? '+$globalHes' : null,
                  ),
                ],
              ),
              // Dikey ayraç
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  width: 1,
                  color: theme.secondaryTextColor.withValues(alpha: 0.20),
                ),
              ),
              // SAĞ: Kapasite (dikey ortada) + close butonu üstte
              // 2026-05-25 (H1): Collapse ikonu (↕) eski X yerine,
              // sağ-ALT köşede (kamera çentiği/üst notch'a değmesin diye
              // aşağıya taşındı). Kapasite içeriği üstte, collapse altta.
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'KAPASİTE',
                    style: TextStyle(
                      color: theme.secondaryTextColor.withValues(alpha: 0.65),
                      fontSize: 9.5,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    totalCapacity.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                      height: 1.0,
                    ),
                  ),
                  Text(
                    'MW',
                    style: TextStyle(
                      color: Colors.greenAccent.withValues(alpha: 0.85),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // M2: Sadece collapse ikonu (kullanıcı toggle yok).
                  Align(
                    alignment: Alignment.bottomRight,
                    child: _collapseBtn(),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Son güncelleme satırı
        if (updateLabel != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: healthy ? Colors.greenAccent : Colors.orangeAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'Son güncelleme: $updateLabel',
                style: TextStyle(
                  color: theme.secondaryTextColor,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// G9: Sol kolon kompakt satır — "Rüzgar 6" tek satırda, etiket büyük,
  /// sayı renkli. Eski _buildStatItem dikey ikinci-satır mantığı yerine
  /// burada yatay düzen kullanılıyor (kompaktlık için).
  Widget _compactStatRow(
    String label,
    int count,
    Color valueColor, {
    String? globalExtra,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 13, // G9: font biraz büyütüldü (12 → 13)
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          '$count',
          style: TextStyle(
            color: valueColor,
            fontSize: 17,
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (globalExtra != null) ...[
          const SizedBox(width: 3),
          Text(
            globalExtra,
            style: TextStyle(
              color: valueColor.withValues(alpha: 0.60),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  /// Collapsed pill: "⚡ X.X MW · N pin  ⤵" — sağ-üstteki Pin Ekle butonuna
  /// çakışmayacak kadar dar (~150dp). Tap → expand.
  Widget _collapsedView({
    required double totalCapacity,
    required int pinCount,
    required VoidCallback onExpand,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onExpand,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, size: 14, color: Colors.greenAccent),
          const SizedBox(width: 4),
          Text(
            '${totalCapacity.toStringAsFixed(1)} MW',
            style: const TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          Container(width: 1, height: 12, color: theme.secondaryTextColor.withValues(alpha: 0.3)),
          const SizedBox(width: 6),
          Text(
            '$pinCount pin',
            style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
          ),
          const SizedBox(width: 4),
          Icon(Icons.unfold_more_rounded, size: 14, color: theme.secondaryTextColor),
        ],
      ),
    );
  }

// 2026-05-25 (G9): Eski `_divider` ve `_buildStatItem` helper'ları silindi
// — yeni 2-kolon layout `_compactStatRow` kullanıyor.
}
