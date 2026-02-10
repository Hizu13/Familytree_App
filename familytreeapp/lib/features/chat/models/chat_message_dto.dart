
import 'package:json_annotation/json_annotation.dart';

part 'chat_message_dto.g.dart';

@JsonSerializable()
class ChatMessageDto {
  final int id;
  @JsonKey(name: 'family_id')
  final int familyId;
  @JsonKey(name: 'sender_id')
  final int senderId;
  final String content;
  @JsonKey(name: 'created_at')
  final String createdAt;
  @JsonKey(name: 'message_type')
  final String messageType;
  @JsonKey(name: 'sender_name')
  final String? senderName;
  @JsonKey(name: 'sender_avatar')
  final String? senderAvatar;

  ChatMessageDto({
    required this.id,
    required this.familyId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    required this.messageType,
    this.senderName,
    this.senderAvatar,
  });

  factory ChatMessageDto.fromJson(Map<String, dynamic> json) => _$ChatMessageDtoFromJson(json);
  Map<String, dynamic> toJson() => _$ChatMessageDtoToJson(this);
}
