// lib/main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

// Servisler
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/core/storage/secure_storage.dart';
import 'package:frontend/core/services/connectivity_service.dart';

// ViewModels
import 'package:frontend/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/reports/viewmodels/report_viewmodel.dart';
import 'package:frontend/features/scenarios/viewmodels/scenario_viewmodel.dart';

// Ekranlar
import 'package:frontend/features/landing/screens/landing_screen.dart';
import 'package:frontend/features/map/screens/map_screen.dart';
import 'package:frontend/features/reports/report_screen.dart';
import 'package:frontend/features/scenarios/scenario_screen.dart';
import 'package:frontend/features/scenarios/scenario_compare_screen.dart';

// Shared
import 'package:frontend/shared/widgets/offline_banner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Türkçe tarih formatlamasını başlat — DateFormat('...', 'tr_TR') için zorunlu.
  await initializeDateFormatting('tr_TR', null);

  // Widget build hatalarını debug konsoluna yaz (red screen göster ama susturma).
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  // NetworkVectorTileProvider'dan gelebilecek iptal istisnalarını yakala ve bastır.
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    final msg = error.toString().toLowerCase();
    final isCancelError = msg.contains('cancelled') ||
        msg.contains('canceled') ||
        msg.contains('request cancel');
    if (!isCancelError) {
      debugPrint('[Unhandled Exception] $error');
      if (kDebugMode) debugPrint(stack.toString());
    }
    return true;
  };

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
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ChangeNotifierProvider(
          create: (context) =>
              AuthViewModel(apiService, secureStorageService),
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
            builder: (context, child) => OfflineBanner(child: child!),
            home: const _AuthGate(),
            onGenerateRoute: (settings) {
              // Sayfa widget'ını belirle
              Widget page;
              switch (settings.name) {
                case '/landing':
                  page = const LandingScreen();
                  break;
                case '/map':
                  page = const MapScreen();
                  break;
                case '/reports':
                  page = const ReportScreen();
                  break;
                case '/scenarios':
                  page = const ScenarioScreen();
                  break;
                case '/scenarios/compare':
                  page = const ScenarioCompareScreen();
                  break;
                default:
                  page = const LandingScreen();
              }

              // /map ve /landing geçişlerinde fade animasyonu
              if (settings.name == '/map' ||
                  settings.name == '/landing') {
                return PageRouteBuilder(
                  settings: settings,
                  pageBuilder: (_, __, ___) => page,
                  transitionDuration: const Duration(milliseconds: 600),
                  reverseTransitionDuration:
                      const Duration(milliseconds: 400),
                  transitionsBuilder: (_, animation, __, child) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                );
              }

              // Diğer sayfalar: standart geçiş
              return MaterialPageRoute(
                settings: settings,
                builder: (_) => page,
              );
            },
          );
        },
      ),
    );
  }
}

/// Auth durumunu kontrol eder ve uygun sayfaya yönlendirir.
/// Başlangıçta splash gösterir, auth kontrol tamamlanınca
/// /landing veya /map sayfasına yönlendirir.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _navigated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tryNavigate();
  }

  void _tryNavigate() {
    if (_navigated) return;
    final auth = Provider.of<AuthViewModel>(context);
    if (auth.isLoggedIn == null) return; // Henüz kontrol edilmedi

    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (auth.isLoggedIn == true) {
        Navigator.of(context).pushReplacementNamed('/map');
      } else {
        Navigator.of(context).pushReplacementNamed('/landing');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeViewModel>(context);
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
