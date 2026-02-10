class UserModel {
  final int id;
  final String username;
  final String? firstName;
  final String? lastName;
  final String email;
  final String role;

  UserModel({
    required this.id,
    required this.username,
    this.firstName,
    this.lastName,
    required this.email,
    required this.role,
  });

  // Helper getter để lấy full name
  String get fullName => '${lastName ?? ''} ${firstName ?? ''}'.trim();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['user_id'] ?? 0, 
      username: json['username'] ?? '',
      firstName: json['first_name'],
      lastName: json['last_name'],
      email: json['email'] ?? '',
      role: json['role'] ?? 'member',
    );
  }
}