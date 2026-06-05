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

  test('informa cuando Firebase limpia tokens vencidos', () {
    final result = EmergencyResult.fromJson({
      'delivery': {
        'push': {
          'status': 'failed',
          'attempted': 3,
          'success': 0,
          'failure': 3,
          'invalidated': 3,
        },
        'twilio': {'status': 'queued'},
      },
    });

    expect(result.pushInvalidated, 3);
    expect(result.userMessage, contains('tokens push registrados estaban vencidos'));
  });

  test('informa cuando Twilio requiere verificar el numero destino', () {
    final result = EmergencyResult.fromJson({
      'delivery': {
        'push': {'status': 'no_recipients'},
        'twilio': {'status': 'unverified_alarm_number', 'error_code': 21608},
      },
    });

    expect(result.twilioErrorCode, '21608');
    expect(result.userMessage, contains('verificado en Twilio'));
  });
}
