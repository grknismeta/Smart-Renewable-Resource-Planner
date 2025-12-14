import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class ScenarioScreen extends StatefulWidget {
  const ScenarioScreen({super.key});

  @override
  State<ScenarioScreen> createState() => _ScenarioScreenState();
}

class _ScenarioScreenState extends State<ScenarioScreen> {
  // Örnek başlangıç verileri
  final List<Map<String, String>> _scenarios = [
    {
      "title": "Temel Senaryo",
      "description": "5 Kaynak - 12.5 MW",
      "date": "15.01.2024",
    },
    {
      "title": "Yüksek Kapasite",
      "description": "8 Kaynak - 25.0 MW",
      "date": "20.01.2024",
    },
  ];

  void _addScenario(String title, String desc) {
    setState(() {
      _scenarios.insert(0, {
        "title": title,
        "description": desc,
        "date": "${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}",
      });
    });
  }

  void _deleteScenario(int index) {
    setState(() {
      _scenarios.removeAt(index);
    });
  }

  void _showAddDialog(BuildContext context, ThemeProvider theme) {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text("Yeni Senaryo", style: TextStyle(color: theme.textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: TextStyle(color: theme.textColor),
              decoration: InputDecoration(
                labelText: "Senaryo Adı",
                labelStyle: TextStyle(color: theme.secondaryTextColor),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.secondaryTextColor)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descController,
              style: TextStyle(color: theme.textColor),
              decoration: InputDecoration(
                labelText: "Açıklama (Örn: 5 Kaynak)",
                labelStyle: TextStyle(color: theme.secondaryTextColor),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.secondaryTextColor)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal", style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                _addScenario(titleController.text, descController.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text("Ekle", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.backgroundColor,
        elevation: 0,
        title: Text("Senaryo Yönetimi", style: TextStyle(color: theme.textColor)),
        iconTheme: IconThemeData(color: theme.textColor),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        onPressed: () => _showAddDialog(context, theme),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _scenarios.isEmpty
          ? Center(
              child: Text(
                "Henüz kaydedilmiş bir senaryo yok.",
                style: TextStyle(color: theme.secondaryTextColor),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _scenarios.length,
              itemBuilder: (context, index) {
                final scenario = _scenarios[index];
                return Dismissible(
                  key: Key(UniqueKey().toString()),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) => _deleteScenario(index),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.redAccent,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.bar_chart, color: Colors.blueAccent),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(scenario['title']!, style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(scenario['description']!, style: TextStyle(color: theme.secondaryTextColor, fontSize: 13)),
                              const SizedBox(height: 8),
                              Text(scenario['date']!, style: TextStyle(color: theme.secondaryTextColor.withOpacity(0.5), fontSize: 11)),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            IconButton(
                              icon: Icon(Icons.play_circle_fill, color: Colors.greenAccent, size: 30),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("${scenario['title']} yüklendi!")),
                                );
                              },
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}