import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';

class RelationshipRepository {
  final Dio _dio = ApiClient().dio;

  Future<String> calculateRelationship(int person1Id, int person2Id, int familyId) async {
    try {
      final response = await _dio.get(
        '/relationships/calculate',
        queryParameters: {
          'person1_id': person1Id,
          'person2_id': person2Id,
          'family_id': familyId,
        },
      );
      if (response.statusCode == 200) {
        return response.data['relationship'] ?? "Không xác định";
      }
      return "Không tìm thấy mối quan hệ";
    } catch (e) {
      if (e is DioException) {
         if (e.response?.statusCode == 404) return "Không tìm thấy dữ liệu thành viên";
      }
      return "Lỗi tính toán: $e";
    }
  }
}
