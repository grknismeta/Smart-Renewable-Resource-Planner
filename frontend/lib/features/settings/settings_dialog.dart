import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/core/config/backend_config.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:provider/provider.dart';

/// Uygulama ayarları diyaloğu.
///
/// İçerik:
///   • Görünüm: Dark/Light tema geçişi
///   • Veri Kaynağı: backend URL + scheduler notu (bilgilendirici)
///   • Hakkında: Sürüm + veri kaynağı bilgisi
///
/// Not: "Gelişmiş" ayarlar (dil, ölçü birimi, bildirimler) ileride eklenecek.
class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  static const String _backendInfo = 'Open-Meteo → Postgres (UTC+3)';
  static const String _appVersion = '0.9.0 — sprint build';

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const SettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeViewModel>(context);

    return AlertDialog(
      backgroundColor: theme.cardColor,
      title: Row(
        children: [
          Icon(Icons.settings_rounded, color: theme.textColor, size: 20),
          const SizedBox(width: 8),
          Text('Ayarlar', style: TextStyle(color: theme.textColor)),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionHeader(title: 'Görünüm', theme: theme),
              _ThemeToggleTile(theme: theme),
              const SizedBox(height: 12),

              _SectionHeader(title: 'Veri Kaynağı', theme: theme),
              _InfoTile(
                icon: Icons.cloud_sync_rounded,
                label: 'Sağlayıcı',
                value: _backendInfo,
                theme: theme,
              ),
              _InfoTile(
                icon: Icons.schedule_rounded,
                label: 'Güncelleme',
                value: 'Saatlik (APScheduler cron)',
                theme: theme,
              ),
              _InfoTile(
                icon: Icons.storage_rounded,
                label: 'Tablolar',
                value: 'province_analysis + hourly_weather',
                theme: theme,
              ),
              // Mobil için: PC LAN IP'si değişince kullanıcı burdan günceller.
              // Web'de Uri.base.host otomatik kullanılır, gerek yok.
              if (!kIsWeb) _BackendUrlTile(theme: theme),
              const SizedBox(height: 12),

              _SectionHeader(title: 'Hakkında', theme: theme),
              _InfoTile(
                icon: Icons.info_outline_rounded,
                label: 'Sürüm',
                value: _appVersion,
                theme: theme,
                onTap: () {
                  Clipboard.setData(const ClipboardData(text: _appVersion));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sürüm bilgisi panoya kopyalandı'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              _InfoTile(
                icon: Icons.public_rounded,
                label: 'Kapsam',
                value: 'Türkiye 81 il + ilçe detayı',
                theme: theme,
              ),
              const SizedBox(height: 8),
              _NoteRow(
                text: 'Dil seçimi ve bildirim tercihleri yakında.',
                theme: theme,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Kapat', style: TextStyle(color: theme.textColor)),
        ),
      ],
    );
  }
}

// ── Alt widget'lar ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final ThemeViewModel theme;
  const _SectionHeader({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Text(
        title,
        style: TextStyle(
          color: theme.secondaryTextColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _ThemeToggleTile extends StatelessWidget {
  final ThemeViewModel theme;
  const _ThemeToggleTile({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.borderColor),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        dense: true,
        secondary: Icon(
          theme.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
          color: theme.isDarkMode ? Colors.blueAccent : Colors.orangeAccent,
        ),
        title: Text(
          'Karanlık Mod',
          style: TextStyle(color: theme.textColor, fontSize: 13),
        ),
        subtitle: Text(
          theme.isDarkMode ? 'Etkin — koyu tema' : 'Kapalı — açık tema',
          style: TextStyle(color: theme.secondaryTextColor, fontSize: 11),
        ),
        value: theme.isDarkMode,
        activeColor: Colors.purpleAccent,
        onChanged: (_) => theme.toggleTheme(),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ThemeViewModel theme;
  final VoidCallback? onTap;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 16, color: theme.secondaryTextColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: theme.secondaryTextColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        color: theme.textColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.copy_rounded,
                    size: 14, color: theme.secondaryTextColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mobil/Desktop için backend URL override girişi.
///
/// SharedPreferences'a yazar; `BaseService.baseUrl` bir sonraki istekte
/// yeni değeri kullanır. Web'de gizlenir (Uri.base.host otomatik).
class _BackendUrlTile extends StatefulWidget {
  final ThemeViewModel theme;
  const _BackendUrlTile({required this.theme});

  @override
  State<_BackendUrlTile> createState() => _BackendUrlTileState();
}

class _BackendUrlTileState extends State<_BackendUrlTile> {
  late final TextEditingController _controller;
  bool _saving = false;
  String? _status; // 'saved' | 'reset' | null

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: BackendConfig.instance.mobileUrl,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await BackendConfig.instance.setMobileUrl(_controller.text);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _status = 'saved';
      _controller.text = BackendConfig.instance.mobileUrl;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Backend URL kaydedildi: ${BackendConfig.instance.mobileUrl}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _reset() async {
    setState(() => _saving = true);
    await BackendConfig.instance.reset();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _status = 'reset';
      _controller.text = BackendConfig.instance.mobileUrl;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Varsayılan backend URL geri yüklendi'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: BackendConfig.instance.hasOverride
              ? Colors.cyanAccent.withValues(alpha: 0.35)
              : theme.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dns_rounded,
                  size: 16, color: theme.secondaryTextColor),
              const SizedBox(width: 8),
              Text(
                'Backend URL (mobil/desktop)',
                style: TextStyle(
                  color: theme.secondaryTextColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              if (BackendConfig.instance.hasOverride)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'ÖZEL',
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _controller,
            enabled: !_saving,
            style: TextStyle(color: theme.textColor, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'http://192.168.1.x:8000',
              hintStyle: TextStyle(
                color: theme.secondaryTextColor.withValues(alpha: 0.5),
                fontSize: 12,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: theme.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: theme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Colors.cyanAccent, width: 1.5),
              ),
            ),
            autocorrect: false,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'PC LAN IP değiştiğinde güncelleyin (örn. ipconfig'
                  ' → 192.168.x.x). Backend 0.0.0.0:8000\'de dinlemeli.',
                  style: TextStyle(
                    color: theme.secondaryTextColor.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton.icon(
                onPressed: _saving ? null : _reset,
                icon: const Icon(Icons.restore_rounded, size: 14),
                label: const Text('Varsayılan',
                    style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: theme.secondaryTextColor,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded, size: 14),
                label: const Text('Kaydet',
                    style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
          if (_status != null) const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  final String text;
  final ThemeViewModel theme;
  const _NoteRow({required this.text, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 13,
            color: theme.secondaryTextColor.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: theme.secondaryTextColor.withValues(alpha: 0.7),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
