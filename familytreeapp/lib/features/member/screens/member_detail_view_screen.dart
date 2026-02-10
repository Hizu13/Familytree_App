import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/models/member_model.dart';
import '../logic/member_bloc.dart';
import '../logic/member_event.dart';
import '../logic/member_state.dart';
import '../data/member_repo.dart';
import 'member_edit_screen.dart';

class MemberDetailViewScreen extends StatefulWidget {
  final MemberModel member;

  const MemberDetailViewScreen({super.key, required this.member});

  @override
  State<MemberDetailViewScreen> createState() => _MemberDetailViewScreenState();
}

class _MemberDetailViewScreenState extends State<MemberDetailViewScreen> {
  late MemberModel currentMember;
  String? _relationship;
  bool _isLoadingRelationship = false;

  @override
  void initState() {
    super.initState();
    currentMember = widget.member;
    _fetchRelationship();
  }

  Future<void> _fetchRelationship() async {
    final state = context.read<MemberBloc>().state;
    if (state is MemberLoaded && state.myProfile != null) {
      final me = state.myProfile!;
      if (me.id == currentMember.id) {
        setState(() {
          _relationship = "Bản thân";
        });
        return;
      }
      
      setState(() => _isLoadingRelationship = true);
      try {
        final rel = await MemberRepository().getRelationship(me.id!, currentMember.id!, currentMember.familyId!);
        if (mounted) {
           setState(() {
             _relationship = rel;
             _isLoadingRelationship = false;
           });
        }
      } catch (e) {
         if (mounted) setState(() => _isLoadingRelationship = false);
      }
    }
  }

  String _formatDateForDisplay(String? yMd) {
    if (yMd == null || yMd.isEmpty) return "--/--/----";
    try {
      final parts = yMd.split('-');
      if (parts.length == 3) {
        return "${parts[2]}/${parts[1]}/${parts[0]}";
      }
      return yMd;
    } catch (_) {
      return yMd;
    }
  }

  String _getDisplayGender(String gender) {
    switch (gender.toLowerCase()) {
      case "male": return "Nam";
      case "female": return "Nữ";
      case "other": return "Khác";
      default: return gender;
    }
  }

