import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import 'models/relationship_result.dart';

class RelationshipRepository {
  final Dio _dio = ApiClient().dio;

  Future<RelationshipResult> calculateRelationship({
    required int familyId,
    required int person1Id,
    required int person2Id,
  }) async {
    try {
      final response = await _dio.get(
        '/relationships/calculate',
        queryParameters: {
          'family_id': familyId,
          'person1_id': person1Id,
          'person2_id': person2Id,
        },
      );
      return RelationshipResult.fromJson(response.data);
    } catch (e) {
      if (e is DioException && e.response != null) {
        throw Exception(e.response?.data['detail'] ?? "Lỗi tính quan hệ");
      }
      throw Exception("Lỗi kết nối: $e");
    }
  }
}
