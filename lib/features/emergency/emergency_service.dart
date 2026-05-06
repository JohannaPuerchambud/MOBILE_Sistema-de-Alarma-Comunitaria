import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../../core/config/api.dart';
import '../../core/auth/token_storage.dart';

class EmergencyService {
  /// Envía la emergencia al backend con justificación y evidencia fotográfica opcional.
  /// El backend obtiene automáticamente las coordenadas del domicilio
  /// registrado por el administrador.
  static Future<void> triggerEmergency({
    required String justification,
    File? imageFile,
  }) async {
    final token = await TokenStorage().getToken();
    if (token == null) throw Exception("No hay sesión activa. Inicia sesión.");

    final url = Uri.parse("${ApiConfig.baseUrl}/reports/emergency");

    // Usar multipart para soportar imagen opcional
    final request = http.MultipartRequest("POST", url);
    request.headers["Authorization"] = "Bearer $token";

    // Campo de texto
    request.fields["justification"] = justification;

    // Adjuntar imagen si existe
    if (imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath("image", imageFile.path),
      );
    }

    final streamedResponse = await request.send();
    final res = await http.Response.fromStream(streamedResponse);

    if (res.statusCode != 201) {
      // Detectar si el servidor devolvió HTML (Render dormido)
      final body = res.body.trim();
      if (body.startsWith('<!') || body.startsWith('<html')) {
        throw Exception(
          "El servidor no está disponible en este momento. "
          "Intenta de nuevo en unos segundos.",
        );
      }
      // Parsear error JSON del backend
      try {
        final errorData = json.decode(body);
        final msg = errorData['message'] ?? errorData['error'] ?? "Error al activar la emergencia.";
        throw Exception(msg);
      } on FormatException {
        throw Exception("Error al activar la emergencia.");
      }
    }
  }
}
