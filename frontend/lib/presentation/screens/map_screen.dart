import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart'; 
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../providers/map_provider.dart';
import '../../providers/theme_provider.dart'; 
import '../../data/models/pin_model.dart'; 
import '../widgets/sidebar_menu.dart'; 

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  final LatLngBounds turkeyBounds = LatLngBounds(const LatLng(34.0, 24.0), const LatLng(44.0, 46.0));
  bool _showLayersPanel = false; // Başlangıçta kapalı olsun

  // --- UI YARDIMCILARI ---
  void _showErrorDialog(BuildContext context, String message) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hata'), content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Tamam'))],
      ),
    );
  }

  // --- DİNAMİK TEXT FIELD ---
  Widget _buildTextField(TextEditingController controller, String label, ThemeProvider theme, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      style: TextStyle(color: theme.textColor),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.secondaryTextColor),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.secondaryTextColor.withValues(alpha: 0.3))),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
        filled: true,
        fillColor: theme.backgroundColor.withValues(alpha: 0.5),
      ),
    );
  }

  // --- PİN İŞLEMLERİ ---
  void _showPinActionsDialog(BuildContext context, Pin pin) {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    final theme = Provider.of<ThemeProvider>(context, listen: false);

    final nameController = TextEditingController(text: pin.name);
    final capacityController = TextEditingController(text: pin.capacityMw.toStringAsFixed(1));
    final panelAreaController = TextEditingController(text: pin.panelArea?.toStringAsFixed(1) ?? "100.0");
    String selectedType = pin.type;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setStateSB) {
            final isCalculating = mapProvider.isLoading;
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(dialogContext).viewInsets.bottom, top: 20, left: 20, right: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kaynak İşlemleri', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textColor)),
                    const SizedBox(height: 5),
                    Text('ID: ${pin.id} | Potansiyel: ${pin.avgSolarIrradiance?.toStringAsFixed(2) ?? 'N/A'} kWh/m²', style: TextStyle(color: theme.secondaryTextColor)),
                    Divider(color: theme.secondaryTextColor.withValues(alpha: 0.2), height: 24),

                    _buildTextField(nameController, 'Kaynak Adı', theme),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      dropdownColor: theme.cardColor,
                      style: TextStyle(color: theme.textColor),
                      decoration: InputDecoration(
                        labelText: 'Kaynak Tipi', labelStyle: TextStyle(color: theme.secondaryTextColor),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.secondaryTextColor.withValues(alpha: 0.3))),
                        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
                        filled: true, fillColor: theme.backgroundColor.withValues(alpha: 0.5)
                      ),
                      items: ['Güneş Paneli', 'Rüzgar Türbini'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (newValue) { if (newValue != null) setStateSB(() => selectedType = newValue); },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(capacityController, 'Kapasite (MW)', theme, isNumber: true),
                    if (selectedType == 'Güneş Paneli') ...[
                      const SizedBox(height: 16),
                      _buildTextField(panelAreaController, 'Panel Alanı (m²)', theme, isNumber: true),
                    ],
                    if (isCalculating) const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator())),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            try { await mapProvider.deletePin(pin.id); } catch (e) { _showErrorDialog(context, e.toString()); }
                          },
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.calculate), label: const Text('Hesapla'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          onPressed: () async {
                            if (isCalculating) return;
                            setStateSB(() {});
                            try {
                              await mapProvider.calculatePotential(
                                lat: pin.latitude, lon: pin.longitude, type: selectedType,
                                capacityMw: double.tryParse(capacityController.text) ?? 1.0,
                                panelArea: double.tryParse(panelAreaController.text) ?? 0.0,
                              );
                              Navigator.of(ctx).pop();
                              if (mapProvider.latestCalculationResult != null) {
                                _showCalculationResultDialog(context, mapProvider.latestCalculationResult!, theme);
                              }
                            } catch (e) { if (ctx.mounted) _showErrorDialog(ctx, e.toString()); }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCalculationResultDialog(BuildContext context, PinCalculationResponse result, ThemeProvider theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text('Hesaplama Sonucu', style: TextStyle(color: theme.textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kaynak Tipi: ${result.resourceType}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            Divider(color: theme.secondaryTextColor.withValues(alpha: 0.2)),
            if (result.solarCalculation != null) ...[
              _buildResultRow('Anlık Güç', '${result.solarCalculation!.powerOutputKw.toStringAsFixed(2)} kW', theme),
              _buildResultRow('Panel Verimi', '%${(result.solarCalculation!.panelEfficiency * 100).toStringAsFixed(1)}', theme),
              _buildResultRow('Işınım', '${result.solarCalculation!.solarIrradianceKwM2.toStringAsFixed(3)} kW/m²', theme),
              _buildResultRow('Sıcaklık', '${result.solarCalculation!.temperatureCelsius.toStringAsFixed(1)} °C', theme),
            ],
            if (result.windCalculation != null) ...[
              _buildResultRow('Anlık Güç', '${result.windCalculation!.powerOutputKw.toStringAsFixed(2)} kW', theme),
              _buildResultRow('Rüzgar Hızı', '${result.windCalculation!.windSpeedMS.toStringAsFixed(1)} m/s', theme),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { Provider.of<MapProvider>(context, listen: false).clearCalculationResult(); Navigator.of(ctx).pop(); },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String title, String value, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$title:', style: TextStyle(color: theme.secondaryTextColor)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: theme.textColor)),
        ],
      ),
    );
  }
  
  // --- HARİTA ---
  void _handleMapTap(TapPosition tapPosition, LatLng point) async {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    if (mapProvider.placingPinType != null) { _showAddPinDialog(context, point, mapProvider.placingPinType!); }
  }

  void _showAddPinDialog(BuildContext context, LatLng point, String pinType) {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final nameController = TextEditingController(text: 'Yeni Kaynak');
    final capacityController = TextEditingController(text: '1.0');
    String selectedType = pinType;

    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setStateSB) {
          return AlertDialog(
            backgroundColor: theme.cardColor,
            title: Text('Yeni ${selectedType == "Güneş Paneli" ? "Güneş Paneli" : "Rüzgar Türbini"} Ekle', style: TextStyle(color: theme.textColor)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Konum: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}', style: TextStyle(color: theme.secondaryTextColor, fontSize: 12)),
                  const SizedBox(height: 15),
                  _buildTextField(nameController, 'Kaynak Adı', theme),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    dropdownColor: theme.cardColor,
                    style: TextStyle(color: theme.textColor),
                    decoration: InputDecoration(
                      labelText: 'Kaynak Tipi', labelStyle: TextStyle(color: theme.secondaryTextColor),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.secondaryTextColor.withValues(alpha: 0.3))),
                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
                      filled: true, fillColor: theme.backgroundColor.withValues(alpha: 0.5)
                    ),
                    items: ['Güneş Paneli', 'Rüzgar Türbini'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) { if (val != null) setStateSB(() => selectedType = val); },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(capacityController, 'Kapasite (MW)', theme, isNumber: true),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('İptal')),
              ElevatedButton(
                onPressed: () async {
                  try { await mapProvider.addPin(point, nameController.text, selectedType, double.tryParse(capacityController.text) ?? 1.0); Navigator.of(ctx).pop(); } 
                  catch (e) { _showErrorDialog(context, e.toString()); }
                },
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPinIcon(Pin pin) {
    if (pin.type == 'Güneş Paneli') return const Icon(Icons.solar_power, color: Colors.orange, size: 35.0);
    if (pin.type == 'Rüzgar Türbini') return const Icon(Icons.wind_power, color: Colors.blue, size: 35.0);
    return const Icon(Icons.location_pin, color: Colors.red, size: 35.0);
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context);
    final theme = Provider.of<ThemeProvider>(context); 

    List<Marker> markers = mapProvider.pins.map((pin) {
      return Marker(
        width: 80.0, height: 80.0, point: LatLng(pin.latitude, pin.longitude),
        child: GestureDetector(onTap: () => _showPinActionsDialog(context, pin), child: _buildPinIcon(pin)),
      );
    }).toList();

    return Scaffold(
      appBar: MediaQuery.of(context).size.width <= 600 ? AppBar(
        title: const Text('SRRP'),
        backgroundColor: theme.backgroundColor,
        foregroundColor: theme.textColor,
      ) : null,
      body: Row(
        children: [
          // 1. Sidebar (Sol Menü)
          if (MediaQuery.of(context).size.width > 600) 
            const SidebarMenu(),
          
          // 2. Harita Alanı
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(39.0, 35.5),
                    initialZoom: 6.4, minZoom: 6.2, maxZoom: 18.0,
                    cameraConstraint: CameraConstraint.contain(bounds: turkeyBounds),
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                    onTap: _handleMapTap,
                    backgroundColor: theme.mapBackgroundColor, 
                  ),
                  children: [
                    // A. Taban Haritası (OSM)
                    TileLayer(
                      tileProvider: CancellableNetworkTileProvider(),
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      keepBuffer: 10,
                      panBuffer: 1,
                    ),

                    // B. Veri Katmanları
                    if (mapProvider.currentLayer == MapLayer.wind)
                      const CircleLayer(circles: <CircleMarker>[]),
                    
                    if (mapProvider.currentLayer == MapLayer.temp)
                      const CircleLayer(circles: <CircleMarker>[]),

                    // C. Sınırlar
                    PolygonLayer(
                      polygons: [Polygon(points: [turkeyBounds.southWest, LatLng(turkeyBounds.northEast.latitude, turkeyBounds.southWest.longitude), turkeyBounds.northEast, LatLng(turkeyBounds.southWest.latitude, turkeyBounds.northEast.longitude)], color: Colors.transparent, borderStrokeWidth: 3.0, borderColor: Colors.red.withValues(alpha: 0.3))],
                    ),
                    MarkerLayer(markers: markers),
                  ],
                ),

                // --- UI ELEMANLARI ---
                
                // 1. DASHBOARD (SOL ÜST)
                Positioned(
                  top: 20, 
                  left: 20, 
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: theme.cardColor.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.secondaryTextColor.withValues(alpha: 0.1))),
                    child: Row(children: [_buildStatItem("Total Output", "0.0 MW", Colors.greenAccent, theme), const SizedBox(width: 20), Container(width: 1, height: 30, color: theme.secondaryTextColor.withValues(alpha: 0.2)), const SizedBox(width: 20), _buildStatItem("Capacity", "0 MW", theme.textColor, theme)])
                  )
                ),

                // 2. KONTROL VE KATMANLAR (SAĞ ÜST)
                // Orijinal tasarımdaki gibi Ekleme Butonlarını sağa aldık.
                Positioned(
                  top: 20, 
                  right: 20, 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end, 
                    children: [
                      // --- EKLEME BUTONLARI (YAN YANA) ---
                      Row(
                        children: [
                          _buildActionButton("Rüzgar Türbini", Icons.wind_power, Colors.blue, theme, () => mapProvider.startPlacingMarker('Rüzgar Türbini')),
                          const SizedBox(width: 10),
                          _buildActionButton("Güneş Paneli", Icons.solar_power, Colors.orange, theme, () => mapProvider.startPlacingMarker('Güneş Paneli')),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // --- KATMAN BUTONU VE PANELİ ---
                      FloatingActionButton.small(
                        heroTag: 'layer_toggle', 
                        backgroundColor: theme.cardColor, 
                        child: Icon(Icons.layers, color: theme.textColor), 
                        onPressed: () => setState(() => _showLayersPanel = !_showLayersPanel)
                      ),
                      if (_showLayersPanel) ...[
                        const SizedBox(height: 10), 
                        Container(
                          width: 220, 
                          padding: const EdgeInsets.all(12), 
                          decoration: BoxDecoration(color: theme.cardColor.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.secondaryTextColor.withValues(alpha: 0.1))), 
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start, 
                            children: [
                              Text("Katmanlar", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)), 
                              Divider(color: theme.secondaryTextColor.withValues(alpha: 0.2)), 
                              _buildLayerSwitch("Rüzgar Haritası (Backend)", MapLayer.wind, mapProvider, theme), 
                              _buildLayerSwitch("Sıcaklık Haritası (Backend)", MapLayer.temp, mapProvider, theme)
                            ]
                          )
                        )
                      ]
                    ]
                  )
                ),

                // 3. EKLEME UYARISI (ALT ORTA)
                if (mapProvider.placingPinType != null) 
                  Positioned(bottom: 100, left: 0, right: 0, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)]), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.touch_app, color: Colors.white), const SizedBox(width: 8), Text("${mapProvider.placingPinType} Eklemek için Haritaya Dokunun", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(width: 10), InkWell(onTap: mapProvider.stopPlacingMarker, child: const Icon(Icons.cancel, color: Colors.white))])))),
                
                // 4. ZOOM BUTONLARI (SAĞ ALT)
                Positioned(bottom: 40, right: 20, child: Column(children: [_buildZoomButton(Icons.add, theme, () { _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1); }), const SizedBox(height: 8), _buildZoomButton(Icons.remove, theme, () { _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1); })]))
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET YAPICILAR ---

  // Yeni Buton Tasarımı (Orijinal Görseldeki Gibi)
  Widget _buildActionButton(String label, IconData icon, Color color, ThemeProvider theme, VoidCallback onPressed) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.cardColor,
        foregroundColor: color,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: color.withValues(alpha: 0.3)))
      ),
      icon: Icon(icon, size: 20),
      label: Text(label),
      onPressed: onPressed,
    );
  }

  Widget _buildStatItem(String label, String value, Color valueColor, ThemeProvider theme) { return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: theme.secondaryTextColor, fontSize: 12)), Text(value, style: TextStyle(color: valueColor, fontSize: 18, fontWeight: FontWeight.bold))]); }
  
  Widget _buildLayerSwitch(String title, MapLayer layer, MapProvider provider, ThemeProvider theme) { 
    final bool isActive = provider.currentLayer == layer; 
    return InkWell(
      onTap: () { provider.changeMapLayer(); }, 
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0), 
        child: Row(
          children: [
            Icon(isActive ? Icons.check_circle : Icons.radio_button_unchecked, color: isActive ? Colors.greenAccent : theme.secondaryTextColor.withValues(alpha: 0.5), size: 20), 
            const SizedBox(width: 10), 
            Expanded(child: Text(title, style: TextStyle(color: isActive ? theme.textColor : theme.secondaryTextColor), overflow: TextOverflow.ellipsis))
          ]
        )
      )
    ); 
  }
  
  Widget _buildZoomButton(IconData icon, ThemeProvider theme, VoidCallback onTap) { return Container(decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]), child: IconButton(icon: Icon(icon, color: theme.textColor), onPressed: onTap, constraints: const BoxConstraints(minWidth: 40, minHeight: 40))); }
}