import 'dart:ui'; // ImageFilter için
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoginMode = true;
  bool _isLoading = false;

  final _emailController = TextEditingController(text: "");
  final _passwordController = TextEditingController(text: "");
  final _confirmPasswordController = TextEditingController();

  final LatLng _center = const LatLng(39.0, 35.5);
  final LatLngBounds _turkeyBounds = LatLngBounds(
    const LatLng(34.0, 24.0),
    const LatLng(44.0, 46.0),
  );

  void _submit() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen e-posta ve şifre giriniz."), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      if (_isLoginMode) {
        // --- GİRİŞ YAP ---
        await authProvider.login(
          _emailController.text,
          _passwordController.text,
        );
      } else {
        // --- KAYIT OL ---
        if (_passwordController.text != _confirmPasswordController.text) {
          throw Exception("Şifreler eşleşmiyor.");
        }

        await authProvider.register(
          _emailController.text,
          _passwordController.text,
        );
        
        // Kayıt sonrası otomatik giriş
        await authProvider.login(
          _emailController.text,
          _passwordController.text,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Kayıt ve Giriş Başarılı!"), backgroundColor: Colors.green),
          );
        }
      }

      // --- BAŞARILI İŞLEM SONRASI YÖNLENDİRME (KRİTİK DÜZELTME) ---
      if (mounted) {
        // Misafir modundan geldiysek veya normal açılışsa, anasayfaya yönlendir ve geçmişi temizle.
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }

    } catch (e) {
      if (!mounted) return;
      String errorMessage = e.toString().replaceAll("Exception:", "").trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("İşlem Hatası: $errorMessage"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _continueAsGuest() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Misafir olarak devam ediliyor..."), backgroundColor: Colors.blue),
    );
    Navigator.of(context).pushReplacementNamed('/map');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, 
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 6.0,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
              cameraConstraint: CameraConstraint.contain(bounds: _turkeyBounds),
            ),
            children: [
              TileLayer(
                tileProvider: CancellableNetworkTileProvider(),
                urlTemplate: 'https://services.arcgisonline.com/arcgis/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}',
              ),
            ],
          ),

          Container(color: Colors.black.withOpacity(0.3)),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 380,
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E232F).withOpacity(0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.eco, size: 50, color: Colors.greenAccent),
                        const SizedBox(height: 10),
                        
                        Text(
                          _isLoginMode ? "SRRP Giriş" : "SRRP Kayıt Ol",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "Akıllı Yenilenebilir Kaynak Planlayıcı",
                          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),

                        _buildGlassTextField(
                          controller: _emailController,
                          hintText: "E-posta",
                          icon: Icons.email_outlined,
                        ),
                        const SizedBox(height: 15),

                        _buildGlassTextField(
                          controller: _passwordController,
                          hintText: "Şifre",
                          icon: Icons.lock_outline,
                          isPassword: true,
                        ),
                        
                        if (!_isLoginMode) ...[
                          const SizedBox(height: 15),
                          _buildGlassTextField(
                            controller: _confirmPasswordController,
                            hintText: "Şifre Tekrar",
                            icon: Icons.lock_reset,
                            isPassword: true,
                          ),
                        ],

                        const SizedBox(height: 25),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isLoginMode ? Colors.blueAccent : Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 5,
                            ),
                            child: _isLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(
                                    _isLoginMode ? "Giriş Yap" : "Kayıt Ol",
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),

                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              _isLoginMode ? "Hesabın yok mu? " : "Zaten hesabın var mı? ",
                              style: TextStyle(color: Colors.white.withOpacity(0.7)),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isLoginMode = !_isLoginMode;
                                  _confirmPasswordController.clear();
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  _isLoginMode ? "Kayıt Ol" : "Giriş Yap",
                                  style: const TextStyle(
                                    color: Colors.white, 
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        TextButton(
                          onPressed: _continueAsGuest,
                          child: Text(
                            "Giriş Yapmadan Devam Et",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        
                        if (_isLoginMode)
                          TextButton(
                            onPressed: () {},
                            child: Text(
                              "Şifremi Unuttum",
                              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white70),
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }
}