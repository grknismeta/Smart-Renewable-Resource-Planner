// lib/features/reports/widgets/common/report_mini_map.dart
//
// Raporlar'a özel harita — Sprint Reports v3 + F4 (interaktif).
//
// Ana harita (MapScreen) state'ine dokunmaz. Marker gösterir:
//   - Bölge tab: bölgenin illeri (climatology skoruna göre renkli)
//   - İl tab: ilin ilçeleri
//
// 2026-05-25 (F4): Tıklanabilir + bbox-bound.
//   - `bounds` verilirse haritayı o sınırın dışına çıkmaya engeller
//     (MapOptions.maxBounds). Bölge/il seçilince haritada o sınırda kalır.
//   - `onMarkerTap` verilirse marker'a tıklayınca callback çalışır
//     (en yakın marker'a snap, threshold içinde — drill-down navigasyon için).

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre/maplibre.dart' as ml;

import 'package:frontend/core/network/api_client.dart';

/// 2026-05-27 (N4): Marker boyut profili.
/// `large` — eski default (skor bazlı 5-12 px, label görünür)
/// `compact` — yeni: sadece şehir/ilçe merkezini gösteren 3-4 px nokta,
///            label sadece highlight'ta. Polygon tıklamasıyla seçim yapılır.
enum ReportMarkerSize { large, compact }

/// Haritada gösterilecek tek bir nokta.
class ReportMapMarker {
  final double lat;
  final double lon;
  final String label;
  final double score; // 0-100 — renk + yarıçap
  final bool highlighted; // seçili öğe (daha büyük + parlak)

  const ReportMapMarker({
    required this.lat,
    required this.lon,
    required this.label,
    required this.score,
    this.highlighted = false,
  });
}

class ReportMiniMap extends StatefulWidget {
  final List<ReportMapMarker> markers;
  final double height;

  /// Skora göre renk yerine sabit tek renk kullan (örn. tüm pin'ler cyan).
  final Color? fixedColor;

  /// 2026-05-25 (F4): Verilirse haritayı bu bbox'a hapseder (setMaxBounds).
  /// Kullanıcı pan/zoom ile dışına çıkamaz — bölge/il seçildiğinde "sınır
  /// içinde kal" deneyimi.
  final ml.LngLatBounds? bounds;

  /// 2026-05-25 (F4): Padding derece cinsinden — sabit eklenir. Geri uyum için
  /// null değil; sıfır verirsen kapatılır. N4 ile dynamic alternatifi:
  /// `boundsPaddingRatio` kullanılınca bu alan ihmal edilir.
  final double boundsPadding; // derece — varsayılan 0.4°

  /// 2026-05-27 (N4): Bounds boyutunun yüzdesi (0.20 = %20). Verilirse
  /// `boundsPadding`'in yerine geçer — büyük bölgede daha geniş, küçük ilçede
  /// daha dar padding üretir. Caller kullanmazsa null kalır, eski davranış.
  final double? boundsPaddingRatio;

  /// 2026-05-25 (F4): Marker tıklama callback. En yakın marker (threshold
  /// içinde) ile çağrılır. Verilmezse harita salt gösterim.
  final ValueChanged<ReportMapMarker>? onMarkerTap;

  /// 2026-05-27 (N4): İlçe sınırlarını çiz. İl/bölge filtresi:
  /// - `districtProvinceFilter`: tek ilin tüm ilçeleri (en hafif endpoint)
  /// - `districtRegionFilter`: bölge → ilgili illerin ilçeleri
  /// İkisi de null ise ilçe katmanı çizilmez (geri uyum).
  final String? districtProvinceFilter;
  final String? districtRegionFilter;

  /// 2026-05-27 (N4): Marker boyut profili. `compact` raporlardaki yeni
  /// davranış (3-4 px sabit). `large` eski davranış (skor bazlı 5-12 px).
  final ReportMarkerSize markerSize;

  const ReportMiniMap({
    super.key,
    required this.markers,
    this.height = 260,
    this.fixedColor,
    this.bounds,
    this.boundsPadding = 0.4,
    this.boundsPaddingRatio,
    this.onMarkerTap,
    this.districtProvinceFilter,
    this.districtRegionFilter,
    this.markerSize = ReportMarkerSize.large,
  });

  @override
  State<ReportMiniMap> createState() => _ReportMiniMapState();
}

class _ReportMiniMapState extends State<ReportMiniMap> {
  ml.MapController? _map;
  ml.StyleController? _style;
  bool _ready = false;

