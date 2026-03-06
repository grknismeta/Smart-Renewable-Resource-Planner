import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/models/recommendation_model.dart';
import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'package:frontend/features/map/widgets/wind_rose_widget.dart';

/// Harita üzerinde gösterilen "Önerilen Bölgeler" yan panel widget'ı.
///
/// Bir buton olarak başlar; tıklandığında aşağıdaki kategorileri listeler:
///   • Güçlü rüzgar bölgeleri
///   • Stabil rüzgar (Weibull k > 2.5)
///   • Yüksek sirkülasyon
///   • En iyi güneş bölgeleri
///
/// Herhangi bir şehire tıklandığında Rüzgar Gülü diyaloğu açılır.
class RecommendationsPanel extends StatefulWidget {
  final ThemeViewModel theme;
  final MapViewModel mapViewModel;

  const RecommendationsPanel({
    super.key,
    required this.theme,
    required this.mapViewModel,
  });

  @override
  State<RecommendationsPanel> createState() => _RecommendationsPanelState();
}

class _RecommendationsPanelState extends State<RecommendationsPanel>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _animController;
  late final Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _animController.forward();
      // Veri yoksa yükle
      if (widget.mapViewModel.recommendations == null &&
          !widget.mapViewModel.isLoadingRecommendations) {
        widget.mapViewModel.loadRecommendations();
      }
    } else {
      _animController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final vm = widget.mapViewModel;

    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.purpleAccent.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Başlık butonu ─────────────────────────────────────────────────
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: Colors.purpleAccent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Önerilen Bölgeler',
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: theme.secondaryTextColor,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Genişleyen içerik ─────────────────────────────────────────────
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Column(
              children: [
                Divider(
                  height: 1,
                  color: theme.secondaryTextColor.withValues(alpha: 0.2),
                ),

                // Yükleniyor
                if (vm.isLoadingRecommendations)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          color: Colors.purpleAccent,
                          strokeWidth: 2,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Weibull analizi çalışıyor...',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  )

                // Hata
                else if (vm.recommendationError != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.cloud_off_rounded,
                            color: Colors.orangeAccent, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          'Backend bağlantısı gerekli',
                          style: TextStyle(
                            color: theme.secondaryTextColor,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: vm.loadRecommendations,
                          icon: const Icon(Icons.refresh_rounded, size: 14),
                          label: const Text('Yeniden Dene'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.purpleAccent,
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  )

                // Boş veri / ML yakında
                else if (vm.recommendations == null || vm.recommendations!.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.auto_awesome_mosaic_rounded,
                          color: Colors.purpleAccent,
                          size: 32,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'ML Tabanlı Öneri',
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Makine öğrenimi ile güçlendirilmiş\nbölge önerileri yakında aktif olacak.',
                          style: TextStyle(
                            color: theme.secondaryTextColor,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.purpleAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.purpleAccent.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Text(
                            '🚀 Geliştirme Aşamasında',
                            style: TextStyle(
                              color: Colors.purpleAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )

                // Kategoriler
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: _buildCategories(vm.recommendations!, theme),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories(RecommendationsData data, ThemeViewModel theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.windStrong.isNotEmpty)
          _CategorySection(
            title: '💨 Güçlü Rüzgar',
            subtitle: 'v̄ > 7 m/s',
            color: Colors.redAccent,
            cities: data.windStrong,
            theme: theme,
            onCityTap: _showWindRoseDialog,
          ),
        if (data.windStable.isNotEmpty)
          _CategorySection(
            title: '🔵 Stabil Rüzgar',
            subtitle: 'Weibull k > 2.5',
            color: Colors.blueAccent,
            cities: data.windStable,
            theme: theme,
            onCityTap: _showWindRoseDialog,
          ),
        if (data.windCirculation.isNotEmpty)
          _CategorySection(
            title: '🌀 Yüksek Sirkülasyon',
            subtitle: 'Değişken ama yoğun',
            color: Colors.cyanAccent,
            cities: data.windCirculation,
            theme: theme,
            onCityTap: _showWindRoseDialog,
          ),
        if (data.solarTop.isNotEmpty)
          _CategorySection(
            title: '☀️ En İyi Güneş',
            subtitle: 'Yüksek ışınım',
            color: Colors.orangeAccent,
            cities: data.solarTop,
            theme: theme,
            onCityTap: _showSolarDetailDialog,
          ),
      ],
    );
  }

  void _showWindRoseDialog(RecommendedCity city) {
    showDialog(
      context: context,
      builder: (ctx) => _WindRoseDialog(city: city, theme: widget.theme),
    );
  }

  void _showSolarDetailDialog(RecommendedCity city) {
    showDialog(
      context: context,
      builder: (ctx) => _SolarDetailDialog(city: city, theme: widget.theme),
    );
  }
}

// ── Kategori Bölümü ───────────────────────────────────────────────────────────

class _CategorySection extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color color;
  final List<RecommendedCity> cities;
  final ThemeViewModel theme;
  final void Function(RecommendedCity) onCityTap;

  const _CategorySection({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.cities,
    required this.theme,
    required this.onCityTap,
  });

  @override
  State<_CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<_CategorySection> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık
        InkWell(
          onTap: () => setState(() => _show = !_show),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
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
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: widget.theme.textColor,
                          fontSize: 12,
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
                  _show
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: widget.theme.secondaryTextColor,
                  size: 16,
                ),
              ],
            ),
          ),
        ),

        // Şehir listesi
        if (_show)
          ...widget.cities.take(5).map(
            (city) => InkWell(
              onTap: () => widget.onCityTap(city),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 4, horizontal: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 12,
                      color: widget.color.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        city.name,
                        style: TextStyle(
                          color: widget.theme.textColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (city.avgWindSpeed != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${city.avgWindSpeed!.toStringAsFixed(1)} m/s',
                          style: TextStyle(
                            color: widget.color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else if (city.avgRadiation != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${city.avgRadiation!.toStringAsFixed(0)} W',
                          style: TextStyle(
                            color: widget.color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Rüzgar Gülü Diyalog ───────────────────────────────────────────────────────

class _WindRoseDialog extends StatelessWidget {
  final RecommendedCity city;
  final ThemeViewModel theme;

  const _WindRoseDialog({required this.city, required this.theme});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: theme.cardColor,
      title: Row(
        children: [
          const Icon(Icons.air, color: Colors.cyanAccent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              city.name,
              style: TextStyle(color: theme.textColor, fontSize: 16),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // İstatistikler
            _StatRow('Ortalama Hız', '${city.avgWindSpeed?.toStringAsFixed(1) ?? "-"} m/s', theme),
            _StatRow('Maks. Hız', '${city.maxWindSpeed?.toStringAsFixed(1) ?? "-"} m/s', theme),
            _StatRow('Weibull k', city.weibullK?.toStringAsFixed(2) ?? '-', theme),
            _StatRow('Weibull λ', city.weibullLambda?.toStringAsFixed(2) ?? '-', theme),
            _StatRow('Std. Sapma', '${city.windStd?.toStringAsFixed(2) ?? "-"} m/s', theme),
            _StatRow('Kategori', city.windCategory ?? '-', theme),

            const SizedBox(height: 16),

            // Rüzgar gülü
            if (city.windRose != null) ...[
              Text(
                'Rüzgar Gülü',
                style: TextStyle(
                  color: theme.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              WindRoseWidget(
                data: city.windRose!,
                cityName: city.name,
                size: 200,
              ),
              const SizedBox(height: 8),
              // Renk açıklaması
              const _WindSpeedLegend(),
            ] else
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Rüzgar yön verisi yetersiz.',
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final ThemeViewModel theme;

  const _StatRow(this.label, this.value, this.theme);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: theme.secondaryTextColor, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _WindSpeedLegend extends StatelessWidget {
  const _WindSpeedLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF2196F3),
                Color(0xFF4CAF50),
                Color(0xFFFFEB3B),
                Color(0xFFFF9800),
                Color(0xFFF44336),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Düşük → Yüksek hız',
          style: TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }
}

// ── Güneş Detay Diyalog ───────────────────────────────────────────────────────

class _SolarDetailDialog extends StatelessWidget {
  final RecommendedCity city;
  final ThemeViewModel theme;

  const _SolarDetailDialog({required this.city, required this.theme});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: theme.cardColor,
      title: Row(
        children: [
          const Icon(Icons.wb_sunny, color: Colors.orangeAccent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              city.name,
              style: TextStyle(color: theme.textColor, fontSize: 16),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Güneş ışınım istatistikleri
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.orangeAccent.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.flash_on, color: Colors.amber, size: 32),
                const SizedBox(height: 8),
                Text(
                  '${city.totalRadiationKwh?.toStringAsFixed(1) ?? "-"} kWh/m²',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '7 günlük toplam ışınım',
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _StatRow('Ort. Işınım', '${city.avgRadiation?.toStringAsFixed(0) ?? "-"} W/m²', theme),
          _StatRow('Kategori', city.solarCategory ?? '-', theme),
          _StatRow('Koordinat', '${city.lat.toStringAsFixed(2)}°K, ${city.lon.toStringAsFixed(2)}°D', theme),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}
