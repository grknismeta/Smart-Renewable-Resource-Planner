import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/models/recommendation_model.dart';

/// Önerilen şehirlerin kategori bazlı listesi.
class CityListSection extends StatelessWidget {
  final RecommendationsData data;
  final ThemeViewModel theme;
  final void Function(RecommendedCity city) onCityTap;

  const CityListSection({
    super.key,
    required this.data,
    required this.theme,
    required this.onCityTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      children: [
        if (data.windStrong.isNotEmpty)
          _CategoryGroup(
            title: 'Güçlü Rüzgar',
            subtitle: 'v̄ > 7 m/s',
            icon: Icons.air,
            color: Colors.redAccent,
            cities: data.windStrong,
            theme: theme,
            onCityTap: onCityTap,
          ),
        if (data.windStable.isNotEmpty)
          _CategoryGroup(
            title: 'Stabil Rüzgar',
            subtitle: 'Weibull k > 2.5',
            icon: Icons.waves,
            color: Colors.blueAccent,
            cities: data.windStable,
            theme: theme,
            onCityTap: onCityTap,
          ),
        if (data.windCirculation.isNotEmpty)
          _CategoryGroup(
            title: 'Yüksek Sirkülasyon',
            subtitle: 'Değişken ama yoğun',
            icon: Icons.cyclone,
            color: Colors.cyanAccent,
            cities: data.windCirculation,
            theme: theme,
            onCityTap: onCityTap,
          ),
        if (data.solarTop.isNotEmpty)
          _CategoryGroup(
            title: 'En İyi Güneş',
            subtitle: 'Yüksek ışınım',
            icon: Icons.wb_sunny,
            color: Colors.orangeAccent,
            cities: data.solarTop,
            theme: theme,
            onCityTap: onCityTap,
            isSolar: true,
          ),
      ],
    );
  }
}

class _CategoryGroup extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<RecommendedCity> cities;
  final ThemeViewModel theme;
  final void Function(RecommendedCity) onCityTap;
  final bool isSolar;

  const _CategoryGroup({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.cities,
    required this.theme,
    required this.onCityTap,
    this.isSolar = false,
  });

  @override
  State<_CategoryGroup> createState() => _CategoryGroupState();
}

class _CategoryGroupState extends State<_CategoryGroup> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 32,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(widget.icon, size: 16, color: widget.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: widget.theme.textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          color: widget.theme.secondaryTextColor,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: widget.theme.secondaryTextColor,
                  size: 18,
                ),
              ],
            ),
          ),
        ),

        // Şehir listesi
        AnimatedCrossFade(
          firstChild: Column(
            children: widget.cities.take(6).map((city) {
              return _CityTile(
                city: city,
                color: widget.color,
                theme: widget.theme,
                isSolar: widget.isSolar,
                onTap: () => widget.onCityTap(city),
              );
            }).toList(),
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState:
              _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),

        const SizedBox(height: 4),
      ],
    );
  }
}

class _CityTile extends StatelessWidget {
  final RecommendedCity city;
  final Color color;
  final ThemeViewModel theme;
  final bool isSolar;
  final VoidCallback onTap;

  const _CityTile({
    required this.city,
    required this.color,
    required this.theme,
    required this.isSolar,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        child: Row(
          children: [
            Icon(
              Icons.location_on_rounded,
              size: 14,
              color: color.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                city.name,
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Skor badge
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                '${city.score.toInt()}',
                style: TextStyle(
                  color: theme.secondaryTextColor,
                  fontSize: 10,
                ),
              ),
            ),
            // Değer badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isSolar
                    ? '${city.avgRadiation?.toStringAsFixed(0) ?? "-"} W/m²'
                    : '${city.avgWindSpeed?.toStringAsFixed(1) ?? "-"} m/s',
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: theme.secondaryTextColor.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
