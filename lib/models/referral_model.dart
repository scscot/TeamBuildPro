class ReferralModel {
  final String referredBy;
  final String referredUser;
  final DateTime referredAt;

  ReferralModel({
    required this.referredBy,
    required this.referredUser,
    required this.referredAt,
  });

  factory ReferralModel.fromJson(Map<String, dynamic> json) {
    return ReferralModel(
      referredBy: json['referredBy'] ?? '',
      referredUser: json['referredUser'] ?? '',
      referredAt: DateTime.parse(json['referredAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'referredBy': referredBy,
        'referredUser': referredUser,
        'referredAt': referredAt.toIso8601String(),
      };
}
