import 'package:flutter/material.dart';
import '../../../viewmodels/theme_view_model.dart';
import '../widgets/help_shared_widgets.dart';

class ReportsHelpTab extends StatelessWidget {
  final ThemeViewModel theme;

  const ReportsHelpTab({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HelpSectionTitle('Raporlama Araçları', theme),
          const SizedBox(height: 16),
          Text(
            'Analizlerinizi profesyonel formatlarda dışa aktararak sunumlarınızda veya fizibilite çalışmalarınızda kullanabilirsiniz.',
            style: TextStyle(color: theme.textColor, fontSize: 15),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              HelpReportTypeCard(
                title: 'PDF Raporu',
                desc: 'Görsel grafikler, harita görüntüleri ve özet tablolar içeren, sunuma hazır detaylı döküman.',
                icon: Icons.picture_as_pdf,
                color: Colors.red,
                theme: theme,
              ),
              HelpReportTypeCard(
                title: 'Excel (CSV) Raporu',
                desc: 'Ham verileri, saatlik üretim tahminlerini ve maliyet kalemlerini içeren, düzenlenebilir tablo formatı.',
                icon: Icons.table_chart,
                color: Colors.green,
                theme: theme,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
