import 'package:flutter/material.dart';
import 'package:frontend/core/theme/theme_view_model.dart';
import 'package:frontend/features/reports/screens/report_screen.dart';

class ReportButton extends StatelessWidget {
  final ThemeViewModel theme;
  final bool isCollapsed;

  const ReportButton({
    super.key,
    required this.theme,
    required this.isCollapsed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ReportScreen()),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: isCollapsed
            ? null
            : BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.secondaryTextColor.withValues(alpha: 0.1),
                ),
              ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4.0),
              child: Icon(Icons.description, color: Colors.green),
            ),
            if (!isCollapsed) ...[
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  "Raporlar",
                  style: TextStyle(
                    color: theme.textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: theme.secondaryTextColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
