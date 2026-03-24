// lib/features/reports/widgets/tabs/province_drill_tab.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/models/weather_model.dart';
import 'package:frontend/features/reports/viewmodels/report_viewmodel.dart';
import 'package:frontend/features/scenarios/dialogs/scenario_create_dialog.dart';

// ── Türkiye 81 il görüntü adları (DB ASCII → doğru Türkçe) ──────────────────
const _kDisplayNames = <String, String>{
  'Adana': 'Adana', 'Adiyaman': 'Adıyaman', 'Afyon': 'Afyonkarahisar',
  'Agri': 'Ağrı', 'Aksaray': 'Aksaray', 'Amasya': 'Amasya',
  'Ankara': 'Ankara', 'Antalya': 'Antalya', 'Ardahan': 'Ardahan',
  'Artvin': 'Artvin', 'Aydin': 'Aydın', 'Balikesir': 'Balıkesir',
  'Bartin': 'Bartın', 'Batman': 'Batman', 'Bayburt': 'Bayburt',
  'Bilecik': 'Bilecik', 'Bingol': 'Bingöl', 'Bitlis': 'Bitlis',
  'Bolu': 'Bolu', 'Burdur': 'Burdur', 'Bursa': 'Bursa',
  'Canakkale': 'Çanakkale', 'Cankiri': 'Çankırı', 'Corum': 'Çorum',
  'Denizli': 'Denizli', 'Diyarbakir': 'Diyarbakır', 'Duzce': 'Düzce',
  'Edirne': 'Edirne', 'Elazig': 'Elazığ', 'Erzincan': 'Erzincan',
  'Erzurum': 'Erzurum', 'Eskisehir': 'Eskişehir', 'Gaziantep': 'Gaziantep',
  'Giresun': 'Giresun', 'Gumushane': 'Gümüşhane', 'Hakkari': 'Hakkari',
  'Hatay': 'Hatay', 'Igdir': 'Iğdır', 'Isparta': 'Isparta',
  'Istanbul': 'İstanbul', 'Izmir': 'İzmir',
  'Kahramanmaras': 'Kahramanmaraş', 'Karabuk': 'Karabük',
  'Karaman': 'Karaman', 'Kars': 'Kars', 'Kastamonu': 'Kastamonu',
  'Kayseri': 'Kayseri', 'Kilis': 'Kilis', 'Kirikkale': 'Kırıkkale',
  'Kirklareli': 'Kırklareli', 'Kirsehir': 'Kırşehir',
  'Kocaeli': 'Kocaeli', 'Konya': 'Konya', 'Kutahya': 'Kütahya',
  'Malatya': 'Malatya', 'Manisa': 'Manisa', 'Mardin': 'Mardin',
  'Mersin': 'Mersin', 'Mugla': 'Muğla', 'Mus': 'Muş',
  'Nevsehir': 'Nevşehir', 'Nigde': 'Niğde', 'Ordu': 'Ordu',
  'Osmaniye': 'Osmaniye', 'Rize': 'Rize', 'Sakarya': 'Sakarya',
  'Samsun': 'Samsun', 'Sanliurfa': 'Şanlıurfa', 'Siirt': 'Siirt',
  'Sinop': 'Sinop', 'Sirnak': 'Şırnak', 'Sivas': 'Sivas',
  'Tekirdag': 'Tekirdağ', 'Tokat': 'Tokat', 'Trabzon': 'Trabzon',
  'Tunceli': 'Tunceli', 'Usak': 'Uşak', 'Van': 'Van',
  'Yalova': 'Yalova', 'Yozgat': 'Yozgat', 'Zonguldak': 'Zonguldak',
};

// ── Türkiye 7 coğrafi bölge → il listesi (DB adları) ────────────────────────
const _kRegionMap = <String, List<String>>{
  'Marmara': ['Istanbul', 'Tekirdag', 'Edirne', 'Kirklareli', 'Canakkale',
    'Balikesir', 'Bursa', 'Yalova', 'Kocaeli', 'Sakarya', 'Duzce',
    'Bolu', 'Bilecik'],
  'Ege': ['Izmir', 'Manisa', 'Afyon', 'Kutahya', 'Usak', 'Denizli',
    'Aydin', 'Mugla'],
  'Akdeniz': ['Antalya', 'Isparta', 'Burdur', 'Mersin', 'Adana',
    'Osmaniye', 'Hatay', 'Kahramanmaras'],
  'İç Anadolu': ['Ankara', 'Konya', 'Eskisehir', 'Karaman', 'Aksaray',
    'Nigde', 'Kirsehir', 'Nevsehir', 'Kirikkale', 'Yozgat', 'Sivas',
    'Corum', 'Kayseri'],
  'Karadeniz': ['Zonguldak', 'Karabuk', 'Bartin', 'Kastamonu', 'Sinop',
    'Samsun', 'Ordu', 'Giresun', 'Trabzon', 'Rize', 'Artvin',
    'Gumushane', 'Amasya', 'Tokat', 'Bayburt'],
  'Doğu Anadolu': ['Erzurum', 'Erzincan', 'Agri', 'Kars', 'Ardahan',
    'Igdir', 'Tunceli', 'Elazig', 'Bingol', 'Mus', 'Van', 'Bitlis',
    'Hakkari', 'Malatya'],
  'Güneydoğu': ['Gaziantep', 'Kilis', 'Adiyaman', 'Sanliurfa',
    'Diyarbakir', 'Mardin', 'Sirnak', 'Batman', 'Siirt'],
};

