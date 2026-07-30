class AppointmentModel {
  final String id;
  final String title;
  final DateTime date;
  final String createdBy;
  final double? expectedCost;

  AppointmentModel({
    required this.id,
    required this.title,
    required this.date,
    required this.createdBy,
    this.expectedCost,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json, String documentId) {
    return AppointmentModel(
      id: documentId,
      title: json['title'] ?? '',
      date: DateTime.parse(json['date']),
      createdBy: json['created_by'] ?? '',
      expectedCost: (json['expected_cost'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'date': date.toIso8601String(),
      'created_by': createdBy,
      if (expectedCost != null) 'expected_cost': expectedCost,
    };
  }

  AppointmentModel copyWith({
    String? id,
    String? title,
    DateTime? date,
    String? createdBy,
    double? expectedCost,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      createdBy: createdBy ?? this.createdBy,
      expectedCost: expectedCost ?? this.expectedCost,
    );
  }
}
