import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/relationship_repository.dart';
import 'relationship_event.dart';
import 'relationship_state.dart';

class RelationshipBloc extends Bloc<RelationshipEvent, RelationshipState> {
  final RelationshipRepository _repo = RelationshipRepository();

  RelationshipBloc() : super(RelationshipInitial()) {
    on<RelationshipCalculatePressed>(_onCalculate);
  }

  Future<void> _onCalculate(
    RelationshipCalculatePressed event,
    Emitter<RelationshipState> emit,
  ) async {
    emit(RelationshipLoading());
    try {
      final result = await _repo.calculateRelationship(
        familyId: event.familyId,
        person1Id: event.person1Id,
        person2Id: event.person2Id,
      );
      emit(RelationshipSuccess(result));
    } catch (e) {
      emit(RelationshipFailure(e.toString()));
    }
  }
}
