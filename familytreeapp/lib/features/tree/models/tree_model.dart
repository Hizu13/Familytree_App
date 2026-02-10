class TreeNode {
  final int id;
  final String name;
  final String gender;
  final String birthYear;
  final String? dob;
  final String? avatarUrl;
  final List<int> spouses;
  final int? fatherId;
  final int? motherId;

  TreeNode({
    required this.id,
    required this.name,
    required this.gender,
    required this.birthYear,
    this.dob,
    this.avatarUrl,
    this.spouses = const [],
    this.fatherId,
    this.motherId,
  });

  factory TreeNode.fromJson(Map<String, dynamic> json) {
    return TreeNode(
      id: json['id'],
      name: json['name'] ?? "Không tên",
      gender: json['gender'] ?? "Nam",
      birthYear: json['birth_year']?.toString() ?? "N/A",
      dob: json['dob'],
      avatarUrl: json['avatar_url'],
      spouses: (json['spouses'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [],
      fatherId: json['father_id'],
      motherId: json['mother_id'],
    );
  }
}

class TreeEdge {
  final int fromId;
  final int toId;
  final String type;

  TreeEdge({
    required this.fromId,
    required this.toId,
    required this.type,
  });

  factory TreeEdge.fromJson(Map<String, dynamic> json) {
    return TreeEdge(
      fromId: json['from_id'],
      toId: json['to_id'],
      type: json['type'],
    );
  }
}

class TreeResponse {
  final List<TreeNode> nodes;
  final List<TreeEdge> edges;

  TreeResponse({required this.nodes, required this.edges});

  factory TreeResponse.fromJson(Map<String, dynamic> json) {
    return TreeResponse(
      nodes: (json['nodes'] as List).map((e) => TreeNode.fromJson(e)).toList(),
      edges: (json['edges'] as List).map((e) => TreeEdge.fromJson(e)).toList(),
    );
  }
}
class TreeRelationship {
  final int fromId; // ID người cha/mẹ
  final int toId;   // ID người con

  TreeRelationship({required this.fromId, required this.toId});
}
