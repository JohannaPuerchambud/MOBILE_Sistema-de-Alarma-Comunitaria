class ApiConfig {
  static const Duration requestTimeout = Duration(seconds: 20);
  static const Duration emergencyTimeout = Duration(seconds: 45);
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api-sistema-de-alarma-comunitaria.onrender.com/api',
  );

  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: 'https://api-sistema-de-alarma-comunitaria.onrender.com',
  );
}
