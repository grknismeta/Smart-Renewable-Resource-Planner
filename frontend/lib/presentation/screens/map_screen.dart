// lib/presentation/screens/map_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../providers/map_provider.dart';
import '../../providers/auth_provider.dart';
import '../widgets/control_buttons.dart';
import '../../data/models/pin_model.dart'; // Artık Pin, PinCalculationResponse vb. içeriyor

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // ... (API sabitleri ve _showErrorDialog - değişiklik yok) ...
  final String myMapboxAccessToken =
      "pk.eyJ1IjoiZ3JrbmlzbWV0YSIsImEiOiJjbWdzODB4YmgyNTNrMmlzYTl4NmZxbnZpIn0.Ocbt8oI-AN4H5PedVops7A";
  final String myOpenWeatherApiKey = "b525f47f8adb6ddfceea1bc14bc72633";

  void _showErrorDialog(BuildContext context, String message) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hata'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  // --- 1. GÜNCELLEME: "Kötü" AlertDialog'u BottomSheet ile değiştirme ---
  void _showPinActionsDialog(BuildContext context, Pin pin) {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);

    // Controller'lar pin'in mevcut verileriyle doldurulur
    final nameController = TextEditingController(text: pin.name);
    final capacityController = TextEditingController(
      text: pin.capacityMw.toStringAsFixed(1),
    );
    final panelAreaController = TextEditingController(
      text: pin.panelArea?.toStringAsFixed(1) ?? "100.0",
    );

    // Dropdown için state (pin'in mevcut tipini al)
    String selectedType = pin.type;

    // AlertDialog yerine showModalBottomSheet kullanıyoruz
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Klavye açıldığında boyutu ayarlar
      builder: (ctx) {
        // BottomSheet'in state'ini (örn: Dropdown) yönetmek için StatefulBuilder
        return StatefulBuilder(
          builder: (dialogContext, setStateSB) {
            final isCalculating = mapProvider.isLoading;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kaynak İşlemleri',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'ID: ${pin.id} | Yıllık Potansiyel: ${pin.avgSolarIrradiance?.toStringAsFixed(2) ?? 'N/A'} kWh/m²/gün',
                    ),
                    const Divider(height: 24),

                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Kaynak Adı',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- 2. GÜNCELLEME: "Tip" alanı artık Dropdown ---
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Kaynak Tipi',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Güneş Paneli', 'Rüzgar Türbini']
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setStateSB(() {
                            selectedType = newValue;
                          });
                        }
                      },
                    ),

                    // --- GÜNCELLEME SONU ---
                    const SizedBox(height: 16),
                    TextField(
                      controller: capacityController,
                      decoration: const InputDecoration(
                        labelText: 'Kapasite (MW)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    // Sadece Güneş Paneli seçiliyse Panel Alanı'nı göster
                    if (selectedType == 'Güneş Paneli')
                      TextField(
                        controller: panelAreaController,
                        decoration: const InputDecoration(
                          labelText: 'Panel Alanı (m²)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),

                    if (isCalculating)
                      const Padding(
                        padding: EdgeInsets.only(top: 16, bottom: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),

                    const SizedBox(height: 20),
                    // Butonlar
                    Row(
                      children: [
                        // Sil Butonu
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            Navigator.of(ctx).pop(); // BottomSheet'i kapat
                            try {
                              await mapProvider.deletePin(pin.id);
                            } catch (e) {
                              _showErrorDialog(
                                context,
                                e.toString().replaceFirst('Exception: ', ''),
                              );
                            }
                          },
                        ),
                        // TODO: Güncelle Butonu
                        // TextButton(
                        //   onPressed: () { /* mapProvider.updatePin(...) çağrılacak */ },
                        //   child: const Text('Güncelle'),
                        // ),
                        const Spacer(),
                        // Hesapla Butonu
                        ElevatedButton.icon(
                          icon: const Icon(Icons.calculate),
                          label: const Text('Hesapla'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            if (isCalculating) return;
                            setStateSB(() {}); // Loading'i başlat

                            try {
                              await mapProvider.calculatePotential(
                                lat: pin.latitude,
                                lon: pin.longitude,
                                type:
                                    selectedType, // Dropdown'dan gelen güncel tip
                                capacityMw:
                                    double.tryParse(capacityController.text) ??
                                    1.0,
                                panelArea:
                                    double.tryParse(panelAreaController.text) ??
                                    0.0,
                              );
                              Navigator.of(ctx).pop(); // BottomSheet'i kapat

                              if (mapProvider.latestCalculationResult != null) {
                                _showCalculationResultDialog(
                                  context,
                                  mapProvider.latestCalculationResult!,
                                );
                              } else {
                                _showErrorDialog(
                                  context,
                                  "Hesaplama sonucu alınamadı.",
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                _showErrorDialog(
                                  ctx,
                                  e.toString().replaceFirst('Exception: ', ''),
                                );
                              }
                            } finally {
                              if (ctx.mounted) {
                                setStateSB(() {}); // Loading'i bitir
                              }
                            }
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

  void _showCalculationResultDialog(
    BuildContext context,
    PinCalculationResponse result,
  ) {
    // ... (Bu fonksiyonda değişiklik yok) ...
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hesaplama Sonucu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kaynak Tipi: ${result.resourceType}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Divider(),

            if (result.solarCalculation != null) ...[
              _buildResultRow(
                'Anlık Güç (kW)',
                result.solarCalculation!.powerOutputKw,
                decimalPlaces: 2,
              ),
              _buildResultRow(
                'Panel Verimi',
                result.solarCalculation!.panelEfficiency,
                decimalPlaces: 2,
              ),
              _buildResultRow(
                'Işınım (kW/m²)',
                result.solarCalculation!.solarIrradianceKwM2,
                decimalPlaces: 2,
              ),
              _buildResultRow(
                'Sıcaklık (°C)',
                result.solarCalculation!.temperatureCelsius,
                decimalPlaces: 1,
              ),
            ],

            if (result.windCalculation != null) ...[
              _buildResultRow(
                'Anlık Güç (kW)',
                result.windCalculation!.powerOutputKw,
                decimalPlaces: 2,
              ),
              _buildResultRow(
                'Rüzgar Hızı (m/s)',
                result.windCalculation!.windSpeedMS,
                decimalPlaces: 2,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Provider.of<MapProvider>(
                context,
                listen: false,
              ).clearCalculationResult();
              Navigator.of(ctx).pop();
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String title, double value, {int decimalPlaces = 0}) {
    // ... (değişiklik yok) ...
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$title:'),
          Text(
            value.toStringAsFixed(decimalPlaces),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // Harita Tap İşlemi
  void _handleMapTap(TapPosition tapPosition, LatLng point) async {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);

    // --- 3. GÜNCELLEME: 'isPlacingMarker' (boolean) yerine 'placingPinType' (String) kontrolü
    if (mapProvider.placingPinType != null) {
      // Pin ekleme modu açıksa, dialog'u göster
      _showAddPinDialog(context, point, mapProvider.placingPinType!);
    } else {
      // Pin ekleme modu kapalıysa:
      // TODO: Faz 2 - Anlık Bilgi Aracını (Info Tool) burada çağır
      print(
        "Info modu: ${point.latitude}, ${point.longitude} için veri getirilecek.",
      );
    }
  }

  // Yeni Pin Ekleme Dialogu
  void _showAddPinDialog(BuildContext context, LatLng point, String pinType) {
    // ... (Bu fonksiyonda değişiklik yok) ...
    final mapProvider = Provider.of<MapProvider>(context, listen: false);

    final nameController = TextEditingController(text: 'Yeni Kaynak');
    final capacityController = TextEditingController(text: '1.0');
    String selectedType = 'Güneş Paneli';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setStateSB) {
          return AlertDialog(
            title: Text(
              'Yeni ${selectedType.replaceAll('Paneli', 'Paneli ')}Ekle',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Konum: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
                  ),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Kaynak Adı'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Kaynak Tipi'),
                    items: ['Güneş Paneli', 'Rüzgar Türbini']
                        .map(
                          (type) =>
                              DropdownMenuItem(value: type, child: Text(type)),
                        )
                        .toList(),
                    onChanged: (newValue) {
                      if (newValue != null) {
                        setStateSB(() {
                          selectedType = newValue;
                        });
                      }
                    },
                  ),
                  TextField(
                    controller: capacityController,
                    decoration: const InputDecoration(
                      labelText: 'Kapasite (MW)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(), // Dialog'u kapat
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () async {
                  final String name = nameController.text;
                  final String type = selectedType;
                  final double capacityMw =
                      double.tryParse(capacityController.text) ?? 1.0;

                  try {
                    await mapProvider.addPin(point, name, type, capacityMw);
                    Navigator.of(ctx).pop(); // Dialog'u kapat
                  } catch (e) {
                    _showErrorDialog(
                      context,
                      e.toString().replaceFirst('Exception: ', ''),
                    );
                  }
                },
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- 5. YENİ FONKSİYON: Pin tipine göre dinamik ikon ---
  Widget _buildPinIcon(Pin pin) {
    if (pin.type == 'Güneş Paneli') {
      return const Icon(Icons.solar_power, color: Colors.orange, size: 35.0);
    } else if (pin.type == 'Rüzgar Türbini') {
      return const Icon(Icons.wind_power, color: Colors.blue, size: 35.0);
    }
    // Varsayılan (eğer tip bilinmiyorsa)
    return const Icon(Icons.location_pin, color: Colors.red, size: 35.0);
  }
  // --- YENİ FONKSİYON SONU ---

  @override
  Widget build(BuildContext context) {
    // ... (build metodunda değişiklik yok) ...
    final authProvider = Provider.of<AuthProvider>(context);
    final mapProvider = Provider.of<MapProvider>(context);

    // --- 6. GÜNCELLEME: 'markers' listesi artık dinamik ikonu çağırıyor ---
    List<Marker> markers = mapProvider.pins.map((pin) {
      return Marker(
        width: 80.0,
        height: 80.0,
        point: LatLng(pin.latitude, pin.longitude),
        child: GestureDetector(
          onTap: () => _showPinActionsDialog(context, pin),
          // 'const Icon(...)' yerine yeni fonksiyonumuzu çağırıyoruz
          child: _buildPinIcon(pin),
        ),
      );
    }).toList();
    // --- GÜNCELLEME SONU ---

    return Scaffold(
      appBar: AppBar(
        title: const Text('SRRP Harita Ekranı'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: authProvider.logout,
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
      body: mapProvider.isLoading && mapProvider.pins.isEmpty
          ? const Center(child: CircularProgressIndicator(value: null))
          : Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: const LatLng(38.6191, 27.4289),
                    initialZoom: 10.0,
                    onTap: _handleMapTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://api.mapbox.com/styles/v1/{id}/tiles/{z}/{x}/{y}?access_token={accessToken}',
                      additionalOptions: {
                        'accessToken': myMapboxAccessToken,
                        'id': 'mapbox/streets-v11',
                      },
                    ),
                    if (mapProvider.currentLayer == MapLayer.wind)
                      TileLayer(
                        urlTemplate:
                            'https://tile.openweathermap.org/map/wind_new/{z}/{x}/{y}.png?appid={apiKey}',
                        additionalOptions: {'apiKey': myOpenWeatherApiKey},
                      ),
                    if (mapProvider.currentLayer == MapLayer.temp)
                      TileLayer(
                        urlTemplate:
                            'https://tile.openweathermap.org/map/temp_new/{z}/{x}/{y}.png?appid={apiKey}',
                        additionalOptions: {'apiKey': myOpenWeatherApiKey},
                      ),
                    MarkerLayer(markers: markers),
                  ],
                ),
                Positioned(top: 10.0, right: 10.0, child: ControlButtons()),
                if (mapProvider.isLoading && mapProvider.pins.isNotEmpty)
                  const Positioned(
                    top: 10,
                    left: 10,
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
    );
  }
}
