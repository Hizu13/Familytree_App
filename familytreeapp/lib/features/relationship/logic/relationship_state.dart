import '../data/models/relationship_result.dart';

abstract class RelationshipState {}

class RelationshipInitial extends RelationshipState {}

class RelationshipLoading extends RelationshipState {}

class RelationshipSuccess extends RelationshipState {
  final RelationshipResult result;
  RelationshipSuccess(this.result);
}

class RelationshipFailure extends RelationshipState {
  final String message;
  RelationshipFailure(this.message);
}
