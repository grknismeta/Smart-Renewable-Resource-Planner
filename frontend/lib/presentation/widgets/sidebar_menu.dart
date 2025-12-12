import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/map_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart'; 

class SidebarMenu extends StatefulWidget {
  const SidebarMenu({super.key});

  @override
  State<SidebarMenu> createState() => _SidebarMenuState();
}

class _SidebarMenuState extends State<SidebarMenu> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    // Genişlik geçiş animasyonu: Dar iken 70, açıkken 280
    final double currentWidth = _isCollapsed ? 70.0 : 280.0;
    
    final theme = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final bool isGuest = authProvider.isLoggedIn != true; 

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: currentWidth,
      color: theme.backgroundColor,
      curve: Curves.easeInOut,
      child: Column(
        children: [
          // --- HEADER (LOGO & MENU BUTONU) ---
          Container(
            height: 70,
            padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 0 : 10),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.secondaryTextColor.withValues(alpha: 0.1)))),
            child: _isCollapsed
                ? Center(
                    child: IconButton(
                      icon: Icon(Icons.menu, color: theme.secondaryTextColor),
                      onPressed: () => setState(() => _isCollapsed = false),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const SizedBox(width: 6),
                            const Icon(Icons.eco, color: Colors.greenAccent),
                            const SizedBox(width: 10),
                            Flexible(child: Text("SRRP", style: TextStyle(color: theme.textColor, fontSize: 20, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 1)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.chevron_left, color: theme.secondaryTextColor), 
                        onPressed: () => setState(() => _isCollapsed = true)
                      ),
                    ],
                  ),
          ),

          // --- LİSTE İÇERİĞİ ---
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(_isCollapsed ? 8 : 12),
              children: [
                 // --- SENARYOLAR BÖLÜMÜ ---
                 if (!_isCollapsed) ...[
                   _buildSectionTitle("Kaydedilmiş Senaryolar", color: theme.textColor),
                   const SizedBox(height: 10),
                 ],

                 if (_isCollapsed)
                    // Dar modda senaryo kartları yerine temsili bir ikon
                    Column(
                      children: [
                        const SizedBox(height: 10),
                        Tooltip(
                          message: "Senaryolar",
                          child: Icon(Icons.folder_copy_outlined, color: theme.secondaryTextColor.withValues(alpha: 0.5)),
                        ),
                        const SizedBox(height: 20),
                        Divider(color: theme.secondaryTextColor.withValues(alpha: 0.1), indent: 5, endIndent: 5),
                      ],
                    )
                 else if (isGuest)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: theme.cardColor.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.withValues(alpha: 0.3))),
                      child: Row(children: [const Icon(Icons.lock_outline, color: Colors.orange, size: 20), const SizedBox(width: 10), Expanded(child: Text("Senaryoları kaydetmek için giriş yapmalısınız.", style: TextStyle(color: theme.secondaryTextColor, fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 2))]),
                    )
                 else ...[
                   _buildScenarioCard(title: "Temel Senaryo", description: "5 Kaynak - 12.5 MW", date: "15.01.2024", cardColor: theme.cardColor, textColor: theme.textColor, secondaryColor: theme.secondaryTextColor),
                   const SizedBox(height: 10),
                   _buildScenarioCard(title: "Yüksek Kapasite", description: "8 Kaynak - 25.0 MW", date: "20.01.2024", cardColor: theme.cardColor, textColor: theme.textColor, secondaryColor: theme.secondaryTextColor),
                 ],
                 
                 SizedBox(height: _isCollapsed ? 10 : 20),
                 
                 // --- VERİLER PANELİ ---
                 _DataPanel(theme: theme, mapProvider: Provider.of<MapProvider>(context), isCollapsed: _isCollapsed),
              ],
            ),
          ),

          // --- FOOTER (TEMA & AYARLAR) ---
          Container(
             padding: const EdgeInsets.symmetric(vertical: 10),
             decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.secondaryTextColor.withValues(alpha: 0.1)))),
             child: Column(
               children: [
                  InkWell(
                    onTap: theme.toggleTheme,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 0 : 16, vertical: 12),
                      child: _isCollapsed
                        ? Icon(theme.isDarkMode ? Icons.dark_mode : Icons.light_mode, color: theme.secondaryTextColor, size: 22)
                        : Row(
                            children: [
                              Icon(theme.isDarkMode ? Icons.dark_mode : Icons.light_mode, color: theme.secondaryTextColor, size: 22),
                              const SizedBox(width: 16),
                              Expanded(child: Text(theme.isDarkMode ? "Karanlık Mod" : "Aydınlık Mod", style: TextStyle(color: theme.secondaryTextColor, fontSize: 14), overflow: TextOverflow.ellipsis, maxLines: 1)),
                              SizedBox(height: 24, child: Transform.scale(scale: 0.7, child: Switch(value: theme.isDarkMode, onChanged: (val) => theme.toggleTheme(), activeColor: Colors.blueAccent))),
                            ],
                          ),
                    ),
                  ),

                 if (_isCollapsed)
                    IconButton(icon: Icon(Icons.help_outline, color: theme.secondaryTextColor), onPressed: () {})
                 else
                    ListTile(dense: true, leading: Icon(Icons.help_outline, color: theme.secondaryTextColor, size: 22), title: Text("Yardım", style: TextStyle(color: theme.secondaryTextColor), overflow: TextOverflow.ellipsis), onTap: () {}),
                 
                 if (_isCollapsed)
                    IconButton(
                      icon: Icon(isGuest ? Icons.person_add : Icons.logout, color: isGuest ? Colors.greenAccent : Colors.redAccent),
                      onPressed: () { if (isGuest) { Navigator.of(context).pushReplacementNamed('/auth'); } else { authProvider.logout(); } }
                    )
                 else
                    ListTile(
                       dense: true,
                       leading: Icon(isGuest ? Icons.person_add : Icons.logout, color: isGuest ? Colors.greenAccent : Colors.redAccent, size: 22),
                       title: Text(isGuest ? "Kayıt Ol" : "Çıkış Yap", style: TextStyle(color: isGuest ? Colors.greenAccent : Colors.redAccent, fontWeight: isGuest ? FontWeight.bold : FontWeight.normal), overflow: TextOverflow.ellipsis),
                       onTap: () { if (isGuest) { Navigator.of(context).pushReplacementNamed('/auth'); } else { authProvider.logout(); } },
                     ),
               ],
             ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {required Color color}) { return Text(title, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis, maxLines: 1); }
  
  Widget _buildScenarioCard({required String title, required String description, required String date, required Color cardColor, required Color textColor, required Color secondaryColor}) { 
    return Container(
      padding: const EdgeInsets.all(12), 
      decoration: BoxDecoration(
        color: cardColor, 
        borderRadius: BorderRadius.circular(10), 
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
      ), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 1), 
          const SizedBox(height: 4), 
          Text(description, style: TextStyle(color: secondaryColor, fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 2), 
          const SizedBox(height: 12), 
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              Flexible(child: Text(date, style: TextStyle(color: secondaryColor.withValues(alpha: 0.5), fontSize: 10), overflow: TextOverflow.ellipsis)), 
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), 
                decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(20)), 
                child: const Text("Yükle", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))
              )
            ]
          )
        ]
      )
    ); 
  }
}

