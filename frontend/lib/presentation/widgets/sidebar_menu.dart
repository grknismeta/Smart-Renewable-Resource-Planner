import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/map_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../data/models/pin_model.dart';

// Yan menüdeki sekmeler
enum SidebarTab { data, scenarios, settings, about }

class SidebarMenu extends StatefulWidget {
  const SidebarMenu({super.key});

  @override
  State<SidebarMenu> createState() => _SidebarMenuState();
}

class _SidebarMenuState extends State<SidebarMenu> {
  bool _isCollapsed = false; 
  SidebarTab _selectedTab = SidebarTab.scenarios; 

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    
    final navBgColor = theme.isDarkMode ? const Color(0xFF151922) : Colors.grey[200];
    final panelBgColor = theme.isDarkMode ? const Color(0xFF1E232F) : Colors.white;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- 1. SOL NAVİGASYON RAIL (SABİT 70px) ---
        Container(
          width: 70,
          color: navBgColor,
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Menü Aç/Kapa Butonu
              IconButton(
                icon: Icon(_isCollapsed ? Icons.menu : Icons.menu_open, color: Colors.grey),
                onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
              ),
              const SizedBox(height: 20),
              
              // Logo
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text("SR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 30),

              // Navigasyon İkonları
              _buildNavItem(Icons.storage, "Veriler", SidebarTab.data),
              _buildNavItem(Icons.layers, "Senaryolar", SidebarTab.scenarios),
              
              const Spacer(),
              
              _buildNavItem(Icons.settings, "Ayarlar", SidebarTab.settings),
              _buildNavItem(Icons.info_outline, "Hakkında", SidebarTab.about),
              
              const SizedBox(height: 10),
              // Çıkış / Giriş Butonu (DİNAMİK)
              IconButton(
                icon: Icon(
                  authProvider.isLoggedIn == true ? Icons.logout : Icons.login,
                  color: authProvider.isLoggedIn == true ? Colors.redAccent : Colors.greenAccent,
                ),
                tooltip: authProvider.isLoggedIn == true ? "Çıkış Yap" : "Giriş Yap",
                onPressed: () {
                   if (authProvider.isLoggedIn == true) {
                     authProvider.logout();
                   } else {
                     // Misafir ise giriş ekranına git
                     Navigator.of(context).pushReplacementNamed('/auth');
                   }
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),

        // --- 2. GENİŞLEYEN İÇERİK PANELİ ---
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: _isCollapsed ? 0 : 320, 
          color: panelBgColor,
          curve: Curves.easeInOut,
          child: ClipRect(
            child: OverflowBox(
              minWidth: 320, maxWidth: 320,
              alignment: Alignment.topLeft,
              child: _buildPanelContent(theme),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem(IconData icon, String label, SidebarTab tab) {
    final bool isActive = _selectedTab == tab;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTab = tab;
            _isCollapsed = false; 
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: isActive ? BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ) : null,
          child: Column(
            children: [
              Icon(icon, color: isActive ? Colors.blueAccent : Colors.grey, size: 26),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 10, color: isActive ? Colors.blueAccent : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanelContent(ThemeProvider theme) {
    final mapProvider = Provider.of<MapProvider>(context);

    switch (_selectedTab) {
      case SidebarTab.scenarios:
        return _ScenariosPanel(theme: theme, mapProvider: mapProvider);
      case SidebarTab.data:
        return _DataPanel(theme: theme, mapProvider: mapProvider);
      case SidebarTab.settings:
        return _SettingsPanel(theme: theme);
      default:
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Bilgi", style: TextStyle(color: theme.textColor, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Text("Bu özellik yakında eklenecek.", style: TextStyle(color: theme.secondaryTextColor)),
            ],
          ),
        );
    }
  }
}

// --- 1. SENARYOLAR PANELİ ---
class _ScenariosPanel extends StatelessWidget {
  final ThemeProvider theme;
  final MapProvider mapProvider;

  const _ScenariosPanel({required this.theme, required this.mapProvider});

  @override
  Widget build(BuildContext context) {
    double totalMw = mapProvider.pins.fold(0, (sum, pin) => sum + pin.capacityMw);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Senaryolar", style: TextStyle(color: theme.textColor, fontSize: 20, fontWeight: FontWeight.bold)),
            Container(
              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
              child: IconButton(
                icon: const Icon(Icons.add, color: Colors.white, size: 20),
                onPressed: () { },
                constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF132F4C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.circle, color: Colors.cyanAccent, size: 10),
                const SizedBox(width: 8),
                const Text("Mevcut Durum", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 10),
              Text("${mapProvider.pins.length} kaynak", style: const TextStyle(color: Colors.blue, fontSize: 13)),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(text: "${totalMw.toStringAsFixed(1)} MW", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                    const TextSpan(text: " toplam kapasite", style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        Text("Kaydedilmiş Senaryolar", style: TextStyle(color: theme.secondaryTextColor, fontSize: 14)),
        const SizedBox(height: 10),

        _buildScenarioCard("Temel Senaryo", "İlk planlama senaryosu", "5 kaynak", "12.5 MW", "15.01.2024", theme),
        const SizedBox(height: 10),
        _buildScenarioCard("Yüksek Kapasite", "Maksimum enerji üretimi", "8 kaynak", "25.0 MW", "20.01.2024", theme),
      ],
    );
  }

  Widget _buildScenarioCard(String title, String subtitle, String count, String capacity, String date, ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: theme.secondaryTextColor, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(count, style: TextStyle(color: Colors.blueAccent, fontSize: 13)),
              Text(capacity, style: TextStyle(color: Colors.cyan, fontSize: 13, fontWeight: FontWeight.bold)),
              Text(date, style: TextStyle(color: theme.secondaryTextColor, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text("Yükle"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () {},
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}

// --- 2. VERİLER PANELİ ---
class _DataPanel extends StatelessWidget {
  final ThemeProvider theme;
  final MapProvider mapProvider;

  const _DataPanel({required this.theme, required this.mapProvider});

  @override
  Widget build(BuildContext context) {
    final windPins = mapProvider.pins.where((p) => p.type == 'Rüzgar Türbini').toList();
    final solarPins = mapProvider.pins.where((p) => p.type == 'Güneş Paneli').toList();
    
    final windMw = windPins.fold(0.0, (sum, p) => sum + p.capacityMw);
    final solarMw = solarPins.fold(0.0, (sum, p) => sum + p.capacityMw);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text("Kaynak Verileri", style: TextStyle(color: theme.textColor, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: _buildStatCard("Rüzgar", windPins.length.toString(), "${windMw.toStringAsFixed(1)} MW", Icons.wind_power, const Color(0xFF1B4D3E), const Color(0xFF4ADE80)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard("Güneş", solarPins.length.toString(), "${solarMw.toStringAsFixed(1)} MW", Icons.wb_sunny, const Color(0xFF4D3B1B), const Color(0xFFFACC15)),
            ),
          ],
        ),
        
        const SizedBox(height: 30),
        Text("Kaynaklar", style: TextStyle(color: theme.secondaryTextColor, fontSize: 16)),
        const SizedBox(height: 10),

        if (mapProvider.pins.isEmpty)
           Container(
             padding: const EdgeInsets.symmetric(vertical: 40),
             alignment: Alignment.center,
             child: Column(
               children: [
                 Text("Henüz kaynak eklenmedi", style: TextStyle(color: theme.textColor.withValues(alpha: 0.7), fontSize: 16)),
                 const SizedBox(height: 5),
                 Text("Haritadan kaynak ekleyin", style: TextStyle(color: theme.secondaryTextColor, fontSize: 12)),
               ],
             ),
           )
        else
          ...mapProvider.pins.map((pin) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              pin.type == 'Güneş Paneli' ? Icons.wb_sunny : Icons.wind_power,
              color: pin.type == 'Güneş Paneli' ? Colors.orange : Colors.blue,
            ),
            title: Text(pin.name, style: TextStyle(color: theme.textColor, fontSize: 14)),
            subtitle: Text("${pin.capacityMw} MW", style: TextStyle(color: theme.secondaryTextColor, fontSize: 12)),
            trailing: IconButton(
              icon: Icon(Icons.delete, color: theme.secondaryTextColor, size: 18),
              onPressed: () => mapProvider.deletePin(pin.id),
            ),
          )),
      ],
    );
  }

  Widget _buildStatCard(String title, String count, String capacity, IconData icon, Color bgColor, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          Text(count, style: TextStyle(color: iconColor, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(capacity, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

// --- 3. AYARLAR PANELİ ---
class _SettingsPanel extends StatelessWidget {
  final ThemeProvider theme;
  const _SettingsPanel({required this.theme});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text("Ayarlar", style: TextStyle(color: theme.textColor, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text("Karanlık Mod", style: TextStyle(color: theme.textColor)),
          trailing: Switch(
            value: theme.isDarkMode,
            onChanged: (val) => theme.toggleTheme(),
            activeColor: Colors.blueAccent,
          ),
        ),
      ],
    );
  }
}