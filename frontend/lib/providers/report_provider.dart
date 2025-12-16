import 'package:flutter/material.dart';
import '../core/api_service.dart';
import '../data/models/system_data_models.dart';

class ReportProvider extends ChangeNotifier {
  final ApiService _apiService;

  ReportProvider(this._apiService);

  bool _isLoading = false;
  RegionalReport? _currentReport;
  String _selectedRegion = 'Tümü';
  String _selectedType = 'Wind';
  RegionalSite? _focusedSite;

  bool get isLoading => _isLoading;
  RegionalReport? get report => _currentReport;
  String get selectedRegion => _selectedRegion;
  String get selectedType => _selectedType;
  RegionalSite? get focusedSite => _focusedSite;

  Future<void> fetchReport({String? region, String? type}) async {
    _selectedRegion = region ?? _selectedRegion;
    _selectedType = type ?? _selectedType;
    _isLoading = true;
    notifyListeners();

    try {
      _currentReport = await _apiService.fetchRegionalReport(
        region: _selectedRegion,
        type: _selectedType,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFocusedSite(RegionalSite? site) {
    _focusedSite = site;
    notifyListeners();
  }
}
