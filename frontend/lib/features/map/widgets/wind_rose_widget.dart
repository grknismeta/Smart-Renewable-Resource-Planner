import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:frontend/data/models/recommendation_model.dart';

/// Rüzgar gülü (Wind Rose) widget'ı.
///
/// 16 yönlü polar grafik çizer:
/// - Her petal (yaprak) o yönden gelen rüzgar frekansını temsil eder
/// - Petal rengi ortalama rüzgar hızına göre değişir (mavi → yeşil → sarı → turuncu → kırmızı)
/// - İç çemberler frekans ölçeğini gösterir
class WindRoseWidget extends StatelessWidget {
  final WindRoseData data;
  final double size;
  final String cityName;

  const WindRoseWidget({
    super.key,
    required this.data,
    required this.cityName,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _WindRosePainter(data: data),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _WindRosePainter extends CustomPainter {
  final WindRoseData data;

  const _WindRosePainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 * 0.80;

    final maxFreq = data.frequencies.fold(0.0, math.max);
    final maxSpeed = data.avgSpeeds.fold(0.0, math.max).clamp(1.0, 20.0);

    // ── Arka plan halkaları ───────────────────────────────────────────────────
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, maxRadius * i / 4, gridPaint);
    }

    // ── Yön çizgileri (her 22.5° = 16 yön) ──────────────────────────────────
    final dirLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 0.6;

    for (int i = 0; i < 16; i++) {
      final angle = math.pi / 8 * i - math.pi / 2;
      canvas.drawLine(center, center + Offset(math.cos(angle), math.sin(angle)) * maxRadius, dirLinePaint);
    }

    // ── Petaller ─────────────────────────────────────────────────────────────
    if (maxFreq > 0) {
      final n = data.directions.length;
      final sectorAngle = 2 * math.pi / n;

      for (int i = 0; i < n; i++) {
        final freq = data.frequencies[i];
        if (freq <= 0) continue;

        final speed = data.avgSpeeds[i];
        final petalRadius = maxRadius * (freq / maxFreq);

        // Rüzgar hızına göre renk (mavi→teal→yeşil→sarı→turuncu→kırmızı)
        final t = (speed / maxSpeed).clamp(0.0, 1.0);
        final petalColor = _windSpeedColor(t);

        // Yön açısı (kuzey = -π/2)
        final centerAngle = data.directions[i] * math.pi / 180 - math.pi / 2;
        final startAngle = centerAngle - sectorAngle / 2;

        final path = Path();
        path.moveTo(center.dx, center.dy);
        path.arcTo(
          Rect.fromCircle(center: center, radius: petalRadius),
          startAngle,
          sectorAngle,
          false,
        );
        path.close();

        // Dolgu
        canvas.drawPath(
          path,
          Paint()
            ..color = petalColor.withValues(alpha: 0.75)
            ..style = PaintingStyle.fill,
        );

        // Kenar
        canvas.drawPath(
          path,
          Paint()
            ..color = petalColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
      }
    }

    // ── Merkez nokta ─────────────────────────────────────────────────────────
    canvas.drawCircle(
      center,
      4,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );

    // ── Pusula etiketleri ─────────────────────────────────────────────────────
    _drawLabel(canvas, center, 'K', Offset(0, -(maxRadius + 12)), size);
    _drawLabel(canvas, center, 'G', Offset(0, maxRadius + 14), size);
    _drawLabel(canvas, center, 'D', Offset(maxRadius + 12, 0), size);
    _drawLabel(canvas, center, 'B', Offset(-(maxRadius + 14), 0), size);
  }

  void _drawLabel(Canvas canvas, Offset center, String label, Offset offset, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(
      canvas,
      center + offset - Offset(tp.width / 2, tp.height / 2),
    );
  }

  /// Rüzgar hızı oranına göre renk (0=mavi, 0.5=yeşil, 1=kırmızı)
  Color _windSpeedColor(double t) {
    final colors = [
      const Color(0xFF2196F3), // Mavi — düşük hız
      const Color(0xFF4CAF50), // Yeşil
      const Color(0xFFFFEB3B), // Sarı
      const Color(0xFFFF9800), // Turuncu
      const Color(0xFFF44336), // Kırmızı — yüksek hız
    ];
    final scaled = t * (colors.length - 1);
    final idx = scaled.floor().clamp(0, colors.length - 2);
    final frac = scaled - idx;
    return Color.lerp(colors[idx], colors[idx + 1], frac)!;
  }

  @override
  bool shouldRepaint(_WindRosePainter old) => old.data != data;
}
