import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/map_provider.dart';
import '../../../providers/theme_provider.dart';
import 'map_constants.dart';

/// Sol üst köşede gösterilen dashboard widget'ı
class MapDashboard extends StatelessWidget {
  final ThemeProvider theme;

  const MapDashboard({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Consumer<MapProvider>(
      builder: (context, mapProvider, _) {
        // Pin sayılarını hesapla
        final windPins = mapProvider.pins
            .where((p) => p.type == 'Rüzgar Türbini')
            .length;
        final solarPins = mapProvider.pins
            .where((p) => p.type == 'Güneş Paneli')
            .length;
        final totalCapacity = mapProvider.pins.fold<double>(
          0,
          (sum, pin) => sum + pin.capacityMw,
        );

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.secondaryTextColor.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              _buildStatItem(
                'Rüzgar',
                '$windPins',
                windPins > 0 ? Colors.blueAccent : theme.secondaryTextColor,
              ),
              const SizedBox(width: 20),
              Container(
                width: 1,
                height: 30,
                color: theme.secondaryTextColor.withValues(alpha: 0.2),
              ),
              const SizedBox(width: 20),
              _buildStatItem(
                'Güneş',
                '$solarPins',
                solarPins > 0 ? Colors.orangeAccent : theme.secondaryTextColor,
              ),
              const SizedBox(width: 20),
              Container(
                width: 1,
                height: 30,
                color: theme.secondaryTextColor.withValues(alpha: 0.2),
              ),
              const SizedBox(width: 20),
              _buildStatItem(
                'Kapasite',
                '${totalCapacity.toStringAsFixed(1)} MW',
                Colors.greenAccent,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Pin yerleştirme modunda gösterilen bildirim barı
class PlacementIndicator extends StatelessWidget {
  final String? placingPinType;
  final VoidCallback onCancel;

  const PlacementIndicator({
    super.key,
    required this.placingPinType,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (placingPinType == null) return const SizedBox.shrink();

    final bgColor = MapConstants.getBackgroundColor(placingPinType!);
    final fgColor = MapConstants.getForegroundColor(placingPinType!);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: fgColor, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app, color: fgColor),
            const SizedBox(width: 8),
            Text(
              "⚡ Enerji Kaynağı Ekle",
              style: TextStyle(fontWeight: FontWeight.bold, color: fgColor),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: onCancel,
              child: const Icon(Icons.cancel, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// Zoom kontrolleri
class ZoomControls extends StatelessWidget {
  final ThemeProvider theme;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const ZoomControls({
    super.key,
    required this.theme,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildZoomButton(Icons.remove, onZoomOut),
        const SizedBox(width: 8),
        _buildZoomButton(Icons.add, onZoomIn),
      ],
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: IconButton(
        icon: Icon(icon, color: theme.textColor),
        onPressed: onTap,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      ),
    );
  }
}

/// Harita katmanları paneli
class LayersPanel extends StatelessWidget {
  final ThemeProvider theme;
  final MapProvider mapProvider;
  final String selectedBaseMap;
  final ValueChanged<String> onBaseMapChanged;

  const LayersPanel({
    super.key,
    required this.theme,
    required this.mapProvider,
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
          _buildLayerSwitch("Rüzgar Haritası", MapLayer.wind),
          _buildLayerSwitch("Sıcaklık Haritası", MapLayer.temp),
          _buildLayerSwitch("Işınım Haritası", MapLayer.irradiance),
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

  Widget _buildLayerSwitch(String title, MapLayer layer) {
    final bool isActive = mapProvider.currentLayer == layer;
    return InkWell(
      onTap: () => mapProvider.changeMapLayer(),
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
