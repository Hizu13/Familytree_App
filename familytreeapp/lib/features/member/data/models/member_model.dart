class MemberModel {
  final int? id;
  final String firstName;
  final String? lastName;
  final String gender;
  final String? dateOfBirth;
  final String? dateOfDeath;
  final String? placeOfBirth;
  final String? avatarUrl;
  final String? biography;
  final int? fatherId;
  final int? motherId;
  final int? familyId;
  final String? cccd;
  final int? isFatherOfId;
  final int? isMotherOfId;
  final int? spouseId;
  final String role; // 'admin' | 'editor' | 'member'

  MemberModel({
    this.id,
    required this.firstName,
    this.lastName,
    required this.gender,
    this.dateOfBirth,
    this.dateOfDeath,
    this.placeOfBirth,
    this.avatarUrl,
    this.biography,
    this.fatherId,
    this.motherId,
    this.familyId,
    this.cccd,
    this.isFatherOfId,
    this.isMotherOfId,
    this.spouseId,
    this.role = 'member',
  });

  factory MemberModel.fromJson(Map<String, dynamic> json) {
    return MemberModel(
      id: json['id'],
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'],
      gender: json['gender'] ?? 'unknown',
      dateOfBirth: json['date_of_birth'],
      dateOfDeath: json['date_of_death'],
      placeOfBirth: json['place_of_birth'],
      avatarUrl: json['avatar_url'],
      biography: json['biography'],
      fatherId: json['father_id'],
      motherId: json['mother_id'],
      familyId: json['family_id'],
      cccd: json['cccd'],
      isFatherOfId: json['is_father_of_id'],
      isMotherOfId: json['is_mother_of_id'],
      // spouseId usually not returned in basic list unless we ask for it, 
      // but for creating it is needed in toJson. 
      // If backend returns it later, we can add it here.
      role: json['role'] ?? 'member',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'gender': gender,
      'date_of_birth': dateOfBirth,
      'date_of_death': dateOfDeath,
      'place_of_birth': placeOfBirth,
      'avatar_url': avatarUrl,
      'biography': biography,
      'father_id': fatherId,
      'mother_id': motherId,
      'family_id': familyId,
      'cccd': cccd,
      'is_father_of_id': isFatherOfId,
      'is_mother_of_id': isMotherOfId,
      'spouse_id': spouseId,
    };
  }
  
  String get fullName {
    final last = lastName ?? '';
    final first = firstName;
    final name = "$last $first".trim();
    return id != null ? "$name #$id" : name;
  }
}
