import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

import '../auth/token_storage.dart';
import 'api.dart';

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;

  /// Contexto global para mostrar SnackBars desde cualquier lugar
  static GlobalKey<NavigatorState>? navigatorKey;

  static Future<void> init({GlobalKey<NavigatorState>? navKey}) async {
    navigatorKey = navKey;

    // 1. Solicitar permisos de notificación
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ Permisos de notificación concedidos.');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      debugPrint('⚠️ Permisos provisionales de notificación.');
    } else {
      debugPrint('❌ Permisos de notificación denegados.');
      return;
    }

    // 2. Obtener el "FCM Token" único de este celular
    String? token = await _firebaseMessaging.getToken();
    debugPrint("FCM Token obtenido correctamente.");

    // 3. Enviar este token a nuestra API en Node.js
    if (token != null) {
      await sendTokenToBackend(token);
    }

    // 4. Actualizar el token en el servidor si Firebase decide cambiarlo
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      debugPrint("🔄 Token FCM renovado, actualizando en el servidor...");
      sendTokenToBackend(newToken);
    });

    // 5. Handler para notificaciones recibidas con la app ABIERTA (foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        '💌 Alerta recibida con la app abierta: ${message.notification?.title}',
      );

      final title = message.notification?.title ?? "Notificación";
      final body = message.notification?.body ?? "";

      // Mostrar un SnackBar visible al usuario
      final context = navigatorKey?.currentContext;
      if (context == null || !context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (body.isNotEmpty)
                Text(body, style: const TextStyle(fontSize: 13)),
            ],
          ),
          backgroundColor: const Color(0xFF667EEA),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    });

    // 6. Handler para cuando el usuario toca la notificación (app en background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint(
        '📲 Notificación tocada (background): ${message.notification?.title}',
      );
      // Aquí podrías navegar a una pantalla específica si lo necesitas
    });

    // 7. Verificar si la app fue abierta desde una notificación (terminated)
    RemoteMessage? initialMessage = await _firebaseMessaging
        .getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
        '🚀 App abierta desde notificación: ${initialMessage.notification?.title}',
      );
    }
  }

  // ✅ Método para enviar el token a tu ruta de Node.js
  static Future<void> sendTokenToBackend(String fcmToken) async {
    try {
      final userToken = await TokenStorage().getToken();
      if (userToken == null) return; // Si no hay sesión, no enviamos nada

      final url = Uri.parse("${ApiConfig.baseUrl}/users/fcm-token");

      final response = await http
          .post(
            url,
            headers: {
              "Authorization": "Bearer $userToken",
              "Content-Type": "application/json",
            },
            body: json.encode({"fcm_token": fcmToken}),
          )
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        debugPrint("✅ Token FCM guardado en la base de datos PostgreSQL.");
      } else {
        debugPrint("⚠️ Error al guardar FCM token: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Error enviando FCM token al backend: $e");
    }
  }

  static Future<void> unregisterCurrentDevice() async {
    try {
      final userToken = await TokenStorage().getToken();
      final fcmToken = await _firebaseMessaging.getToken();
      if (userToken == null || fcmToken == null) return;

      final url = Uri.parse("${ApiConfig.baseUrl}/users/fcm-token");
      await http
          .delete(
            url,
            headers: {
              "Authorization": "Bearer $userToken",
              "Content-Type": "application/json",
            },
            body: json.encode({"fcm_token": fcmToken}),
          )
          .timeout(ApiConfig.requestTimeout);
    } catch (e) {
      debugPrint("No se pudo desregistrar el token FCM: $e");
    }
  }
}
