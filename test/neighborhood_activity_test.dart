import 'package:app_mobile_sistema_alarma/features/reports/report_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('interpreta una emergencia con evidencia y ubicación', () {
    final activity = NeighborhoodActivity.fromJson({
      'activity_id': 'emergency-21',
      'source_id': 21,
      'activity_type': 'emergency',
      'title': 'Emergencia',
      'description': 'Fuga de gas',
      'image_url': 'https://example.com/evidence.jpg',
      'created_at': '2026-07-17T22:40:00.000Z',
      'user_id': 8,
      'name': 'María',
      'last_name': 'López',
      'address': 'Calle Principal',
      'latitude': 0.351,
      'longitude': -78.122,
    });

    expect(activity.isEmergency, isTrue);
    expect(activity.hasImage, isTrue);
    expect(activity.hasLocation, isTrue);
    expect(activity.authorName, 'María López');
    expect(activity.description, 'Fuga de gas');
  });

  test('interpreta un reporte sin ubicación', () {
    final activity = NeighborhoodActivity.fromJson({
      'activity_id': 'report-4',
      'source_id': 4,
      'activity_type': 'report',
      'title': 'Actividad sospechosa',
      'description': 'Mucho ruido',
      'created_at': '2026-07-17T22:40:00.000Z',
      'user_id': 8,
    });

    expect(activity.isEmergency, isFalse);
    expect(activity.hasImage, isFalse);
    expect(activity.hasLocation, isFalse);
    expect(activity.authorName, 'Usuario anónimo');
  });
}
