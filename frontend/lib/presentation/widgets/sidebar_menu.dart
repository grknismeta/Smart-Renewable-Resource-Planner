import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/map_provider.dart';

class SidebarMenu extends StatefulWidget {
  const SidebarMenu({super.key});

  @override
  State<SidebarMenu> createState() => _SidebarMenuState();
}

class _SidebarMenuState extends State<SidebarMenu> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    // Panel Genişliği: Kapalıysa 70px, Açıksa 280px
    final width = _isCollapsed ? 70.0 : 280.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: width,
      color: const Color(0xFF1E232F), // Koyu Dashboard Arkaplanı
      child: Column(
        children: [
          // --- LOGO / BAŞLIK ALANI ---
          Container(
            height: 60,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: const Color(0xFF151922),
            child: Row(
              mainAxisAlignment: _isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.spaceBetween,
              children: [
                if (!_isCollapsed)
                  const Text(
                    "SRRP Planner",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                IconButton(
                  icon: Icon(
                    _isCollapsed ? Icons.menu : Icons.chevron_left,
                    color: Colors.white70,
                  ),
                  onPressed: () {
                    setState(() => _isCollapsed = !_isCollapsed);
                  },
                ),
              ],
            ),
          ),

          // --- İÇERİK (Sadece açıksa görünür veya ikon görünür) ---
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(10),
              children: [
                // 1. DASHBOARD WIDGET: Total Output
                _buildDashboardCard(
                  title: "Toplam Üretim",
                  value: "1,240 MW",
                  icon: Icons.bolt,
                  color: Colors.amber,
                  isCollapsed: _isCollapsed,
                ),
                const SizedBox(height: 10),
                _buildDashboardCard(
                  title: "Aktif Kaynak",
                  value: "12 Adet",
                  icon: Icons.grid_view,
                  color: Colors.blue,
                  isCollapsed: _isCollapsed,
                ),
                
                const Divider(color: Colors.white24, height: 30),

                // 2. MENÜ İKONLARI
                _buildMenuItem(
                  icon: Icons.map,
                  text: "Harita Görünümü",
                  isActive: true,
                  isCollapsed: _isCollapsed,
                ),
                _buildMenuItem(
                  icon: Icons.bar_chart,
                  text: "Analizler",
                  isActive: false,
                  isCollapsed: _isCollapsed,
                ),
                _buildMenuItem(
                  icon: Icons.settings,
                  text: "Ayarlar",
                  isActive: false,
                  isCollapsed: _isCollapsed,
                ),
                
                const Divider(color: Colors.white24, height: 30),
                
                // 3. HIZLI EKLEME (Sidebar içine almak isterseniz)
                 if (!_isCollapsed) ...[
                   const Text("Hızlı Ekle", style: TextStyle(color: Colors.white54, fontSize: 12)),
                   const SizedBox(height: 10),
                   _buildAddButton(context, "Güneş Paneli", Icons.solar_power, Colors.orange),
                   const SizedBox(height: 8),
                   _buildAddButton(context, "Rüzgar Türbini", Icons.wind_power, Colors.blue),
                 ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isCollapsed,
  }) {
    if (isCollapsed) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
           color: const Color(0xFF2A3040),
           borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      );
    }
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 5)
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String text,
    required bool isActive,
    required bool isCollapsed,
  }) {
    final color = isActive ? Colors.blueAccent : Colors.white70;
    
    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Icon(icon, color: color),
      );
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      decoration: isActive
          ? BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(text, style: TextStyle(color: color)),
        onTap: () {},
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, String label, IconData icon, Color color) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        foregroundColor: color,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
      ),
      icon: Icon(icon),
      label: Text(label),
      onPressed: () {
         final mapProvider = Provider.of<MapProvider>(context, listen: false);
         mapProvider.startPlacingMarker(label);
      },
    );
  }
}