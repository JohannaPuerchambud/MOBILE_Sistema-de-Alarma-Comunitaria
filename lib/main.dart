import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import 'core/auth/token_storage.dart';
import 'pages/login/login_page.dart';
import 'pages/home/home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<bool> _hasValidToken() async {
    final token = await TokenStorage().getToken();
    if (token == null || token.isEmpty) return false;
    if (JwtDecoder.isExpired(token)) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasValidToken(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return snapshot.data == true
            ? HomePage()
            : const LoginPage();
      },
    );
  }
}
