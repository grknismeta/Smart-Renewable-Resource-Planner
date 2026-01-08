import 'package:flutter/material.dart';
import '../../../../viewmodels/theme_view_model.dart';
import '../../viewmodels/map_view_model.dart';

/// Sidebar'daki veri paneli - Rüzgar/Güneş kaynakları özeti
class DataPanel extends StatelessWidget {
  final ThemeViewModel theme;
  final MapViewModel mapViewModel;
  final bool isCollapsed;

  const DataPanel({
    super.key,
    required this.theme,
    required this.mapViewModel,
    required this.isCollapsed,
  });

  // Renk sabitleri
  static const Color windBgColor = Color(0xFF1F3A58);
  static const Color windFgColor = Color(0xFF2196F3);
  static const Color solarBgColor = Color(0xFF413819);
  static const Color solarFgColor = Color(0xFFFFCA28);

  @override
  Widget build(BuildContext context) {
    final windPins = mapViewModel.pins
        .where((p) => p.type.contains('Rüzgar') || p.type.contains('Wind'))
        .toList();
    final solarPins = mapViewModel.pins
        .where((p) => p.type.contains('Güneş') || p.type.contains('Solar'))
        .toList();

    final windMw = windPins.fold(0.0, (sum, p) => sum + p.capacityMw);
    final solarMw = solarPins.fold(0.0, (sum, p) => sum + p.capacityMw);

    if (isCollapsed) {
      return _buildCollapsedView(windPins.length, solarPins.length);
    }

    return _buildExpandedView(
      windPins.length,
      solarPins.length,
      windMw,
      solarMw,
    );
  }

  /// Dar mod görünümü
  Widget _buildCollapsedView(int windCount, int solarCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCollapsedStatIcon(Icons.air, windFgColor, windCount),
        const SizedBox(height: 12),
        _buildCollapsedStatIcon(Icons.wb_sunny, solarFgColor, solarCount),
        const SizedBox(height: 20),
        Divider(
          color: theme.secondaryTextColor.withValues(alpha: 0.1),
          indent: 5,
          endIndent: 220,
        ),
        const SizedBox(height: 10),
        ..._buildCollapsedPinIndicators(),
      ],
    );
  }

  List<Widget> _buildCollapsedPinIndicators() {
    final indicators = <Widget>[];

    for (final pin in mapViewModel.pins.take(5)) {
      bool isSolar = pin.type.contains('Güneş') || pin.type.contains('Solar');
      indicators.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isSolar ? solarFgColor : windFgColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }

    if (mapViewModel.pins.length > 5) {
      indicators.add(
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 8),
          child: Icon(
            Icons.more_horiz,
            size: 12,
            color: theme.secondaryTextColor,
          ),
        ),
      );
    }

    return indicators;
  }

  Widget _buildCollapsedStatIcon(IconData icon, Color color, int count) {
    return Container(
      width: 40,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Center(
        child: Text(
          count.toString(),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  /// Geniş mod görünümü
  Widget _buildExpandedView(
    int windCount,
    int solarCount,
    double windMw,
    double solarMw,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık
        Text(
          "Kaynak Verileri",
          style: TextStyle(
            color: theme.textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),

        // İstatistik kartları
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: "Rüzgar",
                count: windCount.toString(),
                capacity: "${windMw.toStringAsFixed(1)} MW",
                icon: Icons.air,
                bgColor: windBgColor,
                fgColor: windFgColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: "Güneş",
                count: solarCount.toString(),
                capacity: "${solarMw.toStringAsFixed(1)} MW",
                icon: Icons.wb_sunny,
                bgColor: solarBgColor,
                fgColor: solarFgColor,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 7 Günlük En İyi Rüzgar
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    "7 Gün – En İyi Rüzgar",
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._buildTopWindCities(),
                ],
              ),
            ),
            
            const SizedBox(width: 12),

             // 7 Günlük En İyi Işınım
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    "7 Gün – En İyi Işınım",
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._buildTopSolarCities(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildTopWindCities() {
    if (mapViewModel.weatherSummary.isEmpty) return [const SizedBox()];
    
    final sorted = [...mapViewModel.weatherSummary]
      ..sort(
        (a, b) => (b.avgWindSpeed100m ?? 0).compareTo(a.avgWindSpeed100m ?? 0),
      );

    final top = sorted.take(3).toList();
    return top.map((c) {
      final v = c.avgWindSpeed100m;
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            const Icon(
              Icons.wind_power,
              color: Colors.lightBlueAccent,
              size: 14,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                c.cityName,
                style: TextStyle(color: theme.textColor, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (v != null)
              Text(
                '${v.toStringAsFixed(1)} m/s',
                style: TextStyle(color: theme.secondaryTextColor, fontSize: 10),
              ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildTopSolarCities() {
    if (mapViewModel.weatherSummary.isEmpty) return [const SizedBox()];
      
    final sortedByRad = [...mapViewModel.weatherSummary]
       ..sort((a,b) => (b.totalRadiation ?? 0).compareTo(a.totalRadiation ?? 0));

    final top = sortedByRad.take(3).toList();
    
    return top.map((c) {
      final v = c.totalRadiation;
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            const Icon(
              Icons.wb_sunny,
              color: Colors.orangeAccent,
              size: 14,
            ),
             const SizedBox(width: 4),
            Expanded(
              child: Text(
                c.cityName,
                style: TextStyle(color: theme.textColor, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (v != null)
              Text(
                _formatRadiation(v),
                style: TextStyle(color: theme.secondaryTextColor, fontSize: 10),
              ),
          ],
        ),
      );
    }).toList();
  }

  String _formatRadiation(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(2)} MW/m²';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(2)} kW/m²';
    } else {
      return '${value.toStringAsFixed(0)} W/m²';
    }
  }
}
// _StatCard kept if needed, but removed _PinListItem
class _StatCard extends StatelessWidget {
  final String title;
  final String count;
  final String capacity;
  final IconData icon;
  final Color bgColor;
  final Color fgColor;

  const _StatCard({
    required this.title,
    required this.count,
    required this.capacity,
    required this.icon,
    required this.bgColor,
    required this.fgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fgColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: fgColor, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            count,
            style: TextStyle(
              color: fgColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            capacity,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
