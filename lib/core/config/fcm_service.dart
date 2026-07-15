import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../auth/token_storage.dart';
import 'api.dart';

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;

  static GlobalKey<NavigatorState>? navigatorKey;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedAppSubscription;

  static Future<void> init({GlobalKey<NavigatorState>? navKey}) async {
    navigatorKey = navKey;

    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final allowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!allowed) {
        debugPrint(
          'Notificaciones deshabilitadas por el usuario: '
          '${settings.authorizationStatus.name}.',
        );
        return;
      }

      final token = await _firebaseMessaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('Firebase no entregó un token FCM para este dispositivo.');
      } else {
        await sendTokenToBackend(token);
      }

      await _replaceListeners();

      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint(
          'App abierta desde notificación: '
          '${initialMessage.notification?.title}',
        );
      }
    } catch (error) {
      debugPrint('No se pudo inicializar FCM: $error');
    }
  }

  static Future<void> _replaceListeners() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedAppSubscription?.cancel();

    _tokenRefreshSubscription = _firebaseMessaging.onTokenRefresh.listen((
      newToken,
    ) async {
      await sendTokenToBackend(newToken);
    });

    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundNotification,
    );

    _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      debugPrint('Notificación abierta: ${message.notification?.title}');
    });
  }

  static void _showForegroundNotification(RemoteMessage message) {
    final title = message.notification?.title ?? 'Notificación';
    final body = message.notification?.body ?? '';
    final context = navigatorKey?.currentContext;

    if (context == null || !context.mounted) {
      debugPrint('Notificación recibida en primer plano: $title');
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
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
  }

  static Future<bool> sendTokenToBackend(String fcmToken) async {
    try {
      final userToken = await TokenStorage().getToken();
      if (userToken == null || userToken.isEmpty) {
        debugPrint('No se registró FCM porque no hay una sesión activa.');
        return false;
      }

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/users/fcm-token'),
            headers: {
              'Authorization': 'Bearer $userToken',
              'Content-Type': 'application/json',
            },
            body: json.encode({'fcm_token': fcmToken}),
          )
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        debugPrint('Token FCM registrado correctamente en la API.');
        return true;
      }

      debugPrint(
        'La API rechazó el token FCM (${response.statusCode}): '
        '${response.body}',
      );
      return false;
    } catch (error) {
      debugPrint('Error registrando el token FCM: $error');
      return false;
    }
  }

  static Future<void> unregisterCurrentDevice() async {
    try {
      final userToken = await TokenStorage().getToken();
      final fcmToken = await _firebaseMessaging.getToken();
      if (userToken == null || fcmToken == null) return;

      await http
          .delete(
            Uri.parse('${ApiConfig.baseUrl}/users/fcm-token'),
            headers: {
              'Authorization': 'Bearer $userToken',
              'Content-Type': 'application/json',
            },
            body: json.encode({'fcm_token': fcmToken}),
          )
          .timeout(ApiConfig.requestTimeout);
    } catch (error) {
      debugPrint('No se pudo desregistrar el token FCM: $error');
    } finally {
      await _tokenRefreshSubscription?.cancel();
      await _foregroundSubscription?.cancel();
      await _openedAppSubscription?.cancel();
      _tokenRefreshSubscription = null;
      _foregroundSubscription = null;
      _openedAppSubscription = null;
    }
  }
}
