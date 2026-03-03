// presentation/features/pins/viewmodels/pin_dialog_viewmodel.dart
//
// Sorumluluk: Pin dialog state ve business logic yönetimi
// UI'dan tamamen bağımsız, test edilebilir

import 'package:flutter/foundation.dart';
import 'package:frontend/data/models/system_data_models.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';

/// Pin dialog için ViewModel - UI state ve business logic burada
class PinDialogViewModel extends ChangeNotifier {
  final MapViewModel _mapViewModel;

  // State
  String _selectedType;
  int? _selectedEquipmentId;
  double _panelArea = 10.0; // Default 10 m2
  bool _isSubmitting = false;
  String? _errorMessage;

  // Constructor
  PinDialogViewModel(
    this._mapViewModel,
    String initialType, {
    int? initialEquipmentId,
  }) : _selectedType = initialType,
       _selectedEquipmentId = initialEquipmentId;


  // Getters
  String get selectedType => _selectedType;
  int? get selectedEquipmentId => _selectedEquipmentId;
  double get panelArea => _panelArea;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  List<Equipment> get availableEquipments {
    final type = _selectedType == 'Güneş Paneli' ? 'Solar' : 'Wind';
    return _mapViewModel.equipments.where((e) => e.type == type).toList();
  }

  bool get isLoadingEquipments => _mapViewModel.equipmentsLoading;
  bool get hasEquipments => availableEquipments.isNotEmpty;
  bool get canSubmit => _selectedEquipmentId != null && !_isSubmitting;

  // Actions
  void setPanelArea(String val) {
    if (val.isEmpty) return;
    final parsed = double.tryParse(val);
    if (parsed != null && parsed > 0) {
      _panelArea = parsed;
      notifyListeners();
    }
  }

  void changeType(String newType) {
    if (_selectedType != newType) {
      _selectedType = newType;
      _selectedEquipmentId = null; // Reset selection
      _loadEquipments();
      notifyListeners();
    }
  }

  void selectEquipment(int equipmentId) {
    _selectedEquipmentId = equipmentId;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  // Business Logic
  Future<void> loadInitialData() async {
    final type = _selectedType == 'Güneş Paneli' ? 'Solar' : 'Wind';
    await _mapViewModel.loadEquipments(type: type, forceRefresh: true);
    if (!_isDisposed) notifyListeners();
  }

  Future<void> _loadEquipments() async {
    final type = _selectedType == 'Güneş Paneli' ? 'Solar' : 'Wind';
    await _mapViewModel.loadEquipments(type: type, forceRefresh: true);
    if (!_isDisposed) notifyListeners();
  }

  /// Validation - Returns error message or null if valid
  String? validate() {
    if (_selectedEquipmentId == null) {
      return 'Lütfen bir model seçin';
    }
    if (!hasEquipments) {
      return 'Model bulunamadı';
    }
    return null;
  }

  /// Calculate capacity from selected equipment
  double? getSelectedCapacityMw() {
    if (_selectedEquipmentId == null) return null;

    try {
      final equipment = availableEquipments.firstWhere(
        (e) => e.id == _selectedEquipmentId,
      );
      return equipment.ratedPowerKw / 1000;
    } catch (e) {
      return null;
    }
  }

  /// Submit calculation
  Future<bool> calculatePotential({
    required double lat,
    required double lon,
    required double panelArea,
  }) async {
    final validationError = validate();
    if (validationError != null) {
      _errorMessage = validationError;
      if (!_isDisposed) notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    if (!_isDisposed) notifyListeners();

    try {
      final capacityMw = getSelectedCapacityMw();
      if (capacityMw == null) {
        throw Exception('Kapasite hesaplanamadı');
      }

      await _mapViewModel.calculatePotential(
        lat: lat,
        lon: lon,
        type: _selectedType,
        capacityMw: capacityMw,
        panelArea: panelArea,
      );

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      if (!_isDisposed) {
        _isSubmitting = false;
        notifyListeners();
      }
    }
  }
}
