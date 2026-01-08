import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'dart:ui'; // For window.physicalSize and ImageFilter

import '../../../../data/models/pin_model.dart';
import '../../../../core/api_services/api_service.dart';
import '../../../viewmodels/theme_view_model.dart';
import '../../map/viewmodels/map_view_model.dart';
import '../../pins/viewmodels/pin_dialog_viewmodel.dart';

import '../../../widgets/common/themed_inputs.dart';
import '../../pins/widgets/equipment_selector_widget.dart';
import '../widgets/energy_output_widget.dart';


class PinDetailsDialog extends StatefulWidget {
  final Pin pin;

  const PinDetailsDialog({super.key, required this.pin});

  static void show(BuildContext context, Pin pin) {
    showDialog(
      context: context,
      barrierDismissible: true, // Allow clicking outside
      builder: (_) => PinDetailsDialog(pin: pin),
    );
  }

  @override
  State<PinDetailsDialog> createState() => _PinDetailsDialogState();
}

class _PinDetailsDialogState extends State<PinDetailsDialog> {
  bool _isEditing = false;
  late Pin _currentPin;
  bool _isAnalyzing = false;

  // Edit Mode State
  PinDialogViewModel? _editViewModel;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _currentPin = widget.pin;
    _nameController = TextEditingController(text: _currentPin.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _editViewModel?.dispose();
    super.dispose();
  }

  void _enterEditMode() {
    final mapViewModel = Provider.of<MapViewModel>(context, listen: false);
    _editViewModel = PinDialogViewModel(
      mapViewModel,
      _currentPin.type,
      initialEquipmentId: _currentPin.equipmentId,
    );
    
    // Set initial values
    if (_currentPin.panelArea != null) {
      _editViewModel!.setPanelArea(_currentPin.panelArea.toString());
    }
    
    _editViewModel!.loadInitialData();
    setState(() {
      _isEditing = true;
    });
  }

  void _cancelEdit() {
    _editViewModel?.dispose();
    _editViewModel = null;
    _nameController.text = _currentPin.name;
    setState(() {
      _isEditing = false;
    });
  }

