import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../../core/config/api.dart';
import '../../core/auth/token_storage.dart';
import 'report_model.dart';

class ReportService {
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
      final List data = json.decode(res.body);
      return data.map((e) => ReportModel.fromJson(e)).toList();
    } else {
      // ✅ Extraemos el mensaje limpio del backend
      final errorData = json.decode(res.body);
      throw Exception(errorData['message'] ?? "Error al cargar reportes.");
    }
  }

  /// ✅ ACTUALIZADO: Ahora envía la imagen como multipart/form-data
  /// al backend, que se encarga de subirla a Firebase Storage de forma segura.
  Future<void> createReport({
    required String title,
    required String description,
    File? imageFile, // ✅ Cambiado de String? imageUrl a File? imageFile
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
      final errorData = json.decode(res.body);
      throw Exception(errorData['message'] ?? "Error al crear reporte.");
    }
  }
}