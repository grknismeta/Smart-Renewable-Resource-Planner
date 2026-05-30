// lib/shared/widgets/animated_gradient_button.dart
//
// 2026-05-09 — AnimatedGradientButton
// ----------------------------------------------------------------------------
// "Premium" bottom-sheet butonu: hover/tap anında shimmer sweep + mikro-ikon
// animasyonları. Default state'te ikonlar statik (dikkat dağıtmasın, perf).
//
// Kullanım:
//   AnimatedGradientButton(
//     label: 'Kütüphane',
//     icon: Icons.collections_bookmark_rounded,
//     accentColor: Colors.blueAccent,
//     onPressed: () => ...,
//     microIcons: [
//       BuiltInMicroIcons.spinningSun(),
//       BuiltInMicroIcons.bouncingWaterDrop(),
//       BuiltInMicroIcons.spinningWind(),
//     ],
//   )
//
// Anti-pattern uyarıları:
//   - Animasyon SÜREKLİ çalıştırılmaz (hover/tap-down anında forward, çıkışta
//     reverse). Ekrandaki diğer butonu etkilemez.
//   - Lottie wrapper desteği için `BuiltInMicroIcons.lottie(...)` eklenebilir
//     (asset gelince). Şu an pure-Flutter Transform animasyonları kullanılır.
//   - ShaderMask + LinearGradient ile shimmer sweep — InkWell ripple yerine.

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Bottom sheet'te kullanılan ana eylem butonu — hover/tap'te canlanır.
class AnimatedGradientButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onPressed;
  /// Yandaki mini animasyonlu ikonlar (3 adet önerilir; daha fazlası taşar).
  final List<MicroIconBuilder> microIcons;
  /// Yükseklik — bottom sheet butonu için 56-64 önerilir.
  final double minHeight;

  const AnimatedGradientButton({
    super.key,
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onPressed,
    this.microIcons = const [],
    this.minHeight = 56,
  });

  @override
  State<AnimatedGradientButton> createState() => _AnimatedGradientButtonState();
}

