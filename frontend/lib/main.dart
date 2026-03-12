// lib/main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'package:frontend/features/auth/splash_screen.dart';
import 'package:frontend/features/auth/auth_screen.dart';
import 'package:frontend/features/map/screens/map_screen.dart';
import 'package:frontend/features/reports/report_screen.dart';
import 'package:frontend/features/scenarios/scenario_screen.dart';
import 'package:frontend/features/scenarios/scenario_compare_screen.dart';
import 'package:frontend/features/onboarding/onboarding_screen.dart';

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
  // NOT: flutter_map_cancellable_tile_provider (Dio tabanlı) kaldırıldı;
  //      artık flutter_map yerleşik NetworkTileProvider() kullanılıyor.
  // ÖNEMLI: Windows masaüstünde return false → process crash.
  //         Bu yüzden her durumda return true; hatalar ayrıca loglanıyor.
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    final msg = error.toString().toLowerCase();
    // Beklenen iptal hataları — vector tile provider cancel
    final isCancelError = msg.contains('cancelled') ||
        msg.contains('canceled') ||
        msg.contains('request cancel');
    if (!isCancelError) {
      // Gerçek hatayı logla — çökme değil, sadece kayıt
      debugPrint('[Unhandled Exception] $error');
      if (kDebugMode) debugPrint(stack.toString());
    }
    return true; // Her zaman true — uygulama çalışmaya devam eder
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
        // İnternet bağlantısı izleyici — tüm ağaçtan erişilebilir
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
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
            // Tüm ekranları OfflineBanner ile sar
            builder: (context, child) => OfflineBanner(child: child!),
            home: const _HomeRouter(),
            routes: {
              '/auth':    (context) => const AuthScreen(),
              '/map':     (context) => const MapScreen(),
              '/reports': (context) => const ReportScreen(),
              '/scenarios': (context) => const ScenarioScreen(),
              '/scenarios/compare': (context) => const ScenarioCompareScreen(),
              '/onboarding': (context) => const OnboardingScreen(),
            },
          );
        },
      ),
    );
  }
}

/// Başlangıç yönlendirici: önce onboarding durumunu kontrol eder,
/// sonra auth durumuna göre uygun ekranı gösterir.
class _HomeRouter extends StatefulWidget {
  const _HomeRouter();

  @override
  State<_HomeRouter> createState() => _HomeRouterState();
}

class _HomeRouterState extends State<_HomeRouter> {
  /// null = henüz kontrol edilmedi
  bool? _onboardingDone;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _onboardingDone = prefs.getBool('onboarding_done') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Henüz SharedPreferences okuma tamamlanmadı
    if (_onboardingDone == null) {
      return const SplashScreen();
    }

    // İlk açılış → onboarding ekranını göster
    if (!_onboardingDone!) {
      return const OnboardingScreen();
    }

    // Normal akış: auth durumuna göre yönlendir
    return Consumer<AuthViewModel>(
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
    );
  }
}
