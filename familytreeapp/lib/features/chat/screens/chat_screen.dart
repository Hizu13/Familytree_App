
import 'package:familytreeapp/features/chat/data/chat_repository.dart';
import 'package:familytreeapp/features/chat/logic/chat_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as types;

class ChatScreen extends StatelessWidget {
  final String familyId;

  const ChatScreen({super.key, required this.familyId});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (context) => ChatRepository(),
      child: BlocProvider(
        create: (context) => ChatBloc(
          repository: context.read<ChatRepository>(),
        )..add(ChatStarted(familyId: familyId)),
        child: const _ChatView(),
      ),
    );
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView();

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  late types.InMemoryChatController _chatController;
  Map<String, types.User> _userCache = {};

  @override
  void initState() {
    super.initState();
    _chatController = types.InMemoryChatController(messages: []);
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  Future<types.User?> _resolveUser(String id) async {
    // Return cached user if available
    if (_userCache.containsKey(id)) {
      return _userCache[id]!;
    }
    // Fallback: This is important for "Thành viên" placeholder
    return types.User(id: id, name: "Thành viên");
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatBloc, ChatState>(
      listener: (context, state) {
        if (state is ChatLoadSuccess) {
          _chatController.setMessages(state.messages);
          // Update cache
          setState(() {
            _userCache = state.userCache;
          });
        }
      },
      builder: (context, state) {
        if (state is ChatLoadInProgress) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is ChatLoadSuccess) {
          return Chat(
            chatController: _chatController,
            currentUserId: state.userId,
            resolveUser: _resolveUser,
            onMessageSend: (String message) {
               context.read<ChatBloc>().add(ChatMessageSent(content: message));
            },
            builders: types.Builders(
              chatMessageBuilder: (
                BuildContext context,
                types.Message message,
                int index,
                Animation<double> animation,
                Widget child, {
                bool? isRemoved,
                bool? isSentByMe,
                types.MessageGroupStatus? groupStatus,
              }) {
                return ChatMessage(
                  message: message,
                  index: index,
                  animation: animation,
                  isRemoved: isRemoved,
                  groupStatus: groupStatus,
                  topWidget: (isSentByMe == false && (groupStatus?.isFirst ?? true))
                      ? Padding(
                          padding: const EdgeInsets.only(left: 12, bottom: 4),
                          child: Text(
                            _userCache[message.authorId]?.name ?? "Thành viên",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : null,
                  child: child,
                );
              },
            ),
          );
        } else if (state is ChatLoadFailure) {
          return Center(child: Text("Lỗi: ${state.error}"));
        }
        return const Center(child: Text("Đang khởi tạo..."));
      },
    );
  }
}
