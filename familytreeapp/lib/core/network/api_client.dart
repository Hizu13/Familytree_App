import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:io'; 
import 'token_interceptor.dart';
import '../../config/api_config.dart';
import 'package:file_picker/file_picker.dart';

class ApiClient {
  late Dio _dio;
  static final ApiClient _instance = ApiClient._internal();
  
  factory ApiClient() => _instance;

  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(milliseconds: ApiConfig.connectionTimeout),
      receiveTimeout: const Duration(milliseconds: ApiConfig.receiveTimeout),
      headers: ApiConfig.headers,
    ));

    if (kIsWeb) {
      _dio.options.extra['withCredentials'] = true;
    }

    _initCookieManager();

    // 1. Add Token Interceptor FIRST to inject header
    _dio.interceptors.add(TokenInterceptor());

    // 2. Add Log Interceptor
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => print("API_LOG: $obj"),
    ));
  }

  void _initCookieManager() async {
    // KIỂM TRA: Nếu là Web thì dùng CookieJar bộ nhớ đệm (RAM)
    if (kIsWeb) {
      final cookieJar = CookieJar();
      _dio.interceptors.add(CookieManager(cookieJar));
      return;
    }

    // Nếu là Mobile (Android/iOS) thì mới dùng PersistCookieJar (Lưu vào file)
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final String appDocPath = appDocDir.path;
      
      final cookieJar = PersistCookieJar(
        storage: FileStorage("$appDocPath/.cookies/"),
      );
      _dio.interceptors.add(CookieManager(cookieJar));
    } catch (e) {
      print("Lỗi khởi tạo Cookie: $e");
    }
  }

  Dio get dio => _dio;

  // Xóa cookie, token khi Logout
  Future<void> clearCookies() async {
    try {
       // 1. Xóa trong RAM (CookieJar)
       for (var i in _dio.interceptors) {
          if (i is CookieManager) {
             final cookieJar = i.cookieJar;
             await cookieJar.deleteAll();
          }
       }

       // 2. Xóa File vật lý (Nuclear Option cho Mobile)
       if (!kIsWeb) {
         final appDocDir = await getApplicationDocumentsDirectory();
         final cookiePath = "${appDocDir.path}/.cookies/";
         final cookieDir = Directory(cookiePath);
         if (await cookieDir.exists()) {
           await cookieDir.delete(recursive: true);
           print("SAFE_MODE: Deleted physical cookie directory: $cookiePath");
         }
       }
    } catch (e) {
      print("Error clearing cookies: $e");
    }
  }

  Future<String?> uploadImage(PlatformFile file) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          file.bytes!, 
          filename: file.name,
        ),
      });

      final response = await _dio.post(
        '/upload/image', 
        data: formData,
      );

      return response.data['url'];
    } catch (e) {
      print("Upload error: $e");
      return null;
    }
  }
}