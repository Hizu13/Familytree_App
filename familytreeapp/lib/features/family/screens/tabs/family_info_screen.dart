import 'package:flutter/material.dart';
import '../../data/models/family_model.dart';
import '../family_form_screen.dart';

class FamilyInfoScreen extends StatelessWidget {
  final FamilyModel family;
  final Function(FamilyModel)? onUpdate;
  final bool canEdit;

  const FamilyInfoScreen({super.key, required this.family, this.onUpdate, this.canEdit = false});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canEdit)
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () async {
                 final result = await Navigator.push(
                   context,
                   MaterialPageRoute(builder: (_) => FamilyFormScreen(family: family)),
                 );
                 if (result is FamilyModel && onUpdate != null) {
                    onUpdate!(result);
                 } else if (result == true) {
                    Navigator.pop(context); 
                 }
              },
              child: Text(
                "Chỉnh sửa",
                style: TextStyle(color: Colors.blue.shade600),
              ),
            ),
          ),
          const SizedBox(height: 10),
          
          _buildInfoSection("Tên gia phả", family.name),
          const SizedBox(height: 20),
          _buildInfoSection("Quê quán", family.originLocation ?? "Chưa cập nhật"),
          const SizedBox(height: 20),
          _buildInfoSection("Lời giới thiệu", family.description),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(content),
        ),
      ],
    );
  }
}
