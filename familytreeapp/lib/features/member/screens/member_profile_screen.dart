import 'package:flutter/material.dart';
import '../data/models/member_model.dart';
import '../../../config/app_colors.dart';

class MemberProfileScreen extends StatelessWidget {
  final MemberModel member;

  const MemberProfileScreen({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Thông Tin Chi Tiết")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                backgroundImage: member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
                child: member.avatarUrl == null 
                    ? Text(member.firstName[0], style: const TextStyle(fontSize: 40)) 
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            Text(member.fullName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            _buildInfoRow(Icons.person, "Giới tính", member.gender),
            _buildInfoRow(Icons.cake, "Ngày sinh", member.dateOfBirth ?? "Chưa cập nhật"),
            _buildInfoRow(Icons.location_on, "Nơi sinh", member.placeOfBirth ?? "Chưa cập nhật"),
            _buildInfoRow(Icons.book, "Tiểu sử", member.biography ?? "Chưa có"),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
