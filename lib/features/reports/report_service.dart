import 'dart:convert';
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

  Future<void> createReport({
    required String title,
    required String description,
    String? imageUrl, // ✅ Agregamos este parámetro opcional
  }) async {
    final token = await TokenStorage().getToken();

    if (token == null) throw Exception("No hay token, inicia sesión.");

    final url = Uri.parse("${ApiConfig.baseUrl}/reports");
    final res = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: json.encode({
        "title": title,
        "description": description,
        "image_url": imageUrl, // ✅ Lo enviamos al backend
      }),
    );

    if (res.statusCode != 201) {
      final errorData = json.decode(res.body);
      throw Exception(errorData['message'] ?? "Error al crear reporte.");
    }
  }
}