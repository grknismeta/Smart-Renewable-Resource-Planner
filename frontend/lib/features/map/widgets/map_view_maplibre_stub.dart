import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre/maplibre.dart' as ml;
import 'package:frontend/data/models/pin_model.dart';

class MapViewMapLibre extends StatelessWidget {
  final Function(ml.Position)? onMapTap;
  final Function(Pin)? onPinTap;

  const MapViewMapLibre({super.key, this.onMapTap, this.onPinTap});

  /// Stub: web dışında desteklenmez.
  static void flyTo(double lat, double lon, {double zoom = 10.0}) {}
  static void zoomIn() {}
  static void zoomOut() {}

  /// Stub: web dışında no-op.
  static void setupProvinceSelect(bool enable) {}
  static void setupRegionMode() {}
  static void setupProvinceMode({String? regionFilter}) {}
  static void setupDistrictMode(String provinceName) {}
  static void clearSelectionMode() {}
  static void setInteractive(bool enable) {}
  static void setClickGuard(bool active) {}
  static void setPinPlacementActive(bool active) {}
  static void setTerrainExaggeration(double exaggeration) {}
  static void setHillshadeIntensity(double intensity) {}
  static void toggleContour(bool enabled, double opacity,
      {String source = 'opentopo'}) {}
  static void setContourOpacity(double opacity) {}
  static void setMlChoropleth(String dataJson) {}
  static void clearMlChoropleth() {}
  static void setMaxBounds(
      double swLng, double swLat, double neLng, double neLat) {}
  static void clearMaxBounds() {}
  static void setShowcasePins(String geojsonStr) {}
  // 2026-05-08 Madde 1: Pin preview marker — stub.
  static void showPreviewPin(LatLng? point) {}
  // Madde 5+6+7 — stub.
  static Offset? projectLngLatToScreen(LatLng point) => null;
  static void registerAnchorListener(VoidCallback? callback) {}
  static dynamic get activeControllerForOverlay => null;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Text(
          'MapLibre 3D özelliği sadece Web platformunda desteklenmektedir.',
          style: TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
