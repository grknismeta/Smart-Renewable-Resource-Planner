import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../presentation/widgets/map/map_constants.dart';

class MapUtils {
  MapUtils._();

  /// Constraints the given position to be within Turkey's bounds.
  /// Returns null if the position is within bounds, or the constrained position if it was out of bounds.
  static LatLng? constrainToTurkey(LatLng center) {
    double lat = center.latitude;
    double lon = center.longitude;
    bool changed = false;

    if (lat < MapConstants.turkeyMinLat) {
      lat = MapConstants.turkeyMinLat;
      changed = true;
    } else if (lat > MapConstants.turkeyMaxLat) {
      lat = MapConstants.turkeyMaxLat;
      changed = true;
    }

    if (lon < MapConstants.turkeyMinLon) {
      lon = MapConstants.turkeyMinLon;
      changed = true;
    } else if (lon > MapConstants.turkeyMaxLon) {
      lon = MapConstants.turkeyMaxLon;
      changed = true;
    }

    if (changed) {
      return LatLng(lat, lon);
    }
    return null;
  }
  
  /// Helper to move controller if needed
  static void constrainMapCamera(MapController controller) {
    final constrained = constrainToTurkey(controller.camera.center);
    if (constrained != null) {
      controller.move(constrained, controller.camera.zoom);
    }
  }
}
