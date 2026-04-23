import 'package:frontend/core/storage/secure_storage.dart';
import 'package:frontend/core/network/analysis_service.dart';
import 'package:frontend/core/network/auth_service.dart';
import 'package:frontend/core/network/equipment_service.dart';
import 'package:frontend/core/network/geo_service.dart';
import 'package:frontend/core/network/optimization_service.dart';
import 'package:frontend/core/network/report_service.dart';
import 'package:frontend/core/network/resource_service.dart';
import 'package:frontend/core/network/scenario_service.dart';
import 'package:frontend/core/network/weather_service.dart';
import 'package:frontend/core/network/recommendation_service.dart';
import 'package:frontend/core/network/wind_vector_service.dart';

export 'package:frontend/core/network/analysis_service.dart';
export 'package:frontend/core/network/auth_service.dart';
export 'package:frontend/core/network/equipment_service.dart';
export 'package:frontend/core/network/geo_service.dart';
export 'package:frontend/core/network/optimization_service.dart';
export 'package:frontend/core/network/report_service.dart';
export 'package:frontend/core/network/resource_service.dart';
export 'package:frontend/core/network/scenario_service.dart';
export 'package:frontend/core/network/weather_service.dart';
export 'package:frontend/core/network/recommendation_service.dart';
export 'package:frontend/core/network/wind_vector_service.dart';

class ApiService {
  final SecureStorageService _storageService;

  late final AnalysisService analysis;
  late final AuthService auth;
  late final EquipmentService equipment;
  late final GeoService geo;
  late final OptimizationService optimization;
  late final ReportService report;
  late final ResourceService resource;
  late final ScenarioService scenario;
  late final WeatherService weather;
  late final RecommendationService recommendation;
  late final WindVectorService windVector;

  ApiService(this._storageService) {
    analysis = AnalysisService(_storageService);
    auth = AuthService(_storageService);
    equipment = EquipmentService(_storageService);
    geo = GeoService(_storageService);
    optimization = OptimizationService(_storageService);
    report = ReportService(_storageService);
    resource = ResourceService(_storageService);
    scenario = ScenarioService(_storageService);
    weather = WeatherService(_storageService);
    recommendation = RecommendationService(_storageService);
    windVector = WindVectorService(_storageService);
  }
}
