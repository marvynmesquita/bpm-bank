class LoanModel {
  final String id;
  final String userId;
  final String borrowerName;
  final double amount;
  final String categoryId; // O cartão emprestado
  final String? groupId;
  final DateTime date;
  final bool isPaid;
  final bool isRecurring;
  final int currentInstallment;
  final int totalInstallments;

  LoanModel({
    required this.id,
    required this.userId,
    required this.borrowerName,
    required this.amount,
    required this.categoryId,
    this.groupId,
    required this.date,
    this.isPaid = false,
    this.isRecurring = false,
    this.currentInstallment = 1,
    this.totalInstallments = 1,
  });

  factory LoanModel.fromJson(Map<String, dynamic> json, String documentId) {
    return LoanModel(
      id: documentId,
      userId: json['user_id'] ?? '',
      borrowerName: json['borrower_name'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      categoryId: json['category_id'] ?? '',
      groupId: json['group_id'],
      date: json['date'] != null 
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now() 
          : DateTime.now(),
      isPaid: json['is_paid'] ?? false,
      isRecurring: json['is_recurring'] ?? false,
      currentInstallment: json['current_installment'] ?? 1,
      totalInstallments: json['total_installments'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'borrower_name': borrowerName,
      'amount': amount,
      'category_id': categoryId,
      if (groupId != null) 'group_id': groupId,
      'date': date.toIso8601String().split('T').first,
      'is_paid': isPaid,
      'is_recurring': isRecurring,
      'current_installment': currentInstallment,
      'total_installments': totalInstallments,
    };
  }
}
