// presentation/features/pins/viewmodels/pin_dialog_viewmodel.dart
//
// Sorumluluk: Pin dialog state ve business logic yönetimi
// UI'dan tamamen bağımsız, test edilebilir

import 'package:flutter/foundation.dart';
import '../../../../data/models/pin_model.dart';
import '../../../../data/models/system_data_models.dart';
import '../../../../providers/map_provider.dart';

/// Pin dialog için ViewModel - UI state ve business logic burada
class PinDialogViewModel extends ChangeNotifier {
  final MapProvider _mapProvider;

  // State
  String _selectedType;
  int? _selectedEquipmentId;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Constructor
  PinDialogViewModel(
    this._mapProvider,
    String initialType, {
    int? initialEquipmentId,
  }) : _selectedType = initialType,
       _selectedEquipmentId = initialEquipmentId {
    _loadEquipments();
  }

  // Getters
  String get selectedType => _selectedType;
  int? get selectedEquipmentId => _selectedEquipmentId;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  List<Equipment> get availableEquipments {
    final type = _selectedType == 'Güneş Paneli' ? 'Solar' : 'Wind';
    return _mapProvider.equipments.where((e) => e.type == type).toList();
  }

  bool get isLoadingEquipments => _mapProvider.equipmentsLoading;
  bool get hasEquipments => availableEquipments.isNotEmpty;
  bool get canSubmit => _selectedEquipmentId != null && !_isSubmitting;

  // Actions
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

  // Business Logic
  Future<void> _loadEquipments() async {
    final type = _selectedType == 'Güneş Paneli' ? 'Solar' : 'Wind';
    await _mapProvider.loadEquipments(type: type, forceRefresh: true);
    notifyListeners();
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
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final capacityMw = getSelectedCapacityMw();
      if (capacityMw == null) {
        throw Exception('Kapasite hesaplanamadı');
      }

      await _mapProvider.calculatePotential(
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
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
