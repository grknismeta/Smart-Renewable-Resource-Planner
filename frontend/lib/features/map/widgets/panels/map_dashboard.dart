import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/theme/theme_view_model.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/features/map/viewmodels/map_view_model.dart';

class MapDashboard extends StatefulWidget {
  final ThemeViewModel theme;

  const MapDashboard({super.key, required this.theme});

  @override
  State<MapDashboard> createState() => _MapDashboardState();
}

class _MapDashboardState extends State<MapDashboard> {
  Map<String, dynamic>? _status;
  Timer? _timer;

  ThemeViewModel get theme => widget.theme;

  @override
  void initState() {
    super.initState();
    _fetch();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final result = await api.weather.fetchCollectorStatus();
      if (mounted) setState(() => _status = result);
    } catch (_) {}
  }

  /// Türkiye sınırları içinde mi? (lat 35-43, lon 25-46)
  static bool _isInTurkey(double lat, double lon) {
    return lat >= 35.0 && lat <= 43.0 && lon >= 25.0 && lon <= 46.0;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MapViewModel>(
      builder: (context, mapViewModel, _) {
        final isGlobe = mapViewModel.showGlobe;
        final allPins = mapViewModel.pins;

        // Globe modunda tüm pinleri, normal modda sadece Türkiye pinlerini sayar
        final turkeyPins = allPins.where(
          (p) => _isInTurkey(p.latitude, p.longitude),
        ).toList();
        final globalPins = allPins.where(
          (p) => !_isInTurkey(p.latitude, p.longitude),
        ).toList();
        final activePins = isGlobe ? allPins : turkeyPins;

        // Pin sayılarını hesapla
        final windPins = activePins
            .where((p) => p.type == 'Rüzgar Türbini')
            .length;
        final solarPins = activePins
            .where((p) => p.type == 'Güneş Paneli')
            .length;
        final hesPins = activePins
            .where((p) => p.type == 'Hidroelektrik')
            .length;
        final totalCapacity = activePins.fold<double>(
          0,
          (sum, pin) => sum + pin.capacityMw,
        );

        // Globe modunda Türkiye dışı ekstra sayılar
        final globalWind = isGlobe
            ? globalPins.where((p) => p.type == 'Rüzgar Türbini').length
            : 0;
        final globalSolar = isGlobe
            ? globalPins.where((p) => p.type == 'Güneş Paneli').length
            : 0;
        final globalHes = isGlobe
            ? globalPins.where((p) => p.type == 'Hidroelektrik').length
            : 0;

        // Son güncelleme bilgisi
        final s = _status;
        final minutesAgo = s?['minutes_ago'] as int?;
        final healthy = s?['healthy'] == true;
        final updateLabel = minutesAgo == null
            ? null
            : minutesAgo <= 0
                ? 'az önce'
                : minutesAgo < 60
                    ? '$minutesAgo dk önce'
                    : '${(minutesAgo / 60).round()} sa önce';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.secondaryTextColor.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatItem(
                        'Rüzgar',
                        '$windPins',
                        windPins > 0 ? Colors.blueAccent : theme.secondaryTextColor,
                        globalExtra: globalWind > 0 ? '+$globalWind' : null,
                      ),
                      _divider(),
                      _buildStatItem(
                        'Güneş',
                        '$solarPins',
                        solarPins > 0 ? Colors.orangeAccent : theme.secondaryTextColor,
                        globalExtra: globalSolar > 0 ? '+$globalSolar' : null,
                      ),
                      _divider(),
                      _buildStatItem(
                        'HES',
                        '$hesPins',
                        hesPins > 0 ? const Color(0xFF29B6F6) : theme.secondaryTextColor,
                        globalExtra: globalHes > 0 ? '+$globalHes' : null,
                      ),
                      _divider(),
                      _buildStatItem(
                        'Kapasite',
                        '${totalCapacity.toStringAsFixed(1)} MW',
                        Colors.greenAccent,
                      ),
                    ],
                  ),
                  // Son güncelleme satırı
                  if (updateLabel != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: healthy ? Colors.greenAccent : Colors.orangeAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Son güncelleme: $updateLabel',
                          style: TextStyle(
                            color: theme.secondaryTextColor,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        width: 1,
        height: 30,
        color: theme.secondaryTextColor.withValues(alpha: 0.2),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor,
      {String? globalExtra}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (globalExtra != null) ...[
              const SizedBox(width: 4),
              Text(
                globalExtra,
                style: TextStyle(
                  color: valueColor.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
