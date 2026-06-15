class ChatMessage {
  final int messageId;
  final int userId;
  final String name;
  final String? lastName;
  final String message;
  final String? imageUrl;
  final DateTime createdAt;

  ChatMessage({
    required this.messageId,
    required this.userId,
    required this.name,
    this.lastName,
    required this.message,
    this.imageUrl,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // El servidor guarda en UTC. Convertimos a hora de Ecuador (UTC-5).
    DateTime raw = DateTime.tryParse((json['created_at'] ?? '').toString()) ??
        DateTime.now().toUtc();
    // Si el string no tiene 'Z' ni offset, lo tratamos como UTC explícitamente
    if (!raw.isUtc) {
      raw = DateTime.utc(
          raw.year, raw.month, raw.day, raw.hour, raw.minute, raw.second, raw.millisecond);
    }
    // UTC-5 = Ecuador (America/Guayaquil)
    final ecuadorTime = raw.subtract(const Duration(hours: 5));

    return ChatMessage(
      messageId: (json['message_id'] ?? 0) as int,
      userId: (json['user_id'] ?? 0) as int,
      name: (json['name'] ?? '') as String,
      lastName: json['last_name'] as String?,
      message: (json['message'] ?? '') as String,
      imageUrl: json['image_url'] as String?,
      createdAt: ecuadorTime,
    );
  }

  String get fullName {
    final ln = (lastName ?? '').trim();
    return ln.isEmpty ? name : '$name $ln';
  }

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
}
