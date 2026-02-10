import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../logic/family_bloc.dart';
import '../logic/family_event.dart';
import '../logic/family_state.dart';

class CreateFamilyScreen extends StatefulWidget {
  const CreateFamilyScreen({super.key});

  @override
  State<CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _CreateFamilyScreenState extends State<CreateFamilyScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FamilyBloc(),
      child: Scaffold(
        appBar: AppBar(title: const Text("Tạo Dòng Họ Mới")),
        body: BlocConsumer<FamilyBloc, FamilyState>(
          listener: (context, state) {
            if (state is FamilyCreateSuccess) {
              // Tạo xong -> Quay về trang trước và báo success
              Navigator.pop(context, true); 
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Tạo thành công!")),
              );
            } else if (state is FamilyFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: Colors.red),
              );
            }
          },
          builder: (context, state) {
            bool isLoading = state is FamilyLoading;
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: "Tên dòng họ"),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descController,
                    decoration: const InputDecoration(labelText: "Mô tả"),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              final name = _nameController.text;
                              final desc = _descController.text;
                              if (name.isNotEmpty) {
                                context.read<FamilyBloc>().add(FamilyCreatePressed(name, desc));
                              }
                            },
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Tạo Dòng Họ"),
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
}