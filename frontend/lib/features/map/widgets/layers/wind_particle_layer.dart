import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:frontend/features/map/models/map_models.dart';
import 'package:frontend/core/constants/map_constants.dart';

// ─── Parçacık Modeli ──────────────────────────────────────────────────────────

class _Particle {
  double lat;
  double lon;
  double speed;
  int age;
  int maxAge;
  final Queue<LatLng> trail;

  _Particle({
    required this.lat,
    required this.lon,
    required this.age,
    required this.maxAge,
  })  : trail = Queue<LatLng>(),
        speed = 0.0;
}

// ─── Kalite → Parametre Eşleştirmesi ─────────────────────────────────────────

class _QualityParams {
  final int particleCount;
  final int fps;
  final int trailLen;
  final int maxAge;

  const _QualityParams({
    required this.particleCount,
    required this.fps,
    required this.trailLen,
    required this.maxAge,
  });

  static _QualityParams fromQuality(WindParticleQuality q) {
    switch (q) {
      case WindParticleQuality.light:
        return const _QualityParams(
            particleCount: 1000, fps: 20, trailLen: 14, maxAge: 100);
      case WindParticleQuality.balanced:
        return const _QualityParams(
            particleCount: 2500, fps: 30, trailLen: 18, maxAge: 130);
      case WindParticleQuality.heavy:
        return const _QualityParams(
            particleCount: 5000, fps: 60, trailLen: 25, maxAge: 160);
    }
  }
}

// ─── WindParticleLayer Widget ─────────────────────────────────────────────────

class WindParticleLayer extends StatefulWidget {
  final List<WindVector> vectors;
  final WindParticleQuality quality;

  const WindParticleLayer({
    super.key,
    required this.vectors,
    required this.quality,
  });

  @override
  State<WindParticleLayer> createState() => _WindParticleLayerState();
}

class _WindParticleLayerState extends State<WindParticleLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;
  late _QualityParams _params;
  final Random _rng = Random();

  final Stopwatch _tickStopwatch = Stopwatch()..start();

  // Türkiye sınırları
  static const double _minLat = MapConstants.turkeyMinLat;
  static const double _maxLat = MapConstants.turkeyMaxLat;
  static const double _minLon = MapConstants.turkeyMinLon;
  static const double _maxLon = MapConstants.turkeyMaxLon;

  /// Simülasyon zaman adımı (saniye/tick).
  /// 600 → parçacıklar çok hızlı ve uzun iz bırakıyordu; 80 ile doğal akış.
  static const double _dt = 80.0;

  /// IDW maksimum etki mesafesi (derece²).
  /// ~3° ötesindeki parçacıklar "ölü bölge"ye girer → hız = 0 → reset.
  static const double _maxD2 = 9.0; // 3° × 3°

  @override
  void initState() {
    super.initState();
    _params = _QualityParams.fromQuality(widget.quality);
    _particles = _initParticles(_params.particleCount);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _controller.addListener(_tick);
  }

  @override
  void didUpdateWidget(WindParticleLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quality != widget.quality) {
      _params = _QualityParams.fromQuality(widget.quality);
      if (_particles.length < _params.particleCount) {
        _particles.addAll(
          _initParticles(_params.particleCount - _particles.length),
        );
      } else if (_particles.length > _params.particleCount) {
        _particles = _particles.sublist(0, _params.particleCount);
      }
      for (final p in _particles) {
        while (p.trail.length > _params.trailLen) {
          p.trail.removeFirst();
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_tick);
    _controller.dispose();
    super.dispose();
  }

  List<_Particle> _initParticles(int count) {
    return List.generate(count, (_) => _spawnParticle());
  }

  _Particle _spawnParticle() {
    return _Particle(
      lat: _minLat + _rng.nextDouble() * (_maxLat - _minLat),
      lon: _minLon + _rng.nextDouble() * (_maxLon - _minLon),
      age: _rng.nextInt(_params.maxAge),
      maxAge: _params.maxAge + _rng.nextInt(40) - 20,
    );
  }

  void _resetParticle(_Particle p) {
    p.lat = _minLat + _rng.nextDouble() * (_maxLat - _minLat);
    p.lon = _minLon + _rng.nextDouble() * (_maxLon - _minLon);
    p.age = 0;
    p.speed = 0.0;
    p.maxAge = _params.maxAge + _rng.nextInt(40) - 20;
    p.trail.clear();
  }

  /// IDW (Inverse Distance Weighting) interpolasyonu.
  ///
  /// Yeni: eğer en yakın vektör [_maxD2] (3°) ötesindeyse (0, 0, 0) döner.
  /// Böylece Türkiye veri sınırı dışına çıkan parçacıklar yanlış içe doğru
  /// çekilmek yerine durur ve reset olur.
  (double u, double v, double speed) _interpolate(double lat, double lon) {
    if (widget.vectors.isEmpty) return (0, 0, 0);

    final distances = <(int, double)>[];
    for (int i = 0; i < widget.vectors.length; i++) {
      final vec = widget.vectors[i];
      final dLat = vec.lat - lat;
      final dLon = (vec.lon - lon) * cos(lat * pi / 180);
      final d2 = dLat * dLat + dLon * dLon;
      distances.add((i, d2));
    }
    distances.sort((a, b) => a.$2.compareTo(b.$2));

    // Ölü bölge kontrolü: en yakın nokta dahi çok uzaksa dur
    if (distances.first.$2 > _maxD2) return (0.0, 0.0, 0.0);

    // _maxD2 içindeki en fazla 6 noktayı kullan
    final nearest = distances.where((e) => e.$2 <= _maxD2).take(6);

    double wSum = 0, uSum = 0, vSum = 0, sSum = 0;
    for (final (idx, d2) in nearest) {
      final w = 1.0 / (d2 + 0.001);
      final vec = widget.vectors[idx];
      uSum += vec.u * w;
      vSum += vec.v * w;
      sSum += vec.speed * w;
      wSum += w;
    }

    return (uSum / wSum, vSum / wSum, sSum / wSum);
  }

  void _tick() {
    final targetMs = (1000.0 / _params.fps).floor();
    if (_tickStopwatch.elapsedMilliseconds < targetMs) return;
    _tickStopwatch.reset();

    for (final p in _particles) {
      final (u, v, s) = _interpolate(p.lat, p.lon);
      p.speed = s;

      p.lon += u * _dt / (111320.0 * cos(p.lat * pi / 180));
      p.lat += v * _dt / 111320.0;
      p.age++;

      p.trail.addLast(LatLng(p.lat, p.lon));
      if (p.trail.length > _params.trailLen) {
        p.trail.removeFirst();
      }

      // Sınır dışı, yaşlandı veya ölü bölgede → reset
      if (p.age > p.maxAge ||
          p.lat < _minLat - 1 ||
          p.lat > _maxLat + 1 ||
          p.lon < _minLon - 1 ||
          p.lon > _maxLon + 1) {
        _resetParticle(p);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            isComplex: true,
            willChange: true,
            painter: _WindParticlePainter(
              particles: _particles,
              camera: camera,
            ),
          );
        },
      ),
    );
  }
}

