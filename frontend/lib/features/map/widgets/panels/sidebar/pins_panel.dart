// lib/presentation/widgets/sidebar/pins_panel.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/data/models/pin_model.dart';
import 'package:frontend/features/map/viewmodels/map_view_model.dart';
import 'package:frontend/core/theme/theme_view_model.dart';
import 'package:frontend/core/network/api_service.dart';
import 'package:frontend/features/map/dialogs/map_dialogs.dart';

/// Sidebar'da pin listesini gösteren panel
/// Sidebar'da pin listesini gösteren panel
class PinsPanel extends StatefulWidget {
  final ThemeViewModel theme;
  final MapViewModel mapViewModel;
  final bool isCollapsed;

  const PinsPanel({
    super.key,
    required this.theme,
    required this.mapViewModel,
    required this.isCollapsed,
  });

  @override
  State<PinsPanel> createState() => _PinsPanelState();
}

class _PinsPanelState extends State<PinsPanel> {
  bool _isExpanded = false;
  bool _isReanalyzing = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isCollapsed) {
      // Dar modda sadece ikon
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Icon(
          Icons.location_on,
          color: widget.theme.secondaryTextColor.withValues(alpha: 0.6),
        ),
      );
    }

    final solarPins = widget.mapViewModel.pins
        .where((p) => p.type == 'Güneş Paneli')
        .toList();
    final windPins = widget.mapViewModel.pins
        .where((p) => p.type == 'Rüzgar Türbini')
        .toList();
    final hesPins = widget.mapViewModel.pins
        .where((p) => p.type == 'Hidroelektrik')
        .toList();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.theme.cardColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.theme.secondaryTextColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık ve Genişletme Butonu
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: widget.theme.textColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pinlerim',
                  style: TextStyle(
                    color: widget.theme.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: widget.theme.backgroundColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.mapViewModel.pins.length}',
                    style: TextStyle(
                      color: widget.theme.textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                if (widget.mapViewModel.pins.isNotEmpty)
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: widget.theme.secondaryTextColor,
                  ),
              ],
            ),
          ),

          // Genişletilmiş Liste
          if (_isExpanded) ...[
            const SizedBox(height: 8),

            // Tüm Pinleri Güncelle butonu
            if (widget.mapViewModel.pins.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 30,
                child: OutlinedButton.icon(
                  onPressed: _isReanalyzing ? null : _batchReanalyze,
                  icon: _isReanalyzing
                      ? SizedBox(
                          width: 12, height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: widget.theme.secondaryTextColor,
                          ),
                        )
                      : Icon(Icons.refresh_rounded, size: 14,
                          color: Colors.tealAccent.withValues(alpha: 0.8)),
                  label: Text(
                    _isReanalyzing ? 'Güncelleniyor…' : 'Tüm Pinleri Güncelle',
                    style: TextStyle(
                      fontSize: 10,
                      color: _isReanalyzing
                          ? widget.theme.secondaryTextColor
                          : Colors.tealAccent.withValues(alpha: 0.9),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Colors.tealAccent.withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // Güneş Panelleri
            if (solarPins.isNotEmpty) ...[
              _buildCategoryHeader(
                'Güneş Panelleri',
                solarPins.length,
                Colors.orange,
              ),
              const SizedBox(height: 6),
              ...solarPins.map(
                (pin) => _buildPinItem(context, pin, Colors.orange),
              ),
              const SizedBox(height: 8),
            ],

            // Rüzgar Türbinleri
            if (windPins.isNotEmpty) ...[
              _buildCategoryHeader(
                'Rüzgar Türbinleri',
                windPins.length,
                Colors.blue,
              ),
              const SizedBox(height: 6),
              ...windPins.map(
                (pin) => _buildPinItem(context, pin, Colors.blue),
              ),
              const SizedBox(height: 8),
            ],

            // HES Kurulumları
            if (hesPins.isNotEmpty) ...[
              _buildCategoryHeader(
                'HES Kurulumları',
                hesPins.length,
                const Color(0xFF00BCD4),
              ),
              const SizedBox(height: 6),
              ...hesPins.map(
                (pin) => _buildPinItem(context, pin, const Color(0xFF00BCD4)),
              ),
            ],

            if (widget.mapViewModel.pins.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Henüz pin yok',
                  style: TextStyle(
                    color: widget.theme.secondaryTextColor,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _batchReanalyze() async {
    setState(() => _isReanalyzing = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final result = await api.resource.batchReanalyze();
      final updated = result['updated'] ?? 0;
      final errors = result['errors'] ?? 0;
      if (mounted) {
        // Pinleri yeniden yükle
        await widget.mapViewModel.fetchPins();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$updated pin güncellendi${errors > 0 ? ', $errors hata' : ''}'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Güncelleme hatası: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isReanalyzing = false);
    }
  }

  Widget _buildCategoryHeader(String title, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: widget.theme.secondaryTextColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '($count)',
          style: TextStyle(
            color: widget.theme.secondaryTextColor.withValues(alpha: 0.6),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildPinItem(BuildContext context, Pin pin, Color accentColor) {
    // DB'de kayıtlı konum bilgisi varsa onu kullan, yoksa cache'e bak
    final cityName = pin.locationLabel.isNotEmpty
        ? pin.locationLabel
        : widget.mapViewModel.pinCityName(pin.id);
    final coords = '(${pin.latitude.toStringAsFixed(3)}, ${pin.longitude.toStringAsFixed(3)})';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => MapDialogs.showPinActionsDialog(context, pin),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: widget.theme.backgroundColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  pin.type == 'Güneş Paneli'
                      ? Icons.wb_sunny
                      : pin.type == 'Hidroelektrik'
                      ? Icons.water_drop
                      : Icons.wind_power,
                  color: accentColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Şehir/İlçe adı (en başta) veya pin adı
                      if (cityName.isNotEmpty)
                        Text(
                          cityName,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      // Pin adı + koordinat
                      Text(
                        cityName.isNotEmpty ? '${pin.name} $coords' : '${pin.name} $coords',
                        style: TextStyle(
                          color: widget.theme.textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${pin.capacityMw.toStringAsFixed(1)} MW',
                        style: TextStyle(
                          color: widget.theme.secondaryTextColor,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: widget.theme.secondaryTextColor.withValues(alpha: 0.4),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
