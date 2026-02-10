import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// 1. Import Config
import 'config/app_colors.dart';
import 'config/app_routes.dart';

// 2. Import Logic (Bloc)
import 'features/auth/logic/auth_bloc.dart';

// 3. Import Screens
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/family/screens/family_list_screen.dart'; // Màn hình chính sau khi Login

void main() {
  runApp(const FamilyTreeApp());
}

class FamilyTreeApp extends StatelessWidget {
  const FamilyTreeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      // Khởi tạo AuthBloc ở cấp cao nhất để dùng cho toàn bộ App
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc()..add(AuthCheckStatus()),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Family Tree App',
        
        // Cấu hình giao diện chung
        theme: ThemeData(
          primaryColor: AppColors.primary,
          scaffoldBackgroundColor: AppColors.background,
          useMaterial3: false, // Hoặc true tùy sở thích
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.primary,
            elevation: 0,
            centerTitle: true,
          ),
        ),

        // --- CẤU HÌNH ĐƯỜNG DẪN (ROUTES) ---
        routes: {
          AppRoutes.login: (context) => const LoginScreen(),
          AppRoutes.register: (context) => const RegisterScreen(),
          // Khi gọi AppRoutes.home -> Chạy màn hình FamilyListScreen
          AppRoutes.home: (context) => const FamilyListScreen(),
        },

        // --- XỬ LÝ MÀN HÌNH KHỞI ĐỘNG ---
        // BlocBuilder lắng nghe trạng thái đăng nhập để quyết định màn hình đầu tiên
        home: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            // 1. Nếu đã đăng nhập thành công -> Vào thẳng trang Danh sách
            // Sử dụng key để force rebuild khi user thay đổi
            if (state is AuthAuthenticated) {
              return FamilyListScreen(key: ValueKey('family_${state.user.id}'));
            }
            
            // 2. Nếu chưa đăng nhập hoặc đăng nhập lỗi -> Hiện trang Login
            else if (state is AuthUnauthenticated || state is AuthFailure) {
              return const LoginScreen(key: ValueKey('login'));
            }

            // 3. Mặc định (đang kiểm tra token) -> Hiện vòng xoay chờ
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          },
        ),
      ),
    );
  }
}