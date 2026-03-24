import 'package:flutter/material.dart';
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
