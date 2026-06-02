import 'package:flutter/widgets.dart';
// google_sign_in_web, google_sign_in'in transitive bağımlılığı; web_only.dart'ı
// (renderButton) doğrudan kullanıyoruz.
// ignore: depend_on_referenced_packages
import 'package:google_sign_in_web/web_only.dart' as web;

/// Web: google_sign_in_web plugin'inin GIS (Google Identity Services) butonunu
/// render eder. Tıklanınca sign-in akışı başlar → GoogleSignIn.onCurrentUserChanged
/// tetiklenir (auth_dropdown dinler). signIn() web'de programatik çağrılamaz.
///
/// 2026-06-02: ÖNEMLİ — web.renderButton() içeride FlexHtmlElementView döndürür;
/// bu widget ResizeObserver ile KENDİ boyutunu DOM butonundan ölçer ve başlangıçta
/// Size(1,1)'dir. Sabit `SizedBox(height: 44)` ile sarmak butonu ~1px genişlikte
/// bir kutuya hapsedip görünmez yapıyordu (observer büyütemiyordu). Çözüm: sabit
/// boyut vermeden yalnızca ortala — observer doğal boyuta büyütür (resmi örnek).
Widget renderGoogleWebButton() => Align(
      alignment: Alignment.center,
      child: web.renderButton(),
    );
