import 'package:flutter/material.dart';

class AppColors {
  // Màu xanh chủ đạo (Primary Blue) - Lấy từ Header của App
  static const Color primary = Color(0xFF4A90E2); 
  
  // Màu nền chính (Xám nhạt cho background tổng thể)
  static const Color background = Color(0xFFF5F7FA);

  // Màu trắng (Dùng cho Card, Input field background)
  static const Color white = Colors.white;

  // Màu đen (Dùng cho chữ tiêu đề chính)
  static const Color textPrimary = Color(0xFF333333);

  // Màu xám (Dùng cho chữ phụ, placeholder)
  static const Color textSecondary = Color(0xFF757575);

  // Màu đường viền (Border input)
  static const Color border = Color(0xFFE0E0E0);

  // Màu đỏ (Dùng cho nút Xóa hoặc báo lỗi)
  static const Color error = Color(0xFFE53935);

  // Màu xanh lá (Dùng cho thông báo thành công)
  static const Color success = Color(0xFF43A047);

  // Gradient (Nếu muốn làm nút bấm đẹp hơn)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}