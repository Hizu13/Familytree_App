import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import '../data/models/member_model.dart';

abstract class MemberEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class MemberFetchList extends MemberEvent {
  final int familyId;
  MemberFetchList(this.familyId);

  @override
  List<Object> get props => [familyId];
}

class MemberCreatePressed extends MemberEvent {
  final MemberModel member;
  MemberCreatePressed(this.member);

  @override
  List<Object> get props => [member];
}

class MemberUpdatePressed extends MemberEvent {
  final MemberModel member;
  MemberUpdatePressed(this.member);

  @override
  List<Object> get props => [member];
}

class MemberDeletePressed extends MemberEvent {
  final int memberId;
  MemberDeletePressed(this.memberId);

  @override
  List<Object> get props => [memberId];
}

class MemberImportPressed extends MemberEvent {
  final int familyId;
  final PlatformFile file;
  final int? anchorId;

  MemberImportPressed({required this.familyId, required this.file, this.anchorId});

  @override
  List<Object> get props => [familyId, file, if (anchorId != null) anchorId!];
}

// Reset state (for logout)
class MemberResetState extends MemberEvent {}

