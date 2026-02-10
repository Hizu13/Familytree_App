
import 'dart:async';
import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:familytreeapp/features/chat/data/chat_repository.dart';
import 'package:familytreeapp/features/chat/models/chat_message_dto.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as types;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

part 'chat_event.dart';
part 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository _repository;
  StreamSubscription? _socketSubscription;
  String? _currentUserId;
  String? _familyId;
  final Map<String, types.User> _userCache = {}; // Cache user info

  ChatBloc({required ChatRepository repository}) : _repository = repository, super(ChatInitial()) {
    on<ChatStarted>(_onChatStarted);
    on<ChatMessageSent>(_onMessageSent);
    on<ChatMessageReceived>(_onMessageReceived);
  }

  Future<void> _onChatStarted(ChatStarted event, Emitter<ChatState> emit) async {
    emit(ChatLoadInProgress());
    _familyId = event.familyId;
    
    try {
      // 1. Get current User ID
      try {
         _currentUserId = await _repository.getCurrentUserId();
      } catch (e) {
        emit(const ChatLoadFailure("Not authenticated or failed to get user info"));
        return;
      }

      // 2. Load History
      final history = await _repository.getMessages(event.familyId);
      final uiMessages = history.map((e) => _mapDtoToType(e)).toList();

      // 3. Connect to WS
      print("Bloc Connecting to WS...");
      final stream = await _repository.connect(event.familyId);
      _socketSubscription = stream.listen((data) {
        print("Bloc received data: $data");
        if (data is String) {
          final json = jsonDecode(data);
          final dto = ChatMessageDto.fromJson(json);
          add(ChatMessageReceived(dto));
        }
      }, onError: (error) {
        print("WS Error in Bloc: $error");
      });

      emit(ChatLoadSuccess(uiMessages, _currentUserId!, _userCache));
      
    } catch (e) {
      print("ChatBloc Error: $e");
      emit(ChatLoadFailure(e.toString()));
    }
  }

  void _onMessageSent(ChatMessageSent event, Emitter<ChatState> emit) {
    print("Bloc handling MessageSent: ${event.content}");
    if (_familyId != null) {
      _repository.sendMessage(event.content);
      // Optimistic update could happen here, but for now wait for WS echo
    } else {
      print("Family ID is null in Bloc");
    }
  }

  void _onMessageReceived(ChatMessageReceived event, Emitter<ChatState> emit) {
    if (state is ChatLoadSuccess) {
      final currentState = state as ChatLoadSuccess;
      final newMessage = _mapDtoToType(event.message);
      // flutter_chat_ui expects message at index 0 to be the newest
      final updatedList = [newMessage, ...currentState.messages];
      emit(ChatLoadSuccess(updatedList, currentState.userId, _userCache));
    }
  }

  types.Message _mapDtoToType(ChatMessageDto dto) {
    final authorId = dto.senderId.toString();
    
    // Cache user info for resolveUser or usage
    if (dto.senderName != null && !_userCache.containsKey(authorId)) {
      _userCache[authorId] = types.User(
        id: authorId,
        name: dto.senderName, 
        imageSource: dto.senderAvatar, // Correct field is 'imageSource'
      );
    }
    
    // Parse timestamp
    int createdAtMs = DateTime.now().millisecondsSinceEpoch;
    try {
        createdAtMs = DateTime.parse(dto.createdAt + (dto.createdAt.endsWith("Z") ? "" : "Z")).toLocal().millisecondsSinceEpoch;
    } catch (e) {
        // approximate
    }

    return types.TextMessage(
      authorId: authorId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs), // Expects DateTime
      id: dto.id.toString(),
      text: dto.content,
    );
  }

  @override
  Future<void> close() {
    _socketSubscription?.cancel();
    _repository.dispose();
    return super.close();
  }
}