  void _onEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<MemberBloc>(), // Reuse existing Bloc logic
          child: MemberEditScreen(member: currentMember),
        ),
      ),
    );

    if (result == "deleted") {
      // Return "deleted" to list screen so it can refresh
      if (mounted) Navigator.pop(context, "deleted");
    } else if (result == true) {
      // Return true to indicate update happened
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: BlocBuilder<MemberBloc, MemberState>(
        builder: (context, state) {
          MemberModel? myProfile;
          if (state is MemberLoaded) {
            myProfile = state.myProfile;
          }

          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: const Text("Hồ sơ", style: TextStyle(color: Colors.white)),
              backgroundColor: const Color(0xFF4294E3),
              iconTheme: const IconThemeData(color: Colors.white),
              elevation: 0,
              actions: [
                if (myProfile != null && (myProfile.role == 'admin' || myProfile.role == 'editor'))
                  TextButton(
                    onPressed: _onEdit,
                    child: const Text("Chỉnh sửa", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  )
              ],
              bottom: const TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: [
                   Tab(text: "Thông tin"),
                   Tab(text: "Mối quan hệ"),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                // TAB 1: INFO
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Avatar Area
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                shape: BoxShape.circle,
                                image: currentMember.avatarUrl != null 
                                  ? DecorationImage(image: NetworkImage(currentMember.avatarUrl!), fit: BoxFit.cover)
                                  : null,
                              ),
                              child: currentMember.avatarUrl == null 
                                ? const Icon(Icons.add, color: Colors.white, size: 30) // Placeholder
                                : null,
                            ),
                            const SizedBox(height: 16),
                            // Relationship Tag (Me vs Viewing)
                            if (_relationship != null || _isLoadingRelationship) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE3F2FD),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF4294E3).withOpacity(0.5)),
                                ),
                                child: _isLoadingRelationship 
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Text(
                                      "Mối quan hệ: $_relationship",
                                      style: const TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildReadOnlyField("Họ", currentMember.lastName ?? ""),
                      const SizedBox(height: 16),
                      _buildReadOnlyField("Tên", currentMember.firstName),
                      const SizedBox(height: 16),
                      _buildReadOnlyField("Số căn cước công dân", currentMember.cccd ?? ""),
                      const SizedBox(height: 16),
                      _buildReadOnlyField("Giới tính", _getDisplayGender(currentMember.gender)),
                      const SizedBox(height: 16),
                      _buildReadOnlyField("Ngày sinh", _formatDateForDisplay(currentMember.dateOfBirth)),
                      const SizedBox(height: 16),
                      _buildReadOnlyField("Ngày mất", _formatDateForDisplay(currentMember.dateOfDeath)),
                      const SizedBox(height: 16),
                      _buildReadOnlyField("Quê quán", currentMember.placeOfBirth ?? ""),
                      const SizedBox(height: 16),
                      _buildReadOnlyField("Tiểu sử", currentMember.biography ?? "", maxLines: 5),
                    ],
                  ),
                ),

                // TAB 2: RELATIONSHIPS
                _buildRelationshipsTab(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRelationshipsTab() {
    return BlocBuilder<MemberBloc, MemberState>(
      builder: (context, state) {
        if (state is MemberLoaded) {
          final members = state.members;
          // Find parents
          MemberModel? father;
          MemberModel? mother;
          try {
            father = members.firstWhere((m) => m.id == currentMember.fatherId);
          } catch (_) {}
          try {
            mother = members.firstWhere((m) => m.id == currentMember.motherId);
          } catch (_) {}
          
          // Find children
          final children = members.where((m) => m.fatherId == currentMember.id || m.motherId == currentMember.id).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader("Bố Mẹ"),
              if (father == null && mother == null)
                const Padding(padding: EdgeInsets.only(left: 16, top: 8), child: Text("Chưa có thông tin")),
              if (father != null) _buildMemberItem(father, "Bố"),
              if (mother != null) _buildMemberItem(mother, "Mẹ"),

              const SizedBox(height: 24),
              // --- VỢ/CHỒNG SECTION ---
              _buildSectionHeader("Vợ/Chồng"),
              FutureBuilder<List<MemberModel>>(
                future: MemberRepository().getSpouses(currentMember.id!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 8, left: 16),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  
                  if (snapshot.hasError) {
                    return const Padding(
                      padding: EdgeInsets.only(left: 16, top: 8),
                      child: Text("Lỗi tải thông tin", style: TextStyle(color: Colors.red)),
                    );
                  }
                  
                  final spouses = snapshot.data ?? [];
                  
                  if (spouses.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(left: 16, top: 8),
                      child: Text("Chưa có thông tin"),
                    );
                  }
                  
                  return Column(
                    children: spouses.map((spouse) {
                      final role = spouse.gender == 'male' ? 'Chồng' : 'Vợ';
                      return _buildMemberItem(spouse, role);
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 24),
              _buildSectionHeader("Con Cái (${children.length})"),
              if (children.isEmpty)
                const Padding(padding: EdgeInsets.only(left: 16, top: 8), child: Text("Chưa có thông tin")),
              ...children.map((child) => _buildMemberItem(child, "Con")),
            ],
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4294E3)),
    );
  }

  Widget _buildMemberItem(MemberModel member, String role) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey.shade300,
          backgroundImage: member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
          child: member.avatarUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
        ),
        title: Text(member.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(role),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () {
          // Navigate to this member's detail
           Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<MemberBloc>(),
                child: MemberDetailViewScreen(member: member),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value.isEmpty ? " " : value, 
            style: const TextStyle(fontSize: 16),
            maxLines: maxLines,
          ),
        ),
      ],
    );
  }
}
