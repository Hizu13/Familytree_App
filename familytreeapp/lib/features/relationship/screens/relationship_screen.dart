import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../member/data/models/member_model.dart';
import '../../member/logic/member_bloc.dart';
import '../../member/logic/member_state.dart';
import '../logic/relationship_bloc.dart';
import '../logic/relationship_event.dart';
import '../logic/relationship_state.dart';

class RelationshipScreen extends StatefulWidget {
  final int familyId;

  const RelationshipScreen({super.key, required this.familyId});

  @override
  State<RelationshipScreen> createState() => _RelationshipScreenState();
}

class _RelationshipScreenState extends State<RelationshipScreen> {
  MemberModel? _person1;
  MemberModel? _person2;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => RelationshipBloc()),
        // We assume MemberBloc is available or we create a new one to fetch list
        // Ideally pass existing list or fetch new. Let's fetch new for simplicity.
        BlocProvider(create: (context) => MemberBloc()..add(MemberFetchList(widget.familyId))),
      ],
      child: Scaffold(
        backgroundColor: Colors.white,
        body: BlocBuilder<MemberBloc, MemberState>(
          builder: (context, memberState) {
            if (memberState is MemberLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (memberState is MemberLoaded) {
              final members = memberState.members;
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      "Tính mối quan hệ",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4294E3)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Chọn 2 người để xem người thứ 2 là gì của người thứ 1 theo vai vế gia tộc.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),

                    // Person 1 Selection
                    _buildDropdown(
                      label: "Người thứ 1 (Chủ thể)",
                      value: _person1,
                      items: members,
                      onChanged: (val) => setState(() => _person1 = val),
                    ),
                    const SizedBox(height: 16),

                    // Person 2 Selection
                    _buildDropdown(
                      label: "Người thứ 2 (Đối tượng)",
                      value: _person2,
                      items: members,
                      onChanged: (val) => setState(() => _person2 = val),
                    ),
                    const SizedBox(height: 24),

                    // Calculate Button
                    BlocConsumer<RelationshipBloc, RelationshipState>(
                      listener: (context, relState) {
                        if (relState is RelationshipFailure) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(relState.message)));
                        }
                      },
                      builder: (context, relState) {
                        bool isLoading = relState is RelationshipLoading;
                        
                        return Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4294E3),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: (_person1 != null && _person2 != null && !isLoading)
                                    ? () {
                                        context.read<RelationshipBloc>().add(
                                          RelationshipCalculatePressed(
                                            widget.familyId,
                                            _person1!.id!,
                                            _person2!.id!,
                                          ),
                                        );
                                      }
                                    : null,
                                child: isLoading 
                                  ? const CircularProgressIndicator(color: Colors.white) 
                                  : const Text("Kiểm tra quan hệ", style: TextStyle(fontSize: 16, color: Colors.white)),
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            // Result Area
                            if (relState is RelationshipSuccess)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEDF6FD),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF4294E3).withOpacity(0.3)),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      "${_person2?.fullName} là",
                                      style: const TextStyle(fontSize: 16, color: Colors.black54),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      relState.result.relationship.toUpperCase(),
                                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF4294E3)),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "của ${_person1?.fullName}",
                                      style: const TextStyle(fontSize: 16, color: Colors.black54),
                                    ),
                                  ],
                                ),
                              )
                          ],
                        );
                      },
                    ),
                  ],
                ),
              );
            }
            return const Center(child: Text("Không tải được danh sách thành viên"));
          },
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required MemberModel? value,
    required List<MemberModel> items,
    required Function(MemberModel?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<MemberModel>(
              value: value,
              isExpanded: true,
              hint: const Text("-- Chọn thành viên --"),
              items: items.map((e) {
                return DropdownMenuItem(
                  value: e,
                  child: Text(e.fullName),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
