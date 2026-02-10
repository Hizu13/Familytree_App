abstract class RelationshipEvent {}

class RelationshipCalculatePressed extends RelationshipEvent {
  final int familyId;
  final int person1Id;
  final int person2Id;

  RelationshipCalculatePressed(this.familyId, this.person1Id, this.person2Id);
}
