import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api.dart';
import '../config/connectivity_service.dart';

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  Future<String?> login(String email, String password) async {
    await ConnectivityService.instance.ensureConnected();
    final url = Uri.parse('${ApiConfig.baseUrl}/auth/login');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['token'] as String?;
      }
      if (response.statusCode == 401) {
        throw const AuthException('Correo o contraseña incorrectos.');
      }
      if (response.statusCode == 429) {
        throw const AuthException(
          'Se realizaron demasiados intentos. Espera un momento y vuelve a intentar.',
        );
      }
      if (response.statusCode >= 500) {
        throw const AuthException(
          'El servidor no está disponible. Puede estar iniciando; inténtalo nuevamente en unos segundos.',
        );
      }
      throw const AuthException('No se pudo iniciar sesión.');
    } on TimeoutException {
      throw const AuthException(
        'El servidor está tardando en responder. Puede estar iniciando; inténtalo nuevamente.',
      );
    } on http.ClientException catch (error) {
      throw AuthException(
        ConnectivityService.friendlyMessage(
          error,
          fallback: 'No se pudo conectar con el servidor.',
        ),
      );
    }
  }
}
