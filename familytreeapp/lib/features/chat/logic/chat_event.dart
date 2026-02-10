
part of 'chat_bloc.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object> get props => [];
}

class ChatStarted extends ChatEvent {
  final String familyId;
  const ChatStarted({required this.familyId});
  
  @override
  List<Object> get props => [familyId];
}

class ChatMessageSent extends ChatEvent {
  final String content;
  const ChatMessageSent({required this.content});
  
  @override
  List<Object> get props => [content];
}

class ChatMessageReceived extends ChatEvent {
  final ChatMessageDto message;
  const ChatMessageReceived(this.message);
  
  @override
  List<Object> get props => [message];
}

class ChatHistoryLoaded extends ChatEvent {
  final List<ChatMessageDto> messages;
  const ChatHistoryLoaded(this.messages);
   @override
  List<Object> get props => [messages];
}
