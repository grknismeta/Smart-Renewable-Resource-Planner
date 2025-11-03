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
  // Harita API Sabitleri
  final String myMapboxAccessToken =
      "pk.eyJ1IjoiZ3JrbmlzbWV0YSIsImEiOiJjbWdzODB4YmgyNTNrMmlzYTl4NmZxbnZpIn0.Ocbt8oI-AN4H5PedVops7A";
  final String myOpenWeatherApiKey = "b525f47f8adb6ddfceea1bc14bc72633";

  // UI Fonksiyonları
  void _showErrorDialog(BuildContext context, String message) {
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

  // Pin İşlemleri ve Hesaplama Dialogu
  void _showPinActionsDialog(BuildContext context, Pin pin) {
    final mapProvider = Provider.of<MapProvider>(context, listen: false);

    // Geçici kontrolcüleri oluştur (Hesaplama için)
    final typeController = TextEditingController(text: pin.type);
    final capacityController = TextEditingController(
      text: pin.capacityMw.toStringAsFixed(1),
    );

    // Panel alanı için yeni bir controller ekle
    // 'pin.panelArea' null ise '100.0' kullan
    final panelAreaController = TextEditingController(
      text: pin.panelArea?.toStringAsFixed(1) ?? "100.0",
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          final isCalculating =
              mapProvider.isLoading; // Genel loading state'ini kullan

          return AlertDialog(
            title: const Text('Kaynak İşlemleri'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ID: ${pin.id}\nKonum: ${pin.latitude.toStringAsFixed(4)}, ${pin.longitude.toStringAsFixed(4)}',
                  ),
                  const Divider(),
                  const Text(
                    'Hesaplama Parametreleri:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextField(
                    controller: typeController,
                    decoration: const InputDecoration(
                      labelText: 'Tip (Güneş Paneli/Rüzgar Türbini)',
                    ),
                  ),
                  TextField(
                    controller: capacityController,
                    decoration: const InputDecoration(
                      labelText: 'Kapasite (MW)',
                    ),
                    keyboardType: TextInputType.number,
                  ),

                  // Panel alanı için yeni TextField'ı ekle
                  TextField(
                    controller: panelAreaController,
                    decoration: const InputDecoration(
                      labelText: 'Panel Alanı (m²)',
                    ),
                    keyboardType: TextInputType.number,
                  ),

                  if (isCalculating)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  if (isCalculating) return;
                  setStateSB(() {}); // Loading'i başlatmak için setState

                  try {
                    await mapProvider.calculatePotential(
                      lat: pin.latitude,
                      lon: pin.longitude,
                      type: typeController.text,
                      capacityMw:
                          double.tryParse(capacityController.text) ?? 1.0,

                      // Eksik 'panelArea' parametresini buradan gönder
                      panelArea:
                          double.tryParse(panelAreaController.text) ?? 0.0,
                    );
                    Navigator.of(ctx).pop(); // Dialog'u kapat

                    // --- HATA DÜZELTME YERİ ---
                    // mapProvider.latestCalculationResult artık 'PinCalculationResponse?' tipinde
                    // (Bu değişikliği map_provider.dart'ta da yapman GEREKİR)
                    if (mapProvider.latestCalculationResult != null) {
                      _showCalculationResultDialog(
                        context,
                        mapProvider.latestCalculationResult!,
                      );
                    } else {
                      _showErrorDialog(context, "Hesaplama sonucu alınamadı.");
                    }
                  } catch (e) {
                    _showErrorDialog(
                      ctx,
                      e.toString().replaceFirst('Exception: ', ''),
                    );
                  } finally {
                    // setStateSB çağrısı dialog kapandıktan sonra yapılırsa hata verir.
                    // Bu yüzden 'mounted' kontrolü ekleyebiliriz veya dialog kapanmadan
                    // state'i güncelleyebiliriz. Şimdilik bıraktım.
                    if (context.mounted) {
                      setStateSB(() {}); // Loading'i bitirmek için setState
                    }
                  }
                },
                child: Text(
                  'Hesapla',
                  style: TextStyle(
                    color: isCalculating ? Colors.grey : Colors.green,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Kapat'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  try {
                    await mapProvider.deletePin(pin.id);
                  } catch (e) {
                    _showErrorDialog(
                      context,
                      e.toString().replaceFirst('Exception: ', ''),
                    );
                  }
                },
                child: const Text('Sil', style: TextStyle(color: Colors.red)),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- 1. DÜZELTME: Fonksiyonun parametresini doğru modele değiştir ---
  void _showCalculationResultDialog(
    BuildContext context,
    PinCalculationResponse result,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hesaplama Sonucu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 2. DÜZELTME: Bu alanlar 'PinCalculationResponse' modelinde yok ---
            // 'PinResult' modelindeki bu alanlar backend tarafından (henüz)
            // hesaplanıp gönderilmiyor.
            // _buildResultRow('Yıllık Enerji (kWh)', result.potentialKwhAnnual),
            // _buildResultRow('Tahmini Maliyet (USD)', result.estimatedCost),
            // _buildResultRow('ROI (Yıl)', result.roiYears, decimalPlaces: 1),

            // --- 3. DÜZELTME: Doğru modelden ('result') veriyi oku ---
            // Bu kod artık 'undefined_getter' hatası VERMEYECEK.
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
    if (mapProvider.isPlacingMarker) {
      try {
        await mapProvider.addPin(point);
      } catch (e) {
        _showErrorDialog(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final mapProvider = Provider.of<MapProvider>(context);

    // Pin listesini Marker listesine dönüştür
    List<Marker> markers = mapProvider.pins.map((pin) {
      return Marker(
        width: 80.0,
        height: 80.0,
        point: LatLng(pin.latitude, pin.longitude),
        child: GestureDetector(
          onTap: () => _showPinActionsDialog(context, pin),
          child: const Icon(Icons.location_pin, color: Colors.red, size: 40.0),
        ),
      );
    }).toList();

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
          ? const Center(
              child: CircularProgressIndicator(value: null),
            ) // İlk yükleme için
          : Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: const LatLng(38.6191, 27.4289),
                    initialZoom: 10.0,
                    onTap:
                        _handleMapTap, // <-- Burası artık doğru metodu çağırıyor
                  ),
                  children: [
                    // --- DÜZELTME 1: MAPBOX URL'si ---
                    TileLayer(
                      urlTemplate:
                          'https://api.mapbox.com/styles/v1/{id}/tiles/{z}/{x}/{y}?access_token={accessToken}',
                      additionalOptions: {
                        'accessToken': myMapboxAccessToken,
                        'id': 'mapbox/streets-v11',
                      },
                    ),
                    // --- DÜZELTME 2: RÜZGAR KATMANI URL'si ---
                    if (mapProvider.currentLayer == MapLayer.wind)
                      TileLayer(
                        urlTemplate:
                            'https://tile.openweathermap.org/map/wind_new/{z}/{x}/{y}.png?appid={apiKey}',
                        additionalOptions: {'apiKey': myOpenWeatherApiKey},
                      ),
                    // --- DÜZELTME 3: SICAKLIK KATMANI URL'si ---
                    if (mapProvider.currentLayer == MapLayer.temp)
                      TileLayer(
                        urlTemplate:
                            'https://tile.openweathermap.org/map/temp_new/{z}/{x}/{y}.png?appid={apiKey}',
                        additionalOptions: {'apiKey': myOpenWeatherApiKey},
                      ),
                    // İşaretçiler
                    MarkerLayer(markers: markers),
                  ],
                ),
                // KONTROL BUTONLARI
                Positioned(top: 10.0, right: 10.0, child: ControlButtons()),

                // API işlemi devam ederken küçük loading
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
