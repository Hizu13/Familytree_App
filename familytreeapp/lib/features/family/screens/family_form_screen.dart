import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../family/data/models/family_model.dart'; // Import FamilyModel
import '../logic/family_bloc.dart';
import '../logic/family_event.dart';
import '../logic/family_state.dart';

class FamilyFormScreen extends StatefulWidget {
  final FamilyModel? family; // Nếu null -> Tạo mới, nếu có -> Chỉnh sửa

  const FamilyFormScreen({super.key, this.family});

  @override
  State<FamilyFormScreen> createState() => _FamilyFormScreenState();
}

class _FamilyFormScreenState extends State<FamilyFormScreen> {
  late TextEditingController _nameController;
  late TextEditingController _originController;
  late TextEditingController _descController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.family?.name ?? '');
    _originController = TextEditingController(text: widget.family?.originLocation ?? '');
    _descController = TextEditingController(text: widget.family?.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _originController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.family != null;
    final title = isEditing ? "Chỉnh sửa gia phả" : "Thêm mới gia phả";

    return BlocProvider(
      create: (context) => FamilyBloc(),
      child: BlocConsumer<FamilyBloc, FamilyState>(
        listener: (context, state) {
          if (state is FamilyCreateSuccess) {
            Navigator.pop(context, true);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tạo thành công!")));
          } else if (state is FamilyUpdateSuccess) {
            Navigator.pop(context, state.family); // Trả về object đã update
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cập nhật thành công!")));
          } else if (state is FamilyDeleteSuccess) {
             // Navigate back twice (to list) or just implement navigation logic in UI
             Navigator.of(context).popUntil((route) => route.isFirst); // Về trang chủ
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã xóa gia phả!")));
             // Cần reload list ở trang chủ, nhưng vì pop hết nên trang chủ cần tự reload/listen
          } else if (state is FamilyFailure) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          }
        },
        builder: (context, state) {
          bool isLoading = state is FamilyLoading;
          
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: Text(title, style: const TextStyle(color: Colors.white)),
              backgroundColor: const Color(0xFF4294E3),
              iconTheme: const IconThemeData(color: Colors.white),
              elevation: 0,
              actions: isEditing ? [
                TextButton(
                  onPressed: () {
                     // Confirm Delete
                     showDialog(
                       context: context,
                       builder: (ctx) => AlertDialog(
                         title: const Text("Xác nhận xóa"),
                         content: const Text("Bạn có chắc muốn xóa gia phả này không?"),
                         actions: [
                           TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
                           TextButton(
                             onPressed: () {
                               Navigator.pop(ctx);
                               context.read<FamilyBloc>().add(FamilyDeletePressed(widget.family!.id));
                             }, 
                             child: const Text("Xóa", style: TextStyle(color: Colors.red))
                            ),
                         ],
                       )
                     );
                  },
                  child: const Text("Xóa", style: TextStyle(color: Colors.redAccent, fontSize: 16)),
                )
              ] : null,
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: state is FamilyLoading && (state is! FamilyUpdateSuccess && state is! FamilyCreateSuccess) 
                  ? const Center(child: CircularProgressIndicator()) 
                  : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("Tên dòng họ"),
                        _buildTextField(_nameController, "Nhập họ của bạn"),
                        const SizedBox(height: 20),
                        
                        _buildLabel("Quê quán"),
                        _buildTextField(_originController, "Nhập quê quán của bạn"),
                        const SizedBox(height: 20),
                        
                        _buildLabel("Giới thiệu"),
                        TextField(
                          controller: _descController,
                          maxLines: 5,
                          decoration: InputDecoration(
                            hintText: "Lời giới thiệu về dòng họ của bạn...",
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        const SizedBox(height: 30),
                        
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4294E3),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: isLoading ? null : () {
                              if (_nameController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập tên dòng họ")));
                                return;
                              }
                              
                              if (isEditing) {
                                context.read<FamilyBloc>().add(FamilyUpdatePressed(
                                  widget.family!.id, 
                                  _nameController.text, 
                                  _descController.text,
                                  _originController.text
                                ));
                              } else {
                                context.read<FamilyBloc>().add(FamilyCreatePressed(
                                  _nameController.text, 
                                  _descController.text,
                                  _originController.text
                                ));
                              }
                            },
                            child: isLoading 
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(isEditing ? "Lưu" : "Tiếp theo", style: const TextStyle(color: Colors.white, fontSize: 16)),
                          ),
                        )
                      ],
                    ),
                  ),
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
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: Colors.grey.shade400)
        ),
      ),
    );
  }
}
