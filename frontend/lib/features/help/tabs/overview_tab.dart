import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/help/widgets/help_shared_widgets.dart';

class OverviewTab extends StatelessWidget {
  final ThemeViewModel theme;

  const OverviewTab({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HelpSectionTitle('Akıllı Yenilenebilir Kaynak Planlayıcı Nedir?', theme),
          const SizedBox(height: 12),
          Text(
            'Bu uygulama, Türkiye genelindeki güneş ve rüzgar enerjisi potansiyelini analiz etmenize ve enerji yatırımlarınızı planlamanıza yardımcı olan gelişmiş bir araçtır.',
            style: TextStyle(color: theme.textColor, fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 24),
          HelpInfoCard(
            title: 'Temel Özellikler',
            items: [
              'Detaylı Güneş ve Rüzgar Haritaları',
              'Konum Bazlı Potansiyel Hesaplama',
              'Yatırım Senaryoları Oluşturma (Güneş Paneli / Rüzgar Türbini)',
              'Kapsamlı Karşılaştırmalı Raporlama',
              'Yapay Zeka Destekli Öneriler'
            ],
            icon: Icons.star,
            color: Colors.amber,
            theme: theme,
          ),
          const SizedBox(height: 24),
          HelpSectionTitle('Nasıl Başlarım?', theme),
          const SizedBox(height: 12),
          Text(
            'Sol menüdeki ikonları kullanarak harita katmanlarını değiştirebilir, harita üzerine tıklayarak yeni bir kaynak ekleyebilir veya mevcut projelerinizi senaryolar bölümünden yönetebilirsiniz.',
            style: TextStyle(color: theme.secondaryTextColor, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