  /// 2026-05-25 (G2): Tap-to-activate. Default false → tüm pointer event'ler
  /// AbsorbPointer ile yutulur, parent SingleChildScrollView normal kaydırır.
  /// Kullanıcı haritaya dokununca _active=true olur, mavi border + "Bitir"
  /// chip görünür, harita gesture'ları çalışır. "Bitir" chip → _active=false.
  bool _active = false;

  /// 2026-05-25 (H4): Marker'a tıklayınca alt-orta inline popup açılır
  /// (il/ilçe adı + skor + Detay butonu). "Detay" → caller'ın onMarkerTap
  /// callback'i çağrılır (drill-down). Popup kapatılabilir (×).
  ReportMapMarker? _selectedMarker;

  /// 2026-05-27 (N4): İlçe polygonları cache — fetch sonrası saklanır,
  /// polygon hit-test (point-in-polygon) için kullanılır. Empty list:
  /// fetch yapılmadı veya filtre yok. Null değil; "veri yok" anlamı için
  /// boş list bırakılır.
  List<Map<String, dynamic>> _districtFeatures = const [];
  String? _districtFilterKey; // değişimi tespit etmek için

  static const _styleUrl =
      'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json';

  // Türkiye geneli fallback merkez
  static const _fallbackCenter = (lon: 35.24, lat: 39.06);

