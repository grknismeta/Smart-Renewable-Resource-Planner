// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Servisler
import 'core/api_service.dart';
import 'core/secure_storage_service.dart';

// Provider'lar
import 'providers/auth_provider.dart';
import 'providers/map_provider.dart';
import 'providers/theme_provider.dart'; // <-- YENİ EKLENDİ

// Ekranlar
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/map_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final secureStorageService = SecureStorageService();
    final apiService = ApiService(secureStorageService);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ), // <-- YENİ EKLENDİ
        ChangeNotifierProvider(
          create: (context) => AuthProvider(apiService, secureStorageService),
        ),
        ChangeNotifierProxyProvider<AuthProvider, MapProvider>(
          create: (context) => MapProvider(
            apiService,
            Provider.of<AuthProvider>(context, listen: false),
          ),
          update: (context, auth, map) => map!,
        ),
      ],
      child: Consumer<ThemeProvider>(
        // Tema değişince uygulamayı yeniden çizmek için Consumer
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Akıllı Kaynak Planlayıcı (SRRP)',
            theme: ThemeData(
              primarySwatch: Colors.blue,
              // Scaffold rengini themeProvider'dan alıyoruz
              scaffoldBackgroundColor: themeProvider.backgroundColor,
              brightness: themeProvider.isDarkMode
                  ? Brightness.dark
                  : Brightness.light,
            ),
            home: Consumer<AuthProvider>(
              builder: (ctx, auth, _) {
                if (auth.isLoggedIn == null) {
                  return const SplashScreen();
                }
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
          );
        },
      ),
    );
  }
}
