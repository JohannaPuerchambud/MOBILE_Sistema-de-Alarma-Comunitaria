class ReportModel {
  final int reportId;
  final int userId;
  final String title;
  final String description;
  final DateTime createdAt;
  final String? name;
  final String? lastName;

  ReportModel({
    required this.reportId,
    required this.userId,
    required this.title,
    required this.description,
    required this.createdAt,
    this.name,
    this.lastName,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      reportId: json['report_id'],
      userId: json['user_id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      name: json['name'],
      lastName: json['last_name'],
    );
  }
}
