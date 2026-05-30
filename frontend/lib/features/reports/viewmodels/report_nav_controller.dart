// lib/features/reports/viewmodels/report_nav_controller.dart
//
// Raporlar tab'ları arası drill-down navigasyonu — Sprint R1.
//
// v3 hiyerarşi: Landing → Bölge → İl → İlçe
// Tab'lar ayrı ChangeNotifierProvider scope'larında olduğu için, bir tab'tan
// diğerine "şunu seç" mesajı geçirmek için report_screen seviyesinde paylaşılan
// bu controller kullanılır.
//
// Akış:
//   1. Landing bölge kartı tıklanır → requestRegion(id) + TabController.animateTo(1)
//   2. RegionTab build olur → pendingRegionId'yi tüketir → o bölgeyi seçer
//   3. RegionTab il kartı tıklanır → requestProvince(name) + animateTo(2)
//   4. ProvinceDrillTab build olur → pendingProvince'i tüketir → o ili seçer

import 'package:flutter/foundation.dart';

class ReportNavController extends ChangeNotifier {
  String? _pendingRegionId;
  String? _pendingProvince;
  /// 2026-05-25 (Polish1): Senaryo pin haritasından Santral tab'ına geçerken
  /// hangi pinin seçileceğini taşır.
  int? _pendingPinId;

  String? get pendingRegionId => _pendingRegionId;
  String? get pendingProvince => _pendingProvince;
  int? get pendingPinId => _pendingPinId;

  /// Landing → Bölge tab geçişi için bölge id ayarlar.
  void requestRegion(String regionId) {
    _pendingRegionId = regionId;
    notifyListeners();
  }

  /// Bölge → İl tab geçişi için il adı ayarlar.
  void requestProvince(String province) {
    _pendingProvince = province;
    notifyListeners();
  }

  /// Senaryo → Santral tab geçişi için pin id ayarlar.
  void requestPin(int pinId) {
    _pendingPinId = pinId;
    notifyListeners();
  }

  /// RegionTab pendingRegionId'yi okuduktan sonra çağırır (tek-kullanımlık).
  String? consumeRegion() {
    final r = _pendingRegionId;
    _pendingRegionId = null;
    return r;
  }

  /// ProvinceDrillTab pendingProvince'i okuduktan sonra çağırır.
  String? consumeProvince() {
    final p = _pendingProvince;
    _pendingProvince = null;
    return p;
  }

  /// SantralTab pendingPinId'yi okuduktan sonra çağırır.
  int? consumePin() {
    final id = _pendingPinId;
    _pendingPinId = null;
    return id;
  }
}
