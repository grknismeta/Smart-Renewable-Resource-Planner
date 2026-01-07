import '../secure_storage_service.dart';
import 'auth_service.dart';
import 'equipment_service.dart';
import 'geo_service.dart';
import 'optimization_service.dart';
import 'report_service.dart';
import 'resource_service.dart';
import 'scenario_service.dart';
import 'weather_service.dart';

export 'auth_service.dart';
export 'equipment_service.dart';
export 'geo_service.dart';
export 'optimization_service.dart';
export 'report_service.dart';
export 'resource_service.dart';
export 'scenario_service.dart';
export 'weather_service.dart';

class ApiService {
  final SecureStorageService _storageService;

  late final AuthService auth;
  late final EquipmentService equipment;
  late final GeoService geo;
  late final OptimizationService optimization;
  late final ReportService report;
  late final ResourceService resource;
  late final ScenarioService scenario;
  late final WeatherService weather;

  ApiService(this._storageService) {
    auth = AuthService(_storageService);
    equipment = EquipmentService(_storageService);
    geo = GeoService(_storageService);
    optimization = OptimizationService(_storageService);
    report = ReportService(_storageService);
    resource = ResourceService(_storageService);
    scenario = ScenarioService(_storageService);
    weather = WeatherService(_storageService);
  }
}
