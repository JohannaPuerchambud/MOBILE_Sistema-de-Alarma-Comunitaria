import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../core/config/api.dart';
import '../../core/config/connectivity_service.dart';
import '../../core/auth/session_service.dart';
import '../../core/auth/token_storage.dart';
import 'report_model.dart';

class ReportSubmissionResult {
  final List<String> warnings;

  const ReportSubmissionResult({this.warnings = const []});

  factory ReportSubmissionResult.fromJson(dynamic data) {
    if (data is! Map || data['warnings'] is! List) {
      return const ReportSubmissionResult();
    }

    final warnings = (data['warnings'] as List)
        .whereType<Map>()
        .map((warning) => warning['message']?.toString().trim() ?? '')
        .where((message) => message.isNotEmpty)
        .toList();

    return ReportSubmissionResult(warnings: warnings);
  }
}

class ReportService {
  /// ✅ Helper: decodifica JSON de forma segura.
  /// Si el servidor devuelve HTML (ej. Render dormido), lanza un mensaje claro.
  dynamic _safeJsonDecode(String body) {
    final trimmed = body.trim();
    if (trimmed.startsWith('<!') || trimmed.startsWith('<html')) {
      throw Exception(
        "El servidor no está disponible en este momento. "
        "Intenta de nuevo en unos segundos.",
      );
    }
    try {
      return json.decode(trimmed);
    } catch (_) {
      throw Exception("Respuesta inesperada del servidor. Intenta de nuevo.");
    }
  }

  /// ✅ Helper: extrae mensaje de error del body de forma segura.
  String _extractErrorMessage(String body, String fallback) {
    try {
      final data = _safeJsonDecode(body);
      if (data is Map) {
        return data['message'] ?? data['error'] ?? fallback;
      }
      return fallback;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  static String userMessageForError(Object error) {
    final friendly = ConnectivityService.friendlyMessage(error, fallback: '');
    if (friendly.isNotEmpty) return friendly;
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<List<NeighborhoodActivity>> getNeighborhoodActivity() async {
    await ConnectivityService.instance.ensureConnected();
    final token = await TokenStorage().getToken();
    if (token == null) throw Exception("No hay token, inicia sesión.");

    final url = Uri.parse("${ApiConfig.baseUrl}/reports/activity");
    final res = await http
        .get(
          url,
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
        )
        .timeout(ApiConfig.requestTimeout);

    if (await SessionService.handleStatusCode(res.statusCode)) {
      throw Exception('Tu sesión terminó.');
    }

    if (res.statusCode == 200) {
      final data = _safeJsonDecode(res.body);
      if (data is List) {
        return data
            .whereType<Map>()
            .map(
              (item) => NeighborhoodActivity.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList();
      }
      throw Exception("Formato de respuesta inesperado.");
    }

    throw Exception(
      _extractErrorMessage(
        res.body,
        "Error al cargar la actividad del barrio.",
      ),
    );
  }

  /// ✅ Envía la imagen como multipart/form-data
  /// al backend, que se encarga de subirla a Firebase Storage de forma segura.
  Future<ReportSubmissionResult> createReport({
    required String title,
    required String description,
    File? imageFile,
  }) async {
    await ConnectivityService.instance.ensureConnected();
    final token = await TokenStorage().getToken();

    if (token == null) throw Exception("No hay token, inicia sesión.");

    final url = Uri.parse("${ApiConfig.baseUrl}/reports");

    // Usar multipart request para enviar imagen + datos
    final request = http.MultipartRequest("POST", url);
    request.headers["Authorization"] = "Bearer $token";

    // Campos de texto
    request.fields["title"] = title;
    request.fields["description"] = description;

    // Adjuntar imagen si existe
    if (imageFile != null) {
      // 🟢 CAMBIO CLAVE: Detectar extensión y declarar el Content-Type
      String extension = imageFile.path.split('.').last.toLowerCase();
      if (extension == 'jpg') extension = 'jpeg';

      request.files.add(
        await http.MultipartFile.fromPath(
          "image", // Debe coincidir con el nombre en multer (.single("image"))
          imageFile.path,
          contentType: MediaType(
            'image',
            extension,
          ), // Le avisa a Node.js que es imagen
        ),
      );
    }

    final streamedResponse = await request.send().timeout(
      ApiConfig.requestTimeout,
    );
    final res = await http.Response.fromStream(streamedResponse);

    if (await SessionService.handleStatusCode(res.statusCode)) {
      throw Exception('Tu sesión terminó.');
    }

    if (res.statusCode != 201) {
      throw Exception(
        _extractErrorMessage(res.body, "Error al crear reporte."),
      );
    }

    return ReportSubmissionResult.fromJson(_safeJsonDecode(res.body));
  }
}
