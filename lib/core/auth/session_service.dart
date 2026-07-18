import 'package:flutter/material.dart';

import '../../pages/login/login_page.dart';
import '../navigation/app_navigator.dart';
import 'token_storage.dart';

class SessionService {
  SessionService._();

  static bool _redirecting = false;

  static Future<bool> handleStatusCode(int statusCode) async {
    if (statusCode != 401) return false;
    await expireSession();
    return true;
  }

  static Future<void> expireSession() async {
    if (_redirecting) return;
    _redirecting = true;

    await TokenStorage().clearToken();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = appNavigatorKey.currentState;
      if (navigator == null) {
        _redirecting = false;
        return;
      }

      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
      final context = appNavigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tu sesión terminó. Inicia sesión nuevamente para continuar.',
            ),
          ),
        );
      }
      _redirecting = false;
    });
  }
}
