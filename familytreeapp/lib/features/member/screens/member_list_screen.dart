import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../family/data/models/family_model.dart';
import '../data/models/member_model.dart';
import '../logic/member_bloc.dart';
import '../logic/member_event.dart';
import '../logic/member_state.dart';
import 'member_form_screen.dart';
import 'member_detail_view_screen.dart';

class MemberListScreen extends StatefulWidget {
  final FamilyModel family;

  const MemberListScreen({super.key, required this.family});

  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen> {
  String _searchQuery = "";
  String _selectedGender = "Tất cả";
  String _selectedStatus = "Tất cả";
  
  // Generation filter is harder without computed data. 
  // We will keep UI for it but maybe not implement logic yet, or just basic.
  // String _selectedGeneration = "Tất cả"; 

  String _formatDisplayDate(String? yMd) {
    if (yMd == null || yMd.isEmpty) return "--/--/----";
    try {
      final parts = yMd.split('-');
      if (parts.length == 3) {
        return "${parts[2]}/${parts[1]}/${parts[0]}"; // dd/MM/yyyy
      }
      return yMd;
    } catch (_) {
      return yMd;
    }
  }

  List<MemberModel> _applyFilters(List<MemberModel> original) {
    return original.where((m) {
      // 1. Search
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchName = m.fullName.toLowerCase().contains(query);
        final matchId = m.id.toString().contains(query);
        if (!matchName && !matchId) return false;
      }

      // 2. Gender
      if (_selectedGender != "Tất cả") {
        // Map display to value
        String val = "";
        if (_selectedGender == "Nam") val = "male";
        if (_selectedGender == "Nữ") val = "female";
        if (_selectedGender == "Khác") val = "other";
        
        if (m.gender.toLowerCase() != val) return false;
      }

      // 3. Status
      if (_selectedStatus != "Tất cả") {
        bool isDeceased = m.dateOfDeath != null && m.dateOfDeath!.isNotEmpty;
        if (_selectedStatus == "Còn sống" && isDeceased) return false;
        if (_selectedStatus == "Đã mất" && !isDeceased) return false;
      }

      return true;
    }).toList();
  }

  Widget _buildFilterDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Expanded(
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            items: items.map((e) => DropdownMenuItem(
              value: e,
              child: Text(e, overflow: TextOverflow.ellipsis),
            )).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MemberBloc, MemberState>(
      listener: (context, state) {
        if (state is MemberImportSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Import thành công! Đang làm mới danh sách...")));
        } else if (state is MemberFailure) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: ${state.message}"), backgroundColor: Colors.red));
        }
      },
      builder: (context, state) {
           List<MemberModel> members = [];
           if (state is MemberLoaded) {
             members = state.members;
           }
           
           final filteredMembers = _applyFilters(members);

             return Column(
              children: [
                // Top Search & Filter Area
                Container(
                  padding: const EdgeInsets.all(16.0),
                  color: Colors.grey.shade50, // Slight background distinction
                  child: Column(
                    children: [
                      // Search Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        height: 45,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Colors.black54),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                onChanged: (val) {
                                  setState(() {
                                    _searchQuery = val;
                                  });
                                },
                                decoration: const InputDecoration(
                                  hintText: "Tìm kiếm hồ sơ...",
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Filters Row
                      Row(
                        children: [
                          _buildFilterDropdown(
                            "Giới tính", 
                            _selectedGender, 
                            ["Tất cả", "Nam", "Nữ", "Khác"], 
                            (val) => setState(() => _selectedGender = val!)
                          ),
                          const SizedBox(width: 8),
                          _buildFilterDropdown(
                            "Trạng thái", 
                            _selectedStatus, 
                            ["Tất cả", "Còn sống", "Đã mất"], 
                            (val) => setState(() => _selectedStatus = val!)
                          ),
                          // const SizedBox(width: 8),
                          // Start with 2 filters first as requested mostly specific ones. 
                          // If "Doi" is needed, we need logic.
                        ],
                      ),
                    ],
                  ),
                ),
                
                if (state is MemberLoading)
                   const LinearProgressIndicator(),

                // List
                Expanded(
                  child: filteredMembers.isEmpty && state is! MemberLoading
                    ? const Center(child: Text("Không tìm thấy hồ sơ nào."))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: filteredMembers.length,
                        itemBuilder: (context, index) {
                          final member = filteredMembers[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade400),
                            ),
                            child: InkWell(
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BlocProvider.value(
                                      value: context.read<MemberBloc>(),
                                      child: MemberDetailViewScreen(member: member),
                                    ),
                                  ),
                                );
                                if (result == true || result == "deleted") {
                                  if (context.mounted) {
                                    context.read<MemberBloc>().add(MemberFetchList(widget.family.id!));
                                  }
                                }
                              },
                              child: Row(
                                children: [
                                  // Rounded Avatar
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      shape: BoxShape.circle,
                                      image: member.avatarUrl != null 
                                        ? DecorationImage(image: NetworkImage(member.avatarUrl!), fit: BoxFit.cover)
                                        : null,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Info
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        member.fullName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "${_formatDisplayDate(member.dateOfBirth)} - ${_formatDisplayDate(member.dateOfDeath)}",
                                        style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13, color: Colors.black87),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                ),
              ],
            );
        },
    );
  }
}
