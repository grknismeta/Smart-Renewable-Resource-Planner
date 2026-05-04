// lib/features/map/widgets/panels/recommendations/charts/ml_projection_card.dart
//
// Aşama 3.D — ML Projeksiyon kartı (eski `ml_projection_placeholder.dart`
// yerine geldi).
//
// Backend `/analysis/projection`'a sorar: il × metrik × pencere → günlük
// tahmin + 95% CI. Mini line chart + güven aralığı bandı çizer.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/core/theme/app_theme.dart';

class MlProjectionCard extends StatefulWidget {
  final ThemeViewModel theme;
  final String province;

  const MlProjectionCard({
    super.key,
    required this.theme,
    required this.province,
  });

  @override
  State<MlProjectionCard> createState() => _MlProjectionCardState();
}

class _MlProjectionCardState extends State<MlProjectionCard> {
  String _metric = 'wind_speed';
  int _horizon = 90;
  ProjectionResponse? _data;
  String? _error;
  bool _loading = false;

  static const _metricLabels = <String, String>{
    'wind_speed': 'Rüzgar (m/s)',
    'shortwave_radiation': 'Işınım (W/m²)',
    'temperature': 'Sıcaklık (°C)',
  };

  static const _horizonLabels = <int, String>{
    30: '1 Ay',
    90: '3 Ay',
    180: '6 Ay',
    365: '1 Yıl',
  };

  Color get _accent {
    switch (_metric) {
      case 'shortwave_radiation':
        return Colors.amberAccent;
      case 'temperature':
        return Colors.deepOrangeAccent;
      default:
        return Colors.cyanAccent;
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant MlProjectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.province != widget.province) {
      _data = null;
      _error = null;
      Future.microtask(_load);
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final resp = await api.analysis.fetchProjection(
        province: widget.province,
        metric: _metric,
        horizonDays: _horizon,
      );
      if (!mounted) return;
      setState(() {
        _data = resp;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.purpleAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.purpleAccent.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(theme),
          const SizedBox(height: 10),
          _selectors(theme),
          const SizedBox(height: 12),
          SizedBox(height: 140, child: _chart(theme)),
          const SizedBox(height: 10),
          _footer(theme),
        ],
      ),
    );
  }

  Widget _header(ThemeViewModel theme) {
    return Row(
      children: [
        const Icon(
          Icons.auto_awesome_mosaic_rounded,
          color: Colors.purpleAccent,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          'Gelecek Projeksiyonu',
          style: TextStyle(
            color: theme.textColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        if (_loading)
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          )
        else
          IconButton(
            tooltip: 'Yenile',
            icon: Icon(Icons.refresh_rounded, size: 14, color: theme.secondaryTextColor),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: _load,
          ),
      ],
    );
  }

  Widget _selectors(ThemeViewModel theme) {
    return Row(
      children: [
        Expanded(
          child: _DropdownChip(
            value: _metric,
            items: _metricLabels.entries.map((e) => (e.key, e.value)).toList(),
            theme: theme,
            onChanged: (v) {
              setState(() => _metric = v);
              _load();
            },
          ),
        ),
        const SizedBox(width: 8),
        _DropdownChip<int>(
          value: _horizon,
          items: _horizonLabels.entries.map((e) => (e.key, e.value)).toList(),
          theme: theme,
          onChanged: (v) {
            setState(() => _horizon = v);
            _load();
          },
        ),
      ],
    );
  }

  Widget _chart(ThemeViewModel theme) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final data = _data;
    if (data == null) {
      if (_loading) {
        return Center(
          child: Text(
            'Tahmin hesaplanıyor...',
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 11,
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }
    if (data.points.isEmpty) {
      return Center(
        child: Text(
          'Tahmin için yeterli geçmiş veri yok',
          style: TextStyle(color: theme.secondaryTextColor, fontSize: 11),
        ),
      );
    }

    final spots = <FlSpot>[];
    final lowerSpots = <FlSpot>[];
    final upperSpots = <FlSpot>[];
    double minY = double.infinity;
    double maxY = -double.infinity;
    for (var i = 0; i < data.points.length; i++) {
      final p = data.points[i];
      spots.add(FlSpot(i.toDouble(), p.value));
      lowerSpots.add(FlSpot(i.toDouble(), p.lower));
      upperSpots.add(FlSpot(i.toDouble(), p.upper));
      if (p.lower < minY) minY = p.lower;
      if (p.upper > maxY) maxY = p.upper;
    }
    if (!minY.isFinite) minY = 0;
    if (!maxY.isFinite) maxY = 1;
    if (maxY - minY < 1e-3) maxY = minY + 1;

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        titlesData: const FlTitlesData(show: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          // Üst sınır (görünmez stroke; band için below ile)
          LineChartBarData(
            spots: upperSpots,
            isCurved: true,
            curveSmoothness: 0.25,
            barWidth: 0,
            color: Colors.transparent,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
          // Alt sınır + band fill (alttan üste)
          LineChartBarData(
            spots: lowerSpots,
            isCurved: true,
            curveSmoothness: 0.25,
            barWidth: 0,
            color: Colors.transparent,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: _accent.withValues(alpha: 0.10),
              cutOffY: maxY,
              applyCutOffY: true,
            ),
            aboveBarData: BarAreaData(
              show: true,
              color: _accent.withValues(alpha: 0.18),
            ),
          ),
          // Ana tahmin eğrisi
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            barWidth: 2,
            color: _accent,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _footer(ThemeViewModel theme) {
    final d = _data;
    if (d == null) return const SizedBox.shrink();
    final trend = d.annualTrendPct;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _statChip(
              'Geçmiş',
              '${d.historyYears} yıl',
              theme,
            ),
            if (d.historicalAvg != null)
              _statChip(
                'Ortalama',
                d.historicalAvg!.toStringAsFixed(2),
                theme,
              ),
            if (trend != null)
              _statChip(
                'Yıllık trend',
                '${trend >= 0 ? '+' : ''}${trend.toStringAsFixed(2)}%',
                theme,
                color: trend >= 0
                    ? Colors.greenAccent
                    : Colors.redAccent,
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          d.disclaimer,
          style: TextStyle(
            color: theme.secondaryTextColor.withValues(alpha: 0.65),
            fontSize: 9,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _statChip(String label, String value, ThemeViewModel theme,
      {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: TextStyle(
            color: theme.secondaryTextColor,
            fontSize: 10,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: color ?? theme.textColor,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Küçük dropdown helper (tema uyumlu).
class _DropdownChip<T> extends StatelessWidget {
  final T value;
  final List<(T, String)> items;
  final ThemeViewModel theme;
  final ValueChanged<T> onChanged;

  const _DropdownChip({
    required this.value,
    required this.items,
    required this.theme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.secondaryTextColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.purpleAccent.withValues(alpha: 0.25),
        ),
      ),
      child: DropdownButton<T>(
        value: value,
        isDense: true,
        underline: const SizedBox(),
        dropdownColor: const Color(0xFF1A1A2E),
        style: TextStyle(color: theme.textColor, fontSize: 11),
        items: items
            .map((e) => DropdownMenuItem<T>(
                  value: e.$1,
                  child: Text(
                    e.$2,
                    style: TextStyle(color: theme.textColor, fontSize: 11),
                  ),
                ))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
