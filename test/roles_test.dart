import 'package:flutter_test/flutter_test.dart';
import 'package:app_mobile_sistema_alarma/core/auth/roles.dart';

void main() {
  test('representante y vecino conservan acceso comunitario movil', () {
    expect(canAccessCommunityFeatures(2), isTrue);
    expect(canAccessCommunityFeatures(3), isTrue);
    expect(canAccessCommunityFeatures(1), isFalse);
    expect(canAccessCommunityFeatures(null), isFalse);
  });

  test('muestra nombres de rol coherentes', () {
    expect(communityRoleLabel(2), 'Representante');
    expect(communityRoleLabel(3), 'Vecino');
  });
}
