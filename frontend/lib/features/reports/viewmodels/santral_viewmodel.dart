// lib/features/reports/viewmodels/santral_viewmodel.dart
//
// Santral (Pin Extended) tab için viewmodel.
//   - Kullanıcının pin'leri
//   - Seçili pin için dönem bazlı üretim (today/week/month/year/total)
//
// Veri: GET /pins/ + GET /pins/{id}/generation

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:frontend/core/base/base_view_model.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/data/models/pin_model.dart';

class SantralViewModel extends BaseViewModel {
  final ApiService _api;

  SantralViewModel(this._api);

  List<Pin> _pins = [];
  Pin? _selectedPin;
  String _period = 'month'; // today | week | month | year | total
  PinGeneration? _generation;
  bool _generationLoading = false;
  // Pin lokasyonunun aylık iklim profili (type deep-dive grafikleri için)
  ClimateSeries? _climate;
  bool _climateLoading = false;

  List<Pin> get pins => _pins;
  Pin? get selectedPin => _selectedPin;
  String get period => _period;
  PinGeneration? get generation => _generation;
  bool get generationLoading => _generationLoading;
  ClimateSeries? get climate => _climate;
  bool get climateLoading => _climateLoading;

  static const periodLabels = <String, String>{
    'today': 'Bugün',
    'week': 'Hafta',
    'month': 'Ay',
    'year': 'Yıl',
    'total': 'Toplam',
  };

  Future<void> init({int? initialPinId}) async {
    if (_pins.isNotEmpty) return;
    setBusy(true);
    try {
      _pins = await _api.resource.fetchPins();
      setBusy(false);
      if (_pins.isNotEmpty) {
        final first = initialPinId != null
            ? _pins.cast<Pin?>().firstWhere(
                  (p) => p?.id == initialPinId,
                  orElse: () => _pins.first,
                )
            : _pins.first;
        await selectPin(first!);
      }
    } catch (e, st) {
      debugPrint('SantralVM.init hata: $e\n$st');
      setError(e.toString());
    }
  }

  Future<void> selectPin(Pin pin) async {
    _selectedPin = pin;
    _generation = null;
    _climate = null;
    notifyListeners();
    // Üretim + iklim paralel yüklenir
    await Future.wait([_loadGeneration(), _loadClimate()]);
  }

  Future<void> _loadClimate() async {
    final pin = _selectedPin;
    if (pin == null || pin.city == null || pin.city!.isEmpty) {
      _climate = null;
      return;
    }
    _climateLoading = true;
    notifyListeners();
    try {
      _climate = await _api.analysis.fetchProvinceClimate(pin.city!);
    } catch (e) {
      debugPrint('SantralVM climate hata: $e');
      _climate = null;
    } finally {
      _climateLoading = false;
      notifyListeners();
    }
  }

  Future<void> setPeriod(String period) async {
    if (_period == period) return;
    _period = period;
    notifyListeners();
    await _loadGeneration();
  }

  Future<void> _loadGeneration() async {
    final pin = _selectedPin;
    if (pin == null) return;
    _generationLoading = true;
    notifyListeners();
    try {
      _generation = await _api.resource.fetchPinGeneration(
        pin.id,
        period: _period,
      );
    } catch (e) {
      debugPrint('SantralVM generation hata: $e');
      _generation = null;
    } finally {
      _generationLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    _pins = [];
    final keepId = _selectedPin?.id;
    _selectedPin = null;
    _generation = null;
    await init(initialPinId: keepId);
  }
}
