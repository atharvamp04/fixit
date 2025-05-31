import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentConfirmationScreen extends StatefulWidget {
  const PaymentConfirmationScreen({Key? key}) : super(key: key);

  @override
  State<PaymentConfirmationScreen> createState() =>
      _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen> {
  String selectedOption = '';
  final TextEditingController cashController = TextEditingController();
  File? upiScreenshot;

  Future<void> _pickImageFromCamera() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
    );
    if (pickedFile != null) {
      setState(() => upiScreenshot = File(pickedFile.path));
    }
  }

  Future<void> uploadUPIReceipt(File file, String userName) async {
    final supabase = Supabase.instance.client;

    try {
      final bytes = await file.readAsBytes();
      final fileName = 'upi_receipts/${DateTime.now().millisecondsSinceEpoch}.jpg';

      await supabase.storage
          .from('payments')
          .uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );

      await supabase.from('payment_metadata').insert({
        'type': 'upi',
        'file_path': fileName,
        'user_name': userName,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Upload failed: $e');
    }
  }

  void _submit() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not logged in.")),
      );
      return;
    }

    final response = await supabase
        .from('profiles')
        .select('full_name')
        .eq('id', user.id)
        .single();

    final userName = response['full_name'];

    if (selectedOption == 'cash') {
      final amount = double.tryParse(cashController.text);
      if (amount == null || amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter a valid cash amount.")),
        );
        return;
      }

      // Navigate immediately to CompletedScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CompletedScreen()),
      );

      // Fire and forget insert cash metadata
      supabase.from('payment_metadata').insert({
        'type': 'cash',
        'amount': amount,
        'user_name': userName,
        'timestamp': DateTime.now().toIso8601String(),
      }).catchError((e) {
        print("Cash payment insert error: $e");
      });
    } else if (selectedOption == 'upi' && upiScreenshot != null) {
      // Navigate immediately to CompletedScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CompletedScreen()),
      );

      // Fire and forget upload UPI receipt + insert metadata
      uploadUPIReceipt(upiScreenshot!, userName).catchError((e) {
        print("UPI upload error: $e");
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide payment details.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.yellow.shade600;
    final buttonShadow = [
      BoxShadow(
        color: Colors.green.shade200.withOpacity(0.6),
        offset: const Offset(0, 4),
        blurRadius: 8,
      )
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Confirm Payment"),
        backgroundColor: primaryColor,
        elevation: 4,
        shadowColor: Colors.yellow.shade600,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Select Payment Method",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),

            // Cash Option
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: RadioListTile<String>(
                title: const Text("Cash",
                    style: TextStyle(fontWeight: FontWeight.w600)),
                value: 'cash',
                groupValue: selectedOption,
                activeColor: primaryColor,
                onChanged: (val) => setState(() => selectedOption = val!),
              ),
            ),

            const SizedBox(height: 10),

            // UPI Option
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: RadioListTile<String>(
                title: const Text("UPI",
                    style: TextStyle(fontWeight: FontWeight.w600)),
                value: 'upi',
                groupValue: selectedOption,
                activeColor: primaryColor,
                onChanged: (val) => setState(() => selectedOption = val!),
              ),
            ),

            const SizedBox(height: 20),

            if (selectedOption == 'cash') ...[
              TextField(
                controller: cashController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Enter cash amount collected",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                ),
              ),
            ] else if (selectedOption == 'upi') ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text("Click UPI Payment Screenshot",),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  elevation: 6,
                  shadowColor: Colors.yellow.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                onPressed: _pickImageFromCamera,
              ),
              if (upiScreenshot != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(upiScreenshot!, height: 220),
                  ),
                ),
            ],

            const Spacer(),

            Container(
              decoration: BoxDecoration(
                boxShadow: buttonShadow,
                borderRadius: BorderRadius.circular(18),
              ),
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  elevation: 10,
                  shadowColor: Colors.yellow.shade600,
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: const Center(
                  child: Text("Submit Payment",
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CompletedScreen extends StatefulWidget {
  const CompletedScreen({Key? key}) : super(key: key);

  @override
  State<CompletedScreen> createState() => _CompletedScreenState();
}

class _CompletedScreenState extends State<CompletedScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _scaleAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
          parent: _controller,
          curve: Curves.elasticOut,
        ));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);

    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.yellow.shade600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 120, color: primaryColor),
                const SizedBox(height: 24),
                Text(
                  "Completed",
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Thank you!",
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
