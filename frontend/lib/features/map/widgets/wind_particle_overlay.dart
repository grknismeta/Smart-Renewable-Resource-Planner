import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:frontend/features/map/models/map_models.dart';
import 'package:maplibre/maplibre.dart' as ml;
import 'package:frontend/features/map/widgets/map_view_maplibre.dart';

/// Harita üzerine rüzgar parçacık animasyonu gösteren şeffaf overlay.
/// Native (Android/iOS) için CustomPainter tabanlı çözüm.
/// Web'de JS canvas/WebGL kullanıldığı için bu widget sadece native'de aktif.
///
/// 2026-06-01 (C1/C2): PERF — eskiden her parçacık için her frame'de 2 kez
/// `toScreenLocationSync` (pahalı sync JNI) çağrılıyordu → yüzlerce parçacık ×
/// 2 × 60fps telefonu kilitliyordu. Artık tüm noktalar TEK `toScreenLocationsSync`
/// (batch) çağrısıyla projekte edilir + parçacık sayısı native'e uygun cap'lenir
/// (web'in 800/2000/5000'i değil). Yoğunluk + akıcılık birlikte ("Windy" hissi).
class WindParticleOverlay extends StatefulWidget {
  final List<WindVector> vectors;
  final bool active;
  final WindParticleQuality quality;

  const WindParticleOverlay({
    super.key,
    required this.vectors,
    this.active = true,
    this.quality = WindParticleQuality.balanced,
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
    if (widget.vectors != old.vectors ||
        widget.active != old.active ||
        widget.quality != old.quality) {
      _initParticles();
    }
  }

  /// Native CustomPaint için parçacık tavanı (web WebGL hedefleri değil —
  /// her parçacık bir canvas.drawLine; binlerce çizgi native'de kasar).
  int _targetCount() {
    switch (widget.quality) {
      case WindParticleQuality.light:
        return 120;
      case WindParticleQuality.balanced:
        return 280;
      case WindParticleQuality.heavy:
        return 500;
    }
  }

  void _addParticle(WindVector v) {
    _particles.add(_Particle(
      baseLat: v.lat + (_rng.nextDouble() - 0.5) * 0.3,
      baseLon: v.lon + (_rng.nextDouble() - 0.5) * 0.3,
      u: v.u,
      v: v.v,
      speed: v.speed,
      phase: _rng.nextDouble(),
      life: 0.6 + _rng.nextDouble() * 0.4,
    ));
  }

  void _initParticles() {
    _particles.clear();
    if (!widget.active || widget.vectors.isEmpty) return;

    final target = _targetCount();
    final vecs = widget.vectors;

    if (vecs.length >= target) {
      // Vektör sayısı hedeften fazla → örnekle (stride), her birinden 1 parçacık.
      final stride = (vecs.length / target).ceil();
      for (int vi = 0; vi < vecs.length && _particles.length < target;
          vi += stride) {
        _addParticle(vecs[vi]);
      }
    } else {
      // Az vektör → her birinden birkaç parçacık (hedefe kadar).
      final perVector = (target ~/ vecs.length).clamp(1, 4);
      for (final v in vecs) {
        for (int i = 0; i < perVector && _particles.length < target; i++) {
          _addParticle(v);
        }
        if (_particles.length >= target) break;
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
    final ctrl = controller;
    if (ctrl == null || particles.isEmpty) return;

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // NOT: Parçacık başına projeksiyon (per-point try/catch) — `toScreenLocationsSync`
    // batch'i android'de yine tek tek projekte ediyor AMA per-point try/catch'i
    // yok → ekran dışı tek nokta tüm batch'i patlatıp wind'i gizliyordu. Perf
    // kazancı zaten parçacık CAP'inden geliyor (initParticles), batch'ten değil.
    for (final p in particles) {
      final t = (progress + p.phase) % 1.0;
      if (t > p.life) continue;
      final normalizedT = t / p.life;

      // Rüzgar yönünde hareket: u → doğu (lon), v → kuzey (lat).
      final scaleFactor = p.speed.clamp(0.5, 15.0) * 0.003;
      final curLat = p.baseLat + p.v * normalizedT * scaleFactor;
      final curLon = p.baseLon + p.u * normalizedT * scaleFactor;
      final tailT = (normalizedT - 0.15).clamp(0.0, 1.0);
      final tailLat = p.baseLat + p.v * tailT * scaleFactor;
      final tailLon = p.baseLon + p.u * tailT * scaleFactor;

      try {
        final headScreen =
            ctrl.toScreenLocationSync(ml.Position(curLon, curLat));
        final tailScreen =
            ctrl.toScreenLocationSync(ml.Position(tailLon, tailLat));

        if (headScreen.dx < -50 ||
            headScreen.dx > size.width + 50 ||
            headScreen.dy < -50 ||
            headScreen.dy > size.height + 50) {
          continue;
        }

        final alpha = (math.sin(normalizedT * math.pi) * 0.7).clamp(0.0, 1.0);
        final speedNorm = (p.speed / 15.0).clamp(0.2, 1.0);
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
        continue;
      }
    }
  }

  @override
  bool shouldRepaint(_WindParticlePainter old) => true;
}
