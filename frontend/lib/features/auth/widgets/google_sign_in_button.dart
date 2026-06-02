import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'google_button_render_stub.dart'
    if (dart.library.html) 'google_button_render_web.dart';

/// AUTH-3 (2026-06-01): "Google ile devam et" butonu.
/// - Web: GIS'in render ettiği resmi buton (programatik signIn() web'de yok).
/// - Mobil: ElevatedButton → googleSignIn.signIn(). (Android/iOS OAuth client'ı
///   eklenince çalışır.)
/// Her iki durumda da giriş tamamlanınca [GoogleSignIn.onCurrentUserChanged]
/// tetiklenir; idToken'ı dinleyen taraf (auth_modal) backend'e gönderir.
class GoogleSignInButton extends StatelessWidget {
  final GoogleSignIn googleSignIn;
  const GoogleSignInButton({super.key, required this.googleSignIn});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // GIS resmi butonu (kendi tıklama akışını yönetir).
      return renderGoogleWebButton();
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => googleSignIn.signIn(),
        icon: const Icon(Icons.account_circle_outlined, size: 18),
        label: const Text('Google ile devam et'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
