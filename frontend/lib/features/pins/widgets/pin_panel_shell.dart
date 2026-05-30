// lib/features/pins/widgets/pin_panel_shell.dart
//
// 2026-05-26 (K1) — Floating Draggable Pin Card
// ----------------------------------------------------------------------------
// Tasarım kaynağı: designhtml/add-flows.jsx → FloatingCardAddFlow (V2)
//
// Önemli değişimler:
//   • Mobile bottom-sheet branch'i **rafa kaldırıldı** — tüm cihazlarda
//     floating draggable card.
//   • Default width 300px (önceden 400), maxHeight ekranın %55'i (önceden %78).
//   • Header bar artık **drag handle**: mouse/touch ile başlığın üstünden
//     sürüklenince kart taşınabilir. Cursor `grab`/`grabbing` (web).
//   • Padding/font/ikonlar agresif şekilde küçültüldü → içerik okunur, ekranın
//     küçük bir kısmını kaplar.
//   • Lokasyon satırı tek satır: yer ikonu + il/ilçe baskın + sağda küçük
//     mono koordinat (design HTML pattern).
//
// Composition pattern aynı: caller `body` parametresine kendi içeriğini verir.
// Drag pozisyon yönetimi caller'a `onDragDelta` ile delegated.

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';

/// Pin pop-up kabuğu — kompakt floating card.
///
/// Header bar = drag handle. Caller `onDragDelta` ile delta'yı alıp
/// kendi Positioned'ını günceller (PinFlowOverlay yapar).
class PinPanelShell extends StatefulWidget {
  /// Pin koordinatı — header'da il/ilçe reverse geocode için.
  final LatLng point;

  /// Tip rengi — header gradient + accent.
  final Color accentColor;

  /// Tip ikonu — header sol başında küçük chip içinde.
  final IconData typeIcon;

  /// Başlık — "Yeni Kaynak" veya pin adı.
  final String title;

  /// Kapatma callback'i.
  final VoidCallback onClose;

  /// Body — caller'ın form/detay içeriği. Scrollable otomatik wrapping.
  final Widget body;

  /// Drag delta — header bar'dan sürükleyince çağrılır. PinFlowOverlay
  /// pozisyonunu bu delta ile günceller. Null → drag pasif.
  final ValueChanged<Offset>? onDragDelta;

  /// Drag bitince çağrılır (snap/clamp tetiklemek için).
  final VoidCallback? onDragEnd;

  /// Kart genişliği.
  final double width;

  /// Max yükseklik oranı (ekran yüksekliği × bu).
  final double maxHeightRatio;

  const PinPanelShell({
    super.key,
    required this.point,
    required this.accentColor,
    required this.typeIcon,
    required this.title,
    required this.onClose,
    required this.body,
    this.onDragDelta,
    this.onDragEnd,
    this.width = 300,
    this.maxHeightRatio = 0.55,
  });

  @override
  State<PinPanelShell> createState() => _PinPanelShellState();
}

class _PinPanelShellState extends State<PinPanelShell> {
  String _locationProvince = '';
  String _locationDistrict = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchReverseGeocode());
  }

  @override
  void didUpdateWidget(covariant PinPanelShell old) {
    super.didUpdateWidget(old);
    if (old.point.latitude != widget.point.latitude ||
        old.point.longitude != widget.point.longitude) {
      _fetchReverseGeocode();
    }
  }

  Future<void> _fetchReverseGeocode() async {
    final vm = Provider.of<MapViewModel>(context, listen: false);
    final result = await vm.fetchReverseGeocode(widget.point);
    if (!mounted || result == null) return;
    setState(() {
      _locationProvince = result['province'] ?? '';
      _locationDistrict = result['district'] ?? '';
    });
  }

  String _buildLocationLabel() {
    if (_locationProvince.isEmpty && _locationDistrict.isEmpty) {
      return 'Türkiye dışı';
    }
    if (_locationDistrict.isNotEmpty) {
      return '$_locationDistrict / $_locationProvince';
    }
    return _locationProvince;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeViewModel>(context);
    final screenSize = MediaQuery.of(context).size;
    final constraints =
        BoxConstraints(maxHeight: screenSize.height * widget.maxHeightRatio);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: widget.width,
        constraints: constraints,
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            Colors.black.withValues(alpha: 0.10),
            theme.cardColor,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.accentColor.withValues(alpha: 0.40)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DragHeader(
              accent: widget.accentColor,
              icon: widget.typeIcon,
              title: widget.title,
              onClose: widget.onClose,
              onDragDelta: widget.onDragDelta,
              onDragEnd: widget.onDragEnd,
              theme: theme,
            ),
            _LocationStrip(
              accent: widget.accentColor,
              label: _buildLocationLabel(),
              lat: widget.point.latitude,
              lon: widget.point.longitude,
              theme: theme,
            ),
            // Body — scrollable
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: widget.body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Drag header — taşınabilir + close ───────────────────────────────────────

class _DragHeader extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final String title;
  final VoidCallback onClose;
  final ValueChanged<Offset>? onDragDelta;
  final VoidCallback? onDragEnd;
  final ThemeViewModel theme;

  const _DragHeader({
    required this.accent,
    required this.icon,
    required this.title,
    required this.onClose,
    required this.onDragDelta,
    required this.onDragEnd,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    // Header gradient — design HTML'deki accent strip (üstten alta fade)
    final headerRow = Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0.18),
            accent.withValues(alpha: 0.02),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: theme.secondaryTextColor.withValues(alpha: 0.10),
          ),
        ),
      ),
      child: Row(
        children: [
          // Tip ikon chip — 26x26
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(7),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 14, color: accent),
          ),
          const SizedBox(width: 8),
          // Drag handle çubukları + başlık
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.drag_indicator_rounded,
                  size: 14,
                  color: theme.secondaryTextColor.withValues(alpha: 0.50),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Close
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: theme.secondaryTextColor,
              ),
            ),
          ),
        ],
      ),
    );

    // Drag aktif değilse sade header; aktifse mouse cursor + pan gesture
    if (onDragDelta == null) return headerRow;

    return MouseRegion(
      cursor: SystemMouseCursors.move,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => onDragDelta!(d.delta),
        onPanEnd: (_) => onDragEnd?.call(),
        child: headerRow,
      ),
    );
  }
}

// ─── Location strip — tek satır: ikon + il/ilçe + sağda mono koord ──────────

class _LocationStrip extends StatelessWidget {
  final Color accent;
  final String label;
  final double lat;
  final double lon;
  final ThemeViewModel theme;

  const _LocationStrip({
    required this.accent,
    required this.label,
    required this.lat,
    required this.lon,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.secondaryTextColor.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.place_rounded, size: 12, color: accent),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: theme.textColor.withValues(alpha: 0.92),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${lat.toStringAsFixed(2)}°, ${lon.toStringAsFixed(2)}°',
            style: TextStyle(
              color: theme.secondaryTextColor.withValues(alpha: 0.65),
              fontSize: 10,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
