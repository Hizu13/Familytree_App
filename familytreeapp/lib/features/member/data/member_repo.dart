import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import '../../../../core/network/api_client.dart';
import 'models/member_model.dart';

class MemberRepository {
  final Dio _dio = ApiClient().dio;

  // Lấy danh sách thành viên theo Family ID
  Future<List<MemberModel>> getMembersByFamily(int familyId) async {
    try {
      final response = await _dio.get('/members/$familyId');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((e) => MemberModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      throw Exception("Lỗi tải danh sách thành viên: $e");
    }
  }

  // Thêm thành viên mới
  Future<void> createMember(MemberModel member) async {
    try {
      await _dio.post('/members/', data: member.toJson());
    } catch (e) {
      throw Exception("Lỗi thêm thành viên: $e");
    }
  }

  // Cập nhật thành viên
  Future<void> updateMember(MemberModel member) async {
    try {
      if (member.id == null) throw Exception("ID thành viên không tồn tại");
      await _dio.put('/members/${member.id}', data: member.toJson());
    } catch (e) {
      throw Exception("Lỗi cập nhật thành viên: $e");
    }
  }

  // Xóa thành viên
  Future<void> deleteMember(int memberId) async {
    try {
      await _dio.delete('/members/$memberId');
    } catch (e) {
      throw Exception("Lỗi xóa thành viên: $e");
    }
  }

  // Import thành viên từ Excel
  Future<void> importMembers(int familyId, PlatformFile file, {int? anchorId}) async {
    try {
      MultipartFile multipartFile;

      if (kIsWeb) {
        // Web: Use bytes
        if (file.bytes != null) {
          multipartFile = MultipartFile.fromBytes(file.bytes!, filename: file.name);
        } else {
           throw Exception("File content is empty");
        }
      } else {
        // Mobile/Desktop: Use path
        if (file.path != null) {
          multipartFile = await MultipartFile.fromFile(file.path!, filename: file.name);
        } else {
           throw Exception("File path is invalid");
        }
      }

      FormData formData = FormData.fromMap({
        'family_id': familyId,
        'anchor_id': anchorId,
        'file': multipartFile,
      });

      await _dio.post('/members/import', data: formData);
    } catch (e) {
      throw Exception("Lỗi import thành viên: $e");
    }
  }

  // Lấy hồ sơ cá nhân (Me) trong gia phả
  Future<MemberModel?> getMyProfile(int familyId) async {
    try {
      print("DEBUG: Fetching profile for family $familyId");
      final response = await _dio.get('/families/$familyId/me');
      print("DEBUG: /families/$familyId/me response: ${response.statusCode} - ${response.data}");
      
      if (response.statusCode == 200 && response.data != null) {
        final profile = MemberModel.fromJson(response.data);
        print("DEBUG: Profile parsed: role=${profile.role}, id=${profile.id}");
        return profile;
      }
      return null;
    } catch (e) {
      print("DEBUG: Error fetching my profile: $e");
      // 404 or other errors mean no profile found or error
      return null;
    }
  }

  // Tính mối quan hệ
  Future<String?> getRelationship(int person1Id, int person2Id, int familyId) async {
     try {
       final response = await _dio.get('/relationships/calculate', queryParameters: {
         'person1_id': person1Id,
         'person2_id': person2Id,
         'family_id': familyId
       });
       if (response.statusCode == 200) {
         return response.data['relationship'];
       }
       return null;
     } catch (e) {
       return null;
     }
  }

  // Lấy danh sách vợ/chồng của một thành viên
  Future<List<MemberModel>> getSpouses(int memberId) async {
    try {
      final response = await _dio.get('/members/member/$memberId/spouses');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((e) => MemberModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print("Error fetching spouses: $e");
      return [];
    }
  }

  // Phân quyền thành viên
  Future<void> updateMemberRole(int familyId, int memberId, String newRole) async {
    try {
      await _dio.put(
        '/families/$familyId/members/$memberId/role', 
        data: {'role': newRole}
      );
    } catch (e) {
      if (e is DioException) {
         throw Exception(e.response?.data['detail'] ?? "Lỗi phân quyền");
      }
      throw Exception("Lỗi phân quyền: $e");
    }
  }
}
