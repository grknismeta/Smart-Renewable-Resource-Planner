// lib/features/map/widgets/panels/ml_projection_panel.dart
//
// M-B.2/3 — ML İklim Projeksiyon Haritası paneli.
//
// Ana harita choropleth'ini gelecek ML tahminiyle boyar; yıl slider + ▶ ile
// 2026→2035 arası "iklim nasıl değişiyor" animasyonu. Backend: /ml/choropleth
// (precompute ml_forecast tablosu). Renk: min-max normalize (srrpSetMlChoropleth).
//
// Kendi state'ini tutar; harita bridge'ini doğrudan sürer (MapViewMapLibre).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/map/widgets/map_view_maplibre.dart';

class MlProjectionPanel extends StatefulWidget {
  final ThemeViewModel theme;
  final VoidCallback onClose;
  const MlProjectionPanel({super.key, required this.theme, required this.onClose});

  @override
  State<MlProjectionPanel> createState() => _MlProjectionPanelState();
}

class _MlProjectionPanelState extends State<MlProjectionPanel> {
  String _resource = 'solar';
  String _metric = 'sunshine';
  String _scenario = 'baseline';
  int _year = 2026;
  int _month = 1; // M-H.4: aylık adımlama
  int _minYear = 2026, _maxYear = 2035;
  bool _loading = false;
  bool _playing = false;
  String? _error;
  Timer? _ticker;
  int _seq = 0;
  // M-H.3: legend için response'tan min/max + lokasyon sayısı + örnek değer
  double? _valMin, _valMax;
  int _locCount = 0;

  static const _monthLabelsTr = <String>[
    'Oca','Şub','Mar','Nis','May','Haz',
    'Tem','Ağu','Eyl','Eki','Kas','Ara',
  ];

  /// Toplam ay sayısı (10 yıl × 12 = 120 max).
  int get _totalMonths => (_maxYear - _minYear + 1) * 12;

  /// Mevcut (year, month) çiftinin global ay indeksi (0-based).
  int get _monthIndex => (_year - _minYear) * 12 + (_month - 1);

  static const _resourceMetrics = <String, List<MapEntry<String, String>>>{
    'solar': [MapEntry('sunshine', 'Güneşlenme'), MapEntry('cloud', 'Bulutluluk')],
    'wind': [MapEntry('cloud', 'Bulutluluk'), MapEntry('precipitation', 'Yağış')],
    'hydro': [MapEntry('discharge', 'Nehir Debisi'), MapEntry('precipitation', 'Yağış')],
  };

  static const _scenarios = <MapEntry<String, String>>[
    MapEntry('baseline', 'Baz'),
    MapEntry('rcp45', 'RCP 4.5'),
    MapEntry('rcp85', 'RCP 8.5'),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(_initYears);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    MapViewMapLibre.clearMlChoropleth();
    super.dispose();
  }

