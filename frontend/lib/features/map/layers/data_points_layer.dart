import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';

class DataPointsLayer extends StatelessWidget {
  final MapViewModel mapViewModel;

  const DataPointsLayer({super.key, required this.mapViewModel});

  @override
  Widget build(BuildContext context) {
    if (mapViewModel.weatherSummary.isEmpty) return const SizedBox.shrink();

    return MarkerLayer(
      markers: mapViewModel.weatherSummary.map((city) {
        final isDistrict = city.districtName != null;
        
        return Marker(
          point: LatLng(city.lat, city.lon),
          width: isDistrict ? 12.0 : 20.0,
          height: isDistrict ? 12.0 : 20.0,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDistrict
                ? Colors.white.withValues(alpha: 0.8)
                : Colors.cyanAccent.withValues(alpha: 0.9),
              boxShadow: [
                BoxShadow(
                  color: isDistrict
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.cyanAccent.withValues(alpha: 0.6),
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ],
              border: Border.all(
                color: Colors.white,
                width: 1,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
