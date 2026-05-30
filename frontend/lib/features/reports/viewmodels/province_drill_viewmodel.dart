// lib/features/reports/viewmodels/province_drill_viewmodel.dart
//
// İl Analizi tab'ı v3 için viewmodel.
//   - 81 il listesi (landing endpoint'inden)
//   - Seçili il için: ilçe skorları + best spots + aylık iklim
//   - 2 sub-tab: Potansiyel | Hava

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:frontend/core/base/base_view_model.dart';
import 'package:frontend/core/network/api_service.dart';

enum ProvinceDrillSubTab { potential, weather, projection }

class ProvinceDrillViewModel extends BaseViewModel {
  final ApiService _apiService;

  ProvinceDrillViewModel(this._apiService);

  // İl listesi (alfabetik, 81 il)
  List<String> _allProvinces = [];
  String? _selectedProvince;

  // Seçili il verisi
  ProvinceDistrictsData? _districts;
  ClimateSeries? _climate;

  ProvinceDrillSubTab _subTab = ProvinceDrillSubTab.potential;
  bool _detailLoading = false;

  List<String> get allProvinces => _allProvinces;
  String? get selectedProvince => _selectedProvince;
  ProvinceDistrictsData? get districts => _districts;
  ClimateSeries? get climate => _climate;
  ProvinceDrillSubTab get subTab => _subTab;
  bool get detailLoading => _detailLoading;

  Future<void> init({String? initialProvince}) async {
    if (_allProvinces.isNotEmpty) return;
    setBusy(true);
    try {
      final landing = await _apiService.analysis.fetchLanding(topN: 5);
      final provinces = <String>{};
      for (final r in landing.regions) {
        provinces.addAll(r.provinces);
      }
      _allProvinces = provinces.toList()..sort();
      final first = initialProvince ??
          (_allProvinces.isNotEmpty ? _allProvinces.first : null);
      if (first != null) {
        setBusy(false);
        await selectProvince(first);
      } else {
        setBusy(false);
      }
    } catch (e, st) {
      debugPrint('ProvinceDrillVM.init hata: $e\n$st');
      setError(e.toString());
    }
  }

  Future<void> selectProvince(String name) async {
    if (_selectedProvince == name && _districts != null) return;
    _selectedProvince = name;
    _detailLoading = true;
    _districts = null;
    _climate = null;
    notifyListeners();
    try {
      // Paralel fetch — districts + climate
      final results = await Future.wait([
        _apiService.analysis.fetchProvinceDistricts(name),
        _apiService.analysis.fetchProvinceClimate(name),
      ]);
      _districts = results[0] as ProvinceDistrictsData;
      _climate = results[1] as ClimateSeries;
      _detailLoading = false;
      notifyListeners();
    } catch (e, st) {
      debugPrint('ProvinceDrillVM.selectProvince hata: $e\n$st');
      _detailLoading = false;
      setError(e.toString());
    }
  }

  void setSubTab(ProvinceDrillSubTab tab) {
    if (_subTab == tab) return;
    _subTab = tab;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_selectedProvince != null) {
      final p = _selectedProvince!;
      _selectedProvince = null; // selectProvince guard'ını geç
      await selectProvince(p);
    }
  }
}
