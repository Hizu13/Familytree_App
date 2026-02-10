import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../data/models/member_model.dart';
import '../logic/member_bloc.dart';
import '../logic/member_event.dart';
import '../logic/member_state.dart';
import '../../../core/network/api_client.dart';
import '../../../config/api_config.dart';

class MemberEditScreen extends StatefulWidget {
  final MemberModel member;

  const MemberEditScreen({super.key, required this.member});

  @override
  State<MemberEditScreen> createState() => _MemberEditScreenState();
}

class _MemberEditScreenState extends State<MemberEditScreen> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _dobController;
  late TextEditingController _dodController; // Date of Death
  late TextEditingController _genderController;
  late TextEditingController _cccdController;
  late TextEditingController _pobController;
  late TextEditingController _bioController;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.member.firstName);
    _lastNameController = TextEditingController(text: widget.member.lastName);
    _dobController = TextEditingController(text: _formatDateForDisplay(widget.member.dateOfBirth));
    _dodController = TextEditingController(text: _formatDateForDisplay(widget.member.dateOfDeath));
    _genderController = TextEditingController(text: _getDisplayGender(widget.member.gender));
    _cccdController = TextEditingController(text: widget.member.cccd);
    _pobController = TextEditingController(text: widget.member.placeOfBirth);
    _bioController = TextEditingController(text: widget.member.biography);
    _avatarUrl = widget.member.avatarUrl;
  }
  
  String _getDisplayGender(String gender) {
    switch (gender.toLowerCase()) {
      case "male": return "Nam";
      case "female": return "Nữ";
      case "other": return "Khác";
      default: return gender.isEmpty ? "Nam" : gender;
    }
  }
  
  String _getSubmitGender(String displayGender) {
    switch (displayGender) {
      case "Nam": return "male";
      case "Nữ": return "female";
      case "Khác": return "other";
      default: return "male";
    }
  }

  String _formatDateForDisplay(String? yMd) {
    if (yMd == null || yMd.isEmpty) return "";
    try {
      final parts = yMd.split('-');
      if (parts.length == 3) {
        return "${parts[2]}/${parts[1]}/${parts[0]}"; // yyyy-MM-dd -> dd/MM/yyyy
      }
      return yMd;
    } catch (_) {
      return yMd;
    }
  }
  
  String? _formatDateForSubmit(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final day = parts[0].padLeft(2, '0');
        final month = parts[1].padLeft(2, '0');
        final year = parts[2];
        return "$year-$month-$day"; // dd/MM/yyyy -> yyyy-MM-dd
      }
      return dateStr; 
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _dodController.dispose();
    _genderController.dispose();
    _cccdController.dispose();
    _pobController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
         final file = result.files.first;
         
         // Upload
         final url = await ApiClient().uploadImage(file);
         
         if (url != null) {
            String fullUrl = url;
            if (!url.startsWith('http')) {
               fullUrl = "${ApiConfig.baseUrl}$url";
            }
            setState(() {
              _avatarUrl = fullUrl;
            });
         } else {
            if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi tải ảnh lên")));
            }
         }
      }
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  void _onDelete() {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text("Xác nhận xóa"),
        content: const Text("Bạn có chắc chắn muốn xóa thành viên này không?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<MemberBloc>().add(MemberDeletePressed(widget.member.id!));
            }, 
            child: const Text("Xóa", style: TextStyle(color: Colors.red))
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Chỉnh sửa hồ sơ", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF4294E3),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _onDelete,
            child: const Text("Xóa", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: BlocConsumer<MemberBloc, MemberState>(
        listener: (context, state) {
          if (state is MemberUpdateSuccess) {
            Navigator.pop(context, true); // Return true to indicate update
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cập nhật thành công!")));
          } else if (state is MemberDeleteSuccess) {
            Navigator.pop(context, "deleted"); // Return specific string for delete
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Xóa thành công!")));
          } else if (state is MemberFailure) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          }
        },
        builder: (context, state) {
          bool isLoading = state is MemberLoading;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Center(
                   child: GestureDetector(
                     onTap: _pickAndUploadImage,
                     child: Column(
                       children: [
                         Container(
                           width: 100,
                           height: 100,
                           decoration: BoxDecoration(
                             color: Colors.grey.shade300,
                             shape: BoxShape.circle,
                             image: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                               ? DecorationImage(
                                   image: NetworkImage(_avatarUrl!),
                                   fit: BoxFit.cover,
                                 )
                               : null,
                             border: Border.all(color: Colors.blueAccent, width: 2),
                           ),
                           child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                             ? const Icon(Icons.camera_alt, color: Colors.grey, size: 40)
                             : null,
                         ),
                         const SizedBox(height: 8),
                         const Text("Nhấn để thay đổi ảnh", style: TextStyle(color: Colors.blue, fontStyle: FontStyle.italic)),
                       ],
                     ),
                   ),
                 ),
                 const SizedBox(height: 20),

                _buildLabel("Họ"),
                _buildTextField(_lastNameController, "Nhập họ"),
                const SizedBox(height: 16),
                
                _buildLabel("Tên"),
                _buildTextField(_firstNameController, "Nhập tên"),
                const SizedBox(height: 16),

                _buildLabel("Số căn cước công dân"),
                _buildTextField(_cccdController, "Nhập số cccd"),
                const SizedBox(height: 16),
                
                _buildLabel("Giới tính"),
                DropdownButtonFormField<String>(
                  value: _genderController.text.isNotEmpty ? _genderController.text : "Nam",
                  decoration: _inputDecoration("Chọn giới tính"),
                  items: const [
                    DropdownMenuItem(value: "Nam", child: Text("Nam")),
                    DropdownMenuItem(value: "Nữ", child: Text("Nữ")),
                    DropdownMenuItem(value: "Khác", child: Text("Khác")),
                  ],
                  onChanged: (val) {
                    if (val != null) _genderController.text = val;
                  },
                ),
                const SizedBox(height: 16),
                
                _buildLabel("Ngày sinh"),
                TextField(
                  controller: _dobController,
                  decoration: _inputDecoration("dd/MM/yyyy").copyWith(
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                _buildLabel("Ngày mất (nếu có)"),
                TextField(
                  controller: _dodController,
                  decoration: _inputDecoration("dd/MM/yyyy").copyWith(
                    suffixIcon: const Icon(Icons.event_busy), // Icon Event Busy
                  ),
                ),
                const SizedBox(height: 16),
                
                _buildLabel("Quê quán"),
                _buildTextField(_pobController, "Nhập quê quán"),
                const SizedBox(height: 16),
                
                _buildLabel("Tiểu sử"),
                TextField(
                  controller: _bioController,
                  maxLines: 4,
                  decoration: _inputDecoration("Tóm tắt tiểu sử"),
                ),
                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4294E3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: isLoading
                        ? null
                        : () {
                            final updatedMember = MemberModel(
                              id: widget.member.id,
                              firstName: _firstNameController.text,
                              lastName: _lastNameController.text,
                              cccd: _cccdController.text.isNotEmpty ? _cccdController.text : null,
                              gender: _getSubmitGender(_genderController.text),
                              dateOfBirth: _formatDateForSubmit(_dobController.text),
                              dateOfDeath: _formatDateForSubmit(_dodController.text),
                              placeOfBirth: _pobController.text.isNotEmpty ? _pobController.text : null,
                              biography: _bioController.text,
                              familyId: widget.member.familyId,
                              fatherId: widget.member.fatherId,
                              motherId: widget.member.motherId,
                              avatarUrl: _avatarUrl,
                            );
                            context.read<MemberBloc>().add(MemberUpdatePressed(updatedMember));
                          },
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Lưu thay đổi", style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      decoration: _inputDecoration(hint),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
    );
  }
}
