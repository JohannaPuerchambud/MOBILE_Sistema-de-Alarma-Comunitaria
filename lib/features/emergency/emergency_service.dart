import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../core/config/api.dart';
import '../../core/auth/token_storage.dart';

class EmergencyService {
  /// Envía la emergencia al backend con justificación.
  /// El backend obtiene automáticamente las coordenadas del domicilio
  /// registrado por el administrador.
  static Future<void> triggerEmergency({
    required String justification,
  }) async {
    final token = await TokenStorage().getToken();
    if (token == null) throw Exception("No hay sesión activa. Inicia sesión.");

    final url = Uri.parse("${ApiConfig.baseUrl}/reports/emergency");

    final res = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: json.encode({
        "justification": justification,
      }),
    );

    if (res.statusCode != 201) {
      final errorData = json.decode(res.body);
      throw Exception(errorData['message'] ?? "Error al activar la emergencia.");
    }
  }
}
