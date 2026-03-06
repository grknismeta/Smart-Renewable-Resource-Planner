import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';


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
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 240,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.secondaryTextColor.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Harita Görünümü",
                    style: TextStyle(
                      color: theme.textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "Harita Stili",
                style: TextStyle(
                  color: theme.secondaryTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildBaseMapOption("Koyu Mod", "dark"),
              _buildBaseMapOption("Uydu Görüntüsü", "satellite"),
              _buildBaseMapOption("Sokak Haritası", "street"),
              
              const SizedBox(height: 16),
              Text(
                "Veri Katmanları",
                style: TextStyle(
                  color: theme.secondaryTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildLayerSwitch("Rüzgar Hızı", MapLayerType.wind),
              _buildLayerSwitch("Sıcaklık", MapLayerType.temp),
              _buildLayerSwitch("Güneş Işınımı", MapLayerType.irradiance),

              // Neon toggle (ayraç + switch)
              const SizedBox(height: 12),
              Divider(
                color: theme.secondaryTextColor.withValues(alpha: 0.15),
                thickness: 1,
                height: 1,
              ),
              const SizedBox(height: 10),
              _buildNeonToggle(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNeonToggle() {
    final bool isActive = mapViewModel.showDataPoints;
    return GestureDetector(
      onTap: () => mapViewModel.toggleDataPoints(!isActive),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isActive
              ? Colors.cyanAccent.withValues(alpha: 0.12)
              : theme.secondaryTextColor.withValues(alpha: 0.06),
          border: Border.all(
            color: isActive
                ? Colors.cyanAccent.withValues(alpha: 0.5)
                : Colors.transparent,
            width: 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.cyanAccent.withValues(alpha: 0.15),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Icon(
              Icons.grain,
              size: 16,
              color: isActive ? Colors.cyanAccent : theme.secondaryTextColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Neon Veri Noktaları",
                style: TextStyle(
                  fontSize: 13,
                  color: isActive ? Colors.cyanAccent : theme.secondaryTextColor,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            Switch(
              value: isActive,
              onChanged: (val) => mapViewModel.toggleDataPoints(val),
              activeColor: Colors.cyanAccent,
              activeTrackColor: Colors.cyan.withValues(alpha: 0.3),
              inactiveThumbColor: theme.secondaryTextColor,
              inactiveTrackColor: theme.secondaryTextColor.withValues(alpha: 0.1),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
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
