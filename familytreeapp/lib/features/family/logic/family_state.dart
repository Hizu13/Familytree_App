import '../data/models/family_model.dart';

abstract class FamilyState {}

class FamilyInitial extends FamilyState {}

class FamilyLoading extends FamilyState {}

class FamilyLoaded extends FamilyState {
  final List<FamilyModel> families;
  FamilyLoaded(this.families);
}

class FamilyCreateSuccess extends FamilyState {}

class FamilyUpdateSuccess extends FamilyState {
  final FamilyModel family;
  FamilyUpdateSuccess(this.family);
}

class FamilyDeleteSuccess extends FamilyState {} // New State

class FamilyFailure extends FamilyState {
  final String message;
  FamilyFailure(this.message);
}