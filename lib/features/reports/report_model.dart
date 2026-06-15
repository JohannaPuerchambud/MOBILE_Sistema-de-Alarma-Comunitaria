class ReportModel {
  final int reportId;
  final int userId;
  final String title;
  final String description;
  final DateTime createdAt;
  final String? name;
  final String? lastName;
  final String? imageUrl;
  final String? address;

  ReportModel({
    required this.reportId,
    required this.userId,
    required this.title,
    required this.description,
    required this.createdAt,
    this.name,
    this.lastName,
    this.imageUrl,
    this.address,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    // El servidor guarda en UTC. Convertimos a hora de Ecuador (UTC-5).
    DateTime raw = DateTime.tryParse((json['created_at'] ?? '').toString()) ??
        DateTime.now().toUtc();
    if (!raw.isUtc) {
      raw = DateTime.utc(
          raw.year, raw.month, raw.day, raw.hour, raw.minute, raw.second, raw.millisecond);
    }
    // UTC-5 = Ecuador (America/Guayaquil)
    final ecuadorTime = raw.subtract(const Duration(hours: 5));

    return ReportModel(
      reportId: json['report_id'],
      userId: json['user_id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      createdAt: ecuadorTime,
      name: json['name'],
      lastName: json['last_name'],
      imageUrl: json['image_url'],
      address: json['address'],
    );
  }
}
