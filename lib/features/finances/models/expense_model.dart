import 'category_model.dart';

class ExpenseModel {
  final String id;
  final String userId;
  final String? categoryId;
  final CategoryModel? category;
  final double amount;
  final String? description;
  final DateTime date;
  final String? sharedWithUserId;
  final bool isPaid;
  final bool isRecurring;
  final int currentInstallment;
  final int totalInstallments;

  ExpenseModel({
    required this.id,
    required this.userId,
    this.categoryId,
    this.category,
    required this.amount,
    this.description,
    required this.date,
    this.sharedWithUserId,
    this.isPaid = false,
    this.isRecurring = false,
    this.currentInstallment = 1,
    this.totalInstallments = 1,
  });

  double get effectiveAmount => sharedWithUserId != null ? amount / 2 : amount;

  factory ExpenseModel.fromJson(Map<String, dynamic> json, String documentId) {
    return ExpenseModel(
      id: documentId,
      userId: json['user_id'],
      categoryId: json['category_id'],
      category: json['categories'] != null ? CategoryModel.fromJson(json['categories'], '') : null,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'],
      date: json['date'] != null 
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now() 
          : DateTime.now(),
      sharedWithUserId: json['shared_with_user_id'],
      isPaid: json['is_paid'] ?? false,
      isRecurring: json['is_recurring'] ?? false,
      currentInstallment: json['current_installment'] ?? 1,
      totalInstallments: json['total_installments'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      if (categoryId != null) 'category_id': categoryId,
      'amount': amount,
      if (description != null) 'description': description,
      'date': date.toIso8601String().split('T').first,
      if (sharedWithUserId != null) 'shared_with_user_id': sharedWithUserId,
      'is_paid': isPaid,
      'is_recurring': isRecurring,
      'current_installment': currentInstallment,
      'total_installments': totalInstallments,
    };
  }
}
