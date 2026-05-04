// lib/features/map/animation/time_simulation_controller.dart
//
// Aşama 1.B (yeniden) — Modern Zaman Simülasyonu Controller'ı.
//
// **Mimari:**
//   - Pure Dart `Timer.periodic` — JS bridge bağımlılığı yok.
//   - Tek görsel dil: ilçe choropleth. Her frame'de
//     `applyToChoropleth(metric, vals)` callback çağrılır → MapViewModel
//     `_choroplethData`'yı override eder, render path'i polygon'ları
//     yeniden boyar.
//   - State `TimeSimStatus` enum'unda — net lifecycle (idle → loading →
//     ready → playing/paused → ...).
//   - Animasyon kapanışında `restoreChoroplethCallback` ile orijinal
//     choropleth state geri gelir.
//
// **Önceki sistem (`map_viewmodel.dart` içinde dağılmış olan):**
// JS bridge'lere, `_animFrames`, `_animDistrictValues`, `_animProvinceValues`
// gibi parça state field'larına, çift legend mantığına bağlıydı. Bu controller
// onların hepsinin yerini alır.
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:frontend/core/network/api_service.dart';

enum TimeSimStatus { idle, loading, ready, playing, paused, error }

/// Tek bir frame: timestamp + ilçe değerleri map'i.
class TimeSimFrame {
  final String ts; // ISO "YYYY-MM-DD" veya "YYYY-MM-DDTHH:MM"
  final Map<String, double> values; // "İl|İlçe" → raw metric value

  const TimeSimFrame({required this.ts, required this.values});

  factory TimeSimFrame.parse(Map raw) {
    final ts = raw['ts']?.toString() ?? '';
    final v = <String, double>{};
    final src = raw['vals'];
    if (src is Map) {
      src.forEach((k, val) {
        if (k is String && val is num) v[k] = val.toDouble();
      });
    }
    return TimeSimFrame(ts: ts, values: v);
  }
}

class TimeSimulationController extends ChangeNotifier {
  final ApiService _api;
  final void Function(String metric, Map<String, double> vals) _applyToChoropleth;
  final VoidCallback _restoreChoropleth;

