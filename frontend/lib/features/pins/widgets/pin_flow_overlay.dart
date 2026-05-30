// lib/features/pins/widgets/pin_flow_overlay.dart
//
// 2026-05-26 (K1) — Floating Draggable Card
// ============================================================================
// Eski `_AnchoredBubble` + tail painter ve mobile bottom-sheet branch'i
// rafa kaldırıldı. Yeni davranış:
//
//   • Hem mobile hem desktop'ta tek floating draggable card.
//   • İlk açılışta sağ-altta varsayılan konum (FAB üstüne değil).
//   • Kullanıcı header bar'ı tutup sürükler → kart taşınır.
//   • Konum oturum boyu hatırlanır (`_persistedPosition`) — yeni pin açıldığında
//     en son bırakılan yere gelir.
//   • Drag esnasında ekran kenarına `clamp` — kart dışarı çıkamaz.
//
// State machine `PinFlowController`'da kalır (clean). Burada sadece render +
// pozisyon yönetimi.

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/pins/controllers/pin_flow_controller.dart';
import 'package:frontend/features/pins/dialogs/add_pin_dialog.dart';
import 'package:frontend/features/pins/dialogs/pin_details_dialog.dart';
import 'package:frontend/features/pins/widgets/pin_type_popover_inline.dart';

/// Oturum boyu hatırlanan son pozisyon. Null → default sağ-alt köşe.
/// Static field; widget tree'den bağımsız yaşar (her yeni pin pop-up'ı
/// aynı yere açılır).
Offset? _persistedPosition;

class PinFlowOverlay extends StatefulWidget {
  final PinFlowController controller;
  final void Function(String pinType)? onTypeSelected;

  const PinFlowOverlay({
    super.key,
    required this.controller,
    this.onTypeSelected,
  });

  @override
  State<PinFlowOverlay> createState() => _PinFlowOverlayState();
}

class _PinFlowOverlayState extends State<PinFlowOverlay> {
  Offset? _pos; // local cache — sync ile _persistedPosition

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
    _pos = _persistedPosition;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    super.dispose();
  }

  void _onControllerChange() => setState(() {});

  /// Default pos: sağ-alt köşe (FAB'ın yanı değil — sağdan 16, alttan ~140
  /// → mobile FAB ile çakışmaz).
  Offset _defaultPosition(Size screen, double cardWidth) {
    return Offset(
      screen.width - cardWidth - 16,
      screen.height - (screen.height * 0.55) - 140,
    );
  }

  /// 2026-05-26 (L2): Clamp gevşetildi — kullanıcı kartı ekran dışına
  /// sürükleyebilir. Sadece "header bar'ın tamamı ekran dışına çıkmasın"
  /// kuralı kalır → kullanıcı yine close/drag erişimini koruyabilir.
  /// Minimum görünür alan: 60px x, 30px y.
  Offset _clamp(Offset raw, Size screen, double cardWidth, double cardHeight) {
    // Kart en az 60px x görünür olsun (drag handle ve close icon erişilebilir
    // kalsın). Sol/sağ ekran dışına %90 taşabilir.
    final minX = -(cardWidth - 60);
    final maxX = screen.width - 60;
    // Üstte negatif y kabul; alttaki minimum görünür alan 30px.
    final minY = -30.0;
    final maxY = screen.height - 30;
    final x = raw.dx.clamp(minX, maxX);
    final y = raw.dy.clamp(minY, maxY);
    return Offset(x, y);
  }

  void _onDragDelta(Offset delta, Size screen, double cardWidth) {
    setState(() {
      final current = _pos ?? _defaultPosition(screen, cardWidth);
      _pos = _clamp(
        current + delta,
        screen,
        cardWidth,
        300, // placeholder height; clamp X dominant
      );
    });
  }

  void _onDragEnd() {
    // Son pozisyonu oturum-persisted'a yaz
    _persistedPosition = _pos;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    if (!ctrl.hasOverlay) return const SizedBox.shrink();

    final screen = MediaQuery.of(context).size;
    final cardWidth = _widthForMode(ctrl.mode);
    final content = _buildContent(context);
    if (content == null) return const SizedBox.shrink();

    // _pos null ise default
    final pos = _pos ?? _defaultPosition(screen, cardWidth);
    final clampedPos = _clamp(pos, screen, cardWidth, 300);

    return Positioned(
      left: clampedPos.dx,
      top: clampedPos.dy,
      child: PointerInterceptor(
        child: SizedBox(
          width: cardWidth,
          child: content,
        ),
      ),
    );
  }

  double _widthForMode(PinFlowMode mode) {
    switch (mode) {
      case PinFlowMode.typeSelection:
        return 280;
      case PinFlowMode.addForm:
      case PinFlowMode.detail:
      case PinFlowMode.editForm:
        return 300; // K1: 400 → 300
      case PinFlowMode.idle:
      case PinFlowMode.placing:
        return 280;
    }
  }

  Widget? _buildContent(BuildContext context) {
    final ctrl = widget.controller;
    final screen = MediaQuery.of(context).size;
    final cardWidth = _widthForMode(ctrl.mode);

    void Function(Offset) dragDelta(double w) =>
        (d) => _onDragDelta(d, screen, w);

    switch (ctrl.mode) {
      case PinFlowMode.typeSelection:
        if (ctrl.point == null) return null;
        final themeVM = Provider.of<ThemeViewModel>(context, listen: false);
        // Type popover şu an drag desteklemiyor (küçük, hızlı kapanır).
        return PinTypePopoverInline(
          theme: themeVM,
          locationLabel: ctrl.isResolvingLocation ? '...' : ctrl.locationLabel,
          coordsLabel:
              '${ctrl.point!.latitude.toStringAsFixed(2)}°, ${ctrl.point!.longitude.toStringAsFixed(2)}°',
          onSelect: (type) {
            ctrl.selectType(type);
            widget.onTypeSelected?.call(type);
          },
          onClose: ctrl.close,
        );

      case PinFlowMode.addForm:
        if (ctrl.point == null || ctrl.selectedType == null) return null;
        return AddPinDialog(
          key: ValueKey(
              'add-${ctrl.point!.latitude}-${ctrl.point!.longitude}-${ctrl.selectedType}'),
          point: ctrl.point!,
          initialPinType: ctrl.selectedType!,
          onClose: ctrl.close,
          onDragDelta: dragDelta(cardWidth),
          onDragEnd: _onDragEnd,
        );

      case PinFlowMode.detail:
      case PinFlowMode.editForm:
        if (ctrl.activePin == null) return null;
        return PinDetailsDialog(
          key: ValueKey('detail-${ctrl.activePin!.id}'),
          pin: ctrl.activePin!,
          onClose: ctrl.close,
          onDragDelta: dragDelta(cardWidth),
          onDragEnd: _onDragEnd,
        );

      case PinFlowMode.idle:
      case PinFlowMode.placing:
        return null;
    }
  }
}