  Future<void> _initYears() async {
    try {
      final api = context.read<ApiService>();
      final (mn, mx) = await api.ml.mlChoroplethYears(
        metric: _metric, resource: _resource);
      if (!mounted) return;
      setState(() {
        _minYear = mn;
        _maxYear = mx;
        _year = mn;
      });
    } catch (_) {}
    await _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      // M-F: level=district → ilçe seviyesi (varsa) + il fallback.
      // Backend yanıtı her iki granülerliği de içerir (district key "İl|İlçe" +
      // düz "İl"); frontend choropleth ilçe polygon ilk eşleşmeyi alır.
      // M-H.4: ay parametresi (1-12). Backend tek ay değerini döndürür,
      // 12-ay AVG yerine spesifik ay → animasyon ay-bazlı akıcı olur.
      final resp = await api.ml.mlChoropleth(
        metric: _metric, year: _year, month: _month, resource: _resource,
        scenario: _scenario, level: 'district',
      );
      if (!mounted || seq != _seq) return;
      MapViewMapLibre.setMlChoropleth(jsonEncode(resp.scores));
      setState(() {
        _loading = false;
        _valMin = resp.min;
        _valMax = resp.max;
        _locCount = resp.scores.length;
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _setResource(String r) {
    final metrics = _resourceMetrics[r] ?? const [];
    setState(() {
      _resource = r;
      if (metrics.isNotEmpty && !metrics.any((m) => m.key == _metric)) {
        _metric = metrics.first.key;
      }
    });
    _load();
  }

  void _togglePlay() {
    if (_playing) {
      _ticker?.cancel();
      setState(() => _playing = false);
      return;
    }
    setState(() => _playing = true);
    // M-H.4: aylık adımlama (350ms — 10y × 12 ay × 350ms ≈ 42 sn full döngü)
    _ticker = Timer.periodic(const Duration(milliseconds: 350), (_) {
      if (!mounted) return;
      var nextIdx = _monthIndex + 1;
      if (nextIdx >= _totalMonths) nextIdx = 0;
      setState(() {
        _year = _minYear + nextIdx ~/ 12;
        _month = (nextIdx % 12) + 1;
      });
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final metrics = _resourceMetrics[_resource] ?? const [];
    return Container(
      width: 360,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 16),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Başlık
          Row(
            children: [
              const Icon(Icons.auto_graph_rounded,
                  color: Colors.purpleAccent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ML İklim Projeksiyonu',
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_loading)
                const SizedBox(
                  width: 13, height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6, color: Colors.purpleAccent),
                ),
              IconButton(
                icon: Icon(Icons.close, size: 16, color: theme.secondaryTextColor),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: widget.onClose,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Kaynak chip'leri
          Row(
            children: [
              _chip('Solar', _resource == 'solar', () => _setResource('solar'),
                  const Color(0xFFF59E0B)),
              const SizedBox(width: 6),
              _chip('Wind', _resource == 'wind', () => _setResource('wind'),
                  const Color(0xFF3B82F6)),
              const SizedBox(width: 6),
              _chip('Hydro', _resource == 'hydro', () => _setResource('hydro'),
                  const Color(0xFF06B6D4)),
            ],
          ),
          const SizedBox(height: 6),
          // Metric chip'leri
          Wrap(
            spacing: 6,
            children: [
              for (final m in metrics)
                _chip(m.value, _metric == m.key, () {
                  setState(() => _metric = m.key);
                  _load();
                }, Colors.purpleAccent, small: true),
            ],
          ),
          const SizedBox(height: 6),
          // Senaryo chip'leri
          Row(
            children: [
              for (final s in _scenarios) ...[
                _chip(s.value, _scenario == s.key, () {
                  setState(() => _scenario = s.key);
                  _load();
                }, const Color(0xFFEF4444), small: true),
                const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // Yıl slider + play
          Row(
            children: [
              IconButton(
                icon: Icon(_playing ? Icons.pause_circle : Icons.play_circle,
                    color: Colors.purpleAccent, size: 30),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: _togglePlay,
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    activeTrackColor: Colors.purpleAccent,
                    inactiveTrackColor:
                        theme.secondaryTextColor.withValues(alpha: 0.2),
                    thumbColor: Colors.purpleAccent,
                    overlayColor: Colors.purpleAccent.withValues(alpha: 0.15),
                  ),
                  child: Slider(
                    // M-H.4: ay-bazlı slider (10y × 12 = 120 step)
                    value: _monthIndex.toDouble().clamp(
                        0, (_totalMonths - 1).toDouble()),
                    min: 0,
                    max: (_totalMonths - 1).toDouble(),
                    divisions: _totalMonths - 1,
                    label: '$_year-${_month.toString().padLeft(2, "0")}',
                    onChanged: (v) {
                      if (_playing) _togglePlay();
                      final idx = v.toInt();
                      setState(() {
                        _year = _minYear + idx ~/ 12;
                        _month = (idx % 12) + 1;
                      });
                    },
                    onChangeEnd: (_) => _load(),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                // M-H.4: yıl-ay rozeti (ör. "Mar 2028")
                child: Text(
                    '${_monthLabelsTr[_month - 1]} $_year',
                    style: const TextStyle(
                      color: Colors.purpleAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 10)),
            )
          else ...[
            const SizedBox(height: 8),
            // M-H.3: Renk skalası legend — min→max gradient + birim
            _legend(theme),
            const SizedBox(height: 6),
            // M-J.1: Baz vs senaryo açıklayıcı not — flat-218 yanılgısını önle
            Text(
              _scenarioHint(),
              style: TextStyle(
                  color: theme.secondaryTextColor.withValues(alpha: 0.72),
                  fontSize: 9.5,
                  height: 1.35),
            ),
          ],
        ],
      ),
    );
  }

  // M-H.3: renk skalası legend
  Widget _legend(ThemeViewModel theme) {
    final min = _valMin;
    final max = _valMax;
    if (min == null || max == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(_metricLabel(_metric),
                style: TextStyle(
                    color: theme.textColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('$_locCount lokasyon',
                style: TextStyle(
                    color: theme.secondaryTextColor.withValues(alpha: 0.6),
                    fontSize: 9)),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            // Solar/sunshine: purple (düşük) → yeşil → sarı (yüksek).
            // M-G.2'de metric'e göre değişken renk skalası eklenebilir.
            gradient: const LinearGradient(colors: [
              Color(0xFF581C87),  // mor (düşük)
              Color(0xFF7C3AED),
              Color(0xFF3B82F6),  // mavi
              Color(0xFF10B981),  // yeşil
              Color(0xFFEAB308),  // sarı
              Color(0xFFFCD34D),  // açık sarı (yüksek)
            ]),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(_fmtVal(min),
                style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(_fmtVal((min + max) / 2),
                style: TextStyle(
                    color: theme.secondaryTextColor.withValues(alpha: 0.6),
                    fontSize: 9)),
            const Spacer(),
            Text(_fmtVal(max),
                style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  String _metricLabel(String m) {
    switch (m) {
      case 'sunshine': return 'Güneşlenme (MJ/m²/gün)';
      case 'cloud': return 'Bulutluluk (%)';
      case 'precipitation': return 'Yağış (mm/ay)';
      case 'discharge': return 'Nehir Debisi (m³/s)';
      default: return m;
    }
  }

  String _fmtVal(double v) {
    if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v.abs() >= 10) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }

  String _scenarioHint() {
    // M-J.1: kullanıcı flat-yıllık görünce kafası karışmasın — net açıkla.
    final yrSpan = _maxYear - _minYear;
    switch (_scenario) {
      case 'baseline':
        return 'Baz · ML modelin geçmişten öğrendiği trend ($yrSpan yıl ileri). '
               'İklim değişimi katkısı YOK — yıl-yıl drift küçük olabilir.';
      case 'rcp45':
        return 'RCP 4.5 (orta emisyon) · Baz trendin üzerine IPCC ısınma '
               'projeksiyonu eklenir (~+1.5°C 2050\'ye).';
      case 'rcp85':
        return 'RCP 8.5 (yüksek emisyon) · Baz + IPCC yüksek-ısınma '
               'projeksiyonu (~+2.5°C 2050\'ye).';
      default:
        return '';
    }
  }

  Widget _chip(String label, bool active, VoidCallback onTap, Color color,
      {bool small = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: small ? 8 : 10, vertical: small ? 4 : 6),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: active
                ? color.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? color : widget.theme.secondaryTextColor,
            fontSize: small ? 10.5 : 11.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
