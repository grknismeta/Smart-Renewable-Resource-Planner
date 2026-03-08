import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';

import 'package:frontend/features/map/viewmodels/map_viewmodel.dart';
import 'city_list_section.dart';
import 'city_detail_card.dart';

/// Haritanın sağından kayan önerilen bölgeler paneli.
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
              // Header
              _buildHeader(),
              Divider(
                height: 1,
                color: theme.secondaryTextColor.withValues(alpha: 0.15),
              ),

              // Content
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
    if (vm.isLoadingRecommendations) {
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
              'Weibull analizi çalışıyor...',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      );
    }

    // Error
    if (vm.recommendationError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.orangeAccent, size: 32),
            const SizedBox(height: 8),
            Text(
              'Backend bağlantısı gerekli',
              style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
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
      );
    }

    // Empty / No data
    if (vm.recommendations == null || vm.recommendations!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.auto_awesome_mosaic_rounded,
              color: Colors.purpleAccent,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              'Henüz öneri verisi yok',
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: vm.loadRecommendations,
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Yükle'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.purpleAccent,
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    // Selected city detail
    if (vm.selectedRecommendedCity != null) {
      return CityDetailCard(
        city: vm.selectedRecommendedCity!,
        hourlyData: vm.selectedCityHourlyData,
        isLoading: vm.isLoadingSelectedCityData,
        theme: theme,
        onBack: vm.clearSelectedCity,
      );
    }

    // City list
    return CityListSection(
      data: vm.recommendations!,
      theme: theme,
      onCityTap: (city) {
        onCityNavigate(city.lat, city.lon);
        vm.selectRecommendedCity(city);
      },
    );
  }
}
