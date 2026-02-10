import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/logic/auth_bloc.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _dobController = TextEditingController();
  final _placeOfBirthController = TextEditingController();
  
  String _selectedGender = 'male';
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _placeOfBirthController.dispose();
    super.dispose();
  }

  void _onRegister() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
        AuthRegisterStarted(
          username: _usernameController.text,
          password: _passwordController.text,
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          gender: _selectedGender,
          dateOfBirth: _dobController.text.isNotEmpty ? _formatDateForSubmit(_dobController.text) : null,
          placeOfBirth: _placeOfBirthController.text.isNotEmpty ? _placeOfBirthController.text : null,
          email: _emailController.text,
        ),
      );
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthRegisterSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đăng ký thành công! Vui lòng đăng nhập.')),
            );
            Navigator.pop(context);
          } else if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;
          
          return Column(
            children: [
              // --- CUSTOM HEADER (Theo mẫu ảnh) ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(25, 60, 25, 35),
                decoration: const BoxDecoration(
                  color: Color(0xFF4C8CE2), // Màu xanh đúng mẫu
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(15),
                    bottomRight: Radius.circular(15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Đăng ký tài khoản',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'FamilyTree',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),

              // --- FORM ---
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Tài khoản'),
                        _buildTextField(
                          controller: _usernameController,
                          hint: 'Nhập tên tài khoản của bạn',
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Vui lòng nhập tài khoản';
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

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

                        _buildLabel('Giới tính'),
                        DropdownButtonFormField<String>(
                          value: _selectedGender,
                          decoration: _inputDecoration('Chọn giới tính'),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.black45),
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
                        const SizedBox(height: 18),

                        _buildLabel('Mật khẩu'),
                        _buildTextField(
                          controller: _passwordController,
                          hint: 'Nhập mật khẩu của bạn',
                          obscureText: !_isPasswordVisible,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility : Icons.visibility_off, 
                              color: Colors.black38,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
                            if (value.length < 6) return 'Tối thiểu 6 ký tự';
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        _buildLabel('Nhập lại mật khẩu'),
                        _buildTextField(
                          controller: _confirmPasswordController,
                          hint: 'Nhập lại mật khẩu của bạn',
                          obscureText: !_isConfirmPasswordVisible,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off, 
                              color: Colors.black38,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                          ),
                          validator: (value) {
                            if (value != _passwordController.text) return 'Mật khẩu không khớp';
                            return null;
                          },
                        ),
                        const SizedBox(height: 35),

                        // Nút Đăng ký đúng mẫu
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _onRegister,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4C8CE2),
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shadowColor: Colors.black26,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text(
                                    'Đăng ký', 
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Footer (Đã có tài khoản)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Bạn đã có tài khoản? ', style: TextStyle(color: Colors.black87, fontSize: 13)),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Text(
                                'Đăng nhập', 
                                style: TextStyle(
                                  color: Color(0xFF4C8CE2), 
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 14),
      decoration: _inputDecoration(hint).copyWith(suffixIcon: suffixIcon),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}