import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

import '../../core/config/api.dart';
import '../../core/auth/token_storage.dart';

class EmergencyService {
  /// Solicita permisos y obtiene la ubicación actual del usuario
  static Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Los servicios de ubicación están desactivados. Actívalos en configuración.");
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Permiso de ubicación denegado.");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("Permiso de ubicación denegado permanentemente. Habilítalo desde Configuración.");
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  /// Envía la emergencia al backend con justificación y coordenadas
  static Future<void> triggerEmergency({
    required String justification,
    required double latitude,
    required double longitude,
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
        "latitude": latitude,
        "longitude": longitude,
      }),
    );

    if (res.statusCode != 201) {
      final errorData = json.decode(res.body);
      throw Exception(errorData['message'] ?? "Error al activar la emergencia.");
    }
  }
}
