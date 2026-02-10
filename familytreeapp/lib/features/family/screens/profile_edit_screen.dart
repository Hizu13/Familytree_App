import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _cccdController = TextEditingController(); // Added
  final _dobController = TextEditingController();
  final _placeOfBirthController = TextEditingController();
  
  String _selectedGender = 'male';

  bool _isLoading = false;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoadingProfile = true);
    try {
      final response = await ApiClient().dio.get('/auth/me');
      final data = response.data;
      _firstNameController.text = data['first_name'] ?? '';
      _lastNameController.text = data['last_name'] ?? '';
      _emailController.text = data['email'] ?? '';
      _cccdController.text = data['cccd'] ?? '';
      _placeOfBirthController.text = data['place_of_birth'] ?? '';
      
      // Định dạng ngày sinh từ yyyy-MM-dd sang dd/MM/yyyy
      String? dob = data['date_of_birth'];
      if (dob != null && dob.isNotEmpty) {
        final parts = dob.split('-');
        if (parts.length == 3) {
          _dobController.text = "${parts[2]}/${parts[1]}/${parts[0]}";
        }
      }

      if (data['gender'] != null) {
        _selectedGender = data['gender'];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải thông tin: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ApiClient().dio.put('/auth/profile', data: {
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'email': _emailController.text,
        'cccd': _cccdController.text,
        'gender': _selectedGender,
        'date_of_birth': _formatDateForSubmit(_dobController.text),
        'place_of_birth': _placeOfBirthController.text,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật thành công!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String? _formatDateForSubmit(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        return "${parts[2]}-${parts[1]}-${parts[0]}"; // dd/MM/yyyy -> yyyy-MM-dd
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
    _emailController.dispose();
    _cccdController.dispose();
    _dobController.dispose();
    _placeOfBirthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // --- CUSTOM HEADER ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(25, 60, 25, 30),
                  decoration: const BoxDecoration(
                    color: Color(0xFF4C8CE2),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(15),
                      bottomRight: Radius.circular(15),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Chỉnh sửa hồ sơ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // --- FORM ---
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 25),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Họ'),
                          _buildTextField(
                            controller: _lastNameController,
                            hint: 'Nhập họ của bạn',
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Vui lòng nhập họ';
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          _buildLabel('Tên'),
                          _buildTextField(
                            controller: _firstNameController,
                            hint: 'Nhập tên của bạn',
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Vui lòng nhập tên';
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          _buildLabel('Số CCCD / CMND'),
                          _buildTextField(
                            controller: _cccdController,
                            hint: 'Nhập số CCCD của bạn',
                          ),
                          const SizedBox(height: 18),

                          _buildLabel('Giới tính'),
                          DropdownButtonFormField<String>(
                            value: _selectedGender,
                            decoration: _inputDecoration('Chọn giới tính'),
                            items: const [
                              DropdownMenuItem(value: 'male', child: Text('Nam')),
                              DropdownMenuItem(value: 'female', child: Text('Nữ')),
                              DropdownMenuItem(value: 'other', child: Text('Khác')),
                            ],
                            onChanged: (value) {
                              if (value != null) setState(() => _selectedGender = value);
                            },
                          ),
                          const SizedBox(height: 18),

                          _buildLabel('Ngày sinh'),
                          _buildTextField(
                            controller: _dobController,
                            hint: 'dd/MM/yyyy (VD: 01/01/2000)',
                          ),
                          const SizedBox(height: 18),

                          _buildLabel('Nơi sinh'),
                          _buildTextField(
                            controller: _placeOfBirthController,
                            hint: 'Nhập nơi sinh của bạn',
                          ),
                          const SizedBox(height: 18),

                          _buildLabel('Email'),
                          _buildTextField(
                            controller: _emailController,
                            hint: 'Nhập email của bạn',
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Vui lòng nhập email';
                              if (!value.contains('@')) return 'Email không hợp lệ';
                              return null;
                            },
                          ),
                          const SizedBox(height: 35),

                          // Nút Lưu thay đổi
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4C8CE2),
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shadowColor: Colors.black26,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text(
                                      'Lưu thay đổi', 
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 15),
      decoration: _inputDecoration(hint),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black26, fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF4C8CE2), width: 1.5),
      ),
    );
  }
}
