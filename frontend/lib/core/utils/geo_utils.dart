import 'package:latlong2/latlong.dart';
import 'package:frontend/core/constants/map_constants.dart';

class MapUtils {
  MapUtils._();

  /// Türkiye sınırları dışındaki koordinatları sınır içine çeker.
  /// Sınır içindeyse null döner.
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

    if (changed) return LatLng(lat, lon);
    return null;
  }
}
