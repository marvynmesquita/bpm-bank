class ShoppingItemModel {
  final String id;
  final String name;
  final bool isBought;
  final String createdBy;

  ShoppingItemModel({
    required this.id,
    required this.name,
    this.isBought = false,
    required this.createdBy,
  });

  factory ShoppingItemModel.fromJson(Map<String, dynamic> json, String documentId) {
    return ShoppingItemModel(
      id: documentId,
      name: json['name'] ?? '',
      isBought: json['is_bought'] ?? false,
      createdBy: json['created_by'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'is_bought': isBought,
      'created_by': createdBy,
    };
  }

  ShoppingItemModel copyWith({
    String? id,
    String? name,
    bool? isBought,
    String? createdBy,
  }) {
    return ShoppingItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isBought: isBought ?? this.isBought,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
