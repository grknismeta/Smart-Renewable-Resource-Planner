import 'package:flutter/material.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';

/// Data points are rendered via MapLibre JS (map_view_maplibre_web.dart).
/// This widget is kept as a no-op placeholder.
class DataPointsLayer extends StatelessWidget {
  final MapViewModel mapViewModel;

  const DataPointsLayer({super.key, required this.mapViewModel});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
