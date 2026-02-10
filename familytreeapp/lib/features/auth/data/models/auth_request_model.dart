class LoginRequestModel {
  final String username;
  final String password;

  LoginRequestModel({required this.username, required this.password});

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
    };
  }
}

class RegisterRequestModel {
  final String username;
  final String password;
  final String firstName;
  final String? lastName;
  final String? gender;
  final String? dateOfBirth;
  final String? placeOfBirth;
  final String email;
  final String role; 

  RegisterRequestModel({
    required this.username,
    required this.password,
    required this.firstName,
    this.lastName,
    this.gender,
    this.dateOfBirth,
    this.placeOfBirth,
    required this.email,
    this.role = 'member', // Mặc định là member
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'first_name': firstName,
      'last_name': lastName,
      'gender': gender,
      'date_of_birth': dateOfBirth,
      'place_of_birth': placeOfBirth,
      'email': email,
      'role': role,
    };
  }
}