  TimeSimulationController({
    required ApiService api,
    required void Function(String, Map<String, double>) applyToChoropleth,
    required VoidCallback restoreChoropleth,
  })  : _api = api,
        _applyToChoropleth = applyToChoropleth,
        _restoreChoropleth = restoreChoropleth {
    // Default tarih aralığı = son 30 gün (DB max'i ilk yüklemede clamp eder)
    final now = DateTime.now();
    _endDate = DateTime(now.year, now.month, now.day);
    _startDate = _endDate.subtract(const Duration(days: 30));
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────
  bool _isOpen = false;
  bool get isOpen => _isOpen;

  TimeSimStatus _status = TimeSimStatus.idle;
  TimeSimStatus get status => _status;

  String? _error;
  String? get error => _error;

  // ── Konfigürasyon (kullanıcı değiştirir) ─────────────────────────────────
  late DateTime _startDate;
  late DateTime _endDate;
  String _metric = 'wind';        // wind | temperature | radiation
  String _interval = 'daily';     // daily | hourly
  double _speedFps = 5.0;

  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;
  String get metric => _metric;
  String get interval => _interval;
  double get speedFps => _speedFps;

  // ── DB max tarih (range bilgisi) ────────────────────────────────────────
  DateTime? _dataDailyMin, _dataDailyMax;
  DateTime? _dataHourlyMin, _dataHourlyMax;
  bool _userTouchedDates = false;

  DateTime? get dataDailyMin => _dataDailyMin;
  DateTime? get dataDailyMax => _dataDailyMax;
  DateTime? get dataHourlyMin => _dataHourlyMin;
  DateTime? get dataHourlyMax => _dataHourlyMax;

  /// UI alt-bilgi (ör. "Günlük 2015–2026 · Saatlik 2024–2026")
  String get rangeHint {
    String fmt(DateTime? d) =>
        d == null ? '?' : '${d.year}';
    final daily = (_dataDailyMin != null && _dataDailyMax != null)
        ? 'Günlük ${fmt(_dataDailyMin)}–${fmt(_dataDailyMax)}'
        : '';
    final hourly = (_dataHourlyMin != null && _dataHourlyMax != null)
        ? 'Saatlik ${fmt(_dataHourlyMin)}–${fmt(_dataHourlyMax)}'
        : '';
    return [daily, hourly].where((s) => s.isNotEmpty).join(' · ');
  }

  /// Tarih validasyon — kullanıcıya UI'da uyarı göstermek için.
  String? get dateRangeError {
    if (!_endDate.isAfter(_startDate) && !_endDate.isAtSameMomentAs(_startDate)) {
      return 'Bitiş tarihi başlangıçtan önce olamaz';
    }
    final span = _endDate.difference(_startDate).inDays + 1;
    if (_interval == 'hourly' && span > 30) {
      return 'Saatlik mod en fazla 30 gün — günlük seç ya da aralığı daralt';
    }
    if (_interval == 'daily' && span > 1825) {
      return 'Günlük mod en fazla ~5 yıl';
    }
    return null;
  }

  // ── Frame state ─────────────────────────────────────────────────────────
  List<TimeSimFrame> _frames = const [];
  int _currentIdx = 0;
  double _metricMin = 0, _metricMax = 1;
  Timer? _ticker;
  int _fetchSeq = 0;

  int get totalFrames => _frames.length;
  int get currentFrame => _currentIdx;
  String get currentTimestamp =>
      _frames.isEmpty ? '' : _frames[_currentIdx.clamp(0, _frames.length - 1)].ts;
  double get metricMin => _metricMin;
  double get metricMax => _metricMax;
  bool get hasData => _frames.isNotEmpty;
  bool get isPlaying => _status == TimeSimStatus.playing;

  // ── Setters (UI'dan çağrılır) ───────────────────────────────────────────
  void setStartDate(DateTime d) {
    _startDate = DateTime(d.year, d.month, d.day);
    _userTouchedDates = true;
    notifyListeners();
  }

  void setEndDate(DateTime d) {
    _endDate = DateTime(d.year, d.month, d.day);
    _userTouchedDates = true;
    notifyListeners();
  }

  void setMetric(String m) {
    if (_metric == m) return;
    _metric = m;
    notifyListeners();
  }

  void setInterval(String iv) {
    if (_interval == iv) return;
    _interval = iv;
    // Saatlik mod max 30 gün — kullanıcı eski aralıkta kalmasın
    if (iv == 'hourly') {
      final span = _endDate.difference(_startDate).inDays + 1;
      if (span > 30) {
        _startDate = _endDate.subtract(const Duration(days: 30));
      }
    }
    notifyListeners();
  }

  void setSpeed(double fps) {
    final clamped = fps.clamp(1.0, 30.0);
    if (_speedFps == clamped) return;
    _speedFps = clamped.toDouble();
    if (isPlaying) {
      _ticker?.cancel();
      _startTicker();
    }
    notifyListeners();
  }

  // ── Lifecycle: open / close ─────────────────────────────────────────────
  Future<void> open() async {
    if (_isOpen) return;
    _isOpen = true;
    notifyListeners();
    await _fetchRange();
  }

  void close() {
    _ticker?.cancel();
    _ticker = null;
    _fetchSeq++;
    _frames = const [];
    _currentIdx = 0;
    _status = TimeSimStatus.idle;
    _error = null;
    _userTouchedDates = false;
    _isOpen = false;
    _restoreChoropleth();
    notifyListeners();
  }

  // ── Data range ──────────────────────────────────────────────────────────
  Future<void> _fetchRange() async {
    try {
      final data = await _api.weather.fetchAnimationRange();
      final daily = data['daily'] as Map?;
      final hourly = data['hourly'] as Map?;
      if (daily != null) {
        final dMin = daily['min']?.toString();
        final dMax = daily['max']?.toString();
        if (dMin != null) _dataDailyMin = DateTime.tryParse(dMin);
        if (dMax != null) _dataDailyMax = DateTime.tryParse(dMax);
      }
      if (hourly != null) {
        final hMin = hourly['min']?.toString();
        final hMax = hourly['max']?.toString();
        if (hMin != null) _dataHourlyMin = DateTime.tryParse(hMin);
        if (hMax != null) _dataHourlyMax = DateTime.tryParse(hMax);
      }
      // Kullanıcı tarihlere dokunmadıysa default'u DB max'e clamp et
      if (!_userTouchedDates && _dataDailyMax != null) {
        _endDate = _dataDailyMax!;
        _startDate = _endDate.subtract(const Duration(days: 30));
      }
      notifyListeners();
    } catch (e) {
      // Range alınamazsa varsayılan aralıkla devam et — kritik değil
      if (kDebugMode) debugPrint('[TimeSim] range fetch hata: $e');
    }
  }

  // ── Load frames ─────────────────────────────────────────────────────────
  Future<void> load() async {
    if (dateRangeError != null) {
      _status = TimeSimStatus.error;
      _error = dateRangeError;
      notifyListeners();
      return;
    }

    _ticker?.cancel();
    _ticker = null;

    final seq = ++_fetchSeq;
    _status = TimeSimStatus.loading;
    _error = null;
    notifyListeners();

    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}'
        '-${d.month.toString().padLeft(2, '0')}'
        '-${d.day.toString().padLeft(2, '0')}';

    try {
      final data = await _api.weather.fetchAnimationData(
        start: fmt(_startDate),
        end: fmt(_endDate),
        metric: _metric,
        interval: _interval,
        format: 'districts',
      );
      // Stale fetch guard
      if (seq != _fetchSeq) return;

      final framesRaw = data['frames'] as List? ?? const [];
      _frames = framesRaw
          .whereType<Map>()
          .map(TimeSimFrame.parse)
          .where((f) => f.values.isNotEmpty)
          .toList(growable: false);

      _metricMin = (data['metric_min'] as num?)?.toDouble() ?? 0.0;
      _metricMax = (data['metric_max'] as num?)?.toDouble() ?? 1.0;

      if (_frames.isEmpty) {
        _status = TimeSimStatus.error;
        _error = 'Seçilen aralıkta veri bulunamadı';
      } else {
        _currentIdx = 0;
        _applyCurrentFrame();
        _status = TimeSimStatus.ready;
        _error = null;
      }
    } catch (e) {
      if (seq != _fetchSeq) return;
      _status = TimeSimStatus.error;
      _error = _humanizeError(e);
    }
    notifyListeners();
  }