String _displayName(String raw) => _kDisplayNames[raw] ?? raw;

String _regionOf(String raw) {
  for (final e in _kRegionMap.entries) {
    if (e.value.contains(raw)) return e.key;
  }
  return 'Diğer';
}

/// Tab 2 — İl Analizi
class ProvinceDrillTab extends StatefulWidget {
  const ProvinceDrillTab({super.key});

  @override
  State<ProvinceDrillTab> createState() => _ProvinceDrillTabState();
}

class _ProvinceDrillTabState extends State<ProvinceDrillTab> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _regionFilter = 'Tümü';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ProvinceSummary> _filtered(List<ProvinceSummary> all) {
    return all.where((p) {
      final display = _displayName(p.provinceName).toLowerCase();
      final raw = p.provinceName.toLowerCase();
      final matchSearch = _search.isEmpty ||
          display.contains(_search.toLowerCase()) ||
          raw.contains(_search.toLowerCase());
      final matchRegion = _regionFilter == 'Tümü' ||
          _regionOf(p.provinceName) == _regionFilter;
      return matchSearch && matchRegion;
    }).toList()
      ..sort((a, b) => _computeScore(b).compareTo(_computeScore(a)));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportViewModel>();
    final theme = context.watch<ThemeViewModel>();
    final provinces = vm.provinceSummaries;

    if (vm.isBusy && provinces.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.cyanAccent));
    }
    if (vm.hasError && provinces.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.orangeAccent, size: 32),
            const SizedBox(height: 8),
            Text(
              vm.errorMessage ?? 'İl verisi yüklenemedi',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => vm.init(),
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Yeniden Dene'),
              style: TextButton.styleFrom(foregroundColor: Colors.cyanAccent),
            ),
          ],
        ),
      );
    }
    if (provinces.isEmpty) {
      return const Center(
        child: Text('İl verisi bulunamadı.',
            style: TextStyle(color: Colors.white60, fontSize: 14)),
      );
    }

    final filtered = _filtered(provinces);

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 650;
      if (wide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 240,
              child: _ProvinceListPanel(
                provinces: filtered,
                allCount: provinces.length,
                vm: vm,
                theme: theme,
                searchCtrl: _searchCtrl,
                regionFilter: _regionFilter,
                onSearch: (v) => setState(() => _search = v),
                onRegion: (r) => setState(() => _regionFilter = r),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _ProvinceDetail(vm: vm, theme: theme)),
          ],
        );
      }
      return Column(
        children: [
          SizedBox(
            height: 220,
            child: _ProvinceListPanel(
              provinces: filtered,
              allCount: provinces.length,
              vm: vm,
              theme: theme,
              searchCtrl: _searchCtrl,
              regionFilter: _regionFilter,
              onSearch: (v) => setState(() => _search = v),
              onRegion: (r) => setState(() => _regionFilter = r),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _ProvinceDetail(vm: vm, theme: theme)),
        ],
      );
    });
  }
}

// ── Province List Panel ───────────────────────────────────────────────────────

class _ProvinceListPanel extends StatelessWidget {
  final List<ProvinceSummary> provinces;
  final int allCount;
  final ReportViewModel vm;
  final ThemeViewModel theme;
  final TextEditingController searchCtrl;
  final String regionFilter;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onRegion;

  const _ProvinceListPanel({
    required this.provinces,
    required this.allCount,
    required this.vm,
    required this.theme,
    required this.searchCtrl,
    required this.regionFilter,
    required this.onSearch,
    required this.onRegion,
  });

  static const _regions = [
    'Tümü', 'Marmara', 'Ege', 'Akdeniz',
    'İç Anadolu', 'Karadeniz', 'Doğu Anadolu', 'Güneydoğu',
  ];

