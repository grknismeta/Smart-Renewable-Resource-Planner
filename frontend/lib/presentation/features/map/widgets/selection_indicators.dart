import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';


import '../../../viewmodels/theme_view_model.dart';
import '../viewmodels/map_view_model.dart';
import '../dialogs/map_dialogs.dart'; 
import '../dialogs/optimization_dialog.dart';

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

    // Kullanıcı isteği: Yeşil renk
    const bgColor = Colors.green;
    const fgColor = Colors.white;

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
            const Icon(Icons.touch_app, color: fgColor),
            const SizedBox(width: 8),
            Text(
              "⚡ Haritaya Dokun",
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

/// Bölge seçim işlemini gösterir ve kontrol sağlar (Çoklu Köşe Versiyonu)
class RegionSelectionIndicator extends StatelessWidget {
  final List<LatLng> points;
  final VoidCallback onCancel;

  const RegionSelectionIndicator({
    super.key,
    required this.points,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeViewModel>(context);
    final mapViewModel = Provider.of<MapViewModel>(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Başlık ve İstatistik
          Row(
            children: [
              const Icon(Icons.select_all, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      points.length < 3
                          ? 'En az 3 köşe seçin (${points.length}/3+)'
                          : 'Bölge hazır! ${points.length} köşe seçildi.',
                      style: TextStyle(
                        color: theme.textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (points.isNotEmpty)
                      Text(
                        'Köşeleri sürükleyerek hareket ettirebilirsiniz',
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red, size: 20),
                onPressed: onCancel,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          // Köşe Noktaları Listesi
          if (points.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(
                    points.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: _buildPointChip(
                        index + 1,
                        points[index],
                        theme,
                        () => mapViewModel.removeLastPoint(),
                        isLast: index == points.length - 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Kontrol Butonları
          if (points.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => mapViewModel.removeLastPoint(),
                      icon: const Icon(Icons.undo, size: 16),
                      label: const Text('Son Noktayı Sil'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (points.length >= 3)
                    Expanded(
                      child: ElevatedButton.icon(
                        key: const Key('calculate_region_btn'),
                        onPressed: () {
                          // Optimizasyon dialogunu aç
                          OptimizationDialog.show(context, mapViewModel, theme);
                        },
                        icon: const Icon(Icons.calculate, size: 16),
                        label: const Text('Hesapla'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static Widget _buildPointChip(
    int number,
    LatLng coord,
    ThemeViewModel theme,
    VoidCallback onDelete, {
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isLast
            ? Colors.orange.withValues(alpha: 0.1)
            : Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isLast
              ? Colors.orange.withValues(alpha: 0.5)
              : Colors.blue.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'K$number: ${coord.latitude.toStringAsFixed(3)}, ${coord.longitude.toStringAsFixed(3)}',
            style: TextStyle(color: theme.textColor, fontSize: 10),
          ),
          if (isLast) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: onDelete,
              child: Icon(Icons.close, size: 14, color: Colors.orange),
            ),
          ],
        ],
      ),
    );
  }
}
