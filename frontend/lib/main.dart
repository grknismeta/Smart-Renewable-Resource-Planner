// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Servisler
import 'core/api_service.dart';
import 'core/secure_storage_service.dart';

// ViewModels
import 'presentation/viewmodels/auth_view_model.dart';
import 'presentation/viewmodels/map_view_model.dart';
import 'presentation/viewmodels/theme_view_model.dart';
import 'presentation/viewmodels/report_view_model.dart';
import 'presentation/viewmodels/scenario_view_model.dart';

// Ekranlar
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/map_screen.dart';
import 'presentation/screens/report_screen.dart';
import 'presentation/screens/scenario_screen.dart';

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
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider(create: (_) => ThemeViewModel()),
        ChangeNotifierProvider(
          create: (context) => AuthViewModel(apiService, secureStorageService),
        ),
        ChangeNotifierProvider(create: (_) => ReportViewModel(apiService)),
        ChangeNotifierProvider(create: (_) => ScenarioViewModel(apiService)),
        ChangeNotifierProxyProvider<AuthViewModel, MapViewModel>(
          create: (context) => MapViewModel(
            apiService,
            Provider.of<AuthViewModel>(context, listen: false),
          ),
          update: (context, authViewModel, mapViewModel) => mapViewModel!,
        ),
      ],
      child: Consumer<ThemeViewModel>(
        // Tema değişince uygulamayı yeniden çizmek için Consumer
        builder: (context, themeViewModel, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Akıllı Kaynak Planlayıcı (SRRP)',
            theme: ThemeData(
              primarySwatch: Colors.blue,
              // Scaffold rengini themeProvider'dan alıyoruz
              scaffoldBackgroundColor: themeViewModel.backgroundColor,
              brightness: themeViewModel.isDarkMode
                  ? Brightness.dark
                  : Brightness.light,
            ),
            home: Consumer<AuthViewModel>(
              builder: (ctx, authError, _) {
                // Consumer rebuilds automatically on notifyListeners
                if (authError.isLoggedIn == null) {
                  return const SplashScreen();
                }
                if (authError.isLoggedIn == true) {
                  return const MapScreen();
                } else {
                  return const AuthScreen();
                }
              },
            ),
            routes: {
              '/auth': (context) => const AuthScreen(),
              '/map': (context) => const MapScreen(),
              '/reports': (context) => const ReportScreen(),
              '/scenarios': (context) => const ScenarioScreen(),
            },
          );
        },
      ),
    );
  }
}
