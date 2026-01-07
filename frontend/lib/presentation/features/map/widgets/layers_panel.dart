import 'package:flutter/material.dart';
import '../../../../presentation/viewmodels/theme_view_model.dart';
import '../viewmodels/map_view_model.dart';
import '../models/map_models.dart';

class LayersPanel extends StatelessWidget {
  final ThemeViewModel theme;
  final MapViewModel mapViewModel;
  final String selectedBaseMap;
  final ValueChanged<String> onBaseMapChanged;

  const LayersPanel({
    super.key,
    required this.theme,
    required this.mapViewModel,
    required this.selectedBaseMap,
    required this.onBaseMapChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.secondaryTextColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Harita Stili",
            style: TextStyle(
              color: theme.textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          Divider(color: theme.secondaryTextColor.withValues(alpha: 0.2)),
          _buildBaseMapOption("ArcGIS Koyu", "dark"),
          _buildBaseMapOption("Uydu (Satellite)", "satellite"),
          _buildBaseMapOption("Sokak Haritası", "street"),
          const SizedBox(height: 10),
          Text(
            "Veri Katmanları",
            style: TextStyle(
              color: theme.textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          Divider(color: theme.secondaryTextColor.withValues(alpha: 0.2)),
          _buildLayerSwitch("Rüzgar Haritası", MapLayerType.wind),
          _buildLayerSwitch("Sıcaklık Haritası", MapLayerType.temp),
          _buildLayerSwitch("Işınım Haritası", MapLayerType.irradiance),
        ],
      ),
    );
  }

  Widget _buildBaseMapOption(String title, String value) {
    final bool isActive = selectedBaseMap == value;
    return InkWell(
      onTap: () => onBaseMapChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          children: [
            Icon(
              isActive ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isActive ? Colors.blueAccent : theme.secondaryTextColor,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isActive ? theme.textColor : theme.secondaryTextColor,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayerSwitch(String title, MapLayerType layer) {
    final bool isActive = mapViewModel.currentLayer == layer;
    return InkWell(
      onTap: () {
        if (isActive) {
          mapViewModel.setLayer(MapLayerType.none);
        } else {
          mapViewModel.setLayer(layer);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          children: [
            Icon(
              isActive ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isActive
                  ? Colors.greenAccent
                  : theme.secondaryTextColor.withValues(alpha: 0.5),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isActive ? theme.textColor : theme.secondaryTextColor,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
