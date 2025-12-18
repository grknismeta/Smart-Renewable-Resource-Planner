import 'package:flutter/material.dart';
import '../../../providers/theme_provider.dart';
import '../../screens/scenario_screen.dart';

/// Senaryo yönetimi butonu - Sidebar'da görünen
class ScenarioButton extends StatelessWidget {
  final ThemeProvider theme;
  final bool isGuest;
  final bool isCollapsed;

  const ScenarioButton({
    super.key,
    required this.theme,
    required this.isGuest,
    required this.isCollapsed,
  });

  @override
  Widget build(BuildContext context) {
    if (isGuest) {
      return _buildGuestView();
    }
    return _buildAuthenticatedView(context);
  }

  Widget _buildGuestView() {
    if (isCollapsed) {
      return Center(
        child: Tooltip(
          message: "Giriş Yapmalısınız",
          child: Icon(
            Icons.lock_outline,
            color: Colors.orange.withValues(alpha: 0.7),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Senaryolar için giriş yapın.",
              style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticatedView(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ScenarioScreen()),
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
              child: Icon(Icons.folder_special, color: Colors.blueAccent),
            ),
            if (!isCollapsed) ...[
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  "Senaryo Yönetimi",
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
