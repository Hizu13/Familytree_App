import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../data/models/member_model.dart';
import '../logic/member_bloc.dart';
import '../logic/member_event.dart';
import '../logic/member_state.dart';
import '../../../core/network/api_client.dart';
import '../../../config/api_config.dart';

class MemberFormScreen extends StatefulWidget {
  final int familyId;
  final int? initialFatherId;
  final int? initialMotherId;
  final int? isFatherOfId;
  final int? isMotherOfId;
  final int? spouseId;
  final String? initialGender;

  const MemberFormScreen({
    super.key, 
    required this.familyId,
    this.initialFatherId,
    this.initialMotherId,
    this.isFatherOfId,
    this.isMotherOfId,
    this.spouseId,
    this.initialGender,
  });

  @override
  State<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends State<MemberFormScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dobController = TextEditingController();
  late TextEditingController _genderController;
  String? _avatarUrl;
  
  @override
  void initState() {
    super.initState();
    _genderController = TextEditingController(text: widget.initialGender ?? "Nam");
    // Simple mapper if input is 'male'/'female'
    if (widget.initialGender == 'male') _genderController.text = "Nam";
    if (widget.initialGender == 'female') _genderController.text = "Nữ";
  }
  
  // Lazy init for Hot Reload safety
  TextEditingController? _cccdController;
  TextEditingController? _pobController;
  TextEditingController? _bioController;

  TextEditingController get cccdController => _cccdController ??= TextEditingController();
  TextEditingController get pobController => _pobController ??= TextEditingController();
  TextEditingController get bioController => _bioController ??= TextEditingController();

  String _getSubmitGender(String displayGender) {
    switch (displayGender) {
      case "Nam": return "male";
      case "Nữ": return "female";
      case "Khác": return "other";
      default: return "male";
    }
  }

  String? _formatDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final day = parts[0].padLeft(2, '0');
        final month = parts[1].padLeft(2, '0');
        final year = parts[2];
        return "$year-$month-$day"; 
      }
      return dateStr;
    } catch (e) {
      return null;
    }
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

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _genderController.dispose();
    _cccdController?.dispose();
    _pobController?.dispose();
    _bioController?.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MemberBloc(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text("Thêm mới thành viên", style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF4294E3),
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: BlocConsumer<MemberBloc, MemberState>(
          listener: (context, state) {
            if (state is MemberCreateSuccess) {
              Navigator.pop(context, true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Thêm thành công!")),
              );
            } else if (state is MemberFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: Colors.red),
              );
            }
          },
          builder: (context, state) {
            bool isLoading = state is MemberLoading;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // Avatar Upload
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
                           const Text("Nhấn để thêm ảnh", style: TextStyle(color: Colors.blue, fontStyle: FontStyle.italic)),
                         ],
                       ),
                     ),
                   ),
                   const SizedBox(height: 20),

                  // Fields
                  _buildLabel("Họ"),
                  _buildTextField(_lastNameController, "Nhập họ của bạn"),
                  const SizedBox(height: 16),
                  
                  _buildLabel("Tên"),
                  _buildTextField(_firstNameController, "Nhập tên của bạn"),
                  const SizedBox(height: 16),

                  _buildLabel("Số căn cước công dân"),
                  _buildTextField(cccdController, "Nhập số cccd của bạn"),
                  const SizedBox(height: 16),
                  
                  _buildLabel("Giới tính"),
                  DropdownButtonFormField<String>(
                    value: _genderController.text,
                    decoration: _inputDecoration("Chọn giới của bạn"),
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
                    decoration: _inputDecoration("Nhập ngày sinh (dd/MM/yyyy)").copyWith(
                      suffixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildLabel("Quê quán"),
                  _buildTextField(pobController, "Nhập quê quán của bạn"),
                  const SizedBox(height: 16),
                  
                  _buildLabel("Tiểu sử"),
                  TextField(
                    controller: bioController,
                    maxLines: 4,
                    decoration: _inputDecoration("Tóm tắt giới thiệu bản thân của bạn"),
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
                              final member = MemberModel(
                                firstName: _firstNameController.text,
                                lastName: _lastNameController.text,
                                cccd: cccdController.text.isNotEmpty ? cccdController.text : null,
                                gender: _getSubmitGender(_genderController.text),
                                dateOfBirth: _formatDate(_dobController.text),
                                placeOfBirth: pobController.text.isNotEmpty ? pobController.text : null,
                                biography: bioController.text,
                                familyId: widget.familyId,
                                fatherId: widget.initialFatherId,
                                motherId: widget.initialMotherId,
                                isFatherOfId: widget.isFatherOfId,
                                isMotherOfId: widget.isMotherOfId,
                                spouseId: widget.spouseId,
                                avatarUrl: _avatarUrl,
                              );
                              context.read<MemberBloc>().add(MemberCreatePressed(member));
                            },
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Tạo mới thành viên", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  )
                ],
              ),
            );
          },
        ),
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
