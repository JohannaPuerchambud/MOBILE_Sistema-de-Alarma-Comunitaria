import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../../core/config/api.dart';
import '../../core/auth/token_storage.dart';
import 'report_model.dart';

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
      throw Exception(
        "Respuesta inesperada del servidor. Intenta de nuevo.",
      );
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

  Future<List<ReportModel>> getNeighborhoodReports() async {
    final token = await TokenStorage().getToken();
    if (token == null) throw Exception("No hay token, inicia sesión.");

    final url = Uri.parse("${ApiConfig.baseUrl}/reports/neighborhood");
    final res = await http.get(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (res.statusCode == 200) {
      final data = _safeJsonDecode(res.body);
      if (data is List) {
        return data.map((e) => ReportModel.fromJson(e)).toList();
      }
      throw Exception("Formato de respuesta inesperado.");
    } else {
      throw Exception(_extractErrorMessage(res.body, "Error al cargar reportes."));
    }
  }

  /// ✅ Envía la imagen como multipart/form-data
  /// al backend, que se encarga de subirla a Firebase Storage de forma segura.
  Future<void> createReport({
    required String title,
    required String description,
    File? imageFile,
  }) async {
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
      request.files.add(
        await http.MultipartFile.fromPath(
          "image", // Debe coincidir con el nombre en multer (.single("image"))
          imageFile.path,
        ),
      );
    }

    final streamedResponse = await request.send();
    final res = await http.Response.fromStream(streamedResponse);

    if (res.statusCode != 201) {
      throw Exception(_extractErrorMessage(res.body, "Error al crear reporte."));
    }
  }
}