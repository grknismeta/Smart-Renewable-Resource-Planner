import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:frontend/core/network/analysis_service.dart';
import 'package:frontend/core/theme/app_theme.dart';

import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';

/// Haritanın sağından kayan "Önerilen Bölgeler" paneli.
///
/// Faz 1 sonrası: Veri `province_analysis` tek kaynak tablosundan gelir
/// (`/analysis/provinces?type=wind|solar|hydro&horizon=1m|3m|6m|yearly`).
/// Eski `/recommendations` Weibull uç noktası yetersiz veri dönebildiği için
/// boş kalıyordu; bu panel artık garantili veriyle açılır.
class RecommendationsSidePanel extends StatelessWidget {
  final ThemeViewModel theme;
  final MapViewModel mapViewModel;
  final void Function(double lat, double lon) onCityNavigate;

  const RecommendationsSidePanel({
    super.key,
    required this.theme,
    required this.mapViewModel,
    required this.onCityNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        bottomLeft: Radius.circular(20),
      ),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.88),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              bottomLeft: Radius.circular(20),
            ),
            border: Border(
              left: BorderSide(
                color: Colors.purpleAccent.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(-4, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHeader(),
              Divider(
                height: 1,
                color: theme.secondaryTextColor.withValues(alpha: 0.15),
              ),
              _HorizonBar(theme: theme, vm: mapViewModel),
              Divider(
                height: 1,
                color: theme.secondaryTextColor.withValues(alpha: 0.1),
              ),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            size: 18,
            color: Colors.purpleAccent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Önerilen Bölgeler',
              style: TextStyle(
                color: theme.textColor,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: mapViewModel.closeRecommendationsPanel,
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: theme.secondaryTextColor,
            ),
            splashRadius: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final vm = mapViewModel;

    // Loading
    if (vm.isLoadingAnalysisTop) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Colors.purpleAccent,
              strokeWidth: 2,
            ),
            SizedBox(height: 10),
            Text(
              'Province analizi çalışıyor…',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      );
    }

    // Error
    if (vm.analysisTopError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  color: Colors.orangeAccent, size: 32),
              const SizedBox(height: 8),
              Text(
                'Backend bağlantısı gerekli',
                style: TextStyle(
                    color: theme.secondaryTextColor, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => vm.loadAnalysisTop(horizon: vm.analysisHorizon),
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('Yeniden Dene'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.purpleAccent,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final wind = vm.analysisWindTop ?? const [];
    final solar = vm.analysisSolarTop ?? const [];
    final hydro = vm.analysisHydroTop ?? const [];

    if (wind.isEmpty && solar.isEmpty && hydro.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.hourglass_empty_rounded,
                color: Colors.purpleAccent,
                size: 32,
              ),
              const SizedBox(height: 10),
              Text(
                'Bu pencere için henüz analiz yok',
                style: TextStyle(
                  color: theme.secondaryTextColor,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Saatlik scheduler ilk province_analysis\nyeniden hesaplamasını tamamladıktan sonra\nveri dolacak.',
                style: TextStyle(
                  color: theme.secondaryTextColor.withValues(alpha: 0.7),
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => vm.loadAnalysisTop(horizon: vm.analysisHorizon),
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('Yenile'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.purpleAccent,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      children: [
        if (wind.isNotEmpty)
          _CategoryGroup(
            title: 'En İyi Rüzgar',
            subtitle: _subtitleFor(vm.analysisHorizon),
            icon: Icons.air_rounded,
            color: Colors.redAccent,
            items: wind,
            horizon: vm.analysisHorizon,
            theme: theme,
            onTap: _handleCityTap,
            criteria: 'Kriter: 100m rüzgar hızının kübü '
                '(P ∝ v³) — türbin gücüyle orantılı kapasite proxy\'si.',
          ),
        if (solar.isNotEmpty)
          _CategoryGroup(
            title: 'En İyi Güneş',
            subtitle: _subtitleFor(vm.analysisHorizon),
            icon: Icons.wb_sunny_rounded,
            color: Colors.orangeAccent,
            items: solar,
            horizon: vm.analysisHorizon,
            theme: theme,
            onTap: _handleCityTap,
            criteria:
                'Kriter: kısa dalga ışınım (W/m²), 400 W/m² = 100 puan '
                'doygunluğu.',
          ),
        if (hydro.isNotEmpty)
          _CategoryGroup(
            title: 'En İyi Hidro',
            subtitle: _subtitleFor(vm.analysisHorizon),
            icon: Icons.water_drop_rounded,
            color: Colors.lightBlueAccent,
            items: hydro,
            horizon: vm.analysisHorizon,
            theme: theme,
            onTap: _handleCityTap,
            criteria:
                'Kriter (proxy): %70 yağış (mm/gün; 5 mm ≈ 100 puan) + %30 '
                'sıcaklık (12 °C tepe, ±20 °C). Gerçek HES havza verisi '
                'entegrasyonu geliyor.',
          ),
      ],
    );
  }

  void _handleCityTap(ProvinceAnalysisItem item) {
    // Koordinat yoksa (analysis item'da lat/lon tutmuyoruz) sadece Raporlar'a
    // yönlendir. Harita navigasyonu için raw tabloya bak — çoğunda lat/lon yok.
    final ctx = _rootContext;
    if (ctx == null) return;
    Navigator.of(ctx).pushNamed(
      '/reports',
      arguments: {'province': item.provinceName},
    );
  }

  /// NOTE: side panel stateless; gerçek bir context'e ulaşmak için küçük bir
  /// closure. Parent ondan geçirmediği için `pushNamed` zaman zaman null'la
  /// karşılaşabilir — o zaman no-op.
  BuildContext? get _rootContext => _ContextKeeper.current;

  String _subtitleFor(AnalysisHorizon h) {
    switch (h) {
      case AnalysisHorizon.m1:
        return 'Son 30 gün skoru';
      case AnalysisHorizon.m3:
        return 'Son 90 gün skoru';
      case AnalysisHorizon.m6:
        return 'Son 180 gün skoru';
      case AnalysisHorizon.yearly:
        return 'Son 365 gün skoru';
    }
  }
}

/// Panel BuildContext yakalayıcısı — `_handleCityTap` için.
/// `build()` her çağrıldığında güncellenir.
class _ContextKeeper {
  static BuildContext? current;
}

class _HorizonBar extends StatelessWidget {
  final ThemeViewModel theme;
  final MapViewModel vm;

  const _HorizonBar({required this.theme, required this.vm});

  @override
  Widget build(BuildContext context) {
    // context'i navigasyon için yakala
    _ContextKeeper.current = context;

    const items = <(AnalysisHorizon, String)>[
      (AnalysisHorizon.m1, '1 Ay'),
      (AnalysisHorizon.m3, '3 Ay'),
      (AnalysisHorizon.m6, '6 Ay'),
      (AnalysisHorizon.yearly, '1 Yıl'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: items.map((entry) {
          final isActive = entry.$1 == vm.analysisHorizon;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                onTap: vm.isLoadingAnalysisTop
                    ? null
                    : () => vm.setAnalysisHorizon(entry.$1),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.purpleAccent.withValues(alpha: 0.22)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isActive
                          ? Colors.purpleAccent.withValues(alpha: 0.55)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      entry.$2,
                      style: TextStyle(
                        color: isActive
                            ? Colors.purpleAccent
                            : theme.secondaryTextColor,
                        fontSize: 11,
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CategoryGroup extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<ProvinceAnalysisItem> items;
  final AnalysisHorizon horizon;
  final ThemeViewModel theme;
  final void Function(ProvinceAnalysisItem) onTap;
  final String? criteria; // Skor kriteri tek satır açıklama

  const _CategoryGroup({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.items,
    required this.horizon,
    required this.theme,
    required this.onTap,
    this.criteria,
  });

  @override
  State<_CategoryGroup> createState() => _CategoryGroupState();
}

class _CategoryGroupState extends State<_CategoryGroup> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: widget.color.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icon,
                        size: 16, color: widget.color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            color: theme.secondaryTextColor,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${widget.items.length}',
                      style: TextStyle(
                        color: widget.color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: theme.secondaryTextColor,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            if (widget.criteria != null) ...[
              Container(
                width: double.infinity,
                color: widget.color.withValues(alpha: 0.06),
                padding:
                    const EdgeInsets.fromLTRB(12, 6, 10, 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 12, color: widget.color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.criteria!,
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 10.5,
                          height: 1.35,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Divider(
              height: 1,
              color: widget.color.withValues(alpha: 0.1),
            ),
            ...widget.items.take(10).toList().asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final item = entry.value;
              final score = item.scoreFor(widget.horizon);
              return InkWell(
                onTap: () => widget.onTap(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        child: Text(
                          '$rank.',
                          style: TextStyle(
                            color: theme.secondaryTextColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.location_on_rounded,
                        size: 12,
                        color: widget.color.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.provinceName,
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (score != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: widget.color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            score.toStringAsFixed(1),
                            style: TextStyle(
                              color: widget.color,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: theme.secondaryTextColor.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
