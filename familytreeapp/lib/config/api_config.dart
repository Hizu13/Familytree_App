class ApiConfig {
  // ==========================================================
  // CẤU HÌNH ĐỊA CHỈ SERVER (BASE URL)
  // ==========================================================
  
  // 1. Nếu chạy trên Android Emulator (Máy ảo Android Studio):
  // Dùng IP đặc biệt: 10.0.2.2
  // 1. Khi chạy Flutter Web trên cùng máy:
  static const String baseUrl = "http://localhost:8000";

  // 2. Nếu chạy trên iOS Simulator:
  // static const String baseUrl = "http://127.0.0.1:8000";

  // 3. Nếu chạy trên Máy thật (Điện thoại cắm dây USB):
  // Bạn phải dùng IP mạng LAN của máy tính (Ví dụ: 192.168.1.15)
  // static const String baseUrl = "http://192.168.1.XX:8000";

  // ==========================================================
  // CẤU HÌNH KHÁC
  // ==========================================================
  
  // Thời gian chờ kết nối tối đa (mili-giây)
  static const int receiveTimeout = 60000; // 60 giây
  static const int connectionTimeout = 60000;
  
  // Header mặc định
  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}