import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

import 'core/auth/token_storage.dart';
import 'core/auth/roles.dart';
import 'core/navigation/app_navigator.dart';
import 'core/theme/app_theme.dart';
import 'pages/login/login_page.dart';
import 'pages/home/home_page.dart';
import 'package:intl/date_symbol_data_local.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint(
    "💌 Notificación con app cerrada recibida: ${message.notification?.title}",
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('es_ES', null);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: AppTheme.light,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<bool> _hasValidToken() async {
    final token = await TokenStorage().getToken();
    if (token == null || token.isEmpty) return false;
    try {
      if (JwtDecoder.isExpired(token)) {
        await TokenStorage().clearToken();
        return false;
      }

      final claims = JwtDecoder.decode(token);
      final role = int.tryParse('${claims['role']}');
      if (!canAccessCommunityFeatures(role)) {
        await TokenStorage().clearToken();
        return false;
      }

      return true;
    } catch (_) {
      await TokenStorage().clearToken();
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasValidToken(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return snapshot.data == true ? const HomePage() : const LoginPage();
      },
    );
  }
}
