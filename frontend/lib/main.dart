import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

void main() {
  // Flutter'a, runApp çalışmadan önce temel servisleri
  // hazır hale getirmesi gerektiğini söylüyoruz.
  WidgetsFlutterBinding.ensureInitialized();

  // Access Token'ı uygulama başlamadan önce burada global olarak ayarlıyoruz.
  MapboxOptions.setAccessToken(
    "pk.eyJ1IjoiZ3JrbmlzbWV0YSIsImEiOiJjbWdzODB4YmgyNTNrMmlzYTl4NmZxbnZpIn0.Ocbt8oI-AN4H5PedVops7A",
  );

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
      title: 'Mapbox Prototipi',
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
  MapboxMap? mapboxMap;

  _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    print("Mapbox haritası başarıyla oluşturuldu!");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Akıllı Kaynak Planlayıcı')),
      // Stack widget'ı, çocuklarını (children) üst üste yığmamızı sağlar.
      body: Stack(
        children: [
          // 1. Katman (En Altta): Harita
          MapWidget(
            onMapCreated: _onMapCreated,
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(27.4289, 38.6191)),
              zoom: 10.0,
            ),
            styleUri: MapboxStyles.MAPBOX_STREETS,
          ),

          // 2. Katman (Üstte): Kontrol Butonları Paneli
          // Positioned widget'ı, bir Stack içinde çocuğunun konumunu belirlememizi sağlar.
          Positioned(
            top: 10.0, // Yukarıdan 10 piksel boşluk
            right: 10.0, // Sağdan 10 piksel boşluk
            child: Column(
              // Butonları alt alta dizmek için Column
              children: [
                // Buton 1: Enerji Türü Seçimi
                FloatingActionButton(
                  heroTag: 'btn1', // Her butona farklı bir tag vermek önemlidir
                  mini: true, // Butonu küçültür
                  onPressed: () {
                    print("Enerji Türü Seçimi butonuna basıldı!");
                    // TODO: Enerji türü seçim menüsünü aç
                  },
                  child: const Icon(Icons.energy_savings_leaf),
                ),
                const SizedBox(height: 8), // Butonlar arası boşluk
                // Buton 2: Yerleşim Aracı
                FloatingActionButton(
                  heroTag: 'btn2',
                  mini: true,
                  onPressed: () {
                    print("Yerleşim Aracı butonuna basıldı!");
                    // TODO: Alan seçim modunu değiştir
                  },
                  child: const Icon(Icons.add_location_alt),
                ),
                const SizedBox(height: 8),

                // Buton 3: Harita Katmanı
                FloatingActionButton(
                  heroTag: 'btn3',
                  mini: true,
                  onPressed: () {
                    print("Harita Katmanı butonuna basıldı!");
                    // TODO: Harita katmanını değiştir
                  },
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
//```eof

//### Sonuç

//Bu kodu kaydedip uygulamayı telefonunda yeniden başlattığında, Manisa haritasının sağ üst köşesinde, alt alta duran üç tane yuvarlak buton göreceksin. Bu butonlara bastığında, VS Code'daki **DEBUG CONSOLE**'da ilgili `print` mesajlarını göreceksin.

//**Tebrikler!** Artık sadece çalışan bir haritan yok, aynı zamanda vizyonundaki interaktif kullanıcı arayüzünün ilk parçasını da inşa ettin. Buradan sonra bu butonların içini doldurmak, yeni paneller eklemek ve projeni adım adım büyütmek kalıyor.

/*
// MapScreen widget'ının state'ini (durumunu) yöneten class
class _MapScreenState extends State<MapScreen> {
  // Harita kontrolcüsünü tutmak için bir değişken
  MapboxMap? mapboxMap;

  // Harita oluşturulduğunda çağrılacak olan fonksiyon
  _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    print("Mapbox haritası başarıyla oluşturuldu!");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Akıllı Kaynak Planlayıcı')),
      body: kIsWeb
          // UYGULAMA WEB'DE ÇALIŞIYORSA:
          // Ekrana bir uyarı mesajı bas.
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Harita özelliği web platformunda henüz desteklenmemektedir.\nLütfen mobil cihazınızda test ediniz.',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          // UYGULAMA MOBİLDE ÇALIŞIYORSA (Android/iOS):
          // Haritayı normal şekilde göster.
          : MapWidget(
              onMapCreated: _onMapCreated,
              cameraOptions: CameraOptions(
                center: Point(
                  coordinates: Position(27.4289, 38.6191),
                ), // Manisa
                zoom: 10.0,
              ),
              styleUri:
                  MapboxStyles.MAPBOX_STREETS, // Daha modern bir harita stili
            ),
    );
  }
}
*/
