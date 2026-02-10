import 'package:dio/dio.dart';
import '../storage/local_storage.dart';

class TokenInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 1. Lấy token từ bộ nhớ
    final token = await LocalStorage.getToken();

    // 2. Nếu có token, gắn vào Header Authorization
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    // 3. Cho phép request đi tiếp
    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Xử lý nếu Token hết hạn (Lỗi 401) -> Có thể điều hướng về trang Login tại đây
    if (err.response?.statusCode == 401) {
      // Logic logout tự động (nếu cần)
    }
    super.onError(err, handler);
  }
}