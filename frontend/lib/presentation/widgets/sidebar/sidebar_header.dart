import 'package:flutter/material.dart';
import '../../viewmodels/theme_view_model.dart';

/// Sidebar üst kısmı - Logo ve menü açma/kapama butonu
class SidebarHeader extends StatelessWidget {
  final ThemeViewModel theme;
  final bool isCollapsed;
  final VoidCallback onToggle;

  const SidebarHeader({
    super.key,
    required this.theme,
    required this.isCollapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: EdgeInsets.zero,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.secondaryTextColor.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          // Menü Butonu (Sol 70px)
          SizedBox(
            width: 70,
            height: 70,
            child: IconButton(
              icon: Icon(
                isCollapsed ? Icons.menu : Icons.chevron_left,
                color: theme.secondaryTextColor,
              ),
              onPressed: onToggle,
            ),
          ),
          // Logo ve Başlık
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.eco, color: Colors.greenAccent),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    "SRRP",
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
