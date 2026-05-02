import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../core/auth/token_storage.dart';
import 'chat_service.dart';
import 'chat_model.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final ChatService _chatService = ChatService();
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();

  final List<ChatMessage> messages = [];

  bool connecting = true;
  bool _uploadingImage = false;
  int? myUserId;
  String neighborhoodName = "";

  double _lastKeyboardInset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _inputFocusNode.addListener(() {
      if (_inputFocusNode.hasFocus) {
        _scrollToBottomDelayed();
      }
    });

    _initChat();
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding.instance.platformDispatcher.views.first.viewInsets.bottom;

    if (bottomInset != _lastKeyboardInset) {
      _lastKeyboardInset = bottomInset;
      _scrollToBottomDelayed();
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;

    if (animated) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(0.0);
    }
  }

  void _scrollToBottomDelayed() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    });
  }

  Future<void> _initChat() async {
    final token = await TokenStorage().getToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }

    final claims = JwtDecoder.decode(token);
    myUserId = claims['id'] is int ? claims['id'] : int.tryParse('${claims['id']}');
    neighborhoodName = '${claims['neighborhood_name'] ?? ""}';

    if (mounted) {
      setState(() {});
    }

    await _chatService.connect(
      onHistory: (history) {
        if (!mounted) return;
        setState(() {
          messages.clear();
          messages.addAll(history);
          connecting = false;
        });

        _scrollToBottomDelayed();
      },
      onNewMessage: (msg) {
        if (!mounted) return;
        setState(() {
          messages.add(msg);
        });

        _scrollToBottomDelayed();
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

    _chatService.sendMessage(text);
    _msgCtrl.clear();

    _scrollToBottomDelayed();
  }

  // ✅ Menú para elegir entre Cámara y Galería para el chat
  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF667EEA)),
              title: const Text('Tomar foto con la cámara', style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF667EEA)),
              title: const Text('Elegir de la galería', style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Seleccionar foto, comprimir, subir a Firebase y enviar al chat
  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 60,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (pickedFile == null) return;

      setState(() => _uploadingImage = true);

      // Subir a Firebase Storage
      final file = File(pickedFile.path);
      final fileName = 'chat_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child('chat_images/$fileName');
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Enviar mensaje con imagen
      _chatService.sendMessage('', imageUrl: downloadUrl);

      _scrollToBottomDelayed();
    } catch (e) {
      _snack("Error al enviar la imagen. Intenta de nuevo.");
    } finally {
      if (mounted) {
        setState(() => _uploadingImage = false);
      }
    }
  }

  void _snack(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s)),
    );
  }

  // ✅ Función auxiliar para formatear la fecha
  String _formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  // ✅ Función auxiliar para mostrar un divisor de fecha si cambió el día
  Widget _buildDateDivider(DateTime dateTime) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            DateFormat('d \'de\' MMMM, y', 'es').format(dateTime), // Ej: 16 de marzo, 2026
            style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // ✅ Widget para renderizar la imagen dentro de la burbuja
  Widget _buildChatImage(String imageUrl, bool isMine) {
    return GestureDetector(
      onTap: () => _showFullImage(imageUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl,
          width: 220,
          height: 220,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 220,
              height: 220,
              color: isMine ? Colors.white24 : Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF667EEA), strokeWidth: 2),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => Container(
            width: 220,
            height: 220,
            color: isMine ? Colors.white24 : Colors.grey[200],
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ Ver imagen en pantalla completa
  void _showFullImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text('Imagen', style: TextStyle(color: Colors.white)),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _msgCtrl.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    _chatService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardBottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          neighborhoodName.isEmpty
              ? 'Chat Barrial'
              : 'Chat Barrial $neighborhoodName',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      backgroundColor: const Color(0xFFF4F6F9),
      body: Column(
        children: [
          if (connecting)
            const LinearProgressIndicator(
              color: Color(0xFF667EEA),
              backgroundColor: Colors.white,
            ),

          // ✅ Indicador de subida de imagen
          if (_uploadingImage)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: const Color(0xFF667EEA).withOpacity(0.1),
              child: const Row(
                children: [
                  SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF667EEA)),
                  ),
                  SizedBox(width: 12),
                  Text('Subiendo imagen...', style: TextStyle(color: Color(0xFF667EEA), fontSize: 13)),
                ],
              ),
            ),

          Expanded(
            child: messages.isEmpty
                ? const Center(
              child: Text(
                'Aún no hay mensajes',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                ),
              ),
            )
                : AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: keyboardBottom > 0 ? 8 : 0),
              child: ListView.builder(
                controller: _scrollController,
                reverse: true, // Scroll invertido
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: messages.length,
                itemBuilder: (_, i) {
                  // Mapeamos el índice invertido al índice real de la lista original
                  final originalIndex = messages.length - 1 - i;
                  final m = messages[originalIndex];

                  final isMine = (myUserId != null && m.userId == myUserId);
                  final name = m.fullName.isEmpty ? 'Usuario' : m.fullName;

                  // ✅ Lógica de agrupación:
                  // 1. Verificamos si el mensaje anterior (visualmente el de arriba) es del mismo usuario
                  bool isSameUserAsPrevious = false;
                  if (originalIndex > 0) {
                    final previousMessage = messages[originalIndex - 1];
                    isSameUserAsPrevious = previousMessage.userId == m.userId;
                  }

                  // 2. Verificamos si hubo un cambio de día respecto al mensaje anterior
                  bool isDifferentDay = false;
                  if (originalIndex > 0) {
                    final previousMessage = messages[originalIndex - 1];
                    isDifferentDay = previousMessage.createdAt.day != m.createdAt.day ||
                        previousMessage.createdAt.month != m.createdAt.month ||
                        previousMessage.createdAt.year != m.createdAt.year;
                  }

                  // Si cambió el día, forzamos a que no se agrupe para mostrar el separador
                  if (isDifferentDay) {
                    isSameUserAsPrevious = false;
                  }

                  // ✅ Renderizado del mensaje
                  return Column(
                    crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      // Mostrar el divisor de fecha si es el primer mensaje o si cambió el día
                      if (originalIndex == 0 || isDifferentDay)
                        _buildDateDivider(m.createdAt),

                      Align(
                        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          // ✅ Margen superior reducido si es un mensaje agrupado
                          margin: EdgeInsets.only(
                              top: isSameUserAsPrevious ? 2 : 12,
                              bottom: 2
                          ),
                          padding: EdgeInsets.only(
                            left: m.hasImage ? 4 : 14,
                            right: m.hasImage ? 4 : 14,
                            top: m.hasImage ? 4 : 10,
                            bottom: 10,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: isMine ? const Color(0xFF667EEA) : Colors.white,
                            // ✅ Ajustamos los bordes si está agrupado
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isMine || isSameUserAsPrevious ? 16 : 4),
                              bottomRight: Radius.circular(!isMine || isSameUserAsPrevious ? 16 : 4),
                            ),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ✅ Solo mostrar el nombre si NO está agrupado
                              if (!isSameUserAsPrevious) ...[
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: m.hasImage ? 10 : 0,
                                    bottom: 4,
                                  ),
                                  child: Text(
                                    isMine ? 'Tú' : name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isMine ? Colors.white70 : const Color(0xFF764BA2),
                                    ),
                                  ),
                                ),
                              ],

                              // ✅ Imagen del mensaje (si existe)
                              if (m.hasImage) ...[
                                _buildChatImage(m.imageUrl!, isMine),
                                const SizedBox(height: 6),
                              ],

                              // ✅ Texto del mensaje (solo si no es solo foto)
                              if (m.message.isNotEmpty && m.message != '📷 Foto')
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: m.hasImage ? 10 : 0),
                                  child: Text(
                                    m.message,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: isMine ? Colors.white : const Color(0xFF333333),
                                    ),
                                  ),
                                ),

                              // ✅ Etiqueta de hora alineada a la derecha
                              const SizedBox(height: 4),
                              Padding(
                                padding: EdgeInsets.only(right: m.hasImage ? 10 : 0),
                                child: Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    _formatTime(m.createdAt),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isMine ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // ✅ Barra de entrada con botón de foto
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, -2),
                )
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // ✅ Botón de adjuntar foto
                  IconButton(
                    onPressed: _uploadingImage ? null : _showImageSourceActionSheet,
                    icon: Icon(
                      Icons.attach_file_rounded,
                      color: _uploadingImage ? Colors.grey : const Color(0xFF667EEA),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      focusNode: _inputFocusNode,
                      textInputAction: TextInputAction.send,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF4F6F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onTap: _scrollToBottomDelayed,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _send,
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                      ),
                    ),
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