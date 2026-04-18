import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'package:frontend/core/theme/theme_view_model.dart';

class LegendWidget extends StatelessWidget {
  final ThemeViewModel theme;
  final String title;
  final String unit;
  final List<Color> gradientColors;
  final String minLabel;
  final String maxLabel;
  final String sourceLabel;
  final double width;
  final double titleFontSize;

  /// Sayısal tick değerleri — gradient bar altında eşit aralıklı gösterilir.
  /// Örn: ['0', '50', '100', '150', '200'] veya ['-15', '0', '20', '30', '45']
  final List<String>? tickLabels;

  const LegendWidget({
    super.key,
    required this.theme,
    required this.title,
    required this.unit,
    required this.gradientColors,
    required this.minLabel,
    required this.maxLabel,
    this.sourceLabel = 'Kaynak : Open-Meteo',
    this.width = 200,
    this.titleFontSize = 12,
    this.tickLabels,
  });

  @override
  Widget build(BuildContext context) {
    final hasTicks = tickLabels != null && tickLabels!.length >= 2;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.secondaryTextColor.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık + birim
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(
                        color: theme.textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: titleFontSize,
                      ),
                    ),
                  ),
                  Text(
                    unit,
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Gradient bar
              Container(
                height: 16,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // Tick labels veya min/max labels
              if (hasTicks)
                _buildTickRow()
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(minLabel, style: _tickStyle),
                    Text(maxLabel, style: _tickStyle),
                  ],
                ),

              const SizedBox(height: 6),
              Divider(
                color: theme.secondaryTextColor.withValues(alpha: 0.2),
                height: 1,
              ),
              const SizedBox(height: 6),

              // Kaynak
              Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.secondaryTextColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      sourceLabel,
                      style: TextStyle(
                        color: theme.secondaryTextColor,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle get _tickStyle => TextStyle(
        color: theme.secondaryTextColor,
        fontSize: 9,
        fontWeight: FontWeight.w500,
      );

  Widget _buildTickRow() {
    final ticks = tickLabels!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: ticks
          .map((t) => Text(t, style: _tickStyle))
          .toList(),
    );
  }
}
