import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';

class HelpSectionTitle extends StatelessWidget {
  final String title;
  final ThemeViewModel theme;

  const HelpSectionTitle(this.title, this.theme, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: theme.textColor,
      ),
    );
  }
}

class HelpInfoCard extends StatelessWidget {
  final String title;
  final List<String> items;
  final IconData icon;
  final Color color;
  final ThemeViewModel theme;

  const HelpInfoCard({
    super.key,
    required this.title,
    required this.items,
    required this.icon,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.secondaryTextColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: theme.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Icon(Icons.circle, size: 6, color: theme.secondaryTextColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(color: theme.textColor),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class HelpStepItem extends StatelessWidget {
  final int step;
  final String title;
  final String description;
  final IconData icon;
  final ThemeViewModel theme;

  const HelpStepItem({
    super.key,
    required this.step,
    required this.title,
    required this.description,
    required this.icon,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$step',
              style: const TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: theme.secondaryTextColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HelpFeatureRow extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final ThemeViewModel theme;

  const HelpFeatureRow({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.secondaryTextColor.withOpacity(0.2)),
            ),
            child: Icon(icon, color: theme.secondaryTextColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: theme.textColor,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(color: theme.secondaryTextColor, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HelpReportTypeCard extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  final ThemeViewModel theme;

  const HelpReportTypeCard({
    super.key,
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: TextStyle(color: theme.secondaryTextColor, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
