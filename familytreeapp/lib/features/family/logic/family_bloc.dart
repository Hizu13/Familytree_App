import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/family_repository.dart';
import 'family_event.dart';
import 'family_state.dart';

class FamilyBloc extends Bloc<FamilyEvent, FamilyState> {
  final FamilyRepository _repo = FamilyRepository();

  FamilyBloc() : super(FamilyInitial()) {
    on<FamilyListStarted>((event, emit) async {
      emit(FamilyLoading());
      try {
        final list = await _repo.getFamilies();
        emit(FamilyLoaded(list));
      } catch (e) {
        emit(FamilyFailure(e.toString()));
      }
    });

    on<FamilyCreatePressed>((event, emit) async {
      emit(FamilyLoading());
      try {
        await _repo.createFamily(event.name, event.description, event.originLocation);
        emit(FamilyCreateSuccess());
        add(FamilyListStarted()); // Reload list
      } catch (e) {
        emit(FamilyFailure(e.toString()));
      }
    });

    on<FamilyUpdatePressed>((event, emit) async {
      emit(FamilyLoading());
      try {
        final updatedFamily = await _repo.updateFamily(event.id, event.name, event.description, event.originLocation);
        emit(FamilyUpdateSuccess(updatedFamily));
        add(FamilyListStarted()); // Reload list
      } catch (e) {
        emit(FamilyFailure(e.toString()));
      }
    });

    on<FamilyDeletePressed>((event, emit) async {
      emit(FamilyLoading());
      try {
        await _repo.deleteFamily(event.id);
        emit(FamilyDeleteSuccess());
        add(FamilyListStarted()); // Reload list
      } catch (e) {
        emit(FamilyFailure(e.toString()));
      }
    });

    on<FamilyResetState>((event, emit) {
      emit(FamilyInitial());
    });
  }
}