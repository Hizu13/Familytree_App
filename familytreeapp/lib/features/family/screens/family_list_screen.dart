import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../logic/family_bloc.dart';
import '../logic/family_event.dart';
import '../logic/family_state.dart';
import 'widgets/family_card.dart';
import 'family_form_screen.dart'; // Import màn hình tạo/sửa
import 'family_detail_screen.dart'; // Import màn hình chi tiết


import 'join_family_screen.dart';
import 'settings_screen.dart';
import '../../auth/logic/auth_bloc.dart';

class FamilyListScreen extends StatefulWidget {
  const FamilyListScreen({super.key});

  @override
  State<FamilyListScreen> createState() => _FamilyListScreenState();
}

class _FamilyListScreenState extends State<FamilyListScreen> {
  int _currentIndex = 0;
  FamilyBloc? _familyBloc;
  int? _currentUserId; // Track current user ID

  @override
  void initState() {
    super.initState();
    // Don't create FamilyBloc here, wait for didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Check AuthState and recreate FamilyBloc if user changed
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      if (_currentUserId != authState.user.id) {
        // User changed! Reset everything
        print('[DEBUG] User changed from $_currentUserId to ${authState.user.id}');
        _currentUserId = authState.user.id;
        
        // Close old bloc
        _familyBloc?.close();
        
        // Create new bloc and load data
        _familyBloc = FamilyBloc()..add(FamilyListStarted());
      }
    }
  }

  @override
  void dispose() {
    _familyBloc?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // FamilyBloc will be recreated in didChangeDependencies when user changes
    if (_familyBloc == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return BlocProvider.value(
      value: _familyBloc!,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        
        // --- BODY SWITCHING ---
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildHomeContent(context),
            const SettingsScreen(),
          ],
        ),

        // --- FLOATING ACTION BUTTON (Only show on Home) ---
        floatingActionButton: _currentIndex == 0 ? Builder(
          builder: (context) {
            return FloatingActionButton(
              backgroundColor: const Color(0xFF4294E3),
              child: const Icon(Icons.add, color: Colors.white, size: 32),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (ctx) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.add_circle_outline, color: Color(0xFF4294E3), size: 30),
                            title: const Text("Tạo dòng họ mới", style: TextStyle(fontWeight: FontWeight.bold)),
                            onTap: () async {
                              Navigator.pop(ctx);
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const FamilyFormScreen()),
                              );
                              if (result == true && context.mounted) {
                                _familyBloc?.add(FamilyListStarted());
                              }
                            },
                          ),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.group_add_outlined, color: Color(0xFF4294E3), size: 30),
                            title: const Text("Tham gia dòng họ", style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: const Text("Nhập mã để tham gia"),
                            onTap: () async {
                              Navigator.pop(ctx);
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const JoinFamilyScreen()),
                              );
                              if (result == true && context.mounted) {
                                _familyBloc?.add(FamilyListStarted());
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          }
        ) : null,

        // --- BOTTOM NAVIGATION ---
        bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            selectedItemColor: const Color(0xFF4294E3),
            unselectedItemColor: Colors.grey,
            backgroundColor: Colors.white,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: "Trang chủ",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                label: "Cài đặt",
              ),
            ],
          ),
        ),
      );
  }

  // Extract Home Content to method
  Widget _buildHomeContent(BuildContext context) {
    return Column(
      children: [
        // --- HEADER CUSTOM ---
        Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. Blue Background
            Container(
              width: double.infinity,
              height: 180, // Chiều cao phần xanh
              color: const Color(0xFF4294E3), // Màu xanh dương giống ảnh
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 40), // Đẩy chữ lên trên search bar
                  child: Text(
                    "MyFamilyTree",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            
            // 2. Search Bar overlapping
            Positioned(
              bottom: -25, 
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: const [
                    Icon(Icons.search, color: Colors.black54),
                    SizedBox(width: 10),
                    Text(
                      "Tìm kiếm dòng họ",
                      style: TextStyle(color: Colors.black54, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 40), // Khoảng cách bù cho phần Search Bar thò ra

        // --- TITLE ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Danh sách dòng họ",
              style: TextStyle(
                fontSize: 16,
                color: Colors.black.withOpacity(0.8),
              ),
            ),
          ),
        ),

        // --- LIST CONTENT ---
        Expanded(
          child: BlocBuilder<FamilyBloc, FamilyState>(
            builder: (context, state) {
              if (state is FamilyLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is FamilyLoaded) {
                if (state.families.isEmpty) {
                  return const Center(child: Text("Chưa có dòng họ nào."));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: state.families.length,
                  itemBuilder: (context, index) {
                    final item = state.families[index];
                    return FamilyCard(
                      name: item.name,
                      description: item.description,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => FamilyDetailScreen(family: item)),
                        );
                        // Reload list when returning from detail
                        if (context.mounted) {
                          context.read<FamilyBloc>().add(FamilyListStarted());
                        }
                      },
                    );
                  },
                );
              } else if (state is FamilyFailure) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text("Lỗi tải danh sách", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(state.message, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          context.read<FamilyBloc>().add(FamilyListStarted());
                        },
                        child: const Text("Thử lại"),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ),
      ],
    );
  }
}