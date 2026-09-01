import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // 🟢 NUEVO IMPORT

import '../../core/config/api.dart';
import '../../core/config/connectivity_service.dart';
import '../../core/auth/session_service.dart';
import '../../core/auth/token_storage.dart';

class EmergencyResult {
  final String sirenStatus;
  final String? sirenErrorCode;
  final String pushStatus;
  final int pushAttempted;
  final int pushSuccess;
  final int pushFailure;
  final int pushInvalidated;
  final String evidenceStatus;
  final String? evidenceWarning;
  final int? messageId;

  const EmergencyResult({
    required this.sirenStatus,
    this.sirenErrorCode,
    required this.pushStatus,
    required this.pushAttempted,
    required this.pushSuccess,
    required this.pushFailure,
    required this.pushInvalidated,
    this.evidenceStatus = 'not_provided',
    this.evidenceWarning,
    this.messageId,
  });

  factory EmergencyResult.fromJson(Map<String, dynamic> data) {
    final delivery = data['delivery'];
    if (delivery is! Map) {
      return const EmergencyResult(
        sirenStatus: 'unknown',
        pushStatus: 'unknown',
        pushAttempted: 0,
        pushSuccess: 0,
        pushFailure: 0,
        pushInvalidated: 0,
      );
    }

    // La clave en el JSON ahora es 'infobip' (migrado desde 'twilio')
    final siren = delivery['infobip'] ?? delivery['twilio'];
    final push = delivery['push'];
    final evidence = delivery['evidence'];
    final chat = delivery['chat'];

    return EmergencyResult(
      sirenStatus: siren is Map
          ? '${siren['status'] ?? 'unknown'}'
          : 'unknown',
      sirenErrorCode: siren is Map && siren['error_code'] != null
          ? '${siren['error_code']}'
          : null,
      pushStatus: push is Map ? '${push['status'] ?? 'unknown'}' : 'unknown',
      pushAttempted: push is Map
          ? int.tryParse('${push['attempted'] ?? 0}') ?? 0
          : 0,
      pushSuccess: push is Map
          ? int.tryParse('${push['success'] ?? 0}') ?? 0
          : 0,
      pushFailure: push is Map
          ? int.tryParse('${push['failure'] ?? 0}') ?? 0
          : 0,
      pushInvalidated: push is Map
          ? int.tryParse('${push['invalidated'] ?? 0}') ?? 0
          : 0,
      evidenceStatus: evidence is Map
          ? '${evidence['status'] ?? 'not_provided'}'
          : 'not_provided',
      evidenceWarning: evidence is Map && evidence['warning'] is Map
          ? '${evidence['warning']['message'] ?? ''}'
          : null,
      messageId: chat is Map
          ? int.tryParse('${chat['message_id'] ?? ''}')
          : null,
    );
  }
  String get userMessage {
    final pushMessage = this.pushMessage;
    final sirenMsg = sirenMessage;
    final evidenceMessage = this.evidenceMessage;

    return 'La emergencia quedó registrada. $pushMessage $sirenMsg $evidenceMessage';
  }

  String get evidenceMessage {
    if (evidenceStatus == 'uploaded') {
      return 'La evidencia fotográfica quedó adjunta.';
    }

    if (evidenceStatus == 'failed') {
      final detail = (evidenceWarning ?? '').trim();
      return detail.isEmpty
          ? 'La emergencia se registró sin evidencia fotográfica.'
          : detail;
    }

    return '';
  }

  String get pushMessage {
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

    if (pushStatus == 'unavailable') {
      return 'La emergencia se registró, pero el servicio de notificaciones no estuvo disponible.';
    }
    if (pushStatus == 'no_recipients') {
      return 'No habia otros dispositivos registrados para recibir push.';
    }

    return 'El servidor no informo el resultado de las notificaciones push.';
  }

  String get sirenMessage {
    if (const {
      'queued',
      'ringing',
      'in-progress',
      'in_progress',
      'CALL_IN_PROGRESS',
      'CALLING',
      'completed',
      'FINISHED',
    }.contains(sirenStatus)) {
      return 'La llamada a la alarma fue iniciada correctamente.';
    }

    if (sirenStatus == 'cooldown') {
      return 'La sirena ya fue activada hace menos de 5 minutos. No se realizó una nueva llamada para evitar falsas alarmas.';
    }

    if (sirenStatus == 'no_alarm_number') {
      return 'El barrio no tiene un numero de alarma configurado.';
    }

    if (sirenStatus == 'invalid_alarm_number') {
      return 'El numero de alarma del barrio no tiene formato internacional valido.';
    }

    if (sirenStatus == 'infobip_auth_failed') {
      return 'Las credenciales de Infobip del servidor no son validas.';
    }

    if (sirenStatus == 'not_configured') {
      return 'El servicio de llamadas no esta configurado en el servidor.';
    }

    if (sirenStatus == 'failed' || sirenStatus == 'bad_request') {
      final code = sirenErrorCode == null
          ? ''
          : ' Codigo: $sirenErrorCode.';
      return 'No se pudo crear la llamada a la alarma.$code';
    }

    return 'El servidor no informo el resultado de la llamada a la alarma.';
  }
}

class EmergencyService {
  static String userMessageForError(Object error) {
    final friendly = ConnectivityService.friendlyMessage(error, fallback: '');
    if (friendly.isNotEmpty) return friendly;
    return error.toString().replaceFirst('Exception: ', '');
  }

  /// Envía la emergencia al backend con justificación y evidencia fotográfica opcional.
  /// El backend obtiene automáticamente las coordenadas del domicilio
  /// registrado por el administrador.
  static Future<EmergencyResult> triggerEmergency({
    required String justification,
    File? imageFile,
  }) async {
    await ConnectivityService.instance.ensureConnected();
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
          contentType: MediaType(
            'image',
            extension,
          ), // Le avisa a Node.js que es imagen
        ),
      );
    }

    final streamedResponse = await request.send().timeout(
      ApiConfig.emergencyTimeout,
    );
    final res = await http.Response.fromStream(streamedResponse);

    if (await SessionService.handleStatusCode(res.statusCode)) {
      throw Exception('Tu sesión terminó.');
    }

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
        final msg =
            errorData['message'] ??
            errorData['error'] ??
            "Error al activar la emergencia.";
        throw Exception(msg);
      } on FormatException {
        throw Exception("Error al activar la emergencia.");
      }
    }

    final data = json.decode(res.body);
    return EmergencyResult.fromJson(Map<String, dynamic>.from(data));
  }
}
