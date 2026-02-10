import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/network/api_client.dart';
import '../../../config/app_routes.dart';
import 'profile_edit_screen.dart';
import '../../auth/logic/auth_bloc.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    // Gửi event đăng xuất đến AuthBloc
    context.read<AuthBloc>().add(AuthLogoutStarted());
    
    // AuthBloc sẽ xử lý việc gọi API logout và chuyển state sang Unauthenticated
    // main.dart sẽ tự động navigate về LoginScreen khi nhận state Unauthenticated
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- HEADER CUSTOM (Consistent with Home) ---
        Container(
          width: double.infinity,
          height: 120, // Smaller header than home
          color: const Color(0xFF4294E3),
          child: const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 20),
              child: Text(
                "Cài đặt",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // --- MENU ITEMS ---
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _buildMenuItem(
                icon: Icons.person_outline,
                title: "Chỉnh sửa thông tin cá nhân",
                color: const Color(0xFF4294E3),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
                  );
                  // Optionally reload data if result == true
                },
              ),
              _buildMenuItem(
                icon: Icons.logout,
                title: "Đăng xuất",
                color: Colors.redAccent,
                onTap: () => _handleLogout(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = Colors.black87,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title, 
          style: TextStyle(
            color: color, 
            fontWeight: FontWeight.w500,
            fontSize: 16
          )
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
