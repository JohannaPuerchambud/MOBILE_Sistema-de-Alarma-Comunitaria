import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // 🟢 NUEVO IMPORT

import '../../core/config/api.dart';
import '../../core/auth/token_storage.dart';

class EmergencyResult {
  final String twilioStatus;
  final String pushStatus;
  final int pushSuccess;

  const EmergencyResult({
    required this.twilioStatus,
    required this.pushStatus,
    required this.pushSuccess,
  });

  factory EmergencyResult.fromJson(Map<String, dynamic> data) {
    final delivery = data['delivery'];
    if (delivery is! Map) {
      return const EmergencyResult(
        twilioStatus: 'unknown',
        pushStatus: 'unknown',
        pushSuccess: 0,
      );
    }

    final twilio = delivery['twilio'];
    final push = delivery['push'];

    return EmergencyResult(
      twilioStatus: twilio is Map ? '${twilio['status'] ?? 'unknown'}' : 'unknown',
      pushStatus: push is Map ? '${push['status'] ?? 'unknown'}' : 'unknown',
      pushSuccess: push is Map ? int.tryParse('${push['success'] ?? 0}') ?? 0 : 0,
    );
  }

  String get userMessage {
    final pushMessage = switch (pushStatus) {
      'sent' => pushSuccess == 1
          ? 'Se envio 1 notificacion a un vecino.'
          : 'Se enviaron $pushSuccess notificaciones a vecinos.',
      'partially_sent' => 'Algunas notificaciones no pudieron entregarse.',
      'failed' => 'No se pudieron enviar las notificaciones push.',
      'no_recipients' => 'No habia otros dispositivos registrados para recibir push.',
      _ => 'El servidor no informo el resultado de las notificaciones push.',
    };

    final twilioMessage = switch (twilioStatus) {
      'queued' || 'ringing' || 'in-progress' || 'completed' =>
        'La llamada a la alarma fue creada correctamente.',
      'no_alarm_number' => 'El barrio no tiene un numero de alarma configurado.',
      'not_configured' => 'Twilio no esta configurado en el servidor.',
      'failed' => 'No se pudo crear la llamada a la alarma.',
      _ => 'El servidor no informo el resultado de la llamada a la alarma.',
    };

    return 'La emergencia quedo registrada. $pushMessage $twilioMessage';
  }
}

class EmergencyService {
  /// Envía la emergencia al backend con justificación y evidencia fotográfica opcional.
  /// El backend obtiene automáticamente las coordenadas del domicilio
  /// registrado por el administrador.
  static Future<EmergencyResult> triggerEmergency({
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
      // 🟢 CAMBIO CLAVE: Detectar extensión y declarar el Content-Type
      String extension = imageFile.path.split('.').last.toLowerCase();
      if (extension == 'jpg') extension = 'jpeg';

      request.files.add(
        await http.MultipartFile.fromPath(
          "image",
          imageFile.path,
          contentType: MediaType('image', extension), // Le avisa a Node.js que es imagen
        ),
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

    final data = json.decode(res.body);
    return EmergencyResult.fromJson(Map<String, dynamic>.from(data));
  }
}
