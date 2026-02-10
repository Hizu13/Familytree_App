import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../../family/data/models/family_model.dart';
import '../../member/screens/member_list_screen.dart';
import '../../member/screens/member_form_screen.dart';
import '../../member/logic/member_bloc.dart';
import '../../member/logic/member_event.dart';
import '../../member/logic/member_state.dart';
import '../../member/data/models/member_model.dart';
import 'tabs/family_info_screen.dart';
import '../../tree/screens/tree_view_screen.dart';
import '../../member/data/member_repo.dart';
import '../../member/screens/member_management_screen.dart';
import '../../chat/screens/chat_screen.dart';

class FamilyDetailScreen extends StatefulWidget {
  final FamilyModel? family;

  const FamilyDetailScreen({super.key, this.family});

  @override
  State<FamilyDetailScreen> createState() => _FamilyDetailScreenState();
}

class _FamilyDetailScreenState extends State<FamilyDetailScreen> {
  int _currentIndex = 0;
  late MemberBloc _memberBloc;
  FamilyModel? _currentFamily;


  @override
  void initState() {
    super.initState();
    _currentFamily = widget.family;
    _memberBloc = MemberBloc();
    if (_currentFamily != null) {
      _memberBloc.add(MemberFetchList(_currentFamily!.id!));
    }
  }
  


  @override
  void dispose() {
    _memberBloc.close();
    super.dispose();
  }

  Future<void> _onImport() async {
    // Need list member for anchor selection.
    // We can try to get it from current state if Loaded.
    List<MemberModel> members = [];
    if (_memberBloc.state is MemberLoaded) {
      members = (_memberBloc.state as MemberLoaded).members;
    }

    await showDialog(
      context: context,
      builder: (ctx) {
        MemberModel? tempSelected;
        return StatefulBuilder(
          builder: (stateContext, setState) {
            return AlertDialog(
              title: const Text("Chọn thành viên gốc (Import Excel)"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Chọn người mà các thành viên trong file có quan hệ (Cha, Mẹ, Con...) với họ."),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<MemberModel>(
                    isExpanded: true,
                    hint: const Text("Chọn thành viên (Tuỳ chọn)"),
                    items: members.map((m) => DropdownMenuItem(
                      value: m,
                      child: Text("${m.fullName} (${m.id})"),
                    )).toList(),
                    onChanged: (val) {
                      setState(() => tempSelected = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Hủy bỏ"),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.folder_open),
                  label: const Text("Chọn File Excel"),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      FilePickerResult? result = await FilePicker.platform.pickFiles(
                        type: FileType.any,
                        withData: true, 
                      );

                      if (!mounted) return;

                      if (result != null) {
                         PlatformFile file = result.files.single;
                         
                         if (!file.name.endsWith('.xlsx') && !file.name.endsWith('.xls')) {
                            messenger.showSnackBar(const SnackBar(content: Text("Vui lòng chọn file Excel (.xlsx, .xls)")));
                            return;
                         }

                         if (_currentFamily?.id != null) {
                            Navigator.pop(ctx); 
                            
                            _memberBloc.add(MemberImportPressed(
                              familyId: _currentFamily!.id!, 
                              file: file, 
                              anchorId: tempSelected?.id
                            ));
                            
                            messenger.showSnackBar(const SnackBar(content: Text("Đang xử lý import...")));
                         }
                      }
                    } catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(SnackBar(content: Text("Lỗi chọn file: $e")));
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayFamily = _currentFamily ?? widget.family;

    if (displayFamily == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Chi Tiết")),
        body: const Center(child: Text("Không có thông tin dòng họ.")),
      );
    }

    final List<Widget> _screens = [
      FamilyInfoScreen(
        family: displayFamily,
        onUpdate: (newFamily) {
          setState(() {
            _currentFamily = newFamily;
          });
        },
      ),
      const Center(child: Text("Chat - Đang phát triển")),
      TreeViewScreen(familyId: displayFamily.id!), // Sơ đồ
      MemberListScreen(family: displayFamily), // Các hồ sơ
    ];

    final titles = [
      "Gia phả dòng họ ${displayFamily.name}",
      "Chat",
      "Sơ đồ",
      "Danh sách hồ sơ"
    ];

    return BlocProvider.value(
      value: _memberBloc,
      child: BlocBuilder<MemberBloc, MemberState>(
        builder: (context, state) {
          MemberModel? currentProfile;
          if (state is MemberLoaded) {
            currentProfile = state.myProfile;
          }
          
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: Text(titles[_currentIndex]),
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                if (currentProfile != null && currentProfile.role == 'admin')
                  IconButton(
                    icon: const Icon(Icons.settings),
                    tooltip: "Quản lý thành viên",
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MemberManagementScreen(family: displayFamily),
                        ),
                      );
                    },
                  ),
              ],
            ),
            
            body: IndexedStack(
              index: _currentIndex,
          children: [
            // Tab 0: Home (Info + Files)
            DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Container(
                    color: Colors.blue.shade600,
                    child: const TabBar(
                      labelColor: Colors.white,
                      indicatorColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      tabs: [
                        Tab(text: "Thông tin"),
                        Tab(text: "Tệp"),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        FamilyInfoScreen(
                          family: displayFamily,
                          canEdit: currentProfile != null && (currentProfile.role == 'admin' || currentProfile.role == 'editor'),
                          onUpdate: (newFamily) {
                            setState(() {
                              _currentFamily = newFamily;
                            });
                          },
                        ),
                        const Center(child: Text("Tệp tin - Đang phát triển")),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Tab 1: Chat
            // Tab 1: Chat
            ChatScreen(familyId: displayFamily.id!.toString()),
            
            // Tab 2: TreeView
            TreeViewScreen(familyId: displayFamily.id!),
            
            // Tab 3: MemberList
            MemberListScreen(family: displayFamily),
          ],
        ),

            floatingActionButton: (_currentIndex == 3 && currentProfile != null && (currentProfile.role == 'admin' || currentProfile.role == 'editor'))
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (currentProfile.role == 'admin') // Chỉ admin được import
                    FloatingActionButton(
                      heroTag: "import_btn",
                      backgroundColor: Colors.blue.shade600,
                      onPressed: _onImport,
                      child: const Icon(Icons.upload_file, color: Colors.white),
                    ),
                    if (currentProfile.role == 'admin') const SizedBox(height: 12),
                    
                    FloatingActionButton(
                      heroTag: "add_btn",
                  backgroundColor: Colors.blue.shade600,
                  child: const Icon(Icons.add, color: Colors.white),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (_) => MemberFormScreen(familyId: displayFamily.id))
                    );
                    if (result == true) {
                       _memberBloc.add(MemberFetchList(displayFamily.id!));
                    }
                  },
                ),
              ],
            )
          : null,

        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          selectedItemColor: Colors.blue.shade600,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "Trang chủ"),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: "Chat"),
            BottomNavigationBarItem(icon: Icon(Icons.account_tree_outlined), label: "Sơ đồ"),
            BottomNavigationBarItem(icon: Icon(Icons.description_outlined), label: "Các hồ sơ"),
          ],
        ),
          );
        },
      ),
    );
  }
}
