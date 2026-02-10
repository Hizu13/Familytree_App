import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import 'models/auth_request_model.dart';
import 'models/user_model.dart';
import '../../../core/storage/local_storage.dart';

class AuthRepository {
  final ApiClient _apiClient = ApiClient();

  // --- 1. Đăng nhập (POST /auth/login) ---
  Future<UserModel> login(LoginRequestModel request) async {
    try {
      final response = await _apiClient.dio.post(
        '/auth/login', 
        data: request.toJson(),
      );
      
      // 1. Lưu token (nếu có)
      final token = response.data['access_token'];
      if (token != null) {
        await LocalStorage.saveToken(token);
      }
      
      // Response trả về: {"message": "...", "user": {...}}
      return UserModel.fromJson(response.data['user']);
    } catch (e) {
      throw e;
    }
  }

  // --- 2. Đăng ký (POST /user/) ---
  Future<void> register(RegisterRequestModel request) async {
    try {
      await _apiClient.dio.post(
        '/user/', 
        data: request.toJson(),
      );
    } catch (e) {
      throw e;
    }
  }

  // --- 3. Lấy thông tin user (GET /auth/me) ---
  Future<UserModel> getMe() async {
    try {
      final response = await _apiClient.dio.get('/auth/me');
      return UserModel.fromJson(response.data);
    } catch (e) {
      throw e;
    }
  }

  // --- 4. Đăng xuất (POST /auth/logout) ---
  Future<void> logout() async {
    try {
      await _apiClient.dio.post('/auth/logout');
    } catch (e) {
      // Bỏ qua lỗi logout
    } finally {
      // QUAN TRỌNG: Xóa sạch dữ liệu phía Client bất kể API thành công hay k
      await _apiClient.clearCookies();
      await LocalStorage.clear(); 
    }
  }
}