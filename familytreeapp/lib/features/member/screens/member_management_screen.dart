import 'package:flutter/material.dart';
import '../../family/data/models/family_model.dart';
import '../data/models/member_model.dart';
import '../data/member_repo.dart';
import 'package:flutter/services.dart';

class MemberManagementScreen extends StatefulWidget {
  final FamilyModel family;
  const MemberManagementScreen({super.key, required this.family});

  @override
  State<MemberManagementScreen> createState() => _MemberManagementScreenState();
}

class _MemberManagementScreenState extends State<MemberManagementScreen> {
  final _memberRepo = MemberRepository();
  List<MemberModel> _members = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final list = await _memberRepo.getMembersByFamily(widget.family.id);
      setState(() {
        _members = list;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _updateRole(MemberModel member, String newRole) async {
    try {
      if (member.id == null) return;
      
      // Confirm logic
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Xác nhận"),
          content: Text("Bạn có chắc muốn cấp quyền ${newRole == 'editor' ? 'chỉnh sửa' : 'thành viên'} cho ${member.fullName}?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Hủy")),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Đồng ý")),
          ],
        ),
      );

      if (confirm != true) return;

      await _memberRepo.updateMemberRole(widget.family.id, member.id!, newRole);
      
      // Reload
      _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cập nhật quyền thành công")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Lỗi: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quản lý thành viên"),
        backgroundColor: const Color(0xFF4294E3),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 1. Join Code Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                const Icon(Icons.vpn_key, color: Color(0xFF4294E3)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Mã tham gia gia phả:", style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        widget.family.joinCode ?? "N/A", 
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    if (widget.family.joinCode != null) {
                      Clipboard.setData(ClipboardData(text: widget.family.joinCode!));
                       ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Đã sao chép mã tham gia")),
                        );
                    }
                  },
                )
              ],
            ),
          ),
          
          const Divider(height: 1),

          // 2. Member List
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator()) 
              : _error != null 
                  ? Center(child: Text("Lỗi: $_error"))
                  : ListView.builder(
                      itemCount: _members.length,
                      itemBuilder: (context, index) {
                        final member = _members[index];
                        final isMe = false; // We could inject 'me' if needed, but not critical for List
                        // Simple role check based on string.
                        final roleText = member.role == 'admin' ? "Trưởng tộc (Admin)" :
                                         member.role == 'editor' ? "BTV (Editor)" : "Thành viên";
                        
                        final roleColor = member.role == 'admin' ? Colors.red :
                                          member.role == 'editor' ? Colors.orange : Colors.grey;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
                            child: member.avatarUrl == null ? const Icon(Icons.person) : null,
                          ),
                          title: Text(member.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(roleText, style: TextStyle(color: roleColor, fontSize: 13)),
                          trailing: member.role == 'admin' 
                            ? null // Cannot edit admin
                            : PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'make_editor') _updateRole(member, 'editor');
                                  if (value == 'remove_editor') _updateRole(member, 'member');
                                },
                                itemBuilder: (context) {
                                  if (member.role == 'member') {
                                    return [
                                      const PopupMenuItem(
                                        value: 'make_editor',
                                        child: Text("Cấp quyền Editor"),
                                      ),
                                    ];
                                  } else if (member.role == 'editor') {
                                     return [
                                      const PopupMenuItem(
                                        value: 'remove_editor',
                                        child: Text("Hủy quyền Editor"),
                                      ),
                                    ];
                                  }
                                  return [];
                                },
                            ),
                            
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
