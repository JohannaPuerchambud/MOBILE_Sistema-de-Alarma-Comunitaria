import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/api.dart';
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
  bool _sendingMessage = false;
  bool _socketConnected = false;
  String? _connectionMessage;
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
    final bottomInset = WidgetsBinding
        .instance
        .platformDispatcher
        .views
        .first
        .viewInsets
        .bottom;

    if (bottomInset != _lastKeyboardInset) {
      _lastKeyboardInset = bottomInset;
      _scrollToBottomDelayed();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _chatService.reconnect();
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
    myUserId = claims['id'] is int
        ? claims['id']
        : int.tryParse('${claims['id']}');
    neighborhoodName = '${claims['neighborhood_name'] ?? ""}';

    if (mounted) {
      setState(() {
        connecting = true;
        _connectionMessage = null;
      });
    }

    await _chatService.connect(
      onHistory: (history) {
        if (!mounted) return;
        setState(() {
          messages
            ..clear()
            ..addAll(history);
          connecting = false;
        });
        _scrollToBottomDelayed();
      },
      onNewMessage: (message) {
        if (!mounted) return;
        _upsertMessage(message);
      },
      onError: (message) {
        if (!mounted) return;
        setState(() => connecting = false);
        _snack(message);
      },
      onConnectionChanged: (connected, message) {
        if (!mounted) return;
        setState(() {
          connecting = false;
          _socketConnected = connected;
          _connectionMessage = message;
        });
      },
    );
  }

  void _upsertMessage(ChatMessage message) {
    if (!mounted) return;

    setState(() {
      final index = messages.indexWhere(
        (item) => item.messageId == message.messageId,
      );
      if (index >= 0) {
        messages[index] = message;
      } else {
        messages.add(message);
      }
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    });
    _scrollToBottomDelayed();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sendingMessage) return;

    setState(() => _sendingMessage = true);
    try {
      final sentMessage = await _chatService.sendMessage(text);
      _upsertMessage(sentMessage);
      _msgCtrl.clear();
    } catch (error) {
      _snack(ChatService.userMessageForError(error));
    } finally {
      if (mounted) {
        setState(() => _sendingMessage = false);
      }
    }
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
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: Color(0xFF667EEA),
              ),
              title: const Text(
                'Tomar foto con la cámara',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: Color(0xFF667EEA),
              ),
              title: const Text(
                'Elegir de la galería',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
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

  // ✅ Seleccionar foto, comprimir, subir al backend y enviar URL al chat
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

      final token = await TokenStorage().getToken();
      if (token == null || token.isEmpty) {
        throw const ChatException(
          'Tu sesión terminó. Inicia sesión nuevamente.',
        );
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/chat/upload-image'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath('image', pickedFile.path),
      );

      final streamedResponse = await request.send().timeout(
        ApiConfig.chatRequestTimeout,
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        var message =
            'No se pudo guardar la imagen. Puedes enviar un mensaje de texto.';
        try {
          final decoded = json.decode(response.body);
          if (decoded is Map && decoded['message'] != null) {
            message = decoded['message'].toString();
          }
        } catch (_) {
          // La API no devolvió JSON; se conserva el mensaje seguro.
        }
        throw ChatException(message);
      }

      final decoded = json.decode(response.body);
      final downloadUrl = decoded is Map
          ? decoded['image_url']?.toString()
          : null;
      if (downloadUrl == null || downloadUrl.isEmpty) {
        throw const ChatException(
          'La imagen se guardó, pero la API no devolvió una dirección válida.',
        );
      }

      final sentMessage = await _chatService.sendMessage(
        '',
        imageUrl: downloadUrl,
      );
      _upsertMessage(sentMessage);
    } catch (error) {
      _snack(ChatService.userMessageForError(error));
    } finally {
      if (mounted) {
        setState(() => _uploadingImage = false);
      }
    }
  }

  void _snack(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
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
            DateFormat(
              'd \'de\' MMMM, y',
              'es',
            ).format(dateTime), // Ej: 16 de marzo, 2026
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.bold,
            ),
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
                child: CircularProgressIndicator(
                  color: Color(0xFF667EEA),
                  strokeWidth: 2,
                ),
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
  // ✅ Detecta si un mensaje contiene ubicación (formato nuevo o antiguo)
  static final _locationTagRegex = RegExp(
    r'\[LOCATION:([\-\d.]+),([\-\d.]+)\]',
  );
  static final _legacyMapsRegex = RegExp(
    r'📍\s*Ubicación:\s*(https://maps\.google\.com/\?q=[\-\d.,]+)',
  );
  static final _noEvidenceRegex = RegExp(r'\[NO_EVIDENCE\]');

  /// Detecta si un mensaje es de emergencia
  bool _isEmergencyMessage(String message) {
    return message.contains('🚨') && message.contains('EMERGENCIA ACTIVADA');
  }

  /// Extrae la URL de Google Maps del mensaje, si existe.
  String? _extractMapsUrl(String message) {
    final tagMatch = _locationTagRegex.firstMatch(message);
    if (tagMatch != null) {
      final lat = tagMatch.group(1);
      final lng = tagMatch.group(2);
      return 'https://maps.google.com/?q=$lat,$lng';
    }
    final legacyMatch = _legacyMapsRegex.firstMatch(message);
    if (legacyMatch != null) {
      return legacyMatch.group(1);
    }
    return null;
  }

  /// Limpia el mensaje removiendo tags internos para mostrar solo el texto.
  String _cleanMessageText(String message) {
    String cleaned = message.replaceAll(_locationTagRegex, '').trim();
    cleaned = cleaned.replaceAll(_legacyMapsRegex, '').trim();
    cleaned = cleaned.replaceAll(_noEvidenceRegex, '').trim();
    return cleaned;
  }

  /// Construye el botón de "Ver Ubicación" para mensajes de emergencia.
  Widget _buildLocationButton(String mapsUrl, bool isMine) {
    return GestureDetector(
      onTap: () async {
        try {
          final uri = Uri.parse(mapsUrl);
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No se pudo abrir Google Maps')),
            );
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isMine
                ? [
                    Colors.white.withValues(alpha: 0.25),
                    Colors.white.withValues(alpha: 0.10),
                  ]
                : [const Color(0xFF667EEA), const Color(0xFF764BA2)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: isMine
              ? Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on,
              size: 18,
              color: isMine ? Colors.white : Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              '📍 Ver Ubicación',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isMine ? Colors.white : Colors.white,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.open_in_new,
              size: 14,
              color: isMine ? Colors.white70 : Colors.white70,
            ),
          ],
        ),
      ),
    );
  }

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

          if (!connecting && !_socketConnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              color: const Color(0xFFFFF4E5),
              child: Row(
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 20,
                    color: Color(0xFF9A6700),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _connectionMessage ??
                          'Reconectando el chat en tiempo real…',
                      style: const TextStyle(
                        color: Color(0xFF6B4E00),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => connecting = true);
                      _chatService.reconnect();
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),

          // ✅ Indicador de subida de imagen
          if (_uploadingImage)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: const Color(0xFF667EEA).withValues(alpha: 0.1),
              child: const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF667EEA),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Subiendo imagen...',
                    style: TextStyle(color: Color(0xFF667EEA), fontSize: 13),
                  ),
                ],
              ),
            ),

          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Text(
                      'Aún no hay mensajes',
                      style: TextStyle(fontSize: 15, color: Colors.black54),
                    ),
                  )
                : AnimatedPadding(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.only(
                      bottom: keyboardBottom > 0 ? 8 : 0,
                    ),
                    child: ListView.builder(
                      controller: _scrollController,
                      reverse: true, // Scroll invertido
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      itemCount: messages.length,
                      itemBuilder: (_, i) {
                        // Mapeamos el índice invertido al índice real de la lista original
                        final originalIndex = messages.length - 1 - i;
                        final m = messages[originalIndex];

                        final isMine =
                            (myUserId != null && m.userId == myUserId);
                        final name = m.fullName.isEmpty
                            ? 'Usuario'
                            : m.fullName;

                        // ✅ Lógica de agrupación:
                        // 1. Verificamos si el mensaje anterior (visualmente el de arriba) es del mismo usuario
                        bool isSameUserAsPrevious = false;
                        if (originalIndex > 0) {
                          final previousMessage = messages[originalIndex - 1];
                          isSameUserAsPrevious =
                              previousMessage.userId == m.userId;
                        }

                        // 2. Verificamos si hubo un cambio de día respecto al mensaje anterior
                        bool isDifferentDay = false;
                        if (originalIndex > 0) {
                          final previousMessage = messages[originalIndex - 1];
                          isDifferentDay =
                              previousMessage.createdAt.day !=
                                  m.createdAt.day ||
                              previousMessage.createdAt.month !=
                                  m.createdAt.month ||
                              previousMessage.createdAt.year !=
                                  m.createdAt.year;
                        }

                        // Si cambió el día, forzamos a que no se agrupe para mostrar el separador
                        if (isDifferentDay) {
                          isSameUserAsPrevious = false;
                        }

                        // ✅ Renderizado del mensaje
                        return Column(
                          crossAxisAlignment: isMine
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            // Mostrar el divisor de fecha si es el primer mensaje o si cambió el día
                            if (originalIndex == 0 || isDifferentDay)
                              _buildDateDivider(m.createdAt),

                            Align(
                              alignment: isMine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                // ✅ Margen superior reducido si es un mensaje agrupado
                                margin: EdgeInsets.only(
                                  top: isSameUserAsPrevious ? 2 : 12,
                                  bottom: 2,
                                ),
                                padding: EdgeInsets.only(
                                  left: m.hasImage ? 4 : 14,
                                  right: m.hasImage ? 4 : 14,
                                  top: m.hasImage ? 4 : 10,
                                  bottom: 10,
                                ),
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.75,
                                ),
                                decoration: BoxDecoration(
                                  color: isMine
                                      ? const Color(0xFF667EEA)
                                      : Colors.white,
                                  // ✅ Ajustamos los bordes si está agrupado
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(
                                      isMine || isSameUserAsPrevious ? 16 : 4,
                                    ),
                                    bottomRight: Radius.circular(
                                      !isMine || isSameUserAsPrevious ? 16 : 4,
                                    ),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 2,
                                      offset: Offset(0, 1),
                                    ),
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
                                            color: isMine
                                                ? Colors.white70
                                                : const Color(0xFF764BA2),
                                          ),
                                        ),
                                      ),
                                    ],

                                    // ✅ Imagen del mensaje (si existe y NO es emergencia)
                                    // En emergencias, la imagen se muestra después del botón de ubicación
                                    if (m.hasImage &&
                                        !_isEmergencyMessage(m.message)) ...[
                                      _buildChatImage(m.imageUrl!, isMine),
                                      const SizedBox(height: 6),
                                    ],

                                    // ✅ Texto del mensaje (solo si no es solo foto)
                                    if (m.message.isNotEmpty &&
                                        m.message != '📷 Foto') ...[
                                      Builder(
                                        builder: (_) {
                                          final mapsUrl = _extractMapsUrl(
                                            m.message,
                                          );
                                          final displayText = mapsUrl != null
                                              ? _cleanMessageText(m.message)
                                              : m.message;
                                          final isEmergency =
                                              _isEmergencyMessage(m.message);

                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (displayText.isNotEmpty)
                                                Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: m.hasImage
                                                        ? 10
                                                        : 0,
                                                  ),
                                                  child: Text(
                                                    displayText,
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      color: isMine
                                                          ? Colors.white
                                                          : const Color(
                                                              0xFF333333,
                                                            ),
                                                    ),
                                                  ),
                                                ),
                                              if (mapsUrl != null)
                                                Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: m.hasImage
                                                        ? 10
                                                        : 0,
                                                  ),
                                                  child: _buildLocationButton(
                                                    mapsUrl,
                                                    isMine,
                                                  ),
                                                ),
                                              // ✅ Evidencia de emergencia: imagen o "Sin evidencia"
                                              if (isEmergency) ...[
                                                const SizedBox(height: 8),
                                                Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: m.hasImage
                                                        ? 10
                                                        : 0,
                                                  ),
                                                  child: Text(
                                                    '📸 Evidencia:',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isMine
                                                          ? Colors.white70
                                                          : Colors.grey[600],
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                if (m.hasImage)
                                                  Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: m.hasImage
                                                              ? 6
                                                              : 0,
                                                        ),
                                                    child: _buildChatImage(
                                                      m.imageUrl!,
                                                      isMine,
                                                    ),
                                                  )
                                                else
                                                  Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: m.hasImage
                                                              ? 10
                                                              : 0,
                                                        ),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 8,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: isMine
                                                            ? Colors.white
                                                                  .withValues(
                                                                    alpha: 0.15,
                                                                  )
                                                            : Colors.grey[100],
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .image_not_supported_outlined,
                                                            size: 16,
                                                            color: isMine
                                                                ? Colors.white54
                                                                : Colors.grey,
                                                          ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          Text(
                                                            'Sin evidencia adjunta',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontStyle:
                                                                  FontStyle
                                                                      .italic,
                                                              color: isMine
                                                                  ? Colors
                                                                        .white54
                                                                  : Colors.grey,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ],
                                          );
                                        },
                                      ),
                                    ],

                                    // ✅ Etiqueta de hora alineada a la derecha
                                    const SizedBox(height: 4),
                                    Padding(
                                      padding: EdgeInsets.only(
                                        right: m.hasImage ? 10 : 0,
                                      ),
                                      child: Align(
                                        alignment: Alignment.bottomRight,
                                        child: Text(
                                          _formatTime(m.createdAt),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isMine
                                                ? Colors.white70
                                                : Colors.black54,
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
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // ✅ Botón de adjuntar foto
                  IconButton(
                    onPressed: _uploadingImage || _sendingMessage
                        ? null
                        : _showImageSourceActionSheet,
                    icon: Icon(
                      Icons.attach_file_rounded,
                      color: _uploadingImage
                          ? Colors.grey
                          : const Color(0xFF667EEA),
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
                      onPressed: _sendingMessage ? null : _send,
                      icon: _sendingMessage
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white),
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
