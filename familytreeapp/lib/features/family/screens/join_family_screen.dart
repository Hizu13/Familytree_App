import 'package:flutter/material.dart';
import '../data/family_repository.dart';

class JoinFamilyScreen extends StatefulWidget {
  const JoinFamilyScreen({super.key});

  @override
  State<JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends State<JoinFamilyScreen> {
  final _codeController = TextEditingController();
  final _familyRepo = FamilyRepository();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleJoin() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _familyRepo.joinFamily(code);
      if (mounted) {
        Navigator.pop(context, true); // Return true to refresh list
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tham gia gia phả thành công!")),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        // Remove "Exception: " prefix if present
        if (_errorMessage!.startsWith("Exception: ")) {
          _errorMessage = _errorMessage!.substring(11);
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tham gia Gia phả"),
        backgroundColor: const Color(0xFF4294E3),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text(
              "Nhập mã gia phả để tham gia",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: "Mã gia phả",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                errorText: _errorMessage,
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleJoin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4294E3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "THAM GIA",
                      style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
