class FamilyModel {
  final int id;
  final String name;
  final String description;
  final String? originLocation;
  final String? createdAt;
  final String? joinCode;

  FamilyModel({
    required this.id,
    required this.name,
    required this.description,
    this.originLocation,
    this.createdAt,
    this.joinCode,
  });

  factory FamilyModel.fromJson(Map<String, dynamic> json) {
    return FamilyModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      originLocation: json['origin_location'],
      createdAt: json['created_at'],
      joinCode: json['join_code'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
    };
  }
}