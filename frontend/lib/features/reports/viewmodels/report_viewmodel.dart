import 'package:flutter/foundation.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/data/models/system_data_models.dart';
import 'package:frontend/core/base/base_view_model.dart';
import 'package:flutter/material.dart' show debugPrint;

class ReportViewModel extends BaseViewModel {
  final ApiService _apiService;

  ReportViewModel(this._apiService);

  RegionalReport? _currentReport;
  String _selectedRegion = 'Tümü';
  String _selectedType = 'Wind';
  String _selectedInterval = 'Yıllık';
  String? _selectedProvince; // İl bazlı filtre (null = tüm iller)
  RegionalSite? _focusedSite;

  RegionalReport? get report => _currentReport;
  String get selectedRegion => _selectedRegion;
  String get selectedType => _selectedType;
  String get selectedInterval => _selectedInterval;
  String? get selectedProvince => _selectedProvince;
  RegionalSite? get focusedSite => _focusedSite;

  Future<void> fetchReport({
    String? region,
    String? type,
    String? interval,
    String? province,
    bool clearProvince = false,
  }) async {
    _selectedRegion = region ?? _selectedRegion;
    _selectedType = type ?? _selectedType;
    _selectedInterval = interval ?? _selectedInterval;
    if (clearProvince) {
      _selectedProvince = null;
    } else if (province != null) {
      _selectedProvince = province;
    }
    setBusy(true);

    try {
      _currentReport = await _apiService.report.fetchRegionalReport(
        region: _selectedRegion,
        type: _selectedType,
        interval: _selectedInterval,
        province: _selectedProvince,
      );
    } catch (e) {
      debugPrint('Rapor yüklenirken hata: $e');
      setError('Rapor yüklenemedi');
    } finally {
      setBusy(false);
    }
  }

  void setFocusedSite(RegionalSite? site) {
    _focusedSite = site;
    notifyListeners();
  }
}