  @override
  Widget build(BuildContext context) {
    // F4 + N4: bounds verilmişse padding ile genişletip MapOptions.maxBounds'a
    // ver. `boundsPaddingRatio` öncelikli — bounds size'ın yüzdesi (büyük
    // bölgede daha geniş, küçük ilçede daha dar).
    ml.LngLatBounds? paddedBounds;
    if (widget.bounds != null) {
      final b = widget.bounds!;
      double padDeg;
      if (widget.boundsPaddingRatio != null) {
        final spanLat = b.latitudeNorth.toDouble() - b.latitudeSouth.toDouble();
        final spanLon = b.longitudeEast.toDouble() - b.longitudeWest.toDouble();
        final span = math.max(spanLat, spanLon);
        padDeg = span * widget.boundsPaddingRatio!;
      } else {
        padDeg = widget.boundsPadding;
      }
      paddedBounds = ml.LngLatBounds(
        longitudeWest: b.longitudeWest - padDeg,
        latitudeSouth: b.latitudeSouth - padDeg,
        longitudeEast: b.longitudeEast + padDeg,
        latitudeNorth: b.latitudeNorth + padDeg,
      );
    }
    // Bounds değişimi MapOptions yeniden oluşturma ile yansır; ValueKey ile
    // widget'ı yeniden yarat (native init-time maxBounds için zorunlu).
    final mapKey = ValueKey(
      paddedBounds == null
          ? 'no-bounds'
          : '${paddedBounds.longitudeWest},${paddedBounds.latitudeSouth},'
              '${paddedBounds.longitudeEast},${paddedBounds.latitudeNorth}',
    );

    // 2026-05-25 (G2): Container border rengi aktiflik durumuna göre değişir.
    final borderColor = _active
        ? const Color(0xFF3B82F6) // mavi — aktif
        : Colors.white.withValues(alpha: 0.10); // pasif

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: borderColor, width: _active ? 2 : 1),
        boxShadow: _active
            ? [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: SizedBox(
          // 2026-06-01: Web/geniş ekranda harita çok küçük kalıyordu → 1.5×
          // dikey büyütme. Mobil (dar) olduğu gibi yeterli.
          height: MediaQuery.of(context).size.width >= 900
              ? widget.height * 1.5
              : widget.height,
          child: Stack(
            children: [
              // 2026-05-25 (H3): Harita aktive olduğunda parent
              // SingleChildScrollView gesture arena'da kazanıyordu — harita
              // pan/zoom çalışmıyordu. Çözüm: EagerGestureRecognizer ile
              // harita gesture'ları greedy claim eder, parent scroll alamaz.
              // Pasifken AbsorbPointer ile tüm gesture'lar yutulur (scroll
              // normal çalışır).
              AbsorbPointer(
                absorbing: !_active,
                child: ml.MapLibreMap(
                  key: mapKey,
                  options: ml.MapOptions(
                    initCenter:
                        ml.Position(_fallbackCenter.lon, _fallbackCenter.lat),
                    initZoom: 5.2,
                    initStyle: _styleUrl,
                    maxZoom: 11,
                    minZoom: 4,
                    maxBounds: paddedBounds,
                  ),
                  // Sadece aktif iken eager claim — pasifken normal yarış
                  // (AbsorbPointer zaten engelliyor).
                  gestureRecognizers: _active
                      ? <Factory<OneSequenceGestureRecognizer>>{
                          Factory<EagerGestureRecognizer>(
                              () => EagerGestureRecognizer()),
                        }
                      : null,
                  onMapCreated: (c) => _map = c,
                  onStyleLoaded: (s) {
                    _style = s;
                    _ready = true;
                    // N4: önce ilçe polygonları (altta), sonra marker'lar (üstte).
                    _renderDistrictBoundary().then((_) => _renderMarkers());
                    _fitToMarkers();
                  },
                  // 2026-05-25 (H4): onMarkerTap olmasa bile event dinleniyor —
                  // marker'a tıklayınca inline bilgi kartı her durumda açılır.
                  // Sadece "Detay" butonu onMarkerTap varsa görünür.
                  onEvent: _onMapEvent,
                ),
              ),
              // Pasifken aktivasyon overlay'i (tüm haritanın üstünde).
              if (!_active)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _active = true),
                    child: Container(
                      color: Colors.transparent,
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.20),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app_rounded,
                                size: 14, color: Colors.white70),
                            SizedBox(width: 6),
                            Text(
                              'Haritayla etkileşim için dokun',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              // Aktifken "Bitir" chip (sağ üst).
              if (_active)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _active = false;
                      _selectedMarker = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 3),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_rounded,
                              size: 13, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Bitir',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // 2026-05-25 (H4): Marker bilgi kartı — alt-orta, marker'a
              // tıklayınca açılır. "Detay" → caller drill-down.
              if (_selectedMarker != null)
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: _markerInfoCard(_selectedMarker!),
                ),
            if (widget.markers.isEmpty)
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Harita verisi yok',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }

  @override
  void didUpdateWidget(covariant ReportMiniMap old) {
    super.didUpdateWidget(old);
    if (!_ready) return;
    final filterChanged = old.districtProvinceFilter != widget.districtProvinceFilter ||
        old.districtRegionFilter != widget.districtRegionFilter;
    if (filterChanged) {
      _renderDistrictBoundary();
    }
    if (old.markers != widget.markers ||
        old.bounds != widget.bounds ||
        old.markerSize != widget.markerSize) {
      _renderMarkers();
      _fitToMarkers();
    }
  }

  String _colorFor(double score) {
    if (widget.fixedColor != null) {
      final c = widget.fixedColor!;
      return '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    }
    if (score >= 65) return '#10B981'; // yüksek — yeşil
    if (score >= 45) return '#F59E0B'; // orta — turuncu
    return '#EF4444'; // düşük — kırmızı
  }

  Future<void> _renderMarkers() async {
    final style = _style;
    if (style == null) return;

    // Eski layer/source temizle
    for (final id in ['rmm-circles', 'rmm-labels']) {
      try {
        await style.removeLayer(id);
      } catch (_) {}
    }
    try {
      await style.removeSource('rmm-src');
    } catch (_) {}

    if (widget.markers.isEmpty) return;

    // N4: Marker boyut profili
    //   compact → küçük 3 px nokta + highlight'ta 5 px (şehir merkezi göstergesi)
    //   large   → eski 5-12 px skor bazlı
    final compact = widget.markerSize == ReportMarkerSize.compact;

    final features = widget.markers.map((m) {
      final double radius;
      final double stroke;
      if (compact) {
        radius = m.highlighted ? 5.0 : 3.0;
        stroke = m.highlighted ? 1.5 : 0.8;
      } else {
        radius = m.highlighted
            ? 11.0
            : (5.0 + (m.score / 100) * 7).clamp(5.0, 12.0);
        stroke = m.highlighted ? 2.5 : 1.2;
      }
      return {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [m.lon, m.lat],
        },
        'properties': {
          'label': m.label,
          'color': _colorFor(m.score),
          'radius': radius,
          'stroke': stroke,
          'show_label': compact ? (m.highlighted ? 1 : 0) : 1,
        },
      };
    }).toList();

    final geojson = jsonEncode({
      'type': 'FeatureCollection',
      'features': features,
    });

    try {
      await style.addSource(ml.GeoJsonSource(id: 'rmm-src', data: geojson));
      await style.addLayer(
        ml.CircleStyleLayer(
          id: 'rmm-circles',
          sourceId: 'rmm-src',
          paint: {
            'circle-radius': ['get', 'radius'],
            'circle-color': ['get', 'color'],
            'circle-opacity': 0.85,
            'circle-stroke-width': ['get', 'stroke'],
            'circle-stroke-color': '#FFFFFF',
          },
        ),
      );
      // Etiket katmanı — N4 compact modda sadece highlight'lı marker'larda
      // (show_label==1) görünür, kalabalık önler.
      await style.addLayer(
        ml.SymbolStyleLayer(
          id: 'rmm-labels',
          sourceId: 'rmm-src',
          layout: {
            'text-field': ['get', 'label'],
            'text-size': compact ? 9.0 : 10.0,
            'text-offset': [0.0, 1.2],
            'text-anchor': 'top',
            'text-optional': true,
          },
          paint: {
            'text-color': '#FFFFFF',
            'text-halo-color': '#000000',
            'text-halo-width': 1.2,
            // compact: show_label flag'iyle opaque/transparent
            'text-opacity': compact
                ? ['case', ['==', ['get', 'show_label'], 1], 1.0, 0.0]
                : 1.0,
          },
        ),
      );
    } catch (e) {
      debugPrint('[ReportMiniMap] marker render hatası: $e');
    }
  }

  /// 2026-05-25 (H4): Tıklama event → en yakın marker → inline popup açar.
  /// Popup'taki "Detay" butonu caller'ın `onMarkerTap` callback'ini çağırır
  /// (drill-down). Boş alana tıklama varsa popup'ı kapatır.
  ///
  /// 2026-05-27 (N4): İlçe polygonları yüklü ise önce point-in-polygon
  /// hit-test → o ilçenin marker'ını seç (eğer marker olarak listede varsa).
  /// Bu sayede kullanıcı küçük şehir merkezi noktasına denk getirmeden
  /// ilçenin herhangi bir yerine tıklayarak seçim yapabilir.
  void _onMapEvent(ml.MapEvent event) {
    if (event is! ml.MapEventClick) return;
    if (widget.markers.isEmpty) return;
    final lon = event.point.lng.toDouble();
    final lat = event.point.lat.toDouble();

    // N4: önce polygon hit-test (varsa)
    final hitDistrict = _districtAt(lat, lon);
    if (hitDistrict != null) {
      // Marker listesinde aynı isimle eşleşen var mı? Eşleşirse onu seç.
      final asciiHit = _asciiFold(hitDistrict).toLowerCase();
      ReportMapMarker? match;
      for (final m in widget.markers) {
        if (_asciiFold(m.label).toLowerCase() == asciiHit) {
          match = m;
          break;
        }
      }
      if (match != null) {
        setState(() => _selectedMarker = match);
        return;
      }
      // Polygon hit ama marker yok → popup kapat (info kart gösterilemez)
    }

    // Marker fallback: en yakın marker (Euclidean)
    ReportMapMarker? nearest;
    double nearestD = double.infinity;
    for (final m in widget.markers) {
      final d = math.sqrt(
        math.pow(m.lat - lat, 2) + math.pow((m.lon - lon) * 0.7, 2),
      );
      if (d < nearestD) {
        nearestD = d;
        nearest = m;
      }
    }
    // Threshold ~0.6° (~60 km) — marker yakın ise popup aç, uzak ise popup
    // kapat (kullanıcı boş alana tıklamış gibi).
    setState(() {
      if (nearest != null && nearestD < 0.6) {
        _selectedMarker = nearest;
      } else {
        _selectedMarker = null;
      }
    });
  }

  /// ASCII fold helper — "Beşiktaş" → "Besiktas".
  String _asciiFold(String s) => s
      .replaceAll('İ', 'I')
      .replaceAll('ı', 'i')
      .replaceAll('Ş', 'S')
      .replaceAll('ş', 's')
      .replaceAll('Ç', 'C')
      .replaceAll('ç', 'c')
      .replaceAll('Ğ', 'G')
      .replaceAll('ğ', 'g')
      .replaceAll('Ü', 'U')
      .replaceAll('ü', 'u')
      .replaceAll('Ö', 'O')
      .replaceAll('ö', 'o');

  /// 2026-05-27 (N4): (lat, lon) koordinatı hangi ilçe polygonunda? Ray-casting
  /// point-in-polygon. Performans: GeoJSON 940 ilçe için 10K vertex, O(n)
  /// tek nokta için ~5-10 ms. Filter ile zaten ~50-500 KB veri tutuluyor.
  String? _districtAt(double lat, double lon) {
    for (final f in _districtFeatures) {
      final geom = f['geometry'] as Map?;
      if (geom == null) continue;
      final type = geom['type'] as String?;
      final coords = geom['coordinates'];
      if (coords is! List) continue;

      bool inside = false;
      if (type == 'Polygon') {
        inside = _pointInPolygon(lat, lon, coords);
      } else if (type == 'MultiPolygon') {
        for (final poly in coords) {
          if (_pointInPolygon(lat, lon, poly)) {
            inside = true;
            break;
          }
        }
      }
      if (inside) {
        final props = f['properties'] as Map?;
        return props?['NAME_2']?.toString();
      }
    }
    return null;
  }

  /// Ray-casting algoritması. `polygonCoords` = [outerRing, innerRing1, ...].
  /// Outer ring içinde + inner ring dışında → inside.
  bool _pointInPolygon(double lat, double lon, List polygonCoords) {
    if (polygonCoords.isEmpty) return false;
    bool inside = false;
    // Sadece outer ring (ilk eleman) — Türkiye ilçeleri pratikte inner ring
    // (delik) içermez.
    final outer = polygonCoords[0];
    if (outer is! List) return false;
    int j = outer.length - 1;
    for (int i = 0; i < outer.length; i++) {
      final xi = (outer[i][0] as num).toDouble();
      final yi = (outer[i][1] as num).toDouble();
      final xj = (outer[j][0] as num).toDouble();
      final yj = (outer[j][1] as num).toDouble();
      final intersect = ((yi > lat) != (yj > lat)) &&
          (lon < (xj - xi) * (lat - yi) / (yj - yi + 1e-12) + xi);
      if (intersect) inside = !inside;
      j = i;
    }
    return inside;
  }

  /// 2026-05-27 (N4): İlçe sınırlarını fetch + style'a ekle.
  /// Filter:
  ///   • `districtProvinceFilter` → tek il (~50 KB)
  ///   • `districtRegionFilter` → bölge (~500 KB)
  ///   • İkisi de null → çizilmez (geri uyum)
  Future<void> _renderDistrictBoundary() async {
    final style = _style;
    if (style == null) return;

    // Filter yoksa: eski layer'ları temizle ve çık
    final hasFilter = (widget.districtProvinceFilter ?? '').isNotEmpty ||
        (widget.districtRegionFilter ?? '').isNotEmpty;
    final filterKey =
        '${widget.districtProvinceFilter ?? ''}|${widget.districtRegionFilter ?? ''}';

    // Aynı filter ise yeniden yükleme
    if (filterKey == _districtFilterKey && hasFilter) return;
    _districtFilterKey = filterKey;

    // Önce eski layer/source temizle
    for (final id in ['rmm-dist-line', 'rmm-dist-fill']) {
      try {
        await style.removeLayer(id);
      } catch (_) {}
    }
    try {
      await style.removeSource('rmm-dist-src');
    } catch (_) {}
    _districtFeatures = const [];

    if (!hasFilter) return;

    // Endpoint URL'ini oluştur
    final params = <String, String>{};
    if ((widget.districtProvinceFilter ?? '').isNotEmpty) {
      params['province'] = widget.districtProvinceFilter!;
    }
    if ((widget.districtRegionFilter ?? '').isNotEmpty) {
      params['region'] = widget.districtRegionFilter!;
    }
    final qs = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final url = '${BaseService.webApiBase}/geo/borders/districts?$qs';

    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) {
        debugPrint('[ReportMiniMap] district fetch ${resp.statusCode}: $url');
        return;
      }
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final features = (decoded['features'] as List? ?? const [])
          .cast<Map<String, dynamic>>();
      _districtFeatures = features;

      // GeoJSON'u source'a yaz
      await style.addSource(ml.GeoJsonSource(
        id: 'rmm-dist-src',
        data: resp.body,
      ));
      // Fill katmanı — çok hafif (subtle)
      await style.addLayer(
        ml.FillStyleLayer(
          id: 'rmm-dist-fill',
          sourceId: 'rmm-dist-src',
          paint: {
            'fill-color': '#3B82F6',
            'fill-opacity': 0.05,
          },
        ),
      );
      // Line katmanı — daha belirgin
      await style.addLayer(
        ml.LineStyleLayer(
          id: 'rmm-dist-line',
          sourceId: 'rmm-dist-src',
          paint: {
            'line-color': '#3B82F6',
            'line-width': 1.2,
            'line-opacity': 0.55,
          },
        ),
      );
      debugPrint(
        '[ReportMiniMap] ${features.length} ilçe polygonu yüklendi ($url)',
      );
    } catch (e) {
      debugPrint('[ReportMiniMap] district render hatası: $e');
    }
  }

  /// Marker'lara göre kamerayı ortalar + uygun zoom hesaplar.
  /// 2026-05-25 (H4): Marker bilgi kartı — alt-orta inline popup.
  /// İçerikte: marker label (il/ilçe adı) + skor badge + Detay/Kapat butonları.
  Widget _markerInfoCard(ReportMapMarker m) {
    Color scoreColor;
    if (m.score >= 65) {
      scoreColor = const Color(0xFF10B981);
    } else if (m.score >= 45) {
      scoreColor = const Color(0xFFF59E0B);
    } else {
      scoreColor = const Color(0xFFEF4444);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scoreColor.withValues(alpha: 0.50)),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Icon(Icons.location_on_rounded, size: 14, color: scoreColor),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  m.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Skor ${m.score.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: scoreColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Detay butonu — caller'ın drill-down callback'i
          if (widget.onMarkerTap != null) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: () {
                final marker = _selectedMarker;
                if (marker != null) {
                  widget.onMarkerTap!(marker);
                  setState(() => _selectedMarker = null);
                }
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.cyanAccent.withValues(alpha: 0.50),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Detay',
                      style: TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 3),
                    Icon(Icons.chevron_right_rounded,
                        size: 14, color: Colors.cyanAccent),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(width: 4),
          InkWell(
            onTap: () => setState(() => _selectedMarker = null),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.all(3),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fitToMarkers() async {
    final map = _map;
    if (map == null || widget.markers.isEmpty) return;

    // F4: bounds verilmişse bounds'a fit, marker bbox'una değil.
    if (widget.bounds != null) {
      final b = widget.bounds!;
      final cLat = (b.latitudeSouth.toDouble() + b.latitudeNorth.toDouble()) / 2;
      final cLon = (b.longitudeWest.toDouble() + b.longitudeEast.toDouble()) / 2;
      final span = math.max(
        b.latitudeNorth.toDouble() - b.latitudeSouth.toDouble(),
        (b.longitudeEast.toDouble() - b.longitudeWest.toDouble()) * 0.7,
      );
      double zoom;
      if (span > 8) {
        zoom = 4.8;
      } else if (span > 4) {
        zoom = 5.6;
      } else if (span > 2) {
        zoom = 6.6;
      } else if (span > 1) {
        zoom = 7.6;
      } else if (span > 0.4) {
        zoom = 8.6;
      } else {
        zoom = 9.4;
      }
      try {
        map.animateCamera(
          center: ml.Position(cLon, cLat),
          zoom: zoom,
          nativeDuration: const Duration(milliseconds: 600),
        );
      } catch (e) {
        debugPrint('[ReportMiniMap] bounds fit hatası: $e');
      }
      return;
    }

    final lats = widget.markers.map((m) => m.lat).toList();
    final lons = widget.markers.map((m) => m.lon).toList();
    final minLat = lats.reduce(math.min);
    final maxLat = lats.reduce(math.max);
    final minLon = lons.reduce(math.min);
    final maxLon = lons.reduce(math.max);

    final centerLat = (minLat + maxLat) / 2;
    final centerLon = (minLon + maxLon) / 2;

    // Yayılıma göre kabaca zoom — derece span'ı büyükse uzak.
    final span = math.max(maxLat - minLat, (maxLon - minLon) * 0.7);
    double zoom;
    if (span > 8) {
      zoom = 4.6;
    } else if (span > 4) {
      zoom = 5.4;
    } else if (span > 2) {
      zoom = 6.4;
    } else if (span > 1) {
      zoom = 7.4;
    } else if (span > 0.4) {
      zoom = 8.4;
    } else {
      zoom = 9.2;
    }

    try {
      map.animateCamera(
        center: ml.Position(centerLon, centerLat),
        zoom: zoom,
        nativeDuration: const Duration(milliseconds: 600),
      );
    } catch (e) {
      debugPrint('[ReportMiniMap] fit hatası: $e');
    }
  }
}
