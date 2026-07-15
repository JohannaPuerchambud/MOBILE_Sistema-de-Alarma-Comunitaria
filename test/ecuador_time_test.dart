import 'package:app_mobile_sistema_alarma/core/utils/ecuador_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EcuadorTime', () {
    test('convierte UTC a UTC-5', () {
      final result = EcuadorTime.parse('2026-07-15T16:04:00.000Z');

      expect(result.year, 2026);
      expect(result.month, 7);
      expect(result.day, 15);
      expect(result.hour, 11);
      expect(result.minute, 4);
    });

    test('respeta un timestamp que incluye el offset de Ecuador', () {
      final result = EcuadorTime.parse('2026-07-15T11:04:00-05:00');

      expect(result.hour, 11);
      expect(result.minute, 4);
    });

    test('interpreta timestamps sin zona como UTC del servidor', () {
      final result = EcuadorTime.parse('2026-07-15 16:04:00');

      expect(result.hour, 11);
      expect(result.minute, 4);
    });

    test('ajusta correctamente el cambio al día anterior', () {
      final result = EcuadorTime.parse('2026-07-15T03:30:00Z');

      expect(result.day, 14);
      expect(result.hour, 22);
      expect(result.minute, 30);
    });
  });
}
