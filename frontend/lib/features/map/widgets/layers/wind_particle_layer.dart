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
  double speed; // IDW'den cache'lenen hız (m/s) — paint'te yeniden hesaplanmaz
  int age;
  int maxAge;
  // Trail coğrafi koordinat olarak saklanır: harita pan/zoom'da doğru çizilir,
  // paint() içinde state mutasyonu olmaz.
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
            particleCount: 800, fps: 20, trailLen: 6, maxAge: 120);
      case WindParticleQuality.balanced:
        return const _QualityParams(
            particleCount: 2000, fps: 30, trailLen: 8, maxAge: 160);
      case WindParticleQuality.heavy:
        return const _QualityParams(
            particleCount: 5000, fps: 60, trailLen: 12, maxAge: 200);
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

  // FPS limiti: Stopwatch ile hedef frame süresini takip et.
  // AnimationController 60fps'de çalışır; _tick() gereksiz frame'leri erken döner.
  final Stopwatch _tickStopwatch = Stopwatch()..start();

  // Türkiye sınırları (biraz daha geniş)
  static const double _minLat = MapConstants.turkeyMinLat;
  static const double _maxLat = MapConstants.turkeyMaxLat;
  static const double _minLon = MapConstants.turkeyMinLon;
  static const double _maxLon = MapConstants.turkeyMaxLon;

  // Simülasyon zaman adımı (saniye/tick) — yavaşlatılmış görünüm için
  static const double _dt = 600.0;

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
      // Parçacık sayısını ayarla
      if (_particles.length < _params.particleCount) {
        _particles.addAll(
          _initParticles(_params.particleCount - _particles.length),
        );
      } else if (_particles.length > _params.particleCount) {
        _particles = _particles.sublist(0, _params.particleCount);
      }
      // trailLen azaldıysa fazla trail noktalarını at
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
      age: _rng.nextInt(_params.maxAge), // Stagger ages for natural look
      maxAge: _params.maxAge + _rng.nextInt(60) - 30,
    );
  }

  void _resetParticle(_Particle p) {
    p.lat = _minLat + _rng.nextDouble() * (_maxLat - _minLat);
    p.lon = _minLon + _rng.nextDouble() * (_maxLon - _minLon);
    p.age = 0;
    p.speed = 0.0;
    p.maxAge = _params.maxAge + _rng.nextInt(60) - 30;
    p.trail.clear();
  }

  /// IDW (Inverse Distance Weighting) — en yakın 5 vektörden interpolasyon
  (double u, double v, double speed) _interpolate(double lat, double lon) {
    if (widget.vectors.isEmpty) return (0, 0, 0);

    // Mesafeleri hesapla ve en yakın 5'i seç
    final distances = <(int, double)>[];
    for (int i = 0; i < widget.vectors.length; i++) {
      final v = widget.vectors[i];
      final dLat = v.lat - lat;
      final dLon = (v.lon - lon) * cos(lat * pi / 180);
      final d2 = dLat * dLat + dLon * dLon;
      distances.add((i, d2));
    }
    distances.sort((a, b) => a.$2.compareTo(b.$2));

    final nearest = distances.take(5);
    double wSum = 0, uSum = 0, vSum = 0, sSum = 0;

    for (final (idx, d2) in nearest) {
      final w = 1.0 / (d2 + 0.001); // +epsilon to avoid division by zero
      final vec = widget.vectors[idx];
      uSum += vec.u * w;
      vSum += vec.v * w;
      sSum += vec.speed * w;
      wSum += w;
    }

    return (uSum / wSum, vSum / wSum, sSum / wSum);
  }

  void _tick() {
    // ─── FPS Limiti ────────────────────────────────────────────────────────
    // AnimationController 60fps'de çalışır; _params.fps'ten düşük kalite
    // seçildiğinde gereksiz tick'leri atla → CPU tasarrufu.
    final targetMs = (1000.0 / _params.fps).floor();
    if (_tickStopwatch.elapsedMilliseconds < targetMs) return;
    _tickStopwatch.reset();
    // ──────────────────────────────────────────────────────────────────────

    for (final p in _particles) {
      final (u, v, s) = _interpolate(p.lat, p.lon);

      // Hızı cache'le → paint() içinde yeniden IDW çalıştırmaya gerek yok
      p.speed = s;

      // Coğrafi hareket: U → lon (doğu+), V → lat (kuzey+)
      p.lon += u * _dt / (111320.0 * cos(p.lat * pi / 180));
      p.lat += v * _dt / 111320.0;
      p.age++;

      // Trail'e coğrafi koordinat olarak ekle (ekran değil)
      // Böylece: (1) harita pan/zoom'da trail doğru kalır,
      //          (2) paint() tamamen saf/stateless — mutation yok
      p.trail.addLast(LatLng(p.lat, p.lon));
      if (p.trail.length > _params.trailLen) {
        p.trail.removeFirst();
      }

      // Sınır dışı veya yaşlandıysa reset
      if (p.age > p.maxAge ||
          p.lat < _minLat ||
          p.lat > _maxLat ||
          p.lon < _minLon ||
          p.lon > _maxLon) {
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
// TAMAMEN SAF: state mutation yok, IDW çağrısı yok.
// Her frame'de trail LatLng → ekran Offset dönüşümü yapılır;
// bu işlem O(trailLen) ve harita pan/zoom'da trail'in haritayla
// birlikte hareket etmesini sağlar.

class _WindParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final MapCamera camera;

  _WindParticlePainter({
    required this.particles,
    required this.camera,
  });

  /// Rüzgar hızından renk (Windy.com paleti)
  static Color _speedColor(double speed) {
    if (speed <= 3) return const Color(0xFF1a237e); // derin mavi
    if (speed <= 6) return const Color(0xFF0288d1); // mavi
    if (speed <= 9) return const Color(0xFF00bcd4); // turkuaz/cyan
    if (speed <= 12) return const Color(0xFF4caf50); // yeşil
    return const Color(0xFFFFFFFF); // beyaz (çok kuvvetli)
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      if (p.trail.length < 2) continue;

      final baseColor = _speedColor(p.speed);

      // Yaşa göre genel opaklık (doğma/ölme fade)
      final lifeFraction = p.age / p.maxAge.toDouble();
      final lifeFade = lifeFraction < 0.1
          ? lifeFraction / 0.1
          : lifeFraction > 0.8
              ? (1.0 - lifeFraction) / 0.2
              : 1.0;

      // LatLng → ekran Offset (saf dönüşüm, state yok)
      final points =
          p.trail.map((ll) => camera.getOffsetFromOrigin(ll)).toList();

      // Trail çiz — soldan sağa (eski→yeni) artan opaklık
      for (int i = 1; i < points.length; i++) {
        final segFade = i / points.length.toDouble();
        final alpha = (lifeFade * segFade * 0.8).clamp(0.0, 1.0);

        canvas.drawLine(
          points[i - 1],
          points[i],
          Paint()
            ..color = baseColor.withValues(alpha: alpha)
            ..strokeWidth = 1.2 + p.speed * 0.08
            ..strokeCap = StrokeCap.round
            ..isAntiAlias = true,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WindParticlePainter oldDelegate) => true;
}
