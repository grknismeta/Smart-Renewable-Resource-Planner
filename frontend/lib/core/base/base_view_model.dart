import 'package:flutter/foundation.dart';

enum ViewState { idle, busy, error }

class BaseViewModel extends ChangeNotifier {
  ViewState _state = ViewState.idle;
  String? _errorMessage;

  ViewState get state => _state;
  bool get isBusy => _state == ViewState.busy;
  bool get hasError => _state == ViewState.error;
  String? get errorMessage => _errorMessage;

  void setBusy(bool value) {
    _state = value ? ViewState.busy : ViewState.idle;
    if (value) _errorMessage = null;
    notifyListeners();
  }

  void setError(String message) {
    _state = ViewState.error;
    _errorMessage = message;
    notifyListeners();
  }
}
