abstract class FamilyEvent {}

// Load danh sách
class FamilyListStarted extends FamilyEvent {}

// Tạo mới
class FamilyCreatePressed extends FamilyEvent {
  final String name;
  final String description;
  final String originLocation;

  FamilyCreatePressed(this.name, this.description, this.originLocation);
}

// Cập nhật
class FamilyUpdatePressed extends FamilyEvent {
  final int id;
  final String name;
  final String description;
  final String originLocation;

  FamilyUpdatePressed(this.id, this.name, this.description, this.originLocation);
}

// Xóa
class FamilyDeletePressed extends FamilyEvent {
  final int id;

  FamilyDeletePressed(this.id);
}

// Reset state (for logout)
class FamilyResetState extends FamilyEvent {}

