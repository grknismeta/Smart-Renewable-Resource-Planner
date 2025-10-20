// lib/data/models/pin_model.dart

// API'den gelen temel kaynak (Pin) yapısı
class Pin {
  final int id;
  final String name; 
  final String type; 
  final double capacityMw; 
  final double latitude;
  final double longitude;

  Pin({
    required this.id,
    required this.name,
    required this.type,
    required this.capacityMw,
    required this.latitude,
    required this.longitude,
  });

  factory Pin.fromJson(Map<String, dynamic> json) {
    return Pin(
      id: json['id'] as int,
      name: json['name'] as String,
      type: json['type'] as String,
      capacityMw: (json['capacity_mw'] as num).toDouble(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
  
  // Pin oluştururken/hesaplarken API'ye göndereceğimiz JSON yapısı
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'capacity_mw': capacityMw,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

// Enerji Hesaplama API'sinden dönen sonuç yapısı
class PinResult {
  final double potentialKwhAnnual; // Yıllık potansiyel enerji üretimi (kWh)
  final double estimatedCost;        // Tahmini Kurulum Maliyeti (TL/USD)
  final double roiYears;             // Yatırımın Geri Dönüş Süresi (Yıl)

  PinResult({
    required this.potentialKwhAnnual,
    required this.estimatedCost,
    required this.roiYears,
  });

  factory PinResult.fromJson(Map<String, dynamic> json) {
    return PinResult(
      potentialKwhAnnual: (json['potential_kwh_annual'] as num).toDouble(),
      estimatedCost: (json['estimated_cost'] as num).toDouble(),
      roiYears: (json['roi_years'] as num).toDouble(),
    );
  }
}

// Kayıt ve Giriş için boş bir User modeline gerek yok, API sadece token kullanıyor.
// Ancak gelecekte kullanıcı bilgisi tutulabilir.
class User {
  final int id;
  final String email;

  User({required this.id, required this.email});
}
