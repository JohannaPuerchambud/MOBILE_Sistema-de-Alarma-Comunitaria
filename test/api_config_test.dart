import 'package:app_mobile_sistema_alarma/core/config/api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la configuracion predeterminada usa la API desplegada de forma segura', () {
    expect(ApiConfig.baseUrl, startsWith('https://'));
    expect(ApiConfig.baseUrl, endsWith('/api'));
    expect(ApiConfig.socketUrl, startsWith('https://'));
  });
}
