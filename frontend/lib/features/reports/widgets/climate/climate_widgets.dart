// lib/features/reports/widgets/climate/climate_widgets.dart
//
// Paylaşılan iklim görselleştirme widget'ları — Sprint R1.
//
// Bölge tab'ı + İl Analizi "Hava" sub-tab'ı + (ileride) Santral tab
// hepsi aynı climate widget'larını kullanır.
//
//   • WeatherStripCard  — 12 aylık bar mini-chart (ışınım/rüzgar/yağış/sıcaklık)
//   • WindRoseCard      — 8 yön rüzgar gülü
//   • RiverDischargeCard — aylık nehir debisi (mean/min/max)
//
// Veri: ClimateSeries (analysis_service.dart — /analysis/.../climate)

import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:frontend/core/network/api_service.dart';

const _months = ['O', 'Ş', 'M', 'N', 'M', 'H', 'T', 'A', 'E', 'E', 'K', 'A'];

// ─────────────────────────────────────────────────────────────────────────────
// WEATHER STRIP — 12 aylık bar mini-chart
// ─────────────────────────────────────────────────────────────────────────────

class WeatherStripCard extends StatelessWidget {
  final String label;
  final String unit;
  final List<double> data;
  final Color color;

  const WeatherStripCard({
    super.key,
    required this.label,
    required this.unit,
    required this.data,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final avg = data.isEmpty ? 0.0 : data.reduce((a, b) => a + b) / data.length;
    final maxV = data.isEmpty ? 0.0 : data.reduce(math.max);
    final minV = data.isEmpty ? 0.0 : data.reduce(math.min);
    // Ondalık duyarlığı veriye göre — küçük değerler (m/s) 1 ondalık,
    // büyük değerler (mm/ay) tamsayı.
    final decimals = maxV < 10 ? 1 : 0;
    String fmt(double v) => v.toStringAsFixed(decimals);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst satır: başlık + birim
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      unit,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.30),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              // 2026-05-25 (Fix1): min · ort · max — kullanıcı bar yüksekliğini
              // hangi sayıya göre değerlendireceğini bilsin. Eski sadece "ORT"
              // → "max neye bakıyorum?" belirsizdi.
              _StatChip(label: 'MIN', value: fmt(minV), color: color.withValues(alpha: 0.55)),
              const SizedBox(width: 6),
              _StatChip(label: 'ORT', value: fmt(avg), color: color),
              const SizedBox(width: 6),
              _StatChip(label: 'MAX', value: fmt(maxV), color: color.withValues(alpha: 0.85)),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: CustomPaint(
              painter: _MonthlyStripPainter(
                data: data,
                color: color,
                decimals: decimals,
              ),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

/// MIN/ORT/MAX küçük chip — value altta, label üstte (kompakt).
class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.40),
            fontSize: 7.5,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _MonthlyStripPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final int decimals;
  _MonthlyStripPainter({
    required this.data,
    required this.color,
    this.decimals = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const padBottom = 12.0;
    const padTop = 11.0; // 2026-05-25 (Fix1): her bar üstüne value yazısı için
    final w = size.width;
    final h = size.height - padBottom - padTop;

    final minV = data.reduce(math.min);
    final maxV = data.reduce(math.max);
    final avg = data.reduce((a, b) => a + b) / data.length;
    final range = (maxV - minV).abs() < 0.01 ? 1.0 : (maxV - minV);

    // 2026-05-25 (Fix1): Ortalama hizasında ince yatay çizgi — kullanıcı
    // hangi ay ortalamadan yüksek/düşük görebilsin.
    final avgY = padTop + h - ((avg - minV) / range * h);
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    const dashW = 4.0;
    const gapW = 3.0;
    double x0 = 0;
    while (x0 < w) {
      canvas.drawLine(
          Offset(x0, avgY), Offset(math.min(x0 + dashW, w), avgY), dashPaint);
      x0 += dashW + gapW;
    }
    // "ORT" etiketi sol kenarda
    final avgLabel = TextPainter(
      text: TextSpan(
        text: 'ORT',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.35),
          fontSize: 7.5,
          letterSpacing: 0.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    avgLabel.paint(canvas, Offset(1, avgY - avgLabel.height - 1));

    // Bar'ların hangi indekslerine value yazacağız — dar ekranda 12 değer
    // birbirine girer. Strateji: yer varsa her ay, yoksa sadece min/max/avg
    // çevresindekiler.
    final showAll = w / 12 >= 26; // bar genişliği ≥ 26px ise her ay etiketle
    int? minIdx, maxIdx;
    for (var i = 0; i < data.length; i++) {
      if (minIdx == null || data[i] < data[minIdx]) minIdx = i;
      if (maxIdx == null || data[i] > data[maxIdx]) maxIdx = i;
    }

    final barW = w / 12;
    for (var i = 0; i < 12; i++) {
      final v = i < data.length ? data[i] : 0;
      final norm = (v - minV) / range;
      final barH = (norm * h).clamp(2.0, h);
      final x = i * barW + barW * 0.20;
      final bw = barW * 0.60;
      final isExtreme = i == minIdx || i == maxIdx;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, padTop + h - barH, bw, barH),
          const Radius.circular(2),
        ),
        Paint()
          ..color = color.withValues(alpha: isExtreme ? 1.0 : 0.75),
      );
      // Bar üstüne value
      if (showAll || isExtreme) {
        final vp = TextPainter(
          text: TextSpan(
            text: v.toStringAsFixed(decimals),
            style: TextStyle(
              color: isExtreme
                  ? Colors.white.withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.70),
              fontSize: 8.5,
              fontWeight: isExtreme ? FontWeight.w700 : FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        // Bar üstüne yerleştir (eğer padTop alanına sığarsa)
        final yTop = (padTop + h - barH - vp.height - 1).clamp(0.0, padTop);
        vp.paint(canvas, Offset(x + bw / 2 - vp.width / 2, yTop));
      }
      final tp = TextPainter(
        text: TextSpan(
          text: _months[i],
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.50),
            fontSize: 8.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + bw / 2 - tp.width / 2, size.height - padBottom + 1));
    }
  }

  @override
  bool shouldRepaint(covariant _MonthlyStripPainter old) =>
      old.data != data || old.color != color || old.decimals != decimals;
}

// ─────────────────────────────────────────────────────────────────────────────
// WIND ROSE — 8 yön rüzgar gülü
// ─────────────────────────────────────────────────────────────────────────────

class WindRoseCard extends StatelessWidget {
  final WindRose rose;
  const WindRoseCard({super.key, required this.rose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Rüzgar Yön Dağılımı',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  rose.dominant,
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 1.0,
            child: CustomPaint(painter: _WindRosePainter(rose: rose)),
          ),
        ],
      ),
    );
  }
}

