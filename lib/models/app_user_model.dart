class AppUserModel {
  final String email;
  final String name;
  final String role;

  AppUserModel({
    required this.email,
    required this.name,
    required this.role,
  });

  factory AppUserModel.fromJson(Map<String, dynamic> json) {
    return AppUserModel(
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'email': email,
        'name': name,
        'role': role,
      };
}
