import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixit/services/auth_service.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({Key? key}) : super(key: key);

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _mobileNumberController = TextEditingController();
  final _genderController = TextEditingController();

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _fullNameFocus = FocusNode();
  final FocusNode _mobileNumberFocus = FocusNode();
  final FocusNode _genderFocus = FocusNode();

  bool _isLoading = false;
  final AuthService _authService = AuthService(Supabase.instance.client);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _mobileNumberController.dispose();
    _genderController.dispose();

    _emailFocus.dispose();
    _passwordFocus.dispose();
    _fullNameFocus.dispose();
    _mobileNumberFocus.dispose();
    _genderFocus.dispose();

    super.dispose();
  }

  Future<void> signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final fullName = _fullNameController.text.trim();
    final mobileNumber = _mobileNumberController.text.trim();
    final gender = _genderController.text.trim();

    if (email.isEmpty ||
        password.isEmpty ||
        fullName.isEmpty ||
        mobileNumber.isEmpty ||
        gender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await _authService.signUpWithEmailPassword(
        email, password, fullName, mobileNumber, gender,
      );

      if (user != null) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signup failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during signup: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> googleSignIn() async {
    // Implement Google Sign-In logic here
    print("Google Sign-In clicked");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 100),
              const Text(
                'Create Account 🎉',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              const Text(
                'Fill in the details below to sign up.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              _buildTextField(_emailController, 'Email', Icons.email, _emailFocus),
              const SizedBox(height: 10),
              _buildTextField(_passwordController, 'Password', Icons.lock, _passwordFocus, obscureText: true),
              const SizedBox(height: 10),
              _buildTextField(_fullNameController, 'Full Name', Icons.person, _fullNameFocus),
              const SizedBox(height: 10),
              _buildTextField(_mobileNumberController, 'Mobile Number', Icons.phone, _mobileNumberFocus),
              const SizedBox(height: 10),
              _buildTextField(_genderController, 'Gender', Icons.accessibility, _genderFocus),
              const SizedBox(height: 20),
              _buildSignupButton(),
              const SizedBox(height: 20),
              _buildOrSeparator(),
              const SizedBox(height: 20),
              _buildGoogleSignupButton(),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                  child: const Text(
                    'Already have an account? Login',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEFE516), // Yellow color
                    ),
                  ),
                ),
              )

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, FocusNode focusNode, {bool obscureText = false}) {
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() {}); // Updates UI when focus changes
      },
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'Enter your $label',
          suffixIcon: Icon(
            icon,
            color: focusNode.hasFocus ? const Color(0xFFEFE516) : Colors.grey,
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFEFE516)),
          ),
        ),
        obscureText: obscureText,
      ),
    );
  }

  Widget _buildSignupButton() {
    return Center(
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isLoading ? null : signUp,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEFE516),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.0),
            ),
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Sign Up', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildGoogleSignupButton() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30.0),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3), // Lighter shadow
              spreadRadius: 1,  // Reduced spread
              blurRadius: 4,  // Reduced blur
              offset: const Offset(0, 2), // Subtle shadow position
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: googleSignIn,
            icon: Image.asset(
              'assets/Google.png', // Ensure asset exists
              height: 24,
              width: 24,
            ),
            label: const Text(
              'Sign Up with Google',
              style: TextStyle(color: Colors.black),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0),
              ),
              backgroundColor: Colors.white,
              side: BorderSide.none, // Removes black border
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildOrSeparator() {
    return Row(
      children: [
        Expanded(
          child: Divider(thickness: 2, color: Colors.grey.shade400),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'OR',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: Divider(thickness: 2, color: Colors.grey.shade400),
        ),
      ],
    );
  }

}