// ─── CustomPainter ────────────────────────────────────────────────────────────

class _WindParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final MapCamera camera;

  _WindParticlePainter({
    required this.particles,
    required this.camera,
  });

  /// Windy.com'a yakın hız→renk paleti.
  /// Sakin → mavi, orta → cyan/yeşil, güçlü → sarı, fırtına → beyaz
  static Color _speedColor(double speed) {
    if (speed <= 2)  return const Color(0xFF0D47A1); // derin mavi
    if (speed <= 5)  return const Color(0xFF0288D1); // açık mavi
    if (speed <= 9)  return const Color(0xFF00BCD4); // cyan
    if (speed <= 13) return const Color(0xFF4CAF50); // yeşil
    if (speed <= 18) return const Color(0xFFFFC107); // amber
    if (speed <= 24) return const Color(0xFFFF5722); // turuncu
    return const Color(0xFFFFFFFF);                  // beyaz (fırtına)
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      if (p.trail.length < 2) continue;

      final baseColor = _speedColor(p.speed);

      final lifeFraction = p.age / p.maxAge.toDouble();
      final lifeFade = lifeFraction < 0.1
          ? lifeFraction / 0.1
          : lifeFraction > 0.8
              ? (1.0 - lifeFraction) / 0.2
              : 1.0;

      final points =
          p.trail.map((ll) => camera.getOffsetFromOrigin(ll)).toList();

      for (int i = 1; i < points.length; i++) {
        final segFade = i / points.length.toDouble();
        final alpha = (lifeFade * segFade * 0.85).clamp(0.0, 1.0);

        canvas.drawLine(
          points[i - 1],
          points[i],
          Paint()
            ..color = baseColor.withValues(alpha: alpha)
            ..strokeWidth = 1.0 + p.speed * 0.06
            ..strokeCap = StrokeCap.round
            ..isAntiAlias = true,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WindParticlePainter oldDelegate) => true;
}
