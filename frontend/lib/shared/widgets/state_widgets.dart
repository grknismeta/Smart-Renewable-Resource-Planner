import 'package:flutter/material.dart';

/// Yükleme durumunu gösteren widget
class LoadingIndicator extends StatelessWidget {
  final String? message;
  final Color? color;

  const LoadingIndicator({super.key, this.message, this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: color),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: TextStyle(color: color ?? Colors.grey)),
          ],
        ],
      ),
    );
  }
}

/// Boş durumu gösteren widget
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[const SizedBox(height: 24), action!],
        ],
      ),
    );
  }
}

/// Hata durumunu gösteren widget — backend bağlantı sorunlarını tespit eder.
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({super.key, required this.message, this.onRetry});

  static bool isConnectionError(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('connection') ||
        lower.contains('socket') ||
        lower.contains('network') ||
        lower.contains('unreachable') ||
        lower.contains('refused') ||
        lower.contains('timeout') ||
        lower.contains('bağlan') ||
        lower.contains('sunucu');
  }

  @override
  Widget build(BuildContext context) {
    final connError = isConnectionError(message);
    final iconData  = connError ? Icons.cloud_off_rounded : Icons.error_outline_rounded;
    final iconColor = connError ? Colors.orangeAccent : Colors.redAccent;
    final titleText = connError ? 'Sunucuya Bağlanılamıyor' : 'Bir Hata Oluştu';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, size: 72, color: iconColor),
            const SizedBox(height: 20),
            Text(
              titleText,
              style: TextStyle(color: iconColor, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              connError
                  ? 'Backend servisi çalışmıyor veya internet bağlantısı yok.\n'
                    'Lütfen sunucunun açık olduğundan emin olun.'
                  : message,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            if (connError) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  '📡  http://localhost:8000',
                  style: TextStyle(color: Colors.orangeAccent, fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 28),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: iconColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tekrar Dene', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
