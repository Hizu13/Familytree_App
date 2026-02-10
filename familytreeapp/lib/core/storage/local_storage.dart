import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const String _tokenKey = 'access_token';
  static const String _userIdKey = 'user_id';

  // --- 1. Lưu Token ---
  static Future<void> saveToken(String token) async {
    print("DEBUG: [LocalStorage] Saving token: ${token.substring(0, 10)}...");
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // --- 2. Lấy Token ---
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    // print("DEBUG: [LocalStorage] Read token: ${token != null ? "FOUND" : "NULL"}");
    return token;
  }

  // --- 3. Xóa Token (Đăng xuất) ---
  static Future<void> clear() async {
    print("DEBUG: [LocalStorage] Clearing all data.");
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
  }
}