import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../../core/auth/token_storage.dart';
import 'chat_service.dart';
import 'chat_model.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // ✅ Instanciamos tu servicio centralizado
  final ChatService _chatService = ChatService();
  final _msgCtrl = TextEditingController();

  // ✅ Ahora usamos tu modelo ChatMessage directamente
  final List<ChatMessage> messages = [];
  bool connecting = true;

  int? myUserId;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    final token = await TokenStorage().getToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }

    // Sacamos tu ID para saber cuáles mensajes son tuyos
    final claims = JwtDecoder.decode(token);
    myUserId = claims['id'] is int ? claims['id'] : int.tryParse('${claims['id']}');

    // ✅ Nos conectamos usando el ChatService
    await _chatService.connect(
      onHistory: (history) {
        if (!mounted) return;
        setState(() {
          messages.clear();
          messages.addAll(history);
          connecting = false;
        });
      },
      onNewMessage: (msg) {
        if (!mounted) return;
        setState(() {
          // Lo agregamos al final de la lista
          messages.add(msg);
        });
      },
      onError: (err) {
        if (!mounted) return;
        setState(() => connecting = false);
        _snack(err);
      },
    );
  }

  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    // ✅ Enviamos el mensaje a través del servicio
    _chatService.sendMessage(text);
    _msgCtrl.clear();
  }

  void _snack(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _chatService.disconnect(); // ✅ Nos desconectamos al salir de la pantalla
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat barrial')),
      body: Column(
        children: [
          if (connecting)
            const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(),
            ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              itemBuilder: (_, i) {
                final m = messages[i];
                final isMine = (myUserId != null && m.userId == myUserId);
                final name = m.fullName.isEmpty ? 'Usuario' : m.fullName;

                return Align(
                  alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: isMine ? Colors.blue.shade100 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMine ? 'Tú' : name,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        // ✅ Leemos el mensaje directo del modelo
                        Text(m.message),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje…',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}