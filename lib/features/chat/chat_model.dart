import '../../core/utils/ecuador_time.dart';

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
    return ChatMessage(
      messageId: (json['message_id'] ?? 0) as int,
      userId: (json['user_id'] ?? 0) as int,
      name: (json['name'] ?? '') as String,
      lastName: json['last_name'] as String?,
      message: (json['message'] ?? '') as String,
      imageUrl: json['image_url'] as String?,
      createdAt: EcuadorTime.parse(json['created_at']),
    );
  }

  String get fullName {
    final ln = (lastName ?? '').trim();
    return ln.isEmpty ? name : '$name $ln';
  }

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
}
