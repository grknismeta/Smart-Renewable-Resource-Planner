// lib/core/services/connectivity_service.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// İnternet bağlantısını izleyen singleton servis.
/// Provider üzerinden tüm ağaçtan erişilebilir.
class ConnectivityService extends ChangeNotifier {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;

  ConnectivityService._internal() {
    _checkInitial();
    _subscription = Connectivity().onConnectivityChanged.listen(_onChanged);
  }

  // ── State ──────────────────────────────────────────────────────────────────
  bool _isConnected = true; // optimistic default
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool get isConnected => _isConnected;

  // ── Initialization ─────────────────────────────────────────────────────────
  Future<void> _checkInitial() async {
    final results = await Connectivity().checkConnectivity();
    _onChanged(results);
  }

  void _onChanged(List<ConnectivityResult> results) {
    final connected = results.any((r) => r != ConnectivityResult.none);
    if (connected != _isConnected) {
      _isConnected = connected;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
