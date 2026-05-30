// lib/features/reports/viewmodels/projection_viewmodel.dart
//
// Sprint P2 — SARIMAX projeksiyon viewmodel'i.
//
// İki mod:
//   - PinProjectionMode: kullanıcının pin'i için generation forecast
//   - ProvinceProjectionMode: 81 ilden biri için climatology forecast
//
// Backend: /ml/project/pin/{id} | /ml/project/province/{name}

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:frontend/core/base/base_view_model.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/data/models/pin_model.dart';

enum ProjectionMode { pin, province }

class ProjectionViewModel extends BaseViewModel {
  final ApiService _api;

  ProjectionViewModel(this._api);

  // ── Mod + seçimler ─────────────────────────────────────────────────────────
  ProjectionMode _mode = ProjectionMode.pin;
  ProjectionMode get mode => _mode;

  // Pin modu
  List<Pin> _pins = [];
  Pin? _selectedPin;
  List<Pin> get pins => _pins;
  Pin? get selectedPin => _selectedPin;

  // İl modu
  List<String> _provinces = [];
  String? _selectedProvince;
  String _provinceResource = 'solar'; // solar | wind | hydro
  String _provinceMetric = 'sunshine'; // sunshine | precipitation | cloud | discharge
  List<String> get provinces => _provinces;
  String? get selectedProvince => _selectedProvince;
  String get provinceResource => _provinceResource;
  String get provinceMetric => _provinceMetric;

  // Horizon (1-10 yıl)
  int _years = 5;
  int get years => _years;

  // Forecast result
  MlForecastResponse? _forecast;
  bool _forecastLoading = false;
  String? _forecastError;
  MlForecastResponse? get forecast => _forecast;
  bool get forecastLoading => _forecastLoading;
  String? get forecastError => _forecastError;

  // Health
  MlHealth? _health;
  MlHealth? get health => _health;

  // ── Init ───────────────────────────────────────────────────────────────────

  Future<void> init({int? initialPinId, String? initialProvince}) async {
    if (_pins.isNotEmpty || _provinces.isNotEmpty) return;
    setBusy(true);
    try {
      // Health check (paralel)
      _api.ml.health().then((h) {
        _health = h;
        notifyListeners();
      }).catchError((e) {
        debugPrint('ML health err: $e');
      });

      // Pin'leri yükle
      try {
        _pins = await _api.resource.fetchPins();
      } catch (e) {
        debugPrint('ProjectionVM pins err: $e');
        _pins = [];
      }

      // 81 il listesini analysis/landing'ten al (cache'lenmiş olur)
      try {
        final landing = await _api.analysis.fetchLanding(topN: 1);
        final pset = <String>{};
        for (final r in landing.regions) {
          pset.addAll(r.provinces);
        }
        _provinces = pset.toList()..sort();
      } catch (e) {
        debugPrint('ProjectionVM provinces err: $e');
        _provinces = [];
      }

      // İlk seçim
      if (initialPinId != null) {
        final m = _pins.cast<Pin?>().firstWhere(
              (p) => p?.id == initialPinId,
              orElse: () => null,
            );
        if (m != null) {
          _mode = ProjectionMode.pin;
          await selectPin(m);
        }
      } else if (initialProvince != null && _provinces.contains(initialProvince)) {
        _mode = ProjectionMode.province;
        await selectProvince(initialProvince);
      } else if (_pins.isNotEmpty) {
        _mode = ProjectionMode.pin;
        await selectPin(_pins.first);
      } else if (_provinces.isNotEmpty) {
        _mode = ProjectionMode.province;
        await selectProvince(_provinces.first);
      }
      setBusy(false);
    } catch (e, st) {
      debugPrint('ProjectionVM.init hata: $e\n$st');
      setError(e.toString());
    }
  }

  // ── Mod değişimleri ────────────────────────────────────────────────────────

  Future<void> setMode(ProjectionMode m) async {
    if (_mode == m) return;
    _mode = m;
    _forecast = null;
    _forecastError = null;
    notifyListeners();
    await _refresh();
  }

  Future<void> selectPin(Pin pin) async {
    _selectedPin = pin;
    _mode = ProjectionMode.pin;
    notifyListeners();
    await _refresh();
  }

  Future<void> selectProvince(String name) async {
    _selectedProvince = name;
    _mode = ProjectionMode.province;
    notifyListeners();
    await _refresh();
  }

  Future<void> setProvinceResource(String r) async {
    if (_provinceResource == r) return;
    _provinceResource = r;
    // Resource değişince varsayılan metric
    _provinceMetric = switch (r) {
      'solar' => 'sunshine',
      'wind' => 'cloud', // wind için rüzgar verisi climatology'de yok, cloud cover proxy
      'hydro' => 'discharge',
      _ => 'sunshine',
    };
    notifyListeners();
    if (_mode == ProjectionMode.province) await _refresh();
  }

  Future<void> setProvinceMetric(String m) async {
    if (_provinceMetric == m) return;
    _provinceMetric = m;
    notifyListeners();
    if (_mode == ProjectionMode.province) await _refresh();
  }

  Future<void> setYears(int y) async {
    final clamped = y.clamp(1, 10);
    if (_years == clamped) return;
    _years = clamped;
    notifyListeners();
    await _refresh();
  }

  // ── Forecast çağrısı ───────────────────────────────────────────────────────

  Future<void> _refresh() async {
    _forecastLoading = true;
    _forecastError = null;
    notifyListeners();
    try {
      if (_mode == ProjectionMode.pin) {
        final pin = _selectedPin;
        if (pin == null) {
          _forecast = null;
        } else {
          _forecast = await _api.ml.forecastPin(pinId: pin.id, years: _years);
        }
      } else {
        final prov = _selectedProvince;
        if (prov == null) {
          _forecast = null;
        } else {
          _forecast = await _api.ml.forecastProvince(
            province: prov,
            years: _years,
            resource: _provinceResource,
            metric: _provinceMetric,
          );
        }
      }
    } catch (e) {
      debugPrint('ProjectionVM forecast err: $e');
      _forecastError = e.toString();
      _forecast = null;
    } finally {
      _forecastLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => _refresh();
}
