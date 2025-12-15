import 'package:flutter/material.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/map_provider.dart';

/// Sidebar'daki veri paneli - Rüzgar/Güneş kaynakları özeti
class DataPanel extends StatelessWidget {
  final ThemeProvider theme;
  final MapProvider mapProvider;
  final bool isCollapsed;

  const DataPanel({
    super.key,
    required this.theme,
    required this.mapProvider,
    required this.isCollapsed,
  });

  // Renk sabitleri
  static const Color windBgColor = Color(0xFF1F3A58);
  static const Color windFgColor = Color(0xFF2196F3);
  static const Color solarBgColor = Color(0xFF413819);
  static const Color solarFgColor = Color(0xFFFFCA28);

  @override
  Widget build(BuildContext context) {
    final windPins = mapProvider.pins
        .where((p) => p.type.contains('Rüzgar') || p.type.contains('Wind'))
        .toList();
    final solarPins = mapProvider.pins
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
          color: theme.secondaryTextColor.withOpacity(0.1),
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

    for (final pin in mapProvider.pins.take(5)) {
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

    if (mapProvider.pins.length > 5) {
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
        color: color.withOpacity(0.2),
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

        // Kaynaklar listesi başlığı
        Text(
          "Kaynaklar",
          style: TextStyle(
            color: theme.secondaryTextColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),

        // Kaynak listesi
        if (mapProvider.pins.isEmpty)
          _buildEmptyState()
        else
          ..._buildPinList(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.add_location_alt_outlined,
            size: 30,
            color: theme.secondaryTextColor.withOpacity(0.3),
          ),
          const SizedBox(height: 5),
          Text(
            "Henüz kaynak eklenmedi",
            style: TextStyle(
              color: theme.textColor.withOpacity(0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPinList() {
    return mapProvider.pins.map((pin) {
      bool isSolar = pin.type.contains('Güneş') || pin.type.contains('Solar');
      return _PinListItem(
        name: pin.name,
        capacity: pin.capacityMw,
        isSolar: isSolar,
        theme: theme,
        onDelete: () => mapProvider.deletePin(pin.id),
      );
    }).toList();
  }
}

/// İstatistik kartı widget'ı
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
        border: Border.all(color: fgColor.withOpacity(0.3)),
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

/// Pin listesi öğesi widget'ı
class _PinListItem extends StatelessWidget {
  final String name;
  final double capacity;
  final bool isSolar;
  final ThemeProvider theme;
  final VoidCallback onDelete;

  const _PinListItem({
    required this.name,
    required this.capacity,
    required this.isSolar,
    required this.theme,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSolar ? DataPanel.solarBgColor : DataPanel.windBgColor;
    final fgColor = isSolar ? DataPanel.solarFgColor : DataPanel.windFgColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: fgColor, width: 1.5),
          ),
          child: Icon(
            isSolar ? Icons.wb_sunny : Icons.air,
            color: fgColor,
            size: 14,
          ),
        ),
        title: Text(
          name,
          style: TextStyle(
            color: theme.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          "$capacity MW",
          style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.delete_outline,
            color: theme.secondaryTextColor.withOpacity(0.7),
            size: 20,
          ),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
