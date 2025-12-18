import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/scenario_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/map_provider.dart';
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
      final sp = Provider.of<ScenarioProvider>(context, listen: false);
      sp.loadScenarios();
    });
  }

  void _showCreateDialog(BuildContext context, ThemeProvider theme) {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    final scenarioProvider = Provider.of<ScenarioProvider>(
      context,
      listen: false,
    );

    // Kullanıcının pinleri
    final pins = mapProvider.pins;
    if (pins.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce haritaya kaynak eklemelisiniz!')),
      );
      return;
    }

    final nameController = TextEditingController();
    final descController = TextEditingController();
    List<int> selectedPinIds = []; // Birden fazla pin seçilebilir
    DateTime? startDate = DateTime.now().add(const Duration(days: -365));
    DateTime? endDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: theme.cardColor,
          title: Text(
            'Yeni Senaryo Oluştur',
            style: TextStyle(color: theme.textColor),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: TextStyle(color: theme.textColor),
                  decoration: InputDecoration(
                    labelText: 'Senaryo Adı',
                    labelStyle: TextStyle(color: theme.secondaryTextColor),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: theme.secondaryTextColor),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descController,
                  style: TextStyle(color: theme.textColor),
                  decoration: InputDecoration(
                    labelText: 'Açıklama (Opsiyonel)',
                    labelStyle: TextStyle(color: theme.secondaryTextColor),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: theme.secondaryTextColor),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Kaynakları Seç (Birden fazla seçilebilir)',
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.secondaryTextColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: pins.length,
                      itemBuilder: (ctx, i) {
                        final pin = pins[i];
                        final isSelected = selectedPinIds.contains(pin.id);
                        return CheckboxListTile(
                          title: Text(
                            '${pin.name} (${pin.type})',
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: 13,
                            ),
                          ),
                          value: isSelected,
                          activeColor: Colors.blueAccent,
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                selectedPinIds.add(pin.id!);
                              } else {
                                selectedPinIds.remove(pin.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(
                    'Başlangıç Tarihi',
                    style: TextStyle(color: theme.textColor, fontSize: 14),
                  ),
                  subtitle: Text(
                    startDate != null
                        ? '${startDate!.day}/${startDate!.month}/${startDate!.year}'
                        : 'Tarihi seçin',
                    style: TextStyle(color: theme.secondaryTextColor),
                  ),
                  trailing: Icon(Icons.calendar_today, color: theme.textColor),
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
                  title: Text(
                    'Bitiş Tarihi',
                    style: TextStyle(color: theme.textColor, fontSize: 14),
                  ),
                  subtitle: Text(
                    endDate != null
                        ? '${endDate!.day}/${endDate!.month}/${endDate!.year}'
                        : 'Tarihi seçin',
                    style: TextStyle(color: theme.secondaryTextColor),
                  ),
                  trailing: Icon(Icons.calendar_today, color: theme.textColor),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'İptal',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              onPressed: () async {
                if (nameController.text.isEmpty || selectedPinIds.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('En az bir kaynak seçmelisiniz!'),
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
                  await scenarioProvider.createScenario(scenarioCreate);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Senaryo oluşturuluyor...')),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text('Hata: $e')));
                  }
                }
              },
              child: const Text(
                'Oluştur',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showScenarioDetail(Scenario scenario, ThemeProvider theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text(scenario.name, style: TextStyle(color: theme.textColor)),
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
                Text(
                  'Sonuçlar:',
                  style: TextStyle(
                    color: theme.textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    scenario.resultData.toString(),
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 12,
                    ),
                    maxLines: 10,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
                  final sp = Provider.of<ScenarioProvider>(
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
    final theme = Provider.of<ThemeProvider>(context);
    final scenarioProvider = Provider.of<ScenarioProvider>(context);

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
              _buildHeader(theme),
              Expanded(
                child: scenarioProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : scenarioProvider.scenarios.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.science_outlined,
                              size: 80,
                              color: theme.secondaryTextColor.withValues(
                                alpha: 0.3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Henüz senaryo yok',
                              style: TextStyle(
                                color: theme.secondaryTextColor,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Yeni bir senaryo oluşturmak için + tuşuna basın',
                              style: TextStyle(
                                color: theme.secondaryTextColor.withValues(
                                  alpha: 0.7,
                                ),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: scenarioProvider.scenarios.length,
                        itemBuilder: (context, index) {
                          final scenario = scenarioProvider.scenarios[index];
                          return _buildScenarioCard(scenario, theme);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        onPressed: () => _showCreateDialog(context, theme),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader(ThemeProvider theme) {
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

  Widget _buildScenarioCard(Scenario scenario, ThemeProvider theme) {
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
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.2),
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
                            color: theme.secondaryTextColor.withValues(
                              alpha: 0.7,
                            ),
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

  Widget _InfoRow(String label, String value, ThemeProvider theme) {
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
