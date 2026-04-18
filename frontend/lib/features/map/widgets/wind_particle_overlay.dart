import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:frontend/features/map/models/map_models.dart';
import 'package:maplibre/maplibre.dart' as ml;
import 'package:frontend/features/map/widgets/map_view_maplibre.dart';

/// Harita üzerine rüzgar parçacık animasyonu gösteren şeffaf overlay.
/// Native (Android/iOS) için CustomPainter tabanlı çözüm.
/// Web'de JS canvas kullanıldığı için bu widget sadece native'de aktif.
class WindParticleOverlay extends StatefulWidget {
  final List<WindVector> vectors;
  final bool active;

  const WindParticleOverlay({
    super.key,
    required this.vectors,
    this.active = true,
  });

  @override
  State<WindParticleOverlay> createState() => _WindParticleOverlayState();
}

class _WindParticleOverlayState extends State<WindParticleOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _initParticles();
  }

  @override
  void didUpdateWidget(WindParticleOverlay old) {
    super.didUpdateWidget(old);
    if (widget.vectors != old.vectors || widget.active != old.active) {
      _initParticles();
    }
  }

  void _initParticles() {
    _particles.clear();
    if (!widget.active || widget.vectors.isEmpty) return;

    // Her vektör noktasında 2-3 parçacık oluştur
    for (final v in widget.vectors) {
      final count = 2 + _rng.nextInt(2); // 2-3 parçacık
      for (int i = 0; i < count; i++) {
        _particles.add(_Particle(
          baseLat: v.lat + (_rng.nextDouble() - 0.5) * 0.3,
          baseLon: v.lon + (_rng.nextDouble() - 0.5) * 0.3,
          u: v.u,
          v: v.v,
          speed: v.speed,
          phase: _rng.nextDouble(), // Rastgele başlangıç fazı
          life: 0.6 + _rng.nextDouble() * 0.4, // 0.6-1.0 ömür
        ));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active || _particles.isEmpty) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _WindParticlePainter(
              particles: _particles,
              progress: _controller.value,
              controller: MapViewMapLibre.activeControllerForOverlay,
            ),
          );
        },
      ),
    );
  }
}

class _Particle {
  final double baseLat;
  final double baseLon;
  final double u; // Doğu bileşeni (m/s)
  final double v; // Kuzey bileşeni (m/s)
  final double speed;
  final double phase;
  final double life;

  _Particle({
    required this.baseLat,
    required this.baseLon,
    required this.u,
    required this.v,
    required this.speed,
    required this.phase,
    required this.life,
  });
}

class _WindParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final ml.MapController? controller;

  _WindParticlePainter({
    required this.particles,
    required this.progress,
    required this.controller,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (controller == null) return;

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final p in particles) {
      // Parçacık ömrü: phase'den başla, life süresince yaşa
      final t = (progress + p.phase) % 1.0;
      if (t > p.life) continue;
      final normalizedT = t / p.life;

      // Rüzgar yönünde hareket: lat/lon ofset
      // u → doğu (lon), v → kuzey (lat)
      // 0.01° ≈ 1km civarında ölçek
      final scaleFactor = p.speed.clamp(0.5, 15.0) * 0.003;
      final curLat = p.baseLat + p.v * normalizedT * scaleFactor;
      final curLon = p.baseLon + p.u * normalizedT * scaleFactor;

      // Kuyruk noktası (biraz geride)
      final tailT = (normalizedT - 0.15).clamp(0.0, 1.0);
      final tailLat = p.baseLat + p.v * tailT * scaleFactor;
      final tailLon = p.baseLon + p.u * tailT * scaleFactor;

      try {
        final headScreen = controller!.toScreenLocationSync(
          ml.Position(curLon, curLat),
        );
        final tailScreen = controller!.toScreenLocationSync(
          ml.Position(tailLon, tailLat),
        );

        // Ekran dışındaysa atla
        if (headScreen.dx < -50 || headScreen.dx > size.width + 50 ||
            headScreen.dy < -50 || headScreen.dy > size.height + 50) {
          continue;
        }

        // Opaklık: başta ve sonda soluk, ortada parlak
        final alpha = (math.sin(normalizedT * math.pi) * 0.7).clamp(0.0, 1.0);
        final speedNorm = (p.speed / 15.0).clamp(0.2, 1.0);

        // Hız bazlı renk: yavaş=açık mavi, hızlı=koyu mavi/beyaz
        paint
          ..color = Color.lerp(
            const Color(0xFF64B5F6),
            const Color(0xFFE3F2FD),
            speedNorm,
          )!.withValues(alpha: alpha)
          ..strokeWidth = 1.5 + speedNorm * 1.5;

        canvas.drawLine(
          Offset(tailScreen.dx, tailScreen.dy),
          Offset(headScreen.dx, headScreen.dy),
          paint,
        );
      } catch (_) {
        // toScreenLocationSync ekran dışı koordinatlarda hata verebilir
        continue;
      }
    }
  }

  @override
  bool shouldRepaint(_WindParticlePainter old) => true;
}
