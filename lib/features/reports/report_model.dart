import '../../core/utils/ecuador_time.dart';

enum NeighborhoodActivityType { report, emergency }

class NeighborhoodActivity {
  final String activityId;
  final int sourceId;
  final int userId;
  final NeighborhoodActivityType type;
  final String title;
  final String description;
  final DateTime createdAt;
  final String? name;
  final String? lastName;
  final String? imageUrl;
  final String? address;
  final double? latitude;
  final double? longitude;

  const NeighborhoodActivity({
    required this.activityId,
    required this.sourceId,
    required this.userId,
    required this.type,
    required this.title,
    required this.description,
    required this.createdAt,
    this.name,
    this.lastName,
    this.imageUrl,
    this.address,
    this.latitude,
    this.longitude,
  });

  factory NeighborhoodActivity.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    double? asDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    return NeighborhoodActivity(
      activityId: json['activity_id']?.toString() ?? '',
      sourceId: asInt(json['source_id']),
      userId: asInt(json['user_id']),
      type: json['activity_type'] == 'emergency'
          ? NeighborhoodActivityType.emergency
          : NeighborhoodActivityType.report,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      createdAt: EcuadorTime.parse(json['created_at']),
      name: json['name']?.toString(),
      lastName: json['last_name']?.toString(),
      imageUrl: json['image_url']?.toString(),
      address: json['address']?.toString(),
      latitude: asDouble(json['latitude']),
      longitude: asDouble(json['longitude']),
    );
  }

  bool get isEmergency => type == NeighborhoodActivityType.emergency;

  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  bool get hasLocation => latitude != null && longitude != null;

  String get authorName {
    final parts = [
      name?.trim() ?? '',
      lastName?.trim() ?? '',
    ].where((part) => part.isNotEmpty);
    final value = parts.join(' ');
    return value.isEmpty ? 'Usuario anónimo' : value;
  }
}
