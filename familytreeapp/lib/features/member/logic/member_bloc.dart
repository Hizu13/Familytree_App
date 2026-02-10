import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/member_repo.dart';
import 'member_event.dart';
import 'member_state.dart';
import '../data/models/member_model.dart';

class MemberBloc extends Bloc<MemberEvent, MemberState> {
  final MemberRepository _repo = MemberRepository();

  MemberBloc() : super(MemberInitial()) {
    on<MemberFetchList>(_onFetchList);
    on<MemberCreatePressed>(_onCreate);
    on<MemberUpdatePressed>(_onUpdate);
    on<MemberDeletePressed>(_onDelete);
    on<MemberImportPressed>(_onImport);
    on<MemberResetState>((event, emit) => emit(MemberInitial()));
  }

  Future<void> _onFetchList(MemberFetchList event, Emitter<MemberState> emit) async {
    emit(MemberLoading());
    try {
      final results = await Future.wait([
        _repo.getMembersByFamily(event.familyId),
        _repo.getMyProfile(event.familyId),
      ]);
      final members = results[0] as List<MemberModel>;
      final profile = results[1] as MemberModel?;
      print("DEBUG: Bloc Loaded. Profile role: ${profile?.role}");
      
      emit(MemberLoaded(members, myProfile: profile));
    } catch (e) {
      print("DEBUG: MemberBloc Error: $e");
      emit(MemberFailure(e.toString()));
    }
  }

  Future<void> _onCreate(MemberCreatePressed event, Emitter<MemberState> emit) async {
    emit(MemberLoading());
    try {
      await _repo.createMember(event.member);
      emit(MemberCreateSuccess());
      // Refresh list
      add(MemberFetchList(event.member.familyId!));
    } catch (e) {
      emit(MemberFailure(e.toString()));
    }
  }

  Future<void> _onUpdate(MemberUpdatePressed event, Emitter<MemberState> emit) async {
    emit(MemberLoading());
    try {
      await _repo.updateMember(event.member);
      emit(MemberUpdateSuccess());
      add(MemberFetchList(event.member.familyId!));
    } catch (e) {
      emit(MemberFailure(e.toString()));
    }
  }

  Future<void> _onDelete(MemberDeletePressed event, Emitter<MemberState> emit) async {
    emit(MemberLoading());
    try {
      await _repo.deleteMember(event.memberId);
      emit(MemberDeleteSuccess());
      // No auto refresh here since we don't have family ID handy unless we pass it.
      // UI usually handles refresh.
    } catch (e) {
      emit(MemberFailure(e.toString()));
    }
  }

  Future<void> _onImport(MemberImportPressed event, Emitter<MemberState> emit) async {
    emit(MemberLoading());
    try {
      await _repo.importMembers(event.familyId, event.file, anchorId: event.anchorId);
      emit(MemberImportSuccess());
      add(MemberFetchList(event.familyId));
    } catch (e) {
      emit(MemberFailure(e.toString()));
    }
  }
}