class _WindRosePainter extends CustomPainter {
  final WindRose rose;
  _WindRosePainter({required this.rose});

  static const _bins = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = math.min(cx, cy) * 0.85;

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (var r = 0.33; r <= 1; r += 0.33) {
      canvas.drawCircle(Offset(cx, cy), maxR * r, gridPaint);
    }

    final maxFreq = rose.histogram.values
        .fold<double>(0, (max, v) => v > max ? v : max);
    final maxNorm = maxFreq > 0 ? maxFreq : 1;

    for (var i = 0; i < 8; i++) {
      final bin = _bins[i];
      final freq = rose.histogram[bin] ?? 0;
      final r = maxR * (freq / maxNorm);
      final a1 = (i * 45 - 22.5 - 90) * math.pi / 180;
      final a2 = (i * 45 + 22.5 - 90) * math.pi / 180;
      final isDominant = bin == rose.dominant;
      final color = isDominant ? Colors.cyanAccent : const Color(0xFF3B82F6);

      final path = Path()
        ..moveTo(cx, cy)
        ..lineTo(cx + r * math.cos(a1), cy + r * math.sin(a1))
        ..arcTo(
          Rect.fromCircle(center: Offset(cx, cy), radius: r),
          a1,
          a2 - a1,
          false,
        )
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = color.withValues(alpha: isDominant ? 0.65 : 0.35),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.85)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke,
      );

      final labelA = (i * 45 - 90) * math.pi / 180;
      final lx = cx + (maxR * 1.12) * math.cos(labelA);
      final ly = cy + (maxR * 1.12) * math.sin(labelA);
      final tp = TextPainter(
        text: TextSpan(
          text: bin,
          style: TextStyle(
            color: isDominant ? Colors.cyanAccent : Colors.white70,
            fontSize: 10,
            fontWeight: isDominant ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));

      if (freq >= 15) {
        final fr = r * 0.65;
        final fx = cx + fr * math.cos(labelA);
        final fy = cy + fr * math.sin(labelA);
        final ft = TextPainter(
          text: TextSpan(
            text: '${freq.toStringAsFixed(0)}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        ft.paint(canvas, Offset(fx - ft.width / 2, fy - ft.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WindRosePainter old) => old.rose != rose;
}

// ─────────────────────────────────────────────────────────────────────────────
// RIVER DISCHARGE — aylık nehir debisi
// ─────────────────────────────────────────────────────────────────────────────

class RiverDischargeCard extends StatelessWidget {
  final List<RiverDischargePoint> discharge;
  final Color color;

  const RiverDischargeCard({
    super.key,
    required this.discharge,
    this.color = const Color(0xFF06B6D4),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water_outlined, size: 14, color: color),
              const SizedBox(width: 6),
              const Text(
                'Aylık Nehir Debisi (m³/s)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (discharge.isNotEmpty)
                Text(
                  'Pik: ${discharge.map((e) => e.mean).reduce(math.max).toStringAsFixed(1)} m³/s',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 3.6,
            child: CustomPaint(
              painter: _DischargePainter(discharge: discharge, color: color),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

class _DischargePainter extends CustomPainter {
  final List<RiverDischargePoint> discharge;
  final Color color;
  _DischargePainter({required this.discharge, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (discharge.isEmpty) return;
    const padBottom = 14.0;
    final w = size.width;
    final h = size.height - padBottom;
    final maxV = discharge.map((e) => e.max).reduce(math.max) * 1.05;
    if (maxV <= 0) return;

    final barW = w / 12;
    for (var i = 0; i < discharge.length && i < 12; i++) {
      final p = discharge[i];
      final x = i * barW + barW * 0.15;
      final bw = barW * 0.70;
      final yMax = h - (p.max / maxV * h);
      final yMin = h - (p.min / maxV * h);
      canvas.drawRect(
        Rect.fromLTRB(x, yMax, x + bw, yMin),
        Paint()..color = color.withValues(alpha: 0.18),
      );
      final yMean = h - (p.mean / maxV * h);
      canvas.drawRect(
        Rect.fromLTRB(x, yMean, x + bw, h),
        Paint()..color = color.withValues(alpha: 0.75),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: _months[i],
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.50),
            fontSize: 9,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + bw / 2 - tp.width / 2, size.height - padBottom + 1));
    }
  }

  @override
  bool shouldRepaint(covariant _DischargePainter old) =>
      old.discharge != discharge || old.color != color;
}
