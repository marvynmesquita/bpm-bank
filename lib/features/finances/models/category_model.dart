class CategoryModel {
  final String id;
  final String name;
  final String type; // 'credito', 'fixa', 'variavel', 'outros'
  final double? fixedValue;
  final int? closingDay;
  final int? dueDay;
  final String createdBy;

  CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    this.fixedValue,
    this.closingDay,
    this.dueDay,
    required this.createdBy,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json, String documentId) {
    return CategoryModel(
      id: documentId,
      name: json['name'],
      type: json['type'],
      fixedValue: (json['fixed_value'] as num?)?.toDouble(),
      closingDay: json['closing_day'] as int?,
      dueDay: json['due_day'] as int?,
      createdBy: json['created_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      if (fixedValue != null) 'fixed_value': fixedValue,
      if (closingDay != null) 'closing_day': closingDay,
      if (dueDay != null) 'due_day': dueDay,
      'created_by': createdBy,
    };
  }
}
