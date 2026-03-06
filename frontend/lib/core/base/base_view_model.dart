import 'package:flutter/foundation.dart';

enum ViewState { idle, busy, error }

class BaseViewModel extends ChangeNotifier {
  ViewState _state = ViewState.idle;
  String? _errorMessage;
  bool _disposed = false;

  ViewState get state => _state;
  bool get isBusy => _state == ViewState.busy;
  bool get hasError => _state == ViewState.error;
  String? get errorMessage => _errorMessage;

  /// Dispose sonrası notifyListeners() çağrısını önleyen guard
  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  void setBusy(bool value) {
    if (_disposed) return;
    _state = value ? ViewState.busy : ViewState.idle;
    if (value) _errorMessage = null;
    notifyListeners();
  }

  void setError(String message) {
    if (_disposed) return;
    _state = ViewState.error;
    _errorMessage = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
