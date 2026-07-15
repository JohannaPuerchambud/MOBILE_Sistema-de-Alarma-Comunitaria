import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/auth/token_storage.dart';
import '../../core/config/api.dart';
import 'chat_model.dart';

class ChatException implements Exception {
  final String message;

  const ChatException(this.message);

  @override
  String toString() => message;
}

class ChatService {
  io.Socket? _socket;
  final TokenStorage _storage = TokenStorage();

  void Function(List<ChatMessage> history)? _onHistory;
  void Function(ChatMessage message)? _onNewMessage;
  void Function(String message)? _onError;
  void Function(bool connected, String? message)? _onConnectionChanged;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect({
    required void Function(List<ChatMessage> history) onHistory,
    required void Function(ChatMessage msg) onNewMessage,
    required void Function(String msg) onError,
    required void Function(bool connected, String? message) onConnectionChanged,
  }) async {
    final token = await _storage.getToken();
    if (token == null || token.isEmpty) {
      onError('Tu sesión terminó. Inicia sesión nuevamente.');
      return;
    }

    disconnect();

    _onHistory = onHistory;
    _onNewMessage = onNewMessage;
    _onError = onError;
    _onConnectionChanged = onConnectionChanged;

    _socket = io.io(ApiConfig.socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'forceNew': true,
      'reconnection': true,
      'reconnectionAttempts': 12,
      'reconnectionDelay': 1000,
      'reconnectionDelayMax': 8000,
      'timeout': ApiConfig.chatConnectTimeout.inMilliseconds,
      'auth': {'token': token},
    });

    _socket!.onConnect((_) {
      _onConnectionChanged?.call(true, null);
    });

    _socket!.onDisconnect((_) {
      _onConnectionChanged?.call(false, 'Reconectando el chat en tiempo real…');
    });

    _socket!.onConnectError((data) {
      _onConnectionChanged?.call(false, userMessageForError(data));
    });

    _socket!.onError((data) {
      _onConnectionChanged?.call(false, userMessageForError(data));
    });

    _socket!.on('reconnect_attempt', (_) {
      _onConnectionChanged?.call(false, 'Reconectando el chat en tiempo real…');
    });

    _socket!.on('error_message', (data) {
      _onError?.call(data?.toString() ?? 'Ocurrió un error en el chat.');
    });

    _socket!.on('history', (data) {
      if (data is List) {
        final history = data
            .whereType<Map>()
            .map(
              (item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
        _onHistory?.call(history);
      }
    });

    _socket!.on('new_message', (data) {
      if (data is Map) {
        _onNewMessage?.call(
          ChatMessage.fromJson(Map<String, dynamic>.from(data)),
        );
      }
    });

    _socket!.connect();

    // La consulta REST despierta el servicio de Render y mantiene disponible
    // el historial aunque el proxy tarde en establecer el WebSocket.
    unawaited(_loadHistoryWithRetry(token));
  }

  Future<void> _loadHistoryWithRetry(String token) async {
    Object? lastError;

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await http
            .get(
              Uri.parse('${ApiConfig.baseUrl}/chat/messages?limit=50'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(ApiConfig.chatConnectTimeout);

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) {
            final history = decoded
                .whereType<Map>()
                .map(
                  (item) =>
                      ChatMessage.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList();
            _onHistory?.call(history);
          }
          return;
        }

        throw ChatException(_messageFromResponse(response));
      } catch (error) {
        lastError = error;
        if (error is ChatException || attempt == 1) break;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }

    if (!isConnected && lastError != null) {
      _onConnectionChanged?.call(false, userMessageForError(lastError));
    }
  }

  Future<ChatMessage> sendMessage(String text, {String? imageUrl}) async {
    final message = text.trim();
    if (message.isEmpty && (imageUrl == null || imageUrl.isEmpty)) {
      throw const ChatException('Escribe un mensaje o adjunta una imagen.');
    }

    final token = await _storage.getToken();
    if (token == null || token.isEmpty) {
      throw const ChatException('Tu sesión terminó. Inicia sesión nuevamente.');
    }

    final requestId =
        '${DateTime.now().microsecondsSinceEpoch}-${message.hashCode}-${imageUrl?.hashCode ?? 0}';

    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await http
            .post(
              Uri.parse('${ApiConfig.baseUrl}/chat/messages'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
                'Idempotency-Key': requestId,
              },
              body: json.encode({
                'message': message.isNotEmpty ? message : '📷 Foto',
                if (imageUrl != null && imageUrl.isNotEmpty)
                  'image_url': imageUrl,
              }),
            )
            .timeout(ApiConfig.chatRequestTimeout);

        if (response.statusCode == 201) {
          final decoded = json.decode(response.body);
          if (decoded is Map) {
            return ChatMessage.fromJson(Map<String, dynamic>.from(decoded));
          }
          throw const ChatException(
            'El servidor devolvió una respuesta inválida.',
          );
        }

        throw ChatException(_messageFromResponse(response));
      } catch (error) {
        lastError = error;
        if (error is ChatException || attempt == 1) break;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }

    throw ChatException(userMessageForError(lastError));
  }

  void reconnect() {
    if (!isConnected) {
      _socket?.connect();
    }
  }

  static String _messageFromResponse(http.Response response) {
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {
      // La respuesta no era JSON; se usa un mensaje seguro.
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      return 'Tu sesión terminó o ya no tienes acceso al barrio.';
    }
    return 'No se pudo completar la operación del chat.';
  }

  static String userMessageForError(Object? error) {
    if (error is ChatException) return error.message;

    final detail = error?.toString().toLowerCase() ?? '';
    if (detail.contains('failed host lookup') ||
        detail.contains('socketexception') ||
        detail.contains('connection refused') ||
        detail.contains('network is unreachable') ||
        detail.contains('clientexception')) {
      return 'Sin conexión con el servidor. Verifica tu internet e inténtalo nuevamente.';
    }
    if (detail.contains('timeout')) {
      return 'El servidor está tardando en responder. El chat seguirá intentando conectarse.';
    }
    if (detail.contains('invalid_token') ||
        detail.contains('no_token') ||
        detail.contains('invalid_user')) {
      return 'Tu sesión terminó. Inicia sesión nuevamente.';
    }

    return 'No se pudo conectar al chat. Se intentará nuevamente.';
  }

  void disconnect() {
    final socket = _socket;
    _socket = null;
    _onHistory = null;
    _onNewMessage = null;
    _onError = null;
    _onConnectionChanged = null;
    socket?.disconnect();
    socket?.dispose();
  }
}
