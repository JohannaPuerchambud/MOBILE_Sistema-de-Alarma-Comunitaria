import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // 🟢 NUEVO IMPORT

import '../../core/config/api.dart';
import '../../core/auth/token_storage.dart';

class EmergencyResult {
  final String twilioStatus;
  final String? twilioErrorCode;
  final String pushStatus;
  final int pushAttempted;
  final int pushSuccess;
  final int pushFailure;
  final int pushInvalidated;

  const EmergencyResult({
    required this.twilioStatus,
    this.twilioErrorCode,
    required this.pushStatus,
    required this.pushAttempted,
    required this.pushSuccess,
    required this.pushFailure,
    required this.pushInvalidated,
  });

  factory EmergencyResult.fromJson(Map<String, dynamic> data) {
    final delivery = data['delivery'];
    if (delivery is! Map) {
      return const EmergencyResult(
        twilioStatus: 'unknown',
        pushStatus: 'unknown',
        pushAttempted: 0,
        pushSuccess: 0,
        pushFailure: 0,
        pushInvalidated: 0,
      );
    }

    final twilio = delivery['twilio'];
    final push = delivery['push'];

    return EmergencyResult(
      twilioStatus: twilio is Map ? '${twilio['status'] ?? 'unknown'}' : 'unknown',
      twilioErrorCode: twilio is Map && twilio['error_code'] != null
          ? '${twilio['error_code']}'
          : null,
      pushStatus: push is Map ? '${push['status'] ?? 'unknown'}' : 'unknown',
      pushAttempted: push is Map ? int.tryParse('${push['attempted'] ?? 0}') ?? 0 : 0,
      pushSuccess: push is Map ? int.tryParse('${push['success'] ?? 0}') ?? 0 : 0,
      pushFailure: push is Map ? int.tryParse('${push['failure'] ?? 0}') ?? 0 : 0,
      pushInvalidated: push is Map ? int.tryParse('${push['invalidated'] ?? 0}') ?? 0 : 0,
    );
  }

  String get userMessage {
    final pushMessage = _pushMessage;
    final twilioMessage = _twilioMessage;

    return 'La emergencia quedo registrada. $pushMessage $twilioMessage';
  }

  String get _pushMessage {
    if (pushStatus == 'sent') {
      return pushSuccess == 1
          ? 'Se envio 1 notificacion a un vecino.'
          : 'Se enviaron $pushSuccess notificaciones a vecinos.';
    }

    if (pushStatus == 'partially_sent') {
      return 'Se enviaron $pushSuccess de $pushAttempted notificaciones push.';
    }

    if (pushStatus == 'failed' && pushInvalidated > 0) {
      return 'Los tokens push registrados estaban vencidos y se limpiaron; los vecinos se registraran de nuevo al abrir la app.';
    }

    if (pushStatus == 'failed') {
      return 'No se pudieron enviar las notificaciones push.';
    }

    if (pushStatus == 'no_recipients') {
      return 'No habia otros dispositivos registrados para recibir push.';
    }

    return 'El servidor no informo el resultado de las notificaciones push.';
  }

  String get _twilioMessage {
    if (['queued', 'ringing', 'in-progress', 'completed'].contains(twilioStatus)) {
      return 'La llamada a la alarma fue creada correctamente.';
    }

    if (twilioStatus == 'no_alarm_number') {
      return 'El barrio no tiene un numero de alarma configurado.';
    }

    if (twilioStatus == 'invalid_alarm_number') {
      return 'El numero de alarma del barrio no tiene formato internacional valido.';
    }

    if (twilioStatus == 'unverified_alarm_number') {
      return 'El numero de alarma debe estar verificado en Twilio para cuentas de prueba.';
    }

    if (twilioStatus == 'invalid_twilio_from') {
      return 'El numero Twilio configurado no puede realizar llamadas.';
    }

    if (twilioStatus == 'twilio_auth_failed') {
      return 'Las credenciales de Twilio del servidor no son validas.';
    }

    if (twilioStatus == 'not_configured') {
      return 'Twilio no esta configurado en el servidor.';
    }

    if (twilioStatus == 'failed') {
      final code = twilioErrorCode == null ? '' : ' Codigo Twilio: $twilioErrorCode.';
      return 'No se pudo crear la llamada a la alarma.$code';
    }

    return 'El servidor no informo el resultado de la llamada a la alarma.';
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

    final streamedResponse = await request.send().timeout(ApiConfig.emergencyTimeout);
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
