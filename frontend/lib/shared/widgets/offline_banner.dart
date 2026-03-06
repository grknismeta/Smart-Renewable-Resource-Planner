// lib/shared/widgets/offline_banner.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/services/connectivity_service.dart';

/// Uygulama genelinde internet yokken alt kısımda turuncu banner gösterir.
/// main.dart'ta MaterialApp.builder içinde kullanılır.
class OfflineBanner extends StatelessWidget {
  final Widget child;
  const OfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivity, _) {
        return Column(
          children: [
            Expanded(child: child),
            AnimatedSize(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              child: connectivity.isConnected
                  ? const SizedBox.shrink()
                  : _OfflineBar(),
            ),
          ],
        );
      },
    );
  }
}

class _OfflineBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.orange.shade800,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: const SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'İnternet bağlantısı yok — veriler önbellekten gösteriliyor',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
