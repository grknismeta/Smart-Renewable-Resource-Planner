import 'package:flutter/material.dart';
import '../../../viewmodels/theme_view_model.dart';
import '../widgets/help_shared_widgets.dart';

class ScenarioHelpTab extends StatelessWidget {
  final ThemeViewModel theme;

  const ScenarioHelpTab({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HelpSectionTitle('Senaryo Yönetimi', theme),
          const SizedBox(height: 16),
          Text(
            'Senaryolar, farklı yatırım planlarını (örneğin "Proje A" vs "Proje B") oluşturup saklamanızı ve karşılaştırmanızı sağlar.',
            style: TextStyle(color: theme.textColor, fontSize: 15),
          ),
          const SizedBox(height: 24),
          HelpFeatureRow(
            title: 'Senaryo Oluşturma',
            description: 'Yan menüden "Senaryolar" sekmesine gidin ve "Yeni Senaryo" butonuna tıklayın. Senaryonuza isim ve bütçe verebilirsiniz.',
            icon: Icons.create_new_folder,
            theme: theme,
          ),
          HelpFeatureRow(
            title: 'Kaynağı Senaryoya Ekleme',
            description: 'Haritada bir kaynak eklerken veya düzenlerken, açılan pencerede "Senaryoya Ekle" seçeneğini kullanarak o kaynağı spesifik bir projenin parçası yapabilirsiniz.',
            icon: Icons.link,
            theme: theme,
          ),
          HelpFeatureRow(
            title: 'Karşılaştırma',
            description: 'Birden fazla senaryonuz olduğunda, senaryo listesinden seçim yaparak toplam maliyet, üretim ve geri dönüş sürelerini yan yana kıyaslayabilirsiniz.',
            icon: Icons.compare_arrows,
            theme: theme,
          ),
        ],
      ),
    );
  }
}
