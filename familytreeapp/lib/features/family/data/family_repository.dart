import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import 'models/family_model.dart';

class FamilyRepository {
  final Dio _dio = ApiClient().dio;

  // 1. Lấy danh sách dòng họ
  Future<List<FamilyModel>> getFamilies() async {
    try {
      final response = await _dio.get('/families/'); 
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => FamilyModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      throw Exception("Lỗi tải danh sách: $e");
    }
  }

  // 2. Tạo dòng họ mới
  Future<FamilyModel> createFamily(String name, String description, String originLocation) async {
    try {
      final response = await _dio.post(
        "/families/",
        data: {
          "name": name, 
          "description": description,
          "origin_location": originLocation,
        },
      );
      return FamilyModel.fromJson(response.data);
    } catch (e) {
      throw Exception("Failed to create family: $e");
    }
  }

  // 3. Cập nhật
  Future<FamilyModel> updateFamily(int id, String name, String description, String originLocation) async {
    try {
      final response = await _dio.put(
        "/families/$id",
        data: {
          "name": name, 
          "description": description,
          "origin_location": originLocation,
        },
      );
      return FamilyModel.fromJson(response.data);
    } catch (e) {
      throw Exception("Failed to update family: $e");
    }
  }

  // 4. Xóa
  Future<void> deleteFamily(int id) async {
    try {
      await _dio.delete("/families/$id");
    } catch (e) {
      throw Exception("Failed to delete family: $e");
    }
  }

  // 5. Tham gia gia phả
  Future<FamilyModel> joinFamily(String code) async {
    try {
      final response = await _dio.post(
        "/families/join",
        data: {"join_code": code},
      );
      return FamilyModel.fromJson(response.data);
    } catch (e) {
      if (e is DioException) {
         throw Exception(e.response?.data['detail'] ?? "Lỗi tham gia gia phả");
      }
      throw Exception("Lỗi tham gia gia phả: $e");
    }
  }
}