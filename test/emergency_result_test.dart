import 'package:app_mobile_sistema_alarma/features/emergency/emergency_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('informa cuando el barrio no tiene numero de alarma', () {
    final result = EmergencyResult.fromJson({
      'delivery': {
        'push': {'status': 'sent', 'success': 2},
        'twilio': {'status': 'no_alarm_number'},
      },
    });

    expect(result.userMessage, contains('2 notificaciones'));
    expect(result.userMessage, contains('no tiene un numero de alarma'));
  });

  test('mantiene compatibilidad con la respuesta anterior de la API', () {
    final result = EmergencyResult.fromJson({
      'message': 'Emergencia activada correctamente',
    });

    expect(result.twilioStatus, 'unknown');
    expect(result.pushStatus, 'unknown');
  });
}
