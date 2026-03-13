import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../core/config/api.dart';
import '../../core/auth/token_storage.dart';
import 'chat_model.dart';

class ChatService {
  IO.Socket? _socket;

  final _storage = TokenStorage();

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect({
    required void Function(List<ChatMessage> history) onHistory,
    required void Function(ChatMessage msg) onNewMessage,
    required void Function(String msg) onError,
  }) async {
    final token = await _storage.getToken();
    if (token == null || token.isEmpty) {
      onError("No hay token. Inicia sesión.");
      return;
    }

    // Si ya hay socket, desconectar primero
    disconnect();

    _socket = IO.io(
      ApiConfig.socketUrl,
      <String, dynamic>{
        "transports": ["websocket"],
        "autoConnect": false,
        // esto llega en socket.handshake.auth.token
        "forceNew": true,
        "auth": {"token": token},
      },
    );

    _socket!.onConnect((_) {
      // conectado
    });

    _socket!.onDisconnect((_) {
      // desconectado
    });

    _socket!.onConnectError((data) {
      onError("No se pudo conectar al chat: $data");
    });

    _socket!.onError((data) {
      onError("Error del chat: $data");
    });

    _socket!.on("error_message", (data) {
      onError(data?.toString() ?? "Error desconocido");
    });

    // historial (backend manda array)
    _socket!.on("history", (data) {
      if (data is List) {
        final list = data
            .whereType<Map>()
            .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        onHistory(list);
      }
    });

    // mensajes nuevos
    _socket!.on("new_message", (data) {
      if (data is Map) {
        final msg = ChatMessage.fromJson(Map<String, dynamic>.from(data));
        onNewMessage(msg);
      }
    });

    _socket!.connect();
  }

  void sendMessage(String text) {
    final msg = text.trim();
    if (msg.isEmpty) return;
    _socket?.emit("send_message", {"message": msg});
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
