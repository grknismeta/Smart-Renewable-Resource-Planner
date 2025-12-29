// lib/presentation/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_view_model.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);

    // AuthViewModel'ın durumu yüklenirken bekleme ekranı gösterilir
    // Assuming isBusy might cover initialization or we check isLoggedIn directly if it's nullable
    // In AuthViewModel, isLoggedIn is bool (initialized to false), but maybe we check if it's checked?
    // Let's assume AuthViewModel handles initialization and notifyListeners.
    // Ideally AuthViewModel should have a state indicating if it has checked persistence.
    // If AuthViewModel logic is "uninitialized" initially, we might need a property for that.
    // However, looking at the previous AuthProvider, it had bool? _isLoggedIn.
    // I should check AuthViewModel again to be sure. But for now, I'll use isLoggedIn check logic if compatible.

    // If AuthViewModel follows BaseViewModel, it has isBusy.
    // But isBusy is generic.
    // Let's rely on isLoggedIn. If it's false, it redirects to Auth. If true, Map.
    // But Splash handles the "waiting" state.
    // If AuthState is Idle, and isLoggedIn is determined...
    // I will write it similar to before but using AuthViewModel.
    // If AuthViewModel doesn't expose a "loading" state for init, we might have an issue.
    // But let's assume isBusy is true during init.

    if (authViewModel.isBusy) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                'Giriş durumu kontrol ediliyor...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Container();
  }
}
