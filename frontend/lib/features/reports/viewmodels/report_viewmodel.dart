import 'package:flutter/material.dart' show debugPrint;
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/data/models/system_data_models.dart';
import 'package:frontend/data/models/weather_model.dart';
import 'package:frontend/core/base/base_view_model.dart';

/// Zaman aralığı modu
enum DateRangeMode { yearly, monthly, custom }

class ReportViewModel extends BaseViewModel {
  final ApiService _apiService;

  ReportViewModel(this._apiService);

  WeatherService get _weatherService => _apiService.weather;

  // ── Mevcut rapor state ────────────────────────────────────────────────────
  RegionalReport? _currentReport;
  String _selectedRegion = 'Tümü';
  String _selectedType = 'Wind';
  String _selectedInterval = 'Yıllık';
  String? _selectedProvince;
  RegionalSite? _focusedSite;

  RegionalReport? get report => _currentReport;
  String get selectedRegion => _selectedRegion;
  String get selectedType => _selectedType;
  String get selectedInterval => _selectedInterval;
  String? get selectedProvince => _selectedProvince;
  RegionalSite? get focusedSite => _focusedSite;

  // ── Zaman aralığı state ───────────────────────────────────────────────────
  DateRangeMode _dateRangeMode = DateRangeMode.yearly;
  List<int> _availableYears = [];
  int? _selectedYear;
  int? _selectedMonth;       // null = tüm yıl (yıllık özet)
  DateTime? _customRangeStart;
  DateTime? _customRangeEnd;

  DateRangeMode get dateRangeMode => _dateRangeMode;
  List<int> get availableYears => _availableYears;
  int? get selectedYear => _selectedYear;
  int? get selectedMonth => _selectedMonth;
  DateTime? get customRangeStart => _customRangeStart;
  DateTime? get customRangeEnd => _customRangeEnd;

  // ── Enerji modu state (Tab 1) ─────────────────────────────────────────────
  String _energyMode = 'hepsi'; // hepsi | gunes | ruzgar | hes

  String get energyMode => _energyMode;

  void setEnergyMode(String mode) {
    if (_energyMode == mode) return;
    _energyMode = mode;
    notifyListeners();
  }

  // ── İl Analizi state (Tab 2) ──────────────────────────────────────────────
  int? _selectedProvinceIndex;
  List<ProvinceSummary> _provinceSummaries = [];

  int? get selectedProvinceIndex => _selectedProvinceIndex;
  List<ProvinceSummary> get provinceSummaries => _provinceSummaries;
  ProvinceSummary? get selectedProvinceSummary =>
      (_selectedProvinceIndex != null &&
              _selectedProvinceIndex! < _provinceSummaries.length)
          ? _provinceSummaries[_selectedProvinceIndex!]
          : null;

  void setSelectedProvinceIndex(int idx) {
    _selectedProvinceIndex = idx;
    notifyListeners();
  }

  // ── Trend state (Tab 4) ───────────────────────────────────────────────────
  String _trendCity = '';
  String _trendMetric = 'solar'; // solar | wind | temperature
  List<TrendPoint> _trendData = [];
  bool _trendLoading = false;

  String get trendCity => _trendCity;
  String get trendMetric => _trendMetric;
  List<TrendPoint> get trendData => _trendData;
  bool get trendLoading => _trendLoading;

  void setTrendCity(String city) {
    if (_trendCity == city) return;
    _trendCity = city;
    _loadTrendData();
  }

  void setTrendMetric(String metric) {
    if (_trendMetric == metric) return;
    _trendMetric = metric;
    _loadTrendData();
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    await Future.wait([
      loadAvailableYears(),
      fetchReport(),
      _loadProvinceSummaries(),
    ]);
  }

  // ── Zaman aralığı metodları ───────────────────────────────────────────────

