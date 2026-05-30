// lib/features/pins/widgets/pin_type_popover_inline.dart
//
// 2026-05-08 — V3 inline popover (Sprint 1.1)
// ----------------------------------------------------------------------------
// Pin Add Flow ikinci aşaması (bkz. [[PinAddFlow]]):
//   1. "Santral Kur" tuşu → placing mode (cursor crosshair)
//   2. **Harita tıkla → BU POPOVER tıklanan noktanın ÜSTÜNDE açılır**
//   3. Tip seç → V2 zengin floating form
//
// Pattern: kart yan-anchored değil, tam tıklanan noktanın ÜZERİNDE konumlanır.
// Ekran kenarına yakınsa flip eder (altta/yanda göster). Kompakt ama
// dokunulabilir alanlar — mobile parmak için ≥44px hit area.
//
// Görsel:
//   ┌──────────────────────────────────────┐
//   │ 📍 Yusufeli / Artvin   40.82°,41.53° │
//   │ Burada ne kuracaksın?                │
//   │ ┌──────┐ ┌──────┐ ┌──────┐           │
//   │ │ ☀    │ │ 💨   │ │ 💧   │           │
//   │ │Güneş │ │Rüzgar│ │ HES  │           │
//   │ └──────┘ └──────┘ └──────┘           │
//   │ Tip seç → form genişler. ESC ile kapat│
//   └──────────────────────────────────────┘
//                  ▼ (tıklanan nokta)

import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';

class PinTypePopoverInline extends StatelessWidget {
  final ThemeViewModel theme;

  /// "İl / İlçe" başlığı (reverse geocode'dan). Boşsa "Türkiye dışı" gösterir.
  final String locationLabel;

  /// "40.82°, 41.53°" koordinat metni.
  final String coordsLabel;

  /// Tip seçildiğinde çağrılır: 'Güneş Paneli' | 'Rüzgar Türbini' | 'HES'.
  final void Function(String pinType) onSelect;

  final VoidCallback onClose;

  const PinTypePopoverInline({
    super.key,
    required this.theme,
    required this.locationLabel,
    required this.coordsLabel,
    required this.onSelect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: theme.cardColor.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.secondaryTextColor.withValues(alpha: 0.18),
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 14, offset: Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: il/ilçe (baskın) + koordinat (küçük) + close
            Row(
              children: [
                Icon(Icons.place_rounded,
                    size: 14, color: theme.secondaryTextColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    locationLabel.isEmpty ? 'Türkiye dışı' : locationLabel,
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  coordsLabel,
                  style: TextStyle(
                    color: theme.secondaryTextColor.withValues(alpha: 0.85),
                    fontSize: 10,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onClose,
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: theme.secondaryTextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Burada ne kuracaksın?',
              style: TextStyle(
                color: theme.textColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _typeCard(
                    type: 'Güneş Paneli',
                    label: 'Güneş',
                    icon: Icons.wb_sunny_rounded,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _typeCard(
                    type: 'Rüzgar Türbini',
                    label: 'Rüzgar',
                    icon: Icons.wind_power_rounded,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _typeCard(
                    type: 'HES',
                    label: 'HES',
                    icon: Icons.water_drop_rounded,
                    color: const Color(0xFF1DB954),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Tip seç → form genişler. ESC ile kapat.',
              style: TextStyle(
                color: theme.secondaryTextColor.withValues(alpha: 0.7),
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeCard({
    required String type,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelect(type),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          // Mobile dokunulabilir min ≥44px hit area
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
