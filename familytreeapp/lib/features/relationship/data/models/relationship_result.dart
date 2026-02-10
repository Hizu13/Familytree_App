class RelationshipResult {
  final String relationship;

  RelationshipResult({required this.relationship});

  factory RelationshipResult.fromJson(Map<String, dynamic> json) {
    return RelationshipResult(
      relationship: json['relationship'] ?? 'Không xác định',
    );
  }
}
