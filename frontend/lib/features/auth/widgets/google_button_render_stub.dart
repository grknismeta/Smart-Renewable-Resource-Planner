import 'package:flutter/widgets.dart';

/// Web-dışı (mobil/masaüstü) stub — web GIS butonu yalnız web'de render edilir.
/// Mobilde GoogleSignInButton kendi ElevatedButton'ını kullanır (signIn()).
Widget renderGoogleWebButton() => const SizedBox.shrink();
