import 'package:flutter_test/flutter_test.dart';
import 'package:app_mobile_sistema_alarma/features/chat/chat_service.dart';

void main() {
  test('oculta el error tecnico cuando falla la resolucion DNS', () {
    final message = ChatService.userMessageForError(
      "SocketException: Failed host lookup: 'api.example.com'",
    );

    expect(message, contains('Sin conexión con el servidor'));
    expect(message, isNot(contains('SocketException')));
    expect(message, isNot(contains('Failed host lookup')));
  });

  test('explica un timeout sin mostrar detalles internos', () {
    final message = ChatService.userMessageForError('timeout');

    expect(message, contains('tardando en responder'));
    expect(message, isNot(contains('Exception')));
  });
}