  String _humanizeError(Object e) {
    final raw = e.toString().replaceFirst('Exception: ', '').trim();
    final lower = raw.toLowerCase();
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return 'İstek zaman aşımına uğradı — aralığı daralt veya tekrar dene';
    }
    if (lower.contains('socket') || lower.contains('connection')) {
      return 'Sunucuya bağlanılamadı — backend çalışıyor mu?';
    }
    if (lower.startsWith('400')) {
      return raw;
    }
    return raw.isEmpty ? 'Bilinmeyen hata' : raw;
  }

  // ── Playback ────────────────────────────────────────────────────────────
  void play() {
    if (_frames.isEmpty || isPlaying) return;
    _status = TimeSimStatus.playing;
    _startTicker();
    notifyListeners();
  }

  void _startTicker() {
    final period = Duration(milliseconds: (1000 / _speedFps).round().clamp(33, 1000));
    _ticker = Timer.periodic(period, (_) {
      if (_frames.isEmpty) return;
      _currentIdx = (_currentIdx + 1) % _frames.length;
      _applyCurrentFrame();
      notifyListeners();
    });
  }

  void pause() {
    _ticker?.cancel();
    _ticker = null;
    if (_status == TimeSimStatus.playing) {
      _status = TimeSimStatus.paused;
    }
    notifyListeners();
  }

  void seek(int idx) {
    if (_frames.isEmpty) return;
    _currentIdx = idx.clamp(0, _frames.length - 1);
    _applyCurrentFrame();
    notifyListeners();
  }

  void stepBy(int delta) => seek(_currentIdx + delta);

  void _applyCurrentFrame() {
    if (_frames.isEmpty) return;
    final f = _frames[_currentIdx.clamp(0, _frames.length - 1)];
    _applyToChoropleth(_metric, f.values);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
