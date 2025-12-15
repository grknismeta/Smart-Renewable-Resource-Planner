import 'package:flutter/material.dart';
import 'map_constants.dart';

/// Harita üzerinde gösterilecek pin ikonları
class MapMarkerIcon extends StatelessWidget {
  final String type;
  final double size;

  const MapMarkerIcon({super.key, required this.type, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final bgColor = MapConstants.getBackgroundColor(type);
    final fgColor = MapConstants.getForegroundColor(type);
    final icon = MapConstants.getIcon(type);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: fgColor, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Icon(icon, color: fgColor, size: size * 0.6),
    );
  }
}

/// Harita üzerinde rüzgar veya güneş kaynağı eklemek için butonlar
class ResourceActionButton extends StatelessWidget {
  final String type;
  final VoidCallback onTap;
  final double size;

  const ResourceActionButton({
    super.key,
    required this.type,
    required this.onTap,
    this.size = 50,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = MapConstants.getBackgroundColor(type);
    final fgColor = MapConstants.getForegroundColor(type);
    final icon = MapConstants.getIcon(type);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: Border.all(color: fgColor, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
        child: Icon(icon, color: fgColor, size: size * 0.56),
      ),
    );
  }
}
