// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatMessageDto _$ChatMessageDtoFromJson(Map<String, dynamic> json) =>
    ChatMessageDto(
      id: (json['id'] as num).toInt(),
      familyId: (json['family_id'] as num).toInt(),
      senderId: (json['sender_id'] as num).toInt(),
      content: json['content'] as String,
      createdAt: json['created_at'] as String,
      messageType: json['message_type'] as String,
      senderName: json['sender_name'] as String?,
      senderAvatar: json['sender_avatar'] as String?,
    );

Map<String, dynamic> _$ChatMessageDtoToJson(ChatMessageDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'family_id': instance.familyId,
      'sender_id': instance.senderId,
      'content': instance.content,
      'created_at': instance.createdAt,
      'message_type': instance.messageType,
      'sender_name': instance.senderName,
      'sender_avatar': instance.senderAvatar,
    };