  @override
  Widget build(BuildContext context) {
    final selected = vm.selectedProvinceIndex;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Başlık ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(children: [
              const Icon(Icons.location_city_rounded,
                  size: 14, color: Colors.cyanAccent),
              const SizedBox(width: 6),
              Text(
                'İller  ${provinces.length}/$allCount',
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ]),
          ),

          // ── Arama ───────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: TextField(
              controller: searchCtrl,
              onChanged: onSearch,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'İl ara…',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 16, color: Colors.white38),
                suffixIcon: searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            size: 14, color: Colors.white38),
                        onPressed: () {
                          searchCtrl.clear();
                          onSearch('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
            ),
          ),

          // ── Bölge Filtresi ───────────────────────────────────────────────────
          SizedBox(
            height: 28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _regions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (_, i) {
                final r = _regions[i];
                final active = r == regionFilter;
                return GestureDetector(
                  onTap: () => onRegion(r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.cyanAccent.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: active
                            ? Colors.cyanAccent.withValues(alpha: 0.5)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      r,
                      style: TextStyle(
                        color: active
                            ? Colors.cyanAccent
                            : Colors.white54,
                        fontSize: 10,
                        fontWeight: active
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: Colors.white12),

          // ── Liste ────────────────────────────────────────────────────────────
          Expanded(
            child: provinces.isEmpty
                ? const Center(
                    child: Text('Sonuç bulunamadı.',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 12)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: provinces.length,
                    itemBuilder: (context, idx) {
                      final p = provinces[idx];
                      // Selected index from vm refers to index in original list
                      final origIdx = vm.provinceSummaries.indexOf(p);
                      final isActive = origIdx == selected;
                      final score = _computeScore(p);
                      return _ProvinceListItem(
                        name: _displayName(p.provinceName),
                        region: _regionOf(p.provinceName),
                        score: score,
                        isActive: isActive,
                        onTap: () =>
                            vm.setSelectedProvinceIndex(origIdx),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProvinceListItem extends StatelessWidget {
  final String name;
  final String region;
  final double score;
  final bool isActive;
  final VoidCallback onTap;

  const _ProvinceListItem({
    required this.name,
    required this.region,
    required this.score,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.cyanAccent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4))
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: isActive
                          ? Colors.cyanAccent
                          : Colors.white70,
                      fontSize: 12,
                      fontWeight: isActive
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    region,
                    style: TextStyle(
                      color: isActive
                          ? Colors.cyanAccent.withValues(alpha: 0.6)
                          : Colors.white30,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _scoreColor(score).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                score.toStringAsFixed(0),
                style: TextStyle(
                  color: _scoreColor(score),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Province Detail ───────────────────────────────────────────────────────────

class _ProvinceDetail extends StatelessWidget {
  final ReportViewModel vm;
  final ThemeViewModel theme;

  const _ProvinceDetail({required this.vm, required this.theme});

  @override
  Widget build(BuildContext context) {
    final p = vm.selectedProvinceSummary;
    if (p == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_outlined,
                size: 36, color: Colors.white12),
            const SizedBox(height: 8),
            const Text('Sol listeden bir il seçin.',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      );
    }

    final displayName = _displayName(p.provinceName);
    final region = _regionOf(p.provinceName);
    final score = _computeScore(p);
    // Yaklaşık finans metrikleri (score bazlı tahmin)
    final lcoe = (2.8 - (score / 100) * 1.2);
    final roi = (10 + (score / 100) * 20);
    final amort = (8 - (score / 100) * 5);
    final irr = (8 + (score / 100) * 16);

    final solarVal = p.avgRadiation ?? 0;
    final windVal = p.avgWindSpeed ?? 0;
    final tempVal = p.avgTemperature ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Başlık ──────────────────────────────────────────────────────────
          _DetailHeader(
              name: displayName, region: region, score: score),
          const SizedBox(height: 10),

          // ── Ne anlıyoruz? Açıklama kutusu ───────────────────────────────────
          _InfoBanner(
            icon: Icons.lightbulb_outline_rounded,
            color: Colors.amberAccent,
            text: 'Bu panel, seçili ilin yenilenebilir enerji '
                'kurulum potansiyelini göstermektedir. '
                'Puanlama güneş ışınımı, rüzgar hızı ve '
                'sıcaklık verilerine göre hesaplanır. '
                'Finansal tahminler ortalama Türkiye LCOE '
                'değerleri baz alınarak yaklaşık hesaplanmıştır.',
          ),
          const SizedBox(height: 12),

          // ── Ham ölçüm verileri ───────────────────────────────────────────────
          _SectionTitle(title: 'Ölçüm Verileri',
              subtitle: 'Son 7 günlük saatlik ortalama'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatChip(
                icon: Icons.wb_sunny_rounded,
                label: 'Güneş Işınımı',
                value: '${solarVal.toStringAsFixed(0)} W/m²',
                color: Colors.orangeAccent,
                hint: '800 W/m² üzeri mükemmel güneş potansiyeli',
              ),
              _StatChip(
                icon: Icons.air_rounded,
                label: 'Rüzgar Hızı',
                value: '${windVal.toStringAsFixed(1)} m/s',
                color: Colors.blueAccent,
                hint: '7+ m/s ticari türbin eşiğidir',
              ),
              _StatChip(
                icon: Icons.thermostat_rounded,
                label: 'Sıcaklık',
                value: '${tempVal.toStringAsFixed(1)} °C',
                color: Colors.redAccent,
                hint: 'Aşırı sıcak iklim panel verimini düşürür',
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Finansal tahminler ───────────────────────────────────────────────
          _SectionTitle(
            title: 'Finansal Tahminler',
            subtitle: 'Puan bazlı yaklaşık değerler — proje fizibilite için referans',
          ),
          const SizedBox(height: 8),
          _RoiGrid(lcoe: lcoe, roi: roi, amort: amort, irr: irr),
          const SizedBox(height: 14),

          // ── Potansiyel radar ─────────────────────────────────────────────────
          _SectionTitle(
            title: 'Potansiyel Radar',
            subtitle: 'Her eksen 0–5 puan arası normalize edilmiş',
          ),
          const SizedBox(height: 8),
          _ProvinceRadarChart(province: p, score: score),
          const SizedBox(height: 14),

          // ── Haritada görüntüle ───────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  DefaultTabController.of(context).animateTo(4),
              icon: const Icon(Icons.map_outlined,
                  size: 16, color: Colors.cyanAccent),
              label: Text(
                '$displayName\'ı Haritada Görüntüle',
                style: const TextStyle(
                    color: Colors.cyanAccent, fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: Colors.cyanAccent.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Senaryo oluştur ──────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => ScenarioCreateDialog(theme: theme),
              ),
              icon: const Icon(Icons.add_chart_rounded, size: 16),
              label: Text(
                '$displayName için Senaryo Oluştur',
                style: const TextStyle(fontSize: 12),
              ),
              style: FilledButton.styleFrom(
                backgroundColor:
                    Colors.deepPurpleAccent.withValues(alpha: 0.18),
                foregroundColor: Colors.deepPurpleAccent,
                side: BorderSide(
                    color: Colors.deepPurpleAccent.withValues(alpha: 0.45)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Yardımcı Widgetlar ────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
        Text(subtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InfoBanner(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11,
                    height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  final String name;
  final String region;
  final double score;

  const _DetailHeader(
      {required this.name, required this.region, required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.cyanAccent.withValues(alpha: 0.08),
          Colors.blueAccent.withValues(alpha: 0.05),
        ]),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.cyanAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.place_outlined,
                      size: 11, color: Colors.white38),
                  const SizedBox(width: 3),
                  Text(region,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                ]),
              ],
            ),
          ),
          // Puan rozeti
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _scoreColor(score).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _scoreColor(score).withValues(alpha: 0.5)),
                ),
                child: Text(score.toStringAsFixed(0),
                    style: TextStyle(
                        color: _scoreColor(score),
                        fontSize: 22,
                        fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 4),
              Text(
                score >= 70
                    ? '⚡ Yüksek Potansiyel'
                    : score >= 45
                        ? '✓ Orta Potansiyel'
                        : '○ Düşük Potansiyel',
                style: TextStyle(
                    color: _scoreColor(score), fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String hint;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: hint,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      color: color.withValues(alpha: 0.8),
                      fontSize: 10)),
            ]),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _RoiGrid extends StatelessWidget {
  final double lcoe;
  final double roi;
  final double amort;
  final double irr;

  const _RoiGrid(
      {required this.lcoe,
      required this.roi,
      required this.amort,
      required this.irr});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 2.4,
      children: [
        _FinCard(
          label: 'LCOE',
          value: '${lcoe.toStringAsFixed(2)} ₺/kWh',
          icon: Icons.bolt_rounded,
          color: Colors.amberAccent,
          hint: 'Düzeltilmiş Enerji Maliyeti — '
              'üretilen her kWh için toplam ömür maliyeti',
        ),
        _FinCard(
          label: 'ROI',
          value: '%${roi.toStringAsFixed(0)}',
          icon: Icons.trending_up_rounded,
          color: Colors.greenAccent,
          hint: 'Yatırım Getirisi — proje ömrü boyunca '
              'toplam kâr / başlangıç yatırımı',
        ),
        _FinCard(
          label: 'Amortisman',
          value: '${amort.toStringAsFixed(1)} yıl',
          icon: Icons.timer_outlined,
          color: Colors.blueAccent,
          hint: 'Geri Ödeme Süresi — yatırımın kendini '
              'karşılaması için geçen tahmini süre',
        ),
        _FinCard(
          label: 'IRR',
          value: '%${irr.toStringAsFixed(0)}',
          icon: Icons.show_chart_rounded,
          color: Colors.purpleAccent,
          hint: 'İç Verimlilik Oranı — yatırımın yıllık '
              'getiri yüzdesi (>12% iyi kabul edilir)',
        ),
      ],
    );
  }
}

class _FinCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String hint;

  const _FinCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: hint,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: color.withValues(alpha: 0.7),
                          fontSize: 9,
                          fontWeight: FontWeight.w600)),
                  Text(value,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            Icon(Icons.info_outline_rounded,
                size: 11, color: Colors.white.withValues(alpha: 0.2)),
          ],
        ),
      ),
    );
  }
}

class _ProvinceRadarChart extends StatelessWidget {
  final ProvinceSummary province;
  final double score;

  const _ProvinceRadarChart(
      {required this.province, required this.score});

  @override
  Widget build(BuildContext context) {
    final solar =
        ((province.avgRadiation ?? 0) / 800).clamp(0.0, 1.0);
    final wind =
        ((province.avgWindSpeed ?? 0) / 10).clamp(0.0, 1.0);
    final temp =
        ((province.avgTemperature ?? 0 + 10) / 50).clamp(0.0, 1.0);
    final cost = (1.0 - score / 100).clamp(0.0, 1.0);
    final land = (score / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          // Açıklama satırı
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: const [
              _RadarLegend('Güneş', 'Işınım potansiyeli (max 800 W/m²)'),
              _RadarLegend('Rüzgar', 'Hız potansiyeli (max 10 m/s)'),
              _RadarLegend('HES', 'Su kaynağı skoru'),
              _RadarLegend('Maliyet Av.', 'Düşük LCOE (yüksek = avantajlı)'),
              _RadarLegend('Arazi', 'Genel kurulum skoru'),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            child: RadarChart(
              duration: Duration.zero,
              RadarChartData(
                dataSets: [
                  RadarDataSet(
                    fillColor: Colors.cyanAccent.withValues(alpha: 0.2),
                    borderColor: Colors.cyanAccent,
                    borderWidth: 2,
                    entryRadius: 3,
                    dataEntries: [
                      RadarEntry(value: solar * 5),
                      RadarEntry(value: wind * 5),
                      RadarEntry(value: temp * 5),
                      RadarEntry(value: cost * 5),
                      RadarEntry(value: land * 5),
                    ],
                  ),
                ],
                radarBackgroundColor: Colors.transparent,
                borderData: FlBorderData(show: false),
                radarBorderData:
                    const BorderSide(color: Colors.white12, width: 1),
                tickBorderData:
                    const BorderSide(color: Colors.white10, width: 0.5),
                gridBorderData:
                    const BorderSide(color: Colors.white12, width: 0.5),
                tickCount: 5,
                ticksTextStyle:
                    const TextStyle(color: Colors.transparent, fontSize: 0),
                getTitle: (index, angle) {
                  const labels = [
                    'Güneş', 'Rüzgar', 'HES', 'Maliyet Av.', 'Arazi'
                  ];
                  return RadarChartTitle(
                      text: labels[index], angle: angle);
                },
                titleTextStyle:
                    const TextStyle(color: Colors.white60, fontSize: 11),
                titlePositionPercentageOffset: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarLegend extends StatelessWidget {
  final String label;
  final String description;
  const _RadarLegend(this.label, this.description);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: description,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 9)),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

double _computeScore(ProvinceSummary p) {
  final solarScore =
      ((p.avgRadiation ?? 0) / 800 * 50).clamp(0.0, 50.0);
  final windScore =
      ((p.avgWindSpeed ?? 0) / 10 * 30).clamp(0.0, 30.0);
  final tempScore =
      ((p.avgTemperature ?? 15 - 20).abs() < 20 ? 20.0 : 10.0);
  return (solarScore + windScore + tempScore).clamp(0.0, 100.0);
}

Color _scoreColor(double score) {
  if (score >= 70) return Colors.greenAccent;
  if (score >= 45) return Colors.orangeAccent;
  return Colors.redAccent;
}
