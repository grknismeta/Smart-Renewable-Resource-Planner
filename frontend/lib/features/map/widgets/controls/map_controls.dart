import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:frontend/core/theme/theme_view_model.dart';

class MapControls extends StatelessWidget {
  final ThemeViewModel theme;
  final VoidCallback onAddPin;
  final VoidCallback onSelectRegion;
  final VoidCallback onToggleLayers;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final bool isSelectingRegion;
  final bool isLayersPanelVisible;
  final VoidCallback? onToggleRecommendations;
  final bool isRecommendationsPanelOpen;
  final VoidCallback? onToggleProvinceMode; // geriye dönük uyumluluk
  final bool isProvinceModeActive;          // geriye dönük uyumluluk
  final VoidCallback? onOpenProvincesMode;
  final bool isProvincesModeActive;
  final VoidCallback? onOpenDistrictsMode;
  final bool isDistrictsModeActive;
  final VoidCallback? onToggleAnimation;
  final bool isAnimationMode;
  final bool isGlobeMode;

  const MapControls({
    super.key,
    required this.theme,
    required this.onAddPin,
    required this.onSelectRegion,
    required this.onToggleLayers,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.isSelectingRegion,
    required this.isLayersPanelVisible,
    this.onToggleRecommendations,
    this.isRecommendationsPanelOpen = false,
    this.onToggleProvinceMode,
    this.isProvinceModeActive = false,
    this.onOpenProvincesMode,
    this.isProvincesModeActive = false,
    this.onOpenDistrictsMode,
    this.isDistrictsModeActive = false,
    this.onToggleAnimation,
    this.isAnimationMode = false,
    this.isGlobeMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Zoom Buttons (Center Right)
        // 1. Top Right Controls (Add Pin & Layers)
        Positioned(
          top: 20,
          right: 20,
          child: PointerInterceptor(child: Column(
            children: [
              // Add Pin
              MapControlButton(
                icon: Icons.add_location_alt_outlined,
                tooltip: "Kaynak Ekle",
                onTap: onAddPin,
                color: Colors.blueAccent,
                theme: theme,
              ),
              const SizedBox(height: 16),
              
              // Map Layers
              MapControlButton(
                icon: Icons.layers_outlined,
                tooltip: "Katmanlar",
                onTap: onToggleLayers,
                color: isLayersPanelVisible ? Colors.greenAccent : theme.textColor,
                theme: theme,
              ),
              const SizedBox(height: 16),

              // Önerilen Bölgeler
              if (onToggleRecommendations != null)
                MapControlButton(
                  icon: Icons.auto_awesome_rounded,
                  tooltip: isGlobeMode ? "Global modda kullanılamaz" : "Önerilen Bölgeler",
                  onTap: isGlobeMode ? () {} : onToggleRecommendations!,
                  color: isGlobeMode
                      ? theme.secondaryTextColor.withValues(alpha: 0.3)
                      : isRecommendationsPanelOpen
                          ? Colors.purpleAccent
                          : theme.textColor,
                  theme: theme,
                ),
              const SizedBox(height: 16),

              // İl Modu — Tüm 81 ili doğrudan göster
              if (onOpenProvincesMode != null)
                MapControlButton(
                  icon: Icons.apartment_rounded,
                  tooltip: isGlobeMode ? "Global modda kullanılamaz" : "İl Modu",
                  onTap: isGlobeMode ? () {} : onOpenProvincesMode!,
                  color: isGlobeMode
                      ? theme.secondaryTextColor.withValues(alpha: 0.3)
                      : isProvincesModeActive
                          ? Colors.tealAccent
                          : theme.textColor,
                  theme: theme,
                ),
              const SizedBox(height: 16),

              // İlçe Modu — Tüm Türkiye ilçelerini doğrudan göster
              if (onOpenDistrictsMode != null)
                MapControlButton(
                  icon: Icons.grid_view_rounded,
                  tooltip: isGlobeMode ? "Global modda kullanılamaz" : "İlçe Modu",
                  onTap: isGlobeMode ? () {} : onOpenDistrictsMode!,
                  color: isGlobeMode
                      ? theme.secondaryTextColor.withValues(alpha: 0.3)
                      : isDistrictsModeActive
                          ? Colors.orangeAccent
                          : theme.textColor,
                  theme: theme,
                ),
              const SizedBox(height: 16),

              // Zaman Simülasyonu
              if (onToggleAnimation != null)
                MapControlButton(
                  icon: Icons.play_circle_outline_rounded,
                  tooltip: isGlobeMode ? "Global modda kullanılamaz" : "Zaman Simülasyonu",
                  onTap: isGlobeMode ? () {} : onToggleAnimation!,
                  color: isGlobeMode
                      ? theme.secondaryTextColor.withValues(alpha: 0.3)
                      : isAnimationMode
                          ? Colors.cyanAccent
                          : theme.textColor,
                  theme: theme,
                ),
            ],
          )),
        ),

        // 2. Zoom Buttons (Bottom Left)
        Positioned(
          bottom: 40, // Sheet is minimized (only handle at ~20-30px), so 40-50 is safe.
          left: 20,
          child: PointerInterceptor(child: Column(
            children: [
              _buildZoomButton(Icons.add, onZoomIn),
              const SizedBox(height: 8),
              _buildZoomButton(Icons.remove, onZoomOut),
            ],
          )),
        ),
      ],
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        border: Border.all(color: theme.secondaryTextColor.withValues(alpha: 0.1)),
      ),
      child: IconButton(
        icon: Icon(icon, color: theme.textColor),
        onPressed: onTap,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }
}

class MapControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;
  final ThemeViewModel theme;
  final double size;
  final double iconSize;

  const MapControlButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.color,
    required this.theme,
    this.size = 50,
    this.iconSize = 26,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: theme.cardColor,
        elevation: 4,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.secondaryTextColor.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(icon, color: color, size: iconSize),
          ),
        ),
      ),
    );
  }
}
