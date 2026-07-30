class TodoItemModel {
  final String id;
  final String title;
  final bool isCompleted;
  final String createdBy;
  final String assignedTo; // 'me', 'partner', or 'both'

  TodoItemModel({
    required this.id,
    required this.title,
    this.isCompleted = false,
    required this.createdBy,
    required this.assignedTo,
  });

  factory TodoItemModel.fromJson(Map<String, dynamic> json, String documentId) {
    return TodoItemModel(
      id: documentId,
      title: json['title'] ?? '',
      isCompleted: json['is_completed'] ?? false,
      createdBy: json['created_by'] ?? '',
      assignedTo: json['assigned_to'] ?? 'both',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'is_completed': isCompleted,
      'created_by': createdBy,
      'assigned_to': assignedTo,
    };
  }

  TodoItemModel copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    String? createdBy,
    String? assignedTo,
  }) {
    return TodoItemModel(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      createdBy: createdBy ?? this.createdBy,
      assignedTo: assignedTo ?? this.assignedTo,
    );
  }
}
