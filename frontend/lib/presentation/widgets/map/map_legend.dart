import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../../providers/theme_provider.dart';

class LegendWidget extends StatelessWidget {
  final ThemeProvider theme;
  final String title;
  final String unit;
  final List<Color> gradientColors;
  final String minLabel;
  final String maxLabel;
  final String sourceLabel;
  final double width;
  final double titleFontSize;

  const LegendWidget({
    super.key,
    required this.theme,
    required this.title,
    required this.unit,
    required this.gradientColors,
    required this.minLabel,
    required this.maxLabel,
    this.sourceLabel = 'Veri Kaynağı : Open-Meteo',
    this.width = 200,
    this.titleFontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
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
              Container(
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    minLabel,
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    maxLabel,
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Divider(color: theme.secondaryTextColor.withValues(alpha: 0.2)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: theme.secondaryTextColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      sourceLabel,
                      style: TextStyle(
                        color: theme.secondaryTextColor,
                        fontSize: 9,
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
}
