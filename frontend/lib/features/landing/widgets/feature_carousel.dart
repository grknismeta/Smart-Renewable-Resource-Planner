import 'package:flutter/material.dart';

/// Özellik kartları karuseli
class FeatureCarousel extends StatefulWidget {
  final bool isDark;
  final bool isWide;

  const FeatureCarousel({
    super.key,
    required this.isDark,
    required this.isWide,
  });

  @override
  State<FeatureCarousel> createState() => _FeatureCarouselState();
}

class _FeatureCarouselState extends State<FeatureCarousel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  final _scrollController = ScrollController();

  static const _features = <_FeatureData>[
    _FeatureData(
      icon: Icons.air,
      color: Color(0xFF06B6D4),
      title: 'Ruzgar Analizi',
      description: 'Weibull dagilimi ile ruzgar potansiyeli hesaplama ve ruzgar gulu gorsellestirme',
    ),
    _FeatureData(
      icon: Icons.wb_sunny_rounded,
      color: Color(0xFFF59E0B),
      title: 'Gunes Haritasi',
      description: 'Isinim yogunlugu heatmap ve bolgesel gunes enerjisi potansiyeli',
    ),
    _FeatureData(
      icon: Icons.auto_awesome,
      color: Color(0xFF8B5CF6),
      title: 'Akilli Oneriler',
      description: '8 kategoride en verimli bolgeleri otomatik siralama',
    ),
    _FeatureData(
      icon: Icons.terrain_rounded,
      color: Color(0xFF10B981),
      title: '3D Arazi',
      description: 'Yukseklik modeli, gokyuzu efekti ve 3D bina gorsellestirme',
    ),
    _FeatureData(
      icon: Icons.description_rounded,
      color: Color(0xFFEF4444),
      title: 'Rapor & Export',
      description: 'Bolgesel analiz raporlari ve PDF export',
    ),
    _FeatureData(
      icon: Icons.public_rounded,
      color: Color(0xFF3B82F6),
      title: 'Global Projeksiyon',
      description: 'Dunya genelinde enerji yatirimi planlama',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeOut,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Ozellikler',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: widget.isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: widget.isWide ? _buildGridLayout() : _buildScrollLayout(),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollLayout() {
    return ListView.separated(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _features.length,
      separatorBuilder: (_, __) => const SizedBox(width: 14),
      itemBuilder: (_, i) => SizedBox(
        width: 220,
        child: _buildCard(_features[i], i),
      ),
    );
  }

  Widget _buildGridLayout() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        childAspectRatio: 1.5,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: _features.length,
      itemBuilder: (_, i) => _buildCard(_features[i], i),
    );
  }

  Widget _buildCard(_FeatureData feature, int index) {
    final bgColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.8);
    final borderColor = (widget.isDark ? Colors.white : Colors.black)
        .withValues(alpha: 0.06);
    final textColor = widget.isDark ? Colors.white : const Color(0xFF1A1A2E);
    final descColor = widget.isDark ? Colors.white60 : const Color(0xFF666666);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: feature.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(feature.icon, color: feature.color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            feature.title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              feature.description,
              style: TextStyle(fontSize: 12, color: descColor, height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureData {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _FeatureData({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}
