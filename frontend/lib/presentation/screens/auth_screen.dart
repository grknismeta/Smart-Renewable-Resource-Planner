// lib/presentation/screens/auth_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

enum AuthMode { login, signup }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  AuthMode _authMode = AuthMode.login;
  bool _isLoading = false;
  
  String get _buttonText => _authMode == AuthMode.login ? 'Giriş Yap' : 'Kayıt Ol';
  String get _switchText => _authMode == AuthMode.login ? 'Hesabınız yok mu? Kayıt Olun' : 'Zaten hesabınız var mı? Giriş Yapın';

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hata Oluştu'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text('Tamam'),
            onPressed: () => Navigator.of(ctx).pop(),
          )
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showErrorDialog('Lütfen tüm alanları doldurun.');
      return;
    }
    
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      if (_authMode == AuthMode.login) {
        await authProvider.login(_emailController.text, _passwordController.text);
      } else {
        await authProvider.register(_emailController.text, _passwordController.text);
        _showErrorDialog('Kayıt başarılı! Şimdi lütfen giriş yapın.');
        setState(() => _authMode = AuthMode.login);
      }
    } catch (e) {
      _showErrorDialog(e.toString().replaceFirst('Exception: ', ''));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_buttonText)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text('SRRP', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 30),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'E-posta (Kullanıcı Adı)'),
                keyboardType: TextInputType.emailAddress,
              ),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Parola'),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _submit,
                      child: Text(_buttonText),
                    ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  setState(() {
                    _authMode = _authMode == AuthMode.login ? AuthMode.signup : AuthMode.login;
                  });
                },
                child: Text(_switchText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