class _DataPanel extends StatelessWidget {
  final ThemeProvider theme;
  final MapProvider mapProvider;
  final bool isCollapsed;

  const _DataPanel({required this.theme, required this.mapProvider, required this.isCollapsed});

  @override
  Widget build(BuildContext context) {
    final windPins = mapProvider.pins.where((p) => p.type.contains('Rüzgar') || p.type.contains('Wind')).toList();
    final solarPins = mapProvider.pins.where((p) => p.type.contains('Güneş') || p.type.contains('Solar')).toList();
    
    final windMw = windPins.fold(0.0, (sum, p) => sum + p.capacityMw);
    final solarMw = solarPins.fold(0.0, (sum, p) => sum + p.capacityMw);

    final windBgColor = const Color(0xFF1F3A58); 
    final windFgColor = const Color(0xFF2196F3); 
    final solarBgColor = const Color(0xFF413819); 
    final solarFgColor = const Color(0xFFFFCA28); 

    if (isCollapsed) {
      // Dar modda sadece ikonlar
      return Column(
        children: [
          _buildCollapsedStatIcon(Icons.air, windFgColor, windPins.length),
          const SizedBox(height: 12),
          _buildCollapsedStatIcon(Icons.wb_sunny, solarFgColor, solarPins.length),
          const SizedBox(height: 20),
          Divider(color: theme.secondaryTextColor.withValues(alpha: 0.1), indent: 5, endIndent: 5),
          const SizedBox(height: 10),
          // Sadece eklenen kaynakların küçük noktaları
           ...mapProvider.pins.take(5).map((pin) {
             bool isSolar = pin.type.contains('Güneş') || pin.type.contains('Solar');
             return Padding(
               padding: const EdgeInsets.symmetric(vertical: 4),
               child: Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: isSolar ? solarFgColor : windFgColor,
                    shape: BoxShape.circle,
                  ),
               ),
             );
           }),
           if(mapProvider.pins.length > 5) 
             Padding(padding: const EdgeInsets.only(top:4), child: Icon(Icons.more_horiz, size: 12, color: theme.secondaryTextColor))
        ],
      );
    }

    // Açık modda tam görünüm
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Kaynak Verileri", style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(child: _buildStatCard("Rüzgar", windPins.length.toString(), "${windMw.toStringAsFixed(1)} MW", Icons.air, windBgColor, windFgColor)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard("Güneş", solarPins.length.toString(), "${solarMw.toStringAsFixed(1)} MW", Icons.wb_sunny, solarBgColor, solarFgColor)),
          ],
        ),
        
        const SizedBox(height: 20),
        Text("Kaynaklar", style: TextStyle(color: theme.secondaryTextColor, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),

        if (mapProvider.pins.isEmpty)
           Container(
             padding: const EdgeInsets.symmetric(vertical: 20), 
             alignment: Alignment.center, 
             child: Column(
               children: [
                 Icon(Icons.add_location_alt_outlined, size: 30, color: theme.secondaryTextColor.withValues(alpha: 0.3)),
                 const SizedBox(height: 5),
                 Text("Henüz kaynak eklenmedi", style: TextStyle(color: theme.textColor.withValues(alpha: 0.7), fontSize: 13)), 
               ]
             )
           )
        else
          ...mapProvider.pins.map((pin) {
            bool isSolar = pin.type.contains('Güneş') || pin.type.contains('Solar');
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSolar ? solarBgColor : windBgColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: isSolar ? solarFgColor : windFgColor, width: 1.5)
                ),
                child: Icon(isSolar ? Icons.wb_sunny : Icons.air, color: isSolar ? solarFgColor : windFgColor, size: 14),
              ),
              title: Text(pin.name, style: TextStyle(color: theme.textColor, fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: Text("${pin.capacityMw} MW", style: TextStyle(color: theme.secondaryTextColor, fontSize: 12)),
              trailing: IconButton(icon: Icon(Icons.delete_outline, color: theme.secondaryTextColor.withValues(alpha: 0.7), size: 20), onPressed: () => mapProvider.deletePin(pin.id)),
                        ),
            );
        }),
      ],
    );
  }

  Widget _buildCollapsedStatIcon(IconData icon, Color color, int count) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5)
      ),
      child: Text(count.toString(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildStatCard(String title, String count, String capacity, IconData icon, Color bgColor, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor, 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: iconColor.withValues(alpha: 0.3)) 
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18), 
              const SizedBox(width: 8), 
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))
            ]
          ),
          const SizedBox(height: 12),
          Text(count, style: TextStyle(color: iconColor, fontSize: 22, fontWeight: FontWeight.bold)), 
          const SizedBox(height: 2),
          Text(capacity, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}