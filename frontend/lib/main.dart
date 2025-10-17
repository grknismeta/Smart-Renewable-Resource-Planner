import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Hangi harita katmanının aktif olduğunu takip etmek için bir enum (sabit liste)
enum MapLayer { none, wind, temp }

// Backend'deki Pin modeline karşılık gelen Dart sınıfı
class Pin {
  final int id;
  final double latitude;
  final double longitude;

  Pin({required this.id, required this.latitude, required this.longitude});

  factory Pin.fromJson(Map<String, dynamic> json) {
    return Pin(
      id: json['id'],
      latitude: json['latitude'],
      longitude: json['longitude'],
    );
  }
}

void main() {
  runApp(const MyApp());
}

// Uygulamanın ana başlangıç widget'ı
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner:
          false, // Sağ üstteki "debug" yazısını kaldırır
      title: 'Akıllı Kaynak Planlayıcı',
      home: MapScreen(),
    );
  }
}

// Haritayı gösterecek olan ana ekran widget'ı (Stateful)
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapLayer _currentLayer = MapLayer.none;
  // Pin (işaretçi) listesini tutan state değişkeni
  final List<Pin> _pins = [];
  bool _isPlacingMarker = false;
  bool _isLoading =
      true; // Veri yüklenirken gösterilecek loading indicator için

  // --- API ve Sabitler ---
  // Yerel makinede çalışan backend için:
  // Android emülatör için: 'http://10.0.2.2:8000'
  // Web ve iOS simülatör için: 'http://127.0.0.1:8000'
  final String _apiBaseUrl = 'http://127.0.0.1:8000';
  final String myMapboxAccessToken =
      "pk.eyJ1IjoiZ3JrbmlzbWV0YSIsImEiOiJjbWdzODB4YmgyNTNrMmlzYTl4NmZxbnZpIn0.Ocbt8oI-AN4H5PedVops7A";
  final String myOpenWeatherApiKey = "b525f47f8adb6ddfceea1bc14bc72633";

  @override
  void initState() {
    super.initState();
    _fetchPins(); // Uygulama başlarken pinleri backend'den çek
  }

  // --- API Fonksiyonları ---

  Future<void> _fetchPins() async {
    try {
      final response = await http.get(Uri.parse('$_apiBaseUrl/pins/'));
      if (response.statusCode == 200) {
        List<dynamic> pinsJson = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _pins.clear();
          _pins.addAll(pinsJson.map((json) => Pin.fromJson(json)).toList());
          _isLoading = false;
        });
      } else {
        throw Exception(
          'Pinler yüklenemedi (Status code: ${response.statusCode})',
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog("Pinler yüklenemedi: ${e.toString()}");
    }
  }

  Future<void> _addPin(LatLng point) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/pins/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'latitude': point.latitude,
          'longitude': point.longitude,
        }),
      );
      if (response.statusCode == 201) {
        // Başarıyla eklendikten sonra listeyi yenile
        _fetchPins();
      } else {
        throw Exception('Pin eklenemedi (Status code: ${response.statusCode})');
      }
    } catch (e) {
      _showErrorDialog("Pin eklenemedi: ${e.toString()}");
    }
  }

  Future<void> _deletePin(int pinId) async {
    try {
      final response = await http.delete(Uri.parse('$_apiBaseUrl/pins/$pinId'));
      if (response.statusCode == 204) {
        // Başarıyla silindikten sonra listeyi yenile
        _fetchPins();
      } else {
        throw Exception('Pin silinemedi (Status code: ${response.statusCode})');
      }
    } catch (e) {
      _showErrorDialog("Pin silinemedi: ${e.toString()}");
    }
  }

  // --- UI Fonksiyonları ---

  void _changeMapLayer() {
    // ... (Bu fonksiyon değişmedi)
    setState(() {
      switch (_currentLayer) {
        case MapLayer.none:
          _currentLayer = MapLayer.wind;
          break;
        case MapLayer.wind:
          _currentLayer = MapLayer.temp;
          break;
        case MapLayer.temp:
          _currentLayer = MapLayer.none;
          break;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Aktif Katman: ${_getLayerName(_currentLayer)}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  String _getLayerName(MapLayer layer) {
    // ... (Bu fonksiyon değişmedi)
    switch (layer) {
      case MapLayer.wind:
        return 'Rüzgar';
      case MapLayer.temp:
        return 'Sıcaklık';
      default:
        return 'Yok';
    }
  }

  void _togglePlacingMarkerMode() {
    setState(() => _isPlacingMarker = !_isPlacingMarker);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isPlacingMarker
              ? 'Pin Ekleme Modu: Aktif'
              : 'Pin Ekleme Modu: Kapalı',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _handleMapTap(dynamic tapPosition, LatLng point) {
    if (_isPlacingMarker) {
      _addPin(point);
    }
  }

  void _showPinActionsDialog(Pin pin) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pin İşlemleri'),
        content: Text(
          'ID: ${pin.id}\nKonum: ${pin.latitude.toStringAsFixed(4)}, ${pin.longitude.toStringAsFixed(4)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deletePin(pin.id);
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hata'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pin listesini Marker listesine dönüştür
    List<Marker> markers = _pins.map((pin) {
      return Marker(
        width: 80.0,
        height: 80.0,
        point: LatLng(pin.latitude, pin.longitude),
        child: GestureDetector(
          onTap: () => _showPinActionsDialog(pin),
          child: const Icon(Icons.location_pin, color: Colors.red, size: 40.0),
        ),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Akıllı Kaynak Planlayıcı')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
                    if (_currentLayer == MapLayer.wind)
                      TileLayer(
                        urlTemplate:
                            'https://tile.openweathermap.org/map/wind_new/{z}/{x}/{y}.png?appid={apiKey}',
                        additionalOptions: {'apiKey': myOpenWeatherApiKey},
                      ),
                    if (_currentLayer == MapLayer.temp)
                      TileLayer(
                        urlTemplate:
                            'https://tile.openweathermap.org/map/temp_new/{z}/{x}/{y}.png?appid={apiKey}',
                        additionalOptions: {'apiKey': myOpenWeatherApiKey},
                      ),
                    MarkerLayer(markers: markers),
                  ],
                ),

                // KONTROL BUTONLARI
                Positioned(
                  top: 10.0,
                  right: 10.0,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        heroTag: 'btn1',
                        mini: true,
                        onPressed: () {},
                        child: const Icon(Icons.energy_savings_leaf),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: 'btn2',
                        mini: true,
                        backgroundColor: _isPlacingMarker
                            ? Colors.blue[800]
                            : Theme.of(context).primaryColor,
                        onPressed: _togglePlacingMarkerMode,
                        child: const Icon(Icons.add_location_alt),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: 'btn3',
                        mini: true,
                        onPressed: _changeMapLayer,
                        child: const Icon(Icons.layers),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
