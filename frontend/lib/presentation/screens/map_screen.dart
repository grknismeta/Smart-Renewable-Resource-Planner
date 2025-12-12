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
  bool _showLayersPanel = false;

  final String _arcGisSatelliteUrl = 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  final String _arcGisDarkUrl = 'https://services.arcgisonline.com/arcgis/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}';
  final String _arcGisStreetUrl = 'https://services.arcgisonline.com/arcgis/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}';

  String _selectedBaseMap = 'dark'; 

  // --- ÖZEL RENKLER (Referans Görsellerden) ---
  
  // Rüzgar (Hydro Görselindeki Mavi Tema)
  final Color _windBgColor = const Color(0xFF1F3A58); // Koyu Mavi Arkaplan
  final Color _windFgColor = const Color(0xFF2196F3); // Parlak Mavi Çerçeve/İkon

  // Güneş (Solar Görselindeki Sarı Tema)
  final Color _solarBgColor = const Color(0xFF413819); // Koyu Sarı/Kahve Arkaplan
  final Color _solarFgColor = const Color(0xFFFFCA28); // Parlak Sarı Çerçeve/İkon

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

  void _showPinActionsDialog(BuildContext context, Pin pin) {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final nameController = TextEditingController(text: pin.name);
    final capacityController = TextEditingController(text: pin.capacityMw.toStringAsFixed(1));
    final panelAreaController = TextEditingController(text: pin.panelArea?.toStringAsFixed(1) ?? "100.0");
    String selectedType = pin.type;

    // Renk ve ikon seçimi
    Color iconColor = pin.type == 'Güneş Paneli' ? _solarFgColor : _windFgColor;
    Color bgColor = pin.type == 'Güneş Paneli' ? _solarBgColor : _windBgColor;
    IconData iconData = pin.type == 'Güneş Paneli' ? Icons.wb_sunny : Icons.air;

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
                    Row(
                      children: [
                        // Dialog içindeki ikon da aynı yuvarlak yapıda
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: bgColor,
                            shape: BoxShape.circle, // Yuvarlak
                            border: Border.all(color: iconColor, width: 2)
                          ),
                          child: Icon(iconData, color: iconColor, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Kaynak İşlemleri', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.textColor)),
                            Text('ID: ${pin.id}', style: TextStyle(color: theme.secondaryTextColor, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('Yıllık Potansiyel: ${pin.avgSolarIrradiance?.toStringAsFixed(2) ?? 'N/A'} kWh/m²', style: TextStyle(color: theme.textColor)),
                    
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
                        IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () async { Navigator.of(ctx).pop(); try { await mapProvider.deletePin(pin.id); } catch (e) { _showErrorDialog(context, e.toString()); } }),
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
        actions: [TextButton(onPressed: () { Provider.of<MapProvider>(context, listen: false).clearCalculationResult(); Navigator.of(ctx).pop(); }, child: const Text('Tamam'))],
      ),
    );
  }

  Widget _buildResultRow(String title, String value, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text('$title:', style: TextStyle(color: theme.secondaryTextColor)), Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: theme.textColor))],
      ),
    );
  }
  
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

  // --- HARİTA PİN SİMGELERİ (TAM YUVARLAK) ---
  Widget _buildPinIcon(Pin pin) {
    if (pin.type == 'Güneş Paneli') {
      return Container(
        width: 40, height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _solarBgColor,
          shape: BoxShape.circle, // YUVARLAK
          border: Border.all(color: _solarFgColor, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
        child: Icon(Icons.wb_sunny, color: _solarFgColor, size: 24),
      );
    } else if (pin.type == 'Rüzgar Türbini') {
      return Container(
        width: 40, height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _windBgColor,
          shape: BoxShape.circle, // YUVARLAK
          border: Border.all(color: _windFgColor, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
        // Rüzgar simgesi (görseldeki "Wind" ikonuna uygun)
        child: Icon(Icons.air, color: _windFgColor, size: 24),
      );
    }
    return const Icon(Icons.location_pin, color: Colors.red, size: 35.0);
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context);
    final theme = Provider.of<ThemeProvider>(context); 

    List<Marker> markers = mapProvider.pins.map((pin) {
      return Marker(
        width: 50.0, height: 50.0, 
        point: LatLng(pin.latitude, pin.longitude),
        child: GestureDetector(onTap: () => _showPinActionsDialog(context, pin), child: _buildPinIcon(pin)),
      );
    }).toList();

    String currentTileUrl = _arcGisDarkUrl;
    if (_selectedBaseMap == 'satellite') currentTileUrl = _arcGisSatelliteUrl;
    if (_selectedBaseMap == 'street') currentTileUrl = _arcGisStreetUrl;

    return Scaffold(
      appBar: MediaQuery.of(context).size.width <= 600 ? AppBar(title: const Text('SRRP'), backgroundColor: theme.backgroundColor, foregroundColor: theme.textColor) : null,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (MediaQuery.of(context).size.width > 600) const SidebarMenu(),
          
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(39.0, 35.5),
                    initialZoom: 6.0, minZoom: 3.0, maxZoom: 18.0,
                    cameraConstraint: CameraConstraint.contain(bounds: turkeyBounds),
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                    onTap: _handleMapTap,
                    backgroundColor: theme.mapBackgroundColor, 
                  ),
                  children: [
                    TileLayer(
                      tileProvider: CancellableNetworkTileProvider(),
                      urlTemplate: currentTileUrl,
                      keepBuffer: 10,
                      panBuffer: 1,
                    ),
                    if (mapProvider.currentLayer == MapLayer.wind) const CircleLayer(circles: <CircleMarker>[]),
                    if (mapProvider.currentLayer == MapLayer.temp) const CircleLayer(circles: <CircleMarker>[]),
                    
                    MarkerLayer(markers: markers),
                  ],
                ),

                // --- DASHBOARD (SOL ÜST) ---
                Positioned(
                  top: 20, left: 20, 
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: theme.cardColor.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.secondaryTextColor.withValues(alpha: 0.1))),
                    child: Row(children: [_buildStatItem("Total Output", "0.0 MW", Colors.greenAccent, theme), const SizedBox(width: 20), Container(width: 1, height: 30, color: theme.secondaryTextColor.withValues(alpha: 0.2)), const SizedBox(width: 20), _buildStatItem("Capacity", "0 MW", theme.textColor, theme)])
                  )
                ),

                // --- BUTONLAR (SAĞ ÜST) - TAM YUVARLAK (KARE/KAPSÜL DEĞİL!) ---
                Positioned(
                  top: 20, right: 20, 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end, 
                    children: [
                      Row(
                        children: [
                          // RÜZGAR BUTONU (Tam Yuvarlak - Mavi Tema)
                          GestureDetector(
                            onTap: () => mapProvider.startPlacingMarker('Rüzgar Türbini'),
                            child: Container(
                              width: 50, height: 50, // Eşit boyut -> Tam Daire
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _windBgColor, 
                                shape: BoxShape.circle, // TAM YUVARLAK
                                border: Border.all(color: _windFgColor, width: 2),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              child: Icon(Icons.air, color: _windFgColor, size: 28),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // GÜNEŞ BUTONU (Tam Yuvarlak - Sarı Tema)
                          GestureDetector(
                            onTap: () => mapProvider.startPlacingMarker('Güneş Paneli'),
                            child: Container(
                              width: 50, height: 50, // Eşit boyut -> Tam Daire
                              decoration: BoxDecoration(
                                color: _solarBgColor, 
                                shape: BoxShape.circle, // TAM YUVARLAK
                                border: Border.all(color: _solarFgColor, width: 2),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              child: Icon(Icons.wb_sunny, color: _solarFgColor, size: 28),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      
                      FloatingActionButton.small(heroTag: 'layer_toggle', backgroundColor: theme.cardColor, child: Icon(Icons.layers, color: theme.textColor), onPressed: () => setState(() => _showLayersPanel = !_showLayersPanel)),
                      
                      if (_showLayersPanel) ...[
                        const SizedBox(height: 10), 
                        Container(
                          width: 220, 
                          padding: const EdgeInsets.all(12), 
                          decoration: BoxDecoration(color: theme.cardColor.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.secondaryTextColor.withValues(alpha: 0.1))), 
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start, 
                            children: [
                              Text("Harita Stili", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)), 
                              Divider(color: theme.secondaryTextColor.withValues(alpha: 0.2)), 
                              _buildBaseMapOption("ArcGIS Koyu", "dark", theme),
                              _buildBaseMapOption("Uydu (Satellite)", "satellite", theme),
                              _buildBaseMapOption("Sokak Haritası", "street", theme),
                              const SizedBox(height: 10), 
                              Text("Veri Katmanları", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)), 
                              Divider(color: theme.secondaryTextColor.withValues(alpha: 0.2)), 
                              _buildLayerSwitch("Rüzgar Haritası", MapLayer.wind, mapProvider, theme), 
                              _buildLayerSwitch("Sıcaklık Haritası", MapLayer.temp, mapProvider, theme)
                            ]
                          )
                        )
                      ]
                    ]
                  )
                ),

                // --- UYARI BARI (DİNAMİK RENKLİ) ---
                if (mapProvider.placingPinType != null) 
                  Positioned(
                    bottom: 100, 
                    left: 0, 
                    right: 0, 
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), 
                        decoration: BoxDecoration(
                          color: mapProvider.placingPinType == 'Güneş Paneli' ? _solarBgColor : _windBgColor, 
                          borderRadius: BorderRadius.circular(30), 
                          border: Border.all(
                            color: mapProvider.placingPinType == 'Güneş Paneli' ? _solarFgColor : _windFgColor,
                            width: 2
                          ),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)]
                        ), 
                        child: Row(
                          mainAxisSize: MainAxisSize.min, 
                          children: [
                            Icon(
                              Icons.touch_app, 
                              color: mapProvider.placingPinType == 'Güneş Paneli' ? _solarFgColor : _windFgColor
                            ), 
                            const SizedBox(width: 8), 
                            Text(
                              "${mapProvider.placingPinType} Eklemek için Haritaya Dokunun", 
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                color: mapProvider.placingPinType == 'Güneş Paneli' ? _solarFgColor : _windFgColor
                              )
                            ), 
                            const SizedBox(width: 10), 
                            InkWell(
                              onTap: mapProvider.stopPlacingMarker, 
                              child: const Icon(Icons.cancel, color: Colors.white) 
                            )
                          ]
                        )
                      )
                    )
                  ),
                
                Positioned(bottom: 40, right: 20, child: Column(children: [_buildZoomButton(Icons.add, theme, () { _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1); }), const SizedBox(height: 8), _buildZoomButton(Icons.remove, theme, () { _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1); })]))
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBaseMapOption(String title, String value, ThemeProvider theme) { final bool isActive = _selectedBaseMap == value; return InkWell(onTap: () => setState(() => _selectedBaseMap = value), child: Padding(padding: const EdgeInsets.symmetric(vertical: 6.0), child: Row(children: [Icon(isActive ? Icons.radio_button_checked : Icons.radio_button_off, color: isActive ? Colors.blueAccent : theme.secondaryTextColor, size: 18), const SizedBox(width: 8), Text(title, style: TextStyle(color: isActive ? theme.textColor : theme.secondaryTextColor, fontSize: 13))]))); }
  Widget _buildStatItem(String label, String value, Color valueColor, ThemeProvider theme) { return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: theme.secondaryTextColor, fontSize: 12)), Text(value, style: TextStyle(color: valueColor, fontSize: 18, fontWeight: FontWeight.bold))]); }
  Widget _buildLayerSwitch(String title, MapLayer layer, MapProvider provider, ThemeProvider theme) { final bool isActive = provider.currentLayer == layer; return InkWell(onTap: () { provider.changeMapLayer(); }, child: Padding(padding: const EdgeInsets.symmetric(vertical: 6.0), child: Row(children: [Icon(isActive ? Icons.check_circle : Icons.radio_button_unchecked, color: isActive ? Colors.greenAccent : theme.secondaryTextColor.withValues(alpha: 0.5), size: 18), const SizedBox(width: 8), Expanded(child: Text(title, style: TextStyle(color: isActive ? theme.textColor : theme.secondaryTextColor, fontSize: 13), overflow: TextOverflow.ellipsis))]))); }
  Widget _buildZoomButton(IconData icon, ThemeProvider theme, VoidCallback onTap) { return Container(decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]), child: IconButton(icon: Icon(icon, color: theme.textColor), onPressed: onTap, constraints: const BoxConstraints(minWidth: 40, minHeight: 40))); }
}