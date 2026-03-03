// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Servisler
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/core/storage/secure_storage.dart';

// ViewModels
import 'package:frontend/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/reports/viewmodels/report_viewmodel.dart';
import 'package:frontend/features/scenarios/viewmodels/scenario_viewmodel.dart';

// Ekranlar
import 'package:frontend/features/auth/splash_screen.dart';
import 'package:frontend/features/auth/auth_screen.dart';
import 'package:frontend/features/map/map_screen.dart';
import 'package:frontend/features/reports/report_screen.dart';
import 'package:frontend/features/scenarios/scenario_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
        builder: (context, themeViewModel, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Akıllı Kaynak Planlayıcı (SRRP)',
            theme: ThemeData(
              primarySwatch: Colors.blue,
              scaffoldBackgroundColor: themeViewModel.backgroundColor,
              brightness: themeViewModel.isDarkMode
                  ? Brightness.dark
                  : Brightness.light,
            ),
            home: Consumer<AuthViewModel>(
              builder: (ctx, authViewModel, _) {
                if (authViewModel.isLoggedIn == null) {
                  return const SplashScreen();
                }
                if (authViewModel.isLoggedIn == true) {
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
