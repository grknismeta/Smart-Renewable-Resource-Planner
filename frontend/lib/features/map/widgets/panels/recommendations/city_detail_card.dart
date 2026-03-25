import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/models/recommendation_model.dart';
import 'package:frontend/data/models/weather_model.dart';
import 'package:frontend/features/map/widgets/wind_rose_widget.dart';
import 'charts/wind_speed_chart.dart';
import 'charts/energy_potential_chart.dart';
import 'charts/weather_forecast_strip.dart';
import 'charts/ml_projection_placeholder.dart';

/// Seçili şehrin detay kartı — grafikler ve istatistikler.
class CityDetailCard extends StatelessWidget {
  final RecommendedCity city;
  final List<CityWeatherData>? hourlyData;
  final bool isLoading;
  final ThemeViewModel theme;
  final VoidCallback onBack;

  const CityDetailCard({
    super.key,
    required this.city,
    required this.hourlyData,
    required this.isLoading,
    required this.theme,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      children: [
        // Geri butonu
        InkWell(
          onTap: onBack,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  Icons.arrow_back_rounded,
                  size: 16,
                  color: Colors.purpleAccent.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 6),
                Text(
                  'Tüm Bölgeler',
                  style: TextStyle(
                    color: Colors.purpleAccent.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 4),

        // Şehir başlığı
        Row(
          children: [
            const Icon(Icons.location_on, size: 20, color: Colors.purpleAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    city.name,
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${city.lat.toStringAsFixed(2)}°K, ${city.lon.toStringAsFixed(2)}°D',
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purpleAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Skor: ${city.score.toInt()}',
                style: const TextStyle(
                  color: Colors.purpleAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // İstatistik grid
        _buildStatsGrid(),

        const SizedBox(height: 12),

        // Rüzgar Gülü (compact)
        if (city.windRose != null) ...[
          _sectionTitle('Rüzgar Gülü'),
          const SizedBox(height: 6),
          Center(
            child: WindRoseWidget(
              data: city.windRose!,
              cityName: city.name,
              size: 160,
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Loading indicator veya grafikler
        if (isLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(
                    color: Colors.purpleAccent,
                    strokeWidth: 2,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Veriler yükleniyor...',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
          )
        else if (hourlyData != null && hourlyData!.isNotEmpty) ...[
          // Rüzgar Hızı Grafiği
          WindSpeedChart(hourlyData: hourlyData!, theme: theme),
          const SizedBox(height: 10),

          // Enerji Potansiyeli
          EnergyPotentialChart(city: city, theme: theme),
          const SizedBox(height: 10),

          // 7 Günlük Tahmin
          WeatherForecastStrip(hourlyData: hourlyData!, theme: theme),
          const SizedBox(height: 10),
        ]
        else if (!isLoading) ...[
          // Veri yüklenemedi — placeholder
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: const Column(
              children: [
                Icon(Icons.cloud_off_rounded, color: Colors.white30, size: 32),
                SizedBox(height: 8),
                Text(
                  'Bu bölgenin detaylı verisi yüklenemedi',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],

        // ML Placeholder
        MlProjectionPlaceholder(theme: theme),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: theme.textColor,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatBadge(
          icon: Icons.air,
          label: 'Ort. Rüzgar',
          value: '${city.avgWindSpeed?.toStringAsFixed(1) ?? "-"} m/s',
          color: Colors.cyanAccent,
          theme: theme,
        ),
        _StatBadge(
          icon: Icons.speed,
          label: 'Maks. Rüzgar',
          value: '${city.maxWindSpeed?.toStringAsFixed(1) ?? "-"} m/s',
          color: Colors.redAccent,
          theme: theme,
        ),
        _StatBadge(
          icon: Icons.show_chart,
          label: 'Weibull k',
          value: city.weibullK?.toStringAsFixed(2) ?? '-',
          color: Colors.blueAccent,
          theme: theme,
        ),
        _StatBadge(
          icon: Icons.wb_sunny,
          label: 'Ort. Işınım',
          value: '${city.avgRadiation?.toStringAsFixed(0) ?? "-"} W/m²',
          color: Colors.orangeAccent,
          theme: theme,
        ),
        _StatBadge(
          icon: Icons.show_chart,
          label: 'Weibull λ',
          value: city.weibullLambda?.toStringAsFixed(2) ?? '-',
          color: Colors.tealAccent,
          theme: theme,
        ),
        _StatBadge(
          icon: Icons.bolt,
          label: 'Skor',
          value: city.score.toInt().toString(),
          color: Colors.purpleAccent,
          theme: theme,
        ),
      ],
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final ThemeViewModel theme;

  const _StatBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: 9,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
