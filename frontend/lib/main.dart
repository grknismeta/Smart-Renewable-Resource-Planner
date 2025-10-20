// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Servisler
import 'core/api_service.dart';
import 'core/secure_storage_service.dart';

// Provider'lar
import 'providers/auth_provider.dart';
import 'providers/map_provider.dart';

// Ekranlar
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/map_screen.dart';

void main() {
  // Widget ağacı başlatılmadan önce SecureStorage kullanımı için gereklidir
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

// Uygulamanın ana başlangıç widget'ı
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Servis ve Provider'ları uygulamaya sağlıyoruz (Dependency Injection)
    final secureStorageService = SecureStorageService();
    final apiService = ApiService(secureStorageService);

    return MultiProvider(
      providers: [
        // AuthProvider, ApiService ve SecureStorage'a ihtiyaç duyar
        ChangeNotifierProvider(
          create: (context) => AuthProvider(apiService, secureStorageService),
        ),
        // MapProvider, ApiService ve AuthProvider'a ihtiyaç duyar
        ChangeNotifierProxyProvider<AuthProvider, MapProvider>(
          create: (context) => MapProvider(apiService, Provider.of<AuthProvider>(context, listen: false)),
          update: (context, auth, map) => map!, // MapProvider'ın tek seferlik oluşturulması yeterli
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Akıllı Kaynak Planlayıcı (SRRP)',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue).copyWith(secondary: Colors.red),
        ),
        home: Consumer<AuthProvider>(
          builder: (ctx, auth, _) {
            // Eğer giriş durumu kontrol ediliyorsa Splash Screen'i göster
            if (auth.isLoggedIn == null) {
              return const SplashScreen();
            }
            // Eğer giriş yapıldıysa Harita Ekranını, yapılmadıysa Giriş Ekranını göster
            if (auth.isLoggedIn == true) {
              return const MapScreen();
            } else {
              return const AuthScreen();
            }
          },
        ),
        routes: {
          '/auth': (context) => const AuthScreen(),
          '/map': (context) => const MapScreen(),
        },
      ),
    );
  }
}
