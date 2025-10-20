// lib/presentation/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    // AuthProvider'ın durumu yüklenirken bekleme ekranı gösterilir
    if (authProvider.isLoggedIn == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Giriş durumu kontrol ediliyor...', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }
    
    // Eğer giriş yapıldıysa MapScreen'e, yapılmadıysa AuthScreen'e yönlendirme.
    // Bu mantık main.dart'ta yönlendirme ile sağlanır.
    return Container(); // main.dart'ta yönlendirme yapılacağı için bu widget boş kalabilir.
  }
}