  Future<void> loadAvailableYears() async {
    try {
      _availableYears = await _weatherService.fetchAvailableYears();
      if (_availableYears.isNotEmpty && _selectedYear == null) {
        _selectedYear = _availableYears.last;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[ReportVM] loadAvailableYears hata: $e');
    }
  }

  void setDateRangeMode(DateRangeMode mode) {
    if (_dateRangeMode == mode) return;
    _dateRangeMode = mode;
    notifyListeners();
    loadReportForCurrentRange();
  }

  void setYear(int year) {
    _selectedYear = year;
    _selectedMonth = null;
    notifyListeners();
    loadReportForCurrentRange();
    if (_trendCity.isNotEmpty) _loadTrendData();
  }

  void setMonth(int? month) {
    _selectedMonth = month;
    notifyListeners();
    if (_trendCity.isNotEmpty) _loadTrendData();
  }

  void setCustomRange(DateTime start, DateTime end) {
    _customRangeStart = start;
    _customRangeEnd = end;
    notifyListeners();
    loadReportForCurrentRange();
  }

  /// Seçili zaman aralığına göre raporu yeniden yükler.
  Future<void> loadReportForCurrentRange() async {
    switch (_dateRangeMode) {
      case DateRangeMode.yearly:
        if (_selectedYear != null) {
          await fetchReport();
          await _loadProvinceSummariesForYear(_selectedYear!);
        }
      case DateRangeMode.monthly:
        if (_selectedYear != null) {
          await fetchReport();
          await _loadProvinceSummariesForYear(_selectedYear!);
        }
      case DateRangeMode.custom:
        if (_customRangeStart != null && _customRangeEnd != null) {
          await _loadProvinceSummariesByDateRange(
              _customRangeStart!, _customRangeEnd!);
        }
    }
  }

  // ── Rapor yükleme ─────────────────────────────────────────────────────────

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
      debugPrint('[ReportVM] fetchReport hata: $e');
      setError('Rapor yüklenemedi');
    } finally {
      setBusy(false);
    }
  }

  // ── İl özeti yükleme ─────────────────────────────────────────────────────

  Future<void> _loadProvinceSummaries() async {
    try {
      _provinceSummaries = await _weatherService.fetchProvinceSummary();
      if (_provinceSummaries.isNotEmpty) {
        _trendCity = _provinceSummaries.first.provinceName;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[ReportVM] _loadProvinceSummaries hata: $e');
    }
  }

  Future<void> _loadProvinceSummariesForYear(int year) async {
    try {
      final start = DateTime(year, 1, 1);
      final end = DateTime(year, 12, 31);
      _provinceSummaries =
          await _weatherService.fetchProvinceSummaryByDateRange(
              start: start, end: end);
      notifyListeners();
    } catch (e) {
      debugPrint('[ReportVM] _loadProvinceSummariesForYear hata: $e');
    }
  }

  Future<void> _loadProvinceSummariesByDateRange(
      DateTime start, DateTime end) async {
    try {
      _provinceSummaries =
          await _weatherService.fetchProvinceSummaryByDateRange(
              start: start, end: end);
      notifyListeners();
    } catch (e) {
      debugPrint('[ReportVM] _loadProvinceSummariesByDateRange hata: $e');
    }
  }

  // ── Trend yükleme ─────────────────────────────────────────────────────────

  Future<void> _loadTrendData() async {
    if (_trendCity.isEmpty) return;
    final year = _selectedYear ?? DateTime.now().year;
    final month = (_dateRangeMode == DateRangeMode.monthly) ? _selectedMonth : null;

    _trendLoading = true;
    notifyListeners();
    try {
      _trendData = await _weatherService.fetchMonthlyTrend(
        _trendCity,
        _trendMetric,
        year,
        month: month,
      );
    } catch (e) {
      debugPrint('[ReportVM] _loadTrendData hata: $e');
      _trendData = [];
    } finally {
      _trendLoading = false;
      notifyListeners();
    }
  }

  // ── Diğer ─────────────────────────────────────────────────────────────────

  void setFocusedSite(RegionalSite? site) {
    _focusedSite = site;
    notifyListeners();
  }
}
