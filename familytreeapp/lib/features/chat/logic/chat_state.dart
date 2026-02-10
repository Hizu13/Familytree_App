import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as types;

part of 'chat_bloc.dart';

abstract class ChatState extends Equatable {
  const ChatState();
  
  @override
  List<Object> get props => [];
}

class ChatInitial extends ChatState {}

class ChatLoadInProgress extends ChatState {}

class ChatLoadSuccess extends ChatState {
  final List<types.Message> messages;
  final String userId; // Current user ID for UI to know who is 'me'
  final Map<String, types.User> userCache;

  const ChatLoadSuccess(this.messages, this.userId, this.userCache);

  @override
  List<Object> get props => [messages, userId, userCache];
}

class ChatLoadFailure extends ChatState {
  final String error;
  const ChatLoadFailure(this.error);
    @override
  List<Object> get props => [error];
}
