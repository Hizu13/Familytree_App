import 'package:equatable/equatable.dart';
import '../data/models/member_model.dart';

abstract class MemberState extends Equatable {
  @override
  List<Object> get props => [];
}

class MemberInitial extends MemberState {}

class MemberLoading extends MemberState {}

class MemberLoaded extends MemberState {
  final List<MemberModel> members;
  final MemberModel? myProfile;

  MemberLoaded(this.members, {this.myProfile});

  @override
  List<Object> get props => [members, myProfile ?? ''];
}

class MemberCreateSuccess extends MemberState {}

class MemberUpdateSuccess extends MemberState {}

class MemberDeleteSuccess extends MemberState {}

class MemberImportSuccess extends MemberState {}

class MemberFailure extends MemberState {
  final String message;
  MemberFailure(this.message);

  @override
  List<Object> get props => [message];
}
