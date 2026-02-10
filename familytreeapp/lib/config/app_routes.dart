class AppRoutes {
  // Màn hình khởi động / Splash
  static const String splash = '/';

  // --- Nhóm Auth (Đăng nhập/Đăng ký) ---
  static const String login = '/login';
  static const String register = '/register';

  // --- Nhóm Family (Quản lý gia phả) ---
  static const String home = '/home'; // Danh sách gia phả
  static const String createFamily = '/create_family'; // Tạo mới gia phả
  static const String familyDetail = '/family_detail'; // Chi tiết gia phả (Thông tin + Tab)

  // --- Nhóm Member (Thành viên) ---
  static const String memberList = '/member_list'; // Danh sách thành viên dạng list
  static const String memberProfile = '/member_profile'; // Hồ sơ chi tiết (Profile)
  static const String addMember = '/add_member'; // Form thêm thành viên mới
  static const String editMember = '/edit_member'; // Form sửa thành viên

  // --- Nhóm Tree (Sơ đồ cây) ---
  static const String treeView = '/tree_view'; // Màn hình vẽ cây gia phả
  
  // --- Nhóm Events (Sự kiện) ---
  static const String eventList = '/event_list';
  static const String addEvent = '/add_event';
}