  Future<void> _handleUpdateSaved() async {
    if (_editViewModel == null) return;
    
    final validationError = _editViewModel!.validate();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(validationError), backgroundColor: Colors.red));
      return;
    }

    final capacityMw = _editViewModel!.getSelectedCapacityMw();
    if (capacityMw == null) return;

    final mapViewModel = Provider.of<MapViewModel>(context, listen: false);
    try {
      final updatedPin = await mapViewModel.updatePin(
        _currentPin.id,
        LatLng(_currentPin.latitude, _currentPin.longitude),
        _nameController.text,
        _editViewModel!.selectedType,
        capacityMw,
        _editViewModel!.selectedEquipmentId,
        _editViewModel!.panelArea,
      );
      
      setState(() {
        _currentPin = updatedPin;
        _isEditing = false;
      });
      _editViewModel?.dispose();
      _editViewModel = null;
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
  }

  Future<void> _handleAnalyze() async {
    setState(() => _isAnalyzing = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final updatedPin = await apiService.resource.analyzePin(_currentPin.id);
      
      // Update global list as well if needed, but for now just local state
      setState(() {
        _currentPin = updatedPin;
      });
      
      // Notify user
      if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Analiz güncellendi"), backgroundColor: Colors.green),
         );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeViewModel>(context);

    return Dialog(
      backgroundColor: Colors.transparent, // Glass effect requires transparent bg
      insetPadding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
             constraints: const BoxConstraints(maxWidth: 450),
             decoration: BoxDecoration(
               color: theme.cardColor.withValues(alpha: 0.8),
               borderRadius: BorderRadius.circular(20),
               border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
             ),
             child: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                 _buildHeader(theme),
                 Flexible(
                   child: SingleChildScrollView(
                     padding: const EdgeInsets.all(20),
                     child: _isEditing ? _buildEditForm(theme) : _buildViewContent(theme),
                   ),
                 ),
               ],
             ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeViewModel theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.secondaryTextColor.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          Icon(
            _currentPin.type == 'Güneş Paneli' ? Icons.wb_sunny : Icons.wind_power,
            color: _currentPin.type == 'Güneş Paneli' ? Colors.orange : Colors.blue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isEditing ? '${_currentPin.name} Kaynağını Güncelle' : _currentPin.name,
              style: TextStyle(
                color: theme.textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: theme.secondaryTextColor),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildViewContent(ThemeViewModel theme) {
    // Analiz verisi varsa EnergyOutputWidget göster
    if (_currentPin.analysis != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EnergyOutputWidget(result: _currentPin.analysis!, theme: theme),
          const SizedBox(height: 20),
          // Actions Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               // Güncelle Butonu
               ElevatedButton.icon(
                 onPressed: _isAnalyzing ? null : _handleAnalyze,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.cardColor,
                    foregroundColor: theme.textColor,
                    elevation: 0,
                    side: BorderSide(color: theme.secondaryTextColor.withValues(alpha: 0.2)),
                  ),
                  icon: _isAnalyzing 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(_isAnalyzing ? "..." : "Güncelle"),
               ),
               const SizedBox(width: 12),
               // Düzenle Butonu
               ElevatedButton.icon(
                  onPressed: _enterEditMode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.cardColor,
                    foregroundColor: theme.textColor,
                    elevation: 0,
                    side: BorderSide(color: theme.secondaryTextColor.withValues(alpha: 0.2)),
                  ),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text("Düzenle"),
               ),
               const SizedBox(width: 12),
               // Kapat Butonu
               ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A2D3E), // Dark button
                    foregroundColor: Colors.white70,
                  ),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text("Kapat"),
               ),
            ],
          ),
        ],
      );
    }

    // Analiz verisi yoksa eski view (konum + analiz butonu)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Location Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.backgroundColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on, color: theme.secondaryTextColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "${_currentPin.latitude.toStringAsFixed(4)}, ${_currentPin.longitude.toStringAsFixed(4)}",
                  style: TextStyle(color: theme.textColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        Container(
           padding: const EdgeInsets.all(16),
           decoration: BoxDecoration(
             color: Colors.orange.withValues(alpha: 0.1),
             borderRadius: BorderRadius.circular(12),
             border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
           ),
           child: Column(
             children: [
               const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
               const SizedBox(height: 12),
               const Text(
                 "Henüz analiz verisi yok.",
                 style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
               ),
               const SizedBox(height: 8),
               Text(
                 "Detaylı üretim tahmini için verileri güncelleyin.",
                 style: TextStyle(color: theme.secondaryTextColor, fontSize: 13),
                 textAlign: TextAlign.center,
               ),
             ],
           ),
         ),
         const SizedBox(height: 24),

        // Actions
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isAnalyzing ? null : _handleAnalyze,
                icon: _isAnalyzing 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Icon(Icons.refresh),
                label: Text(_isAnalyzing ? "Hesaplanıyor..." : "Analizi Başlat"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _enterEditMode,
                icon: const Icon(Icons.edit),
                label: const Text("Düzenle"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.textColor,
                  side: BorderSide(color: theme.secondaryTextColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  


  Widget _buildEditForm(ThemeViewModel theme) {
    if (_editViewModel == null) return const SizedBox();
    
    return ChangeNotifierProvider.value(
       value: _editViewModel!,
       child: Consumer<PinDialogViewModel>(
         builder: (ctx, vm, _) {
           return Column(
             crossAxisAlignment: CrossAxisAlignment.stretch,
             children: [
                ThemedTextField(
                  controller: _nameController, 
                  label: "Kaynak Adı", 
                  theme: theme
                ),
                const SizedBox(height: 16),
                
                // Type Switcher
                Container(
                  decoration: BoxDecoration(
                    color: theme.backgroundColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildTypeOption(theme, "Güneş Paneli", Icons.wb_sunny, vm.selectedType == "Güneş Paneli", () => vm.changeType("Güneş Paneli")),
                      _buildTypeOption(theme, "Rüzgar Türbini", Icons.wind_power, vm.selectedType == "Rüzgar Türbini", () => vm.changeType("Rüzgar Türbini")),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                EquipmentSelectorWidget(
                  equipments: vm.availableEquipments,
                  selectedEquipmentId: vm.selectedEquipmentId,
                  isLoading: vm.isLoadingEquipments,
                  theme: theme,
                  onChanged: (id) { if(id!=null) vm.selectEquipment(id); },
                ),
                
                if (vm.selectedType == 'Güneş Paneli') ...[
                   const SizedBox(height: 16),
                   ThemedTextField(
                      label: 'Panel Alanı (m²)',
                      isNumber: true,
                      onChanged: (val) => vm.setPanelArea(val),
                      controller: TextEditingController(text: vm.panelArea.toString())
                          ..selection = TextSelection.fromPosition(
                             TextPosition(offset: vm.panelArea.toString().length),
                          ),
                      theme: theme,
                   ),
                ],
                
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _cancelEdit,
                        child: Text("İptal", style: TextStyle(color: theme.secondaryTextColor)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _handleUpdateSaved,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        child: const Text("Kaydet"),
                      ),
                    ),
                  ],
                ),

             ],
           );
         }
       ),
    );
  }
  
  Widget _buildTypeOption(ThemeViewModel theme, String label, IconData icon, bool isSelected, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
             duration: const Duration(milliseconds: 200),
             padding: const EdgeInsets.symmetric(vertical: 12),
             decoration: BoxDecoration(
               color: isSelected ? theme.cardColor : Colors.transparent,
               borderRadius: BorderRadius.circular(12),
               boxShadow: isSelected ? [BoxShadow(color: Colors.black12, blurRadius: 4)] : null,
             ),
             child: Icon(icon, color: isSelected ? (label.contains("Güneş") ? Colors.orange : Colors.blue) : theme.secondaryTextColor),
          ),
        ),
      );
  }
}
