class UserModel {
  final String id;
  final String email;
  final String name;
  final double monthlyIncome;
  final DateTime createdAt;
  final String? partnerEmail;
  final String? partnerUid;
  final int? payDay;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.monthlyIncome = 0.0,
    DateTime? createdAt,
    this.partnerEmail,
    this.partnerUid,
    this.payDay,
  }) : createdAt = createdAt ?? DateTime.now();

  factory UserModel.fromJson(Map<String, dynamic> json, String documentId) {
    return UserModel(
      id: documentId,
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      monthlyIncome: (json['monthly_income'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() 
          : DateTime.now(),
      partnerEmail: json['partner_email'],
      partnerUid: json['partner_uid'],
      payDay: json['pay_day'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'name': name,
      'monthly_income': monthlyIncome,
      'created_at': createdAt.toIso8601String(),
      if (partnerEmail != null) 'partner_email': partnerEmail,
      if (partnerUid != null) 'partner_uid': partnerUid,
      if (payDay != null) 'pay_day': payDay,
    };
  }
}
