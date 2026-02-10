
import 'dart:convert';
import 'package:familytreeapp/config/api_config.dart';
import 'package:familytreeapp/features/chat/models/chat_message_dto.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatRepository {
  WebSocketChannel? _channel;
  final Dio _dio = Dio();
  
  // Connect to WebSocket
  Future<Stream<dynamic>> connect(String familyId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    
    // Construct WS URL
    String baseUrl = ApiConfig.baseUrl;
    String wsUrl = baseUrl.replaceFirst('http', 'ws');
    
    // Fix for Flutter Web: prefer 127.0.0.1 over localhost
    if (wsUrl.contains('localhost')) {
      wsUrl = wsUrl.replaceFirst('localhost', '127.0.0.1');
    }
    
    String url = '$wsUrl/families/$familyId/chat?token=$token';
    
    print('WS Connecting to: $url');
    try {
        _channel = WebSocketChannel.connect(Uri.parse(url));
        await _channel!.ready;
        print('WS Connected successfully');
    } catch (e) {
        print('WS Connection error: $e');
    }
    
    return _channel!.stream.map((event) {
      print('WS Received: $event');
      return event;
    });
  }

  // Send message
  void sendMessage(String content, {String type = 'text'}) {
    print('WS Sending: $content');
    if (_channel != null) {
      final payload = jsonEncode({
        'content': content,
        'message_type': type,
      });
      _channel!.sink.add(payload);
      print('WS Sent payload: $payload');
    } else {
      print('WS Channel is null, cannot send');
    }
  }

  // Get Current User ID
  Future<String> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    try {
      final response = await _dio.get(
        '${ApiConfig.baseUrl}/auth/me',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            ...ApiConfig.headers,
          },
        ),
      );
      if (response.statusCode == 200) {
        return response.data['user_id'].toString();
      } else {
        throw Exception('Failed to load user info');
      }
    } catch (e) {
      throw Exception('Error fetching user info: $e');
    }
  }

  // Fetch history (using Dio or ApiClient if valid)
  Future<List<ChatMessageDto>> getMessages(String familyId, {int limit = 50, int skip = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    
    try {
      final response = await _dio.get(
        '${ApiConfig.baseUrl}/families/$familyId/chat/messages',
        queryParameters: {
          'limit': limit,
          'skip': skip,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            ...ApiConfig.headers,
          },
        ),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((e) => ChatMessageDto.fromJson(e)).toList();
      } else {
        throw Exception('Failed to load messages');
      }
    } catch (e) {
      throw Exception('Error fetching messages: $e');
    }
  }

  void dispose() {
    _channel?.sink.close();
  }
}
