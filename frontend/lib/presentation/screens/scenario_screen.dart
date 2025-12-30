import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../presentation/viewmodels/scenario_view_model.dart';
import '../../presentation/viewmodels/theme_view_model.dart';
import '../../presentation/viewmodels/map_view_model.dart';
import '../../data/models/scenario_model.dart';

class ScenarioScreen extends StatefulWidget {
  const ScenarioScreen({super.key});

  @override
  State<ScenarioScreen> createState() => _ScenarioScreenState();
}

class _ScenarioScreenState extends State<ScenarioScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final sp = Provider.of<ScenarioViewModel>(context, listen: false);
      sp.loadScenarios();
    });
  }

  void _showCreateDialog(
    BuildContext context,
    ThemeViewModel theme, {
    Scenario? scenarioToEdit,
  }) {
    final mapViewModel = Provider.of<MapViewModel>(context, listen: false);
    final scenarioViewModel = Provider.of<ScenarioViewModel>(
      context,
      listen: false,
    );

    // Kullanıcının pinleri
    final pins = mapViewModel.pins;

    if (pins.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce haritaya kaynak eklemelisiniz!')),
      );
      return;
    }

    final nameController = TextEditingController(text: scenarioToEdit?.name);
    final descController = TextEditingController(
      text: scenarioToEdit?.description,
    );
    List<int> selectedPinIds = [];
    if (scenarioToEdit != null) {
      selectedPinIds.addAll(scenarioToEdit.pinIds);
    }

    DateTime? startDate =
        scenarioToEdit?.startDate ??
        DateTime.now().add(const Duration(days: -365));
    DateTime? endDate = scenarioToEdit?.endDate ?? DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(ctx).size.width * 0.9, // Explicit width
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  scenarioToEdit != null
                      ? 'Senaryoyu Düzenle'
                      : 'Yeni Senaryo Oluştur',
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          style: TextStyle(color: theme.textColor),
                          decoration: InputDecoration(
                            labelText: 'Senaryo Adı',
                            labelStyle: TextStyle(
                              color: theme.secondaryTextColor,
                            ),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: theme.secondaryTextColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: descController,
                          style: TextStyle(color: theme.textColor),
                          decoration: InputDecoration(
                            labelText: 'Açıklama (Opsiyonel)',
                            labelStyle: TextStyle(
                              color: theme.secondaryTextColor,
                            ),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: theme.secondaryTextColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Kaynakları Seç (Birden fazla seçilebilir)',
                            style: TextStyle(
                              color: theme.secondaryTextColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 200, // Fixed height safe zone
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.secondaryTextColor.withOpacity(0.3),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: pins.isEmpty
                              ? Center(
                                  child: Text(
                                    "Pin yok",
                                    style: TextStyle(
                                      color: theme.secondaryTextColor,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: EdgeInsets.zero,
                                  itemCount: pins.length,
                                  itemBuilder: (ctx, i) {
                                    final pin = pins[i];
                                    final isSelected = selectedPinIds.contains(
                                      pin.id,
                                    );
                                    return CheckboxListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 0,
                                          ),
                                      dense: true,
                                      title: Text(
                                        '${pin.name} (${pin.equipmentName ?? pin.type})',
                                        style: TextStyle(
                                          color: theme.textColor,
                                          fontSize: 13,
                                        ),
                                      ),
                                      value: isSelected,
                                      activeColor: Colors.blueAccent,
                                      checkColor: Colors.white,
                                      onChanged: (val) {
                                        setDialogState(() {
                                          if (val == true) {
                                            selectedPinIds.add(pin.id);
                                          } else {
                                            selectedPinIds.remove(pin.id);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Başlangıç Tarihi',
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            startDate != null
                                ? '${startDate!.day}/${startDate!.month}/${startDate!.year}'
                                : 'Tarihi seçin',
                            style: TextStyle(
                              color: theme.secondaryTextColor,
                              fontSize: 14,
                            ),
                          ),
                          trailing: Icon(
                            Icons.calendar_today,
                            color: theme.textColor,
                            size: 20,
                          ),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: startDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setDialogState(() => startDate = picked);
                            }
                          },
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Bitiş Tarihi',
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            endDate != null
                                ? '${endDate!.day}/${endDate!.month}/${endDate!.year}'
                                : 'Tarihi seçin',
                            style: TextStyle(
                              color: theme.secondaryTextColor,
                              fontSize: 14,
                            ),
                          ),
                          trailing: Icon(
                            Icons.calendar_today,
                            color: theme.textColor,
                            size: 20,
                          ),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: endDate ?? DateTime.now(),
                              firstDate: startDate ?? DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setDialogState(() => endDate = picked);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'İptal',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        if (nameController.text.isEmpty ||
                            selectedPinIds.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Lütfen isim girin ve en az bir kaynak seçin!',
                              ),
                            ),
                          );
                          return;
                        }

                        final scenarioCreate = ScenarioCreate(
                          name: nameController.text,
                          description: descController.text.isEmpty
                              ? null
                              : descController.text,
                          pinIds: selectedPinIds,
                          startDate: startDate,
                          endDate: endDate,
                        );

                        try {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                scenarioToEdit != null
                                    ? 'Senaryo güncelleniyor...'
                                    : 'Senaryo oluşturuluyor...',
                              ),
                            ),
                          );

                          if (scenarioToEdit != null) {
                            await scenarioViewModel.updateScenario(
                              scenarioToEdit.id,
                              scenarioCreate,
                            );
                          } else {
                            await scenarioViewModel.createScenario(
                              scenarioCreate,
                            );
                          }

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  scenarioToEdit != null
                                      ? 'Senaryo güncellendi!'
                                      : 'Senaryo başarıyla oluşturuldu!',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('Hata: $e')));
                          }
                        }
                      },
                      child: Text(
                        scenarioToEdit != null ? 'Güncelle' : 'Oluştur',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showScenarioDetail(Scenario scenario, ThemeViewModel theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                scenario.name,
                style: TextStyle(color: theme.textColor),
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit, color: theme.secondaryTextColor),
              onPressed: () {
                Navigator.pop(ctx);
                _showCreateDialog(context, theme, scenarioToEdit: scenario);
              },
              tooltip: "Düzenle",
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (scenario.description != null) ...[
                Text(
                  scenario.description!,
                  style: TextStyle(color: theme.secondaryTextColor),
                ),
                const SizedBox(height: 16),
              ],
              if (scenario.startDate != null)
                _InfoRow(
                  'Başlangıç',
                  '${scenario.startDate!.day}/${scenario.startDate!.month}/${scenario.startDate!.year}',
                  theme,
                ),
              if (scenario.endDate != null)
                _InfoRow(
                  'Bitiş',
                  '${scenario.endDate!.day}/${scenario.endDate!.month}/${scenario.endDate!.year}',
                  theme,
                ),
              _InfoRow('Pin Sayısı', '${scenario.pinIds.length}', theme),
              if (scenario.pinIds.isNotEmpty)
                _InfoRow('Pin IDler', scenario.pinIds.join(', '), theme),
              const SizedBox(height: 16),
              if (scenario.resultData != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Senaryo Özeti:',
                  style: TextStyle(
                    color: theme.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                _buildResultSummary(scenario.resultData!, theme),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat'),
          ),
          if (scenario.startDate != null && scenario.endDate != null)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final sp = Provider.of<ScenarioViewModel>(
                    context,
                    listen: false,
                  );
                  await sp.calculateScenario(scenario.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Senaryo hesaplandı!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Hesaplama hatası: $e')),
                    );
                  }
                }
              },
              child: const Text(
                'Hesapla',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushReplacementNamed('/reports');
            },
            child: const Text('Rapora Git'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeViewModel = Provider.of<ThemeViewModel>(context);
    final scenarioViewModel = Provider.of<ScenarioViewModel>(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0E1621), Color(0xFF111827), Color(0xFF0B1220)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(themeViewModel),
              Expanded(
                child: scenarioViewModel.isBusy
                    ? const Center(child: CircularProgressIndicator())
                    : scenarioViewModel.scenarios.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.science_outlined,
                              size: 80,
                              color: themeViewModel.secondaryTextColor
                                  .withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Henüz senaryo yok',
                              style: TextStyle(
                                color: themeViewModel.secondaryTextColor,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Yeni bir senaryo oluşturmak için + tuşuna basın',
                              style: TextStyle(
                                color: themeViewModel.secondaryTextColor
                                    .withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: scenarioViewModel.scenarios.length,
                        itemBuilder: (context, index) {
                          final scenario = scenarioViewModel.scenarios[index];
                          return _buildScenarioCard(scenario, themeViewModel);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        onPressed: () => _showCreateDialog(context, themeViewModel),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader(ThemeViewModel theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pushReplacementNamed('/map'),
            icon: const Icon(Icons.arrow_back),
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Text(
            'Senaryolar',
            style: TextStyle(
              color: theme.textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioCard(Scenario scenario, ThemeViewModel theme) {
    final duration = scenario.startDate != null && scenario.endDate != null
        ? scenario.endDate!.difference(scenario.startDate!).inDays
        : 0;

    return GestureDetector(
      onTap: () => _showScenarioDetail(scenario, theme),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.bar_chart,
                      color: Colors.blueAccent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scenario.name,
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (scenario.description != null)
                          Text(
                            scenario.description!,
                            style: TextStyle(
                              color: theme.secondaryTextColor,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 8),
                        Text(
                          duration > 0
                              ? '$duration gün · ${scenario.pinIds.length} kaynak'
                              : '${scenario.pinIds.length} kaynak',
                          style: TextStyle(
                            color: theme.secondaryTextColor.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: theme.secondaryTextColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatEnergy(double kwh) {
    if (kwh >= 1000000) {
      return '${(kwh / 1000000).toStringAsFixed(2)} GWh';
    } else if (kwh >= 1000) {
      return '${(kwh / 1000).toStringAsFixed(2)} MWh';
    } else {
      return '${kwh.toStringAsFixed(2)} kWh';
    }
  }

  Widget _buildResultSummary(Map<String, dynamic> data, ThemeViewModel theme) {
    final double totalSolar = (data['total_solar_kwh'] ?? 0).toDouble();
    final double totalWind = (data['total_wind_kwh'] ?? 0).toDouble();
    final double totalEnergy = (data['total_kwh'] ?? 0).toDouble();
    final int solarCount = (data['solar_count'] ?? 0).toInt();
    final int windCount = (data['wind_count'] ?? 0).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.secondaryTextColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildEnergyCard(
                  'Toplam Üretim',
                  _formatEnergy(totalEnergy),
                  Icons.flash_on,
                  Colors.amber,
                  theme,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildEnergyCard(
                  'Güneş ($solarCount)',
                  _formatEnergy(totalSolar),
                  Icons.wb_sunny,
                  Colors.orangeAccent,
                  theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEnergyCard(
                  'Rüzgar ($windCount)',
                  _formatEnergy(totalWind),
                  Icons.air,
                  Colors.lightBlueAccent,
                  theme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnergyCard(
    String title,
    String value,
    IconData icon,
    Color color,
    ThemeViewModel theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: theme.secondaryTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _InfoRow(String label, String value, ThemeViewModel theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: theme.secondaryTextColor, fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
