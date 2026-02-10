import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import '../data/auth_repository.dart';
import '../data/models/auth_request_model.dart';
import '../data/models/user_model.dart';

// --- EVENTS ---
abstract class AuthEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class AuthCheckStatus extends AuthEvent {}

class AuthLoginStarted extends AuthEvent {
  final String username;
  final String password;
  AuthLoginStarted({required this.username, required this.password});
}

class AuthRegisterStarted extends AuthEvent {
  final String username;
  final String firstName;
  final String? lastName;
  final String email;
  final String password;
  final String? gender;
  final String? dateOfBirth;
  final String? placeOfBirth;
  
  AuthRegisterStarted({
    required this.username,
    required this.firstName,
    this.lastName,
    required this.email,
    required this.password,
    this.gender,
    this.dateOfBirth,
    this.placeOfBirth,
  });
}

class AuthLogoutStarted extends AuthEvent {}

// --- STATES ---
abstract class AuthState extends Equatable {
  @override
  List<Object> get props => [];
}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthAuthenticated extends AuthState {
  final UserModel user;
  AuthAuthenticated(this.user);
}
class AuthUnauthenticated extends AuthState {}
class AuthRegisterSuccess extends AuthState {}
class AuthFailure extends AuthState {
  final String message;
  AuthFailure(this.message);
}

// --- BLOC ---
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repo = AuthRepository();

  AuthBloc() : super(AuthInitial()) {
    
    // Check Status
    on<AuthCheckStatus>((event, emit) async {
      emit(AuthLoading());
      try {
        final user = await _repo.getMe();
        emit(AuthAuthenticated(user));
      } catch (e) {
        emit(AuthUnauthenticated());
      }
    });

    // Login
    on<AuthLoginStarted>((event, emit) async {
      emit(AuthLoading());
      try {
        final request = LoginRequestModel(
          username: event.username, 
          password: event.password
        );
        final user = await _repo.login(request);
        emit(AuthAuthenticated(user));
      } on DioException catch (e) {
        String msg = "Đăng nhập thất bại";
        // SỬA LỖI Ở ĐÂY: Thêm '?? msg'
        if (e.response?.data != null && e.response?.data['detail'] != null) {
          msg = e.response?.data['detail'].toString() ?? msg;
        }
        emit(AuthFailure(msg));
      } catch (e) {
        emit(AuthFailure(e.toString()));
      }
    });

    // Register
    on<AuthRegisterStarted>((event, emit) async {
      emit(AuthLoading());
      try {
        final request = RegisterRequestModel(
          username: event.username,
          password: event.password,
          firstName: event.firstName,
          lastName: event.lastName,
          gender: event.gender,
          dateOfBirth: event.dateOfBirth,
          placeOfBirth: event.placeOfBirth,
          email: event.email,
          role: 'member',
        );
        await _repo.register(request);
        emit(AuthRegisterSuccess());
      } on DioException catch (e) {
        String msg = "Đăng ký thất bại";
        // SỬA LỖI Ở ĐÂY: Thêm '?? msg'
        if (e.response?.data != null && e.response?.data['detail'] != null) {
           msg = e.response?.data['detail'].toString() ?? msg;
        }
        emit(AuthFailure(msg));
      } catch (e) {
        emit(AuthFailure(e.toString()));
      }
    });

    // Logout
    on<AuthLogoutStarted>((event, emit) async {
      await _repo.logout();
      emit(AuthUnauthenticated());
    });
  }
}