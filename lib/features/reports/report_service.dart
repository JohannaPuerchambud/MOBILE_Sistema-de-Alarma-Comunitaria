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

    if (res.statusCode != 200) {
      throw Exception("Error al cargar reportes: ${res.body}");
    }

    final List data = json.decode(res.body);
    return data.map((e) => ReportModel.fromJson(e)).toList();
  }

  Future<void> createReport({
    required String title,
    required String description,
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
      }),
    );

    if (res.statusCode != 201) {
      throw Exception("Error al crear reporte: ${res.body}");
    }
  }
}
