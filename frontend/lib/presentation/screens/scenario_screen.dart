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
    int? selectedPinId = pins.first.id;
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 365));

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
                DropdownButtonFormField<int>(
                  value: selectedPinId,
                  dropdownColor: theme.cardColor,
                  decoration: InputDecoration(
                    labelText: 'Kaynak Seç',
                    labelStyle: TextStyle(color: theme.secondaryTextColor),
                  ),
                  items: pins.map((pin) {
                    return DropdownMenuItem(
                      value: pin.id,
                      child: Text(
                        '${pin.name} (${pin.type})',
                        style: TextStyle(color: theme.textColor),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedPinId = val),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(
                    'Başlangıç Tarihi',
                    style: TextStyle(color: theme.textColor, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${startDate.day}/${startDate.month}/${startDate.year}',
                    style: TextStyle(color: theme.secondaryTextColor),
                  ),
                  trailing: Icon(Icons.calendar_today, color: theme.textColor),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: startDate,
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
                    '${endDate.day}/${endDate.month}/${endDate.year}',
                    style: TextStyle(color: theme.secondaryTextColor),
                  ),
                  trailing: Icon(Icons.calendar_today, color: theme.textColor),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: endDate,
                      firstDate: startDate,
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
                if (nameController.text.isEmpty || selectedPinId == null) {
                  return;
                }

                final scenarioCreate = ScenarioCreate(
                  name: nameController.text,
                  description: descController.text.isEmpty
                      ? null
                      : descController.text,
                  pinId: selectedPinId!,
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
              _InfoRow(
                'Başlangıç',
                '${scenario.startDate.day}/${scenario.startDate.month}/${scenario.startDate.year}',
                theme,
              ),
              _InfoRow(
                'Bitiş',
                '${scenario.endDate.day}/${scenario.endDate.month}/${scenario.endDate.year}',
                theme,
              ),
              _InfoRow('Pin ID', '${scenario.pinId}', theme),
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
                    color: Colors.black.withOpacity(0.2),
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
                              color: theme.secondaryTextColor.withOpacity(0.3),
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
                                color: theme.secondaryTextColor.withOpacity(
                                  0.7,
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
    final duration = scenario.endDate.difference(scenario.startDate).inDays;

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
                          '$duration gün · Pin #${scenario.pinId}',
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