class _AnimatedGradientButtonState extends State<AnimatedGradientButton>
    with TickerProviderStateMixin {
  /// Sweep shimmer animasyonu — hover/tap-down tetikler, tek seferlik soldan
  /// sağa kayar. 700ms tek tur, çıkışta otomatik durur.
  late final AnimationController _shimmer;

  /// Mikro-ikon animasyonları — hover/tap-down boyunca aktif, çıkışta reverse.
  /// Tek controller — tüm mikro ikonlar bu animasyona bağlı (paralel).
  late final AnimationController _hover;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      duration: const Duration(milliseconds: 720),
      vsync: this,
    );
    _hover = AnimationController(
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 220),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _shimmer.dispose();
    _hover.dispose();
    super.dispose();
  }

  void _onEnter() {
    if (widget.onPressed == null) return;
    _hover.forward();
    if (!_shimmer.isAnimating) {
      _shimmer.forward(from: 0);
    }
  }

  void _onExit() {
    _hover.reverse();
  }

  void _onTapDown() {
    if (widget.onPressed == null) return;
    _shimmer.forward(from: 0);
    _hover.forward();
  }

  void _onTapUp() {
    _hover.reverse();
    widget.onPressed?.call();
  }

  void _onTapCancel() {
    _hover.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    final bgColor = widget.accentColor.withValues(alpha: disabled ? 0.04 : 0.10);
    final borderColor = widget.accentColor.withValues(alpha: disabled ? 0.15 : 0.30);
    final fgColor = disabled
        ? widget.accentColor.withValues(alpha: 0.5)
        : widget.accentColor;

    return MouseRegion(
      onEnter: (_) => _onEnter(),
      onExit: (_) => _onExit(),
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _onTapDown(),
        onTapUp: (_) => _onTapUp(),
        onTapCancel: _onTapCancel,
        child: AnimatedBuilder(
          animation: Listenable.merge([_shimmer, _hover]),
          builder: (context, _) {
            return Container(
              constraints: BoxConstraints(minHeight: widget.minHeight),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Color.lerp(borderColor, widget.accentColor, _hover.value)!,
                  width: 1 + (_hover.value * 0.6),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Shimmer sweep — soldan sağa parlayan diyagonal gradient
                  if (_shimmer.isAnimating || _shimmer.value > 0)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: _ShimmerSweep(
                          progress: _shimmer.value,
                          accentColor: widget.accentColor,
                        ),
                      ),
                    ),
                  // Buton içeriği — ikon + label + mikro ikonlar
                  // 2026-05-25 (F1): Dar butonlarda (Row Expanded içinde iki tane,
                  // 1080px telefonda her biri ~165px) microIcons + uzun label
                  // sığmıyor ve Flexible(Text) "Kü..." gibi kesiliyor. LayoutBuilder
                  // ile genişlik <240 ise microIcons gizlenir → label tam görünür.
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 12),
                    child: LayoutBuilder(builder: (ctx, c) {
                      final compact = c.maxWidth < 240;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(widget.icon, size: 20, color: fgColor),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              widget.label,
                              style: TextStyle(
                                color: fgColor,
                                fontSize: compact ? 13.5 : 14.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (widget.microIcons.isNotEmpty && !compact) ...[
                            const SizedBox(width: 12),
                            for (final m in widget.microIcons)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: m.build(_hover, fgColor),
                              ),
                          ],
                        ],
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Shimmer sweep painter ──────────────────────────────────────────────────

class _ShimmerSweep extends StatelessWidget {
  final double progress; // 0..1
  final Color accentColor;

  const _ShimmerSweep({required this.progress, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    if (progress <= 0 || progress >= 1) return const SizedBox.shrink();
    return CustomPaint(painter: _ShimmerPainter(progress, accentColor));
  }
}

class _ShimmerPainter extends CustomPainter {
  final double progress;
  final Color accentColor;

  _ShimmerPainter(this.progress, this.accentColor);

  @override
  void paint(Canvas canvas, Size size) {
    // Buton genişliğinin 1.8 katı sweep — soldan -50% başlar, sağa +180% biter
    final sweepWidth = size.width * 0.55;
    final startX = -sweepWidth + (size.width + 2 * sweepWidth) * progress;
    final rect = Rect.fromLTWH(startX, 0, sweepWidth, size.height);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          accentColor.withValues(alpha: 0),
          accentColor.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0.18),
          accentColor.withValues(alpha: 0.22),
          accentColor.withValues(alpha: 0),
        ],
        stops: const [0, 0.35, 0.5, 0.65, 1],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _ShimmerPainter old) =>
      old.progress != progress || old.accentColor != accentColor;
}

// ─── Mikro-ikon builder interface ───────────────────────────────────────────

/// Tek bir mikro-ikon. `build` çağrısı `hover` (0..1) parametresi alır;
/// 0=statik, 1=tam animasyon (hover veya tap-down durumunda).
abstract class MicroIconBuilder {
  Widget build(Animation<double> hover, Color color);
}

/// Hazır mikro-ikon factory'leri.
class BuiltInMicroIcons {
  BuiltInMicroIcons._();

  // ─── KÜTÜPHANE ────────────────────────────────────────────────────────────

  /// GES — Güneş: yavaş döner + parlama (filter glow).
  static MicroIconBuilder spinningSun() => _TransformMicroIcon(
        icon: Icons.wb_sunny_rounded,
        baseColor: Colors.amber,
        animationBuilder: (hover, child) => RotationTransition(
          turns: Tween<double>(begin: 0, end: 1).animate(hover),
          child: child,
        ),
        duration: const Duration(seconds: 4),
      );

  /// HES — Su damlası: yukarı-aşağı zıplama.
  static MicroIconBuilder bouncingWaterDrop() => _TransformMicroIcon(
        icon: Icons.water_drop_rounded,
        baseColor: const Color(0xFF1E88E5),
        animationBuilder: (hover, child) => AnimatedBuilder(
          animation: hover,
          builder: (_, c) {
            final t = hover.value;
            // 0..1 hover'da yumuşak sinüs zıplama
            final dy = -3 * math.sin(t * math.pi * 2);
            return Transform.translate(offset: Offset(0, dy), child: c);
          },
          child: child,
        ),
        duration: const Duration(milliseconds: 800),
      );

  /// RES — Rüzgar türbini: hızlı döner.
  static MicroIconBuilder spinningWind() => _TransformMicroIcon(
        icon: Icons.wind_power_rounded,
        baseColor: const Color(0xFF66BB6A),
        animationBuilder: (hover, child) => RotationTransition(
          turns: Tween<double>(begin: 0, end: 1).animate(hover),
          child: child,
        ),
        duration: const Duration(milliseconds: 1400),
      );

  // ─── RAPORLAR ─────────────────────────────────────────────────────────────

  /// Madeni para: Y ekseninde flip (perspective).
  static MicroIconBuilder flippingCoin() => _TransformMicroIcon(
        icon: Icons.monetization_on_rounded,
        baseColor: const Color(0xFFFBC02D),
        animationBuilder: (hover, child) => AnimatedBuilder(
          animation: hover,
          builder: (_, c) {
            final angle = hover.value * math.pi * 2; // tam tur
            final m = Matrix4.identity()
              ..setEntry(3, 2, 0.0015) // perspective
              ..rotateY(angle);
            return Transform(
              transform: m,
              alignment: Alignment.center,
              child: c,
            );
          },
          child: child,
        ),
        duration: const Duration(milliseconds: 1600),
      );

  /// 3 sütun bar chart — staggered scale Y (kafalar inip çıkar).
  static MicroIconBuilder pulsingBars() => _PulsingBars();

  /// Yukarı-sağ ok: diagonal bounce.
  static MicroIconBuilder bouncingArrow() => _TransformMicroIcon(
        icon: Icons.trending_up_rounded,
        baseColor: const Color(0xFF66BB6A),
        animationBuilder: (hover, child) => AnimatedBuilder(
          animation: hover,
          builder: (_, c) {
            final t = hover.value;
            final dx = 2.5 * math.sin(t * math.pi * 2);
            final dy = -2.5 * math.sin(t * math.pi * 2);
            return Transform.translate(offset: Offset(dx, dy), child: c);
          },
          child: child,
        ),
        duration: const Duration(milliseconds: 900),
      );
}

// ─── Implementations ────────────────────────────────────────────────────────

class _TransformMicroIcon implements MicroIconBuilder {
  final IconData icon;
  final Color baseColor;
  final Widget Function(Animation<double> hover, Widget child) animationBuilder;
  final Duration duration;

  _TransformMicroIcon({
    required this.icon,
    required this.baseColor,
    required this.animationBuilder,
    required this.duration,
  });

  @override
  Widget build(Animation<double> hover, Color color) {
    return _LoopingWhenHovered(
      hover: hover,
      duration: duration,
      builder: (loop) => animationBuilder(
        loop,
        Icon(icon, size: 16, color: baseColor),
      ),
    );
  }
}

/// `_LoopingWhenHovered` — hover animation 1'e doğru ilerlerken **kendi
/// içinde tekrar tekrar 0..1 dönen** bir döngü controller başlatır. Hover
/// 0'a inince loop durur. Bu sayede mikro animasyonlar hover boyunca pürüzsüz
/// devam eder.
class _LoopingWhenHovered extends StatefulWidget {
  final Animation<double> hover;
  final Duration duration;
  final Widget Function(Animation<double> loop) builder;

  const _LoopingWhenHovered({
    required this.hover,
    required this.duration,
    required this.builder,
  });

  @override
  State<_LoopingWhenHovered> createState() => _LoopingWhenHoveredState();
}

class _LoopingWhenHoveredState extends State<_LoopingWhenHovered>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop;

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(vsync: this, duration: widget.duration);
    widget.hover.addListener(_syncLoop);
    _syncLoop();
  }

  void _syncLoop() {
    if (widget.hover.value > 0.05 && !_loop.isAnimating) {
      _loop.repeat();
    } else if (widget.hover.value <= 0.05 && _loop.isAnimating) {
      _loop.stop();
      _loop.reset();
    }
  }

  @override
  void dispose() {
    widget.hover.removeListener(_syncLoop);
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_loop);
}

class _PulsingBars implements MicroIconBuilder {
  @override
  Widget build(Animation<double> hover, Color color) {
    return _LoopingWhenHovered(
      hover: hover,
      duration: const Duration(milliseconds: 900),
      builder: (loop) => SizedBox(
        height: 18, width: 18,
        child: AnimatedBuilder(
          animation: loop,
          builder: (_, __) {
            final t = loop.value;
            // 3 bar staggered — phase shift 0, 0.33, 0.66
            double h(double phase) {
              final p = (t + phase) % 1.0;
              // 0..0.5 yukarı, 0.5..1 aşağı (sinüs)
              return 4 + 10 * (0.5 - 0.5 * math.cos(p * 2 * math.pi));
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _bar(h(0.0)),
                const SizedBox(width: 1.5),
                _bar(h(0.33)),
                const SizedBox(width: 1.5),
                _bar(h(0.66)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _bar(double h) => Container(
        width: 3,
        height: h,
        decoration: BoxDecoration(
          color: Colors.cyanAccent,
          borderRadius: BorderRadius.circular(1.5),
        ),
      );
}
