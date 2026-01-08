import 'package:flutter/material.dart';
import '../../../viewmodels/theme_view_model.dart';
import '../widgets/help_shared_widgets.dart';

class MapHelpTab extends StatelessWidget {
  final ThemeViewModel theme;

  const MapHelpTab({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HelpSectionTitle('Harita Kullanımı', theme),
          const SizedBox(height: 16),
          HelpStepItem(
            step: 1,
            title: 'Katman Seçimi',
            description: 'Sol üstteki paneli kullanarak "Güneş Işınımı", "Rüzgar Hızı" veya "Sıcaklık" katmanlarını açabilirsiniz. Bu katmanlar, bölgenin potansiyelini renkli ısı haritaları ile gösterir.',
            icon: Icons.layers,
            theme: theme,
          ),
          HelpStepItem(
            step: 2,
            title: 'Konum Analizi ve Kaynak Ekleme',
            description: 'Harita üzerinde ilgilendiğiniz boş bir alana tıklayın. Sistem otomatik olarak bölgenin uygunluğunu (eğim, koruma alanı vb.) kontrol eder. Uygunsa, panel veya türbin ekleme penceresi açılır.',
            icon: Icons.add_location_alt,
            theme: theme,
          ),
          HelpStepItem(
            step: 3,
            title: 'Bölge Seçimi',
            description: 'Üst menüdeki "Bölge Seç" aracı ile haritada çokgen bir alan çizebilir ve bu alan içindeki toplam potansiyeli veya mevcut kaynakları görebilirsiniz.',
            icon: Icons.select_all,
            theme: theme,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'İpucu: Harita üzerinde gezinirken sağ alttaki ölçek ve lejant (renk açıklamaları) size değerler hakkında bilgi verir.',
                    style: TextStyle(color: theme.textColor),
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
