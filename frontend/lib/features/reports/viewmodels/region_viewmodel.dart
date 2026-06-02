// lib/features/reports/viewmodels/region_viewmodel.dart
//
// RegionTab için viewmodel.
// /analysis/landing → 7 bölge listesi (chip selector)
// /analysis/region/{id} → seçili bölge detayı + iller + climate

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:frontend/core/base/base_view_model.dart';
import 'package:frontend/core/network/api_service.dart';

class RegionViewModel extends BaseViewModel {
  final ApiService _apiService;

  RegionViewModel(this._apiService);

  List<RegionMeta> _regions = [];
  RegionDetailData? _selectedRegion;
  String? _selectedRegionId;

  List<RegionMeta> get regions => _regions;
  RegionDetailData? get selectedRegion => _selectedRegion;
  String? get selectedRegionId => _selectedRegionId;

  Future<void> init({String? initialRegionId}) async {
    if (_regions.isNotEmpty) return;
    setBusy(true);
    try {
      // Landing'den bölge listesini al (zaten regions field'ı tek call'da var)
      final landing = await _apiService.analysis.fetchLanding(topN: 5);
      _regions = landing.regions;
      // İlk bölgeyi otomatik seç
      final firstId = initialRegionId ??
          (_regions.isNotEmpty ? _regions.first.id : null);
      if (firstId != null) {
        await _loadRegion(firstId);
      } else {
        setBusy(false);
      }
    } catch (e, st) {
      debugPrint('RegionVM.init hata: $e\n$st');
      setError(e.toString());
    }
  }

  Future<void> selectRegion(String regionId) async {
    if (_selectedRegionId == regionId) return;
    await _loadRegion(regionId);
  }

  // 2026-06-01: "En son istek kazanır" token'ı. Birden çok _loadRegion aynı
  // anda uçarsa (init default + landing pending, ya da hızlı bölge değişimi)
  // geç dönen eski cevabın yeni seçimi ezmesini engeller.
  int _loadToken = 0;

  Future<void> _loadRegion(String regionId) async {
    final token = ++_loadToken;
    setBusy(true);
    try {
      final detail = await _apiService.analysis.fetchRegionDetail(regionId);
      if (token != _loadToken) return; // bayat → daha yeni bir seçim yapıldı
      _selectedRegionId = regionId;
      _selectedRegion = detail;
      setBusy(false);
    } catch (e, st) {
      if (token != _loadToken) return;
      debugPrint('RegionVM.loadRegion hata: $e\n$st');
      setError(e.toString());
    }
  }

  Future<void> refresh() async {
    if (_selectedRegionId != null) {
      await _loadRegion(_selectedRegionId!);
    }
  }
}
