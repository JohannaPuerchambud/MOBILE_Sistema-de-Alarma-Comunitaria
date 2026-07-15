import 'package:app_mobile_sistema_alarma/features/reports/report_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('acepta un reporte creado sin advertencias', () {
    final result = ReportSubmissionResult.fromJson({
      'report': {'report_id': 1},
      'warnings': [],
    });

    expect(result.warnings, isEmpty);
  });

  test('expone la advertencia cuando Firebase omite la evidencia', () {
    final result = ReportSubmissionResult.fromJson({
      'report': {'report_id': 2},
      'warnings': [
        {
          'code': 'evidence_upload_failed',
          'message': 'El reporte se registró sin evidencia.',
        },
      ],
    });

    expect(result.warnings, ['El reporte se registró sin evidencia.']);
  });
}
