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

  bool _isLoading = false;

  final AuthService _authService = AuthService(Supabase.instance.client);

  // Sign up with Email and Password
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

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _authService.signUpWithEmailPassword(
        email,
        password,
        fullName,
        mobileNumber,
        gender,
      );

      if (user != null) {
        // Navigate to home screen after successful signup
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
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Google Sign-In Functionality
  Future<void> _nativeGoogleSignIn() async {
    const webClientId =
        '420646018313-4iql2ugkb2s080g1cgbansvugmqnql1k.apps.googleusercontent.com';
    const iosClientId =
        '420646018313-onbp2q23jm6f7j26ipp2nl1sgeassoki.apps.googleusercontent.com';

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: iosClientId,
        serverClientId: webClientId,
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        throw 'Access Token or ID Token not found.';
      }

      final response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.session != null) {
        final userId = response.user?.id;
        if (userId == null) throw 'User ID is null after Google Sign-In';

        // Create the profile for Google sign-in users
        final data = await Supabase.instance.client
            .from('profiles')
            .upsert({
          'id': userId,
          'full_name': googleUser.displayName ?? '',
          'email': googleUser.email,
          'mobile_number': '',
          'gender': '',
        })
            .select();

        if (data is! List) {
          throw Exception('Profile creation failed: $data');
        }

        Navigator.pushReplacementNamed(context, '/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Sign-In failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during Google Sign-In: $e')),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _mobileNumberController.dispose();
    _genderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Create an account',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildTextField(_emailController, 'Email', Icons.email),
              const SizedBox(height: 10),
              _buildTextField(
                _passwordController,
                'Password',
                Icons.lock,
                obscureText: true,
              ),
              const SizedBox(height: 10),
              _buildTextField(_fullNameController, 'Full Name', Icons.person),
              const SizedBox(height: 10),
              _buildTextField(
                  _mobileNumberController, 'Mobile Number', Icons.phone),
              const SizedBox(height: 10),
              _buildTextField(_genderController, 'Gender', Icons.accessibility),
              const SizedBox(height: 20),
              _buildSignupButton(),
              const SizedBox(height: 10),
              _buildGoogleSignupButton(),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/login'),
                child: const Text('Already have an account? Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      IconData icon, {bool obscureText = false}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Enter your $label',
        suffixIcon: Icon(icon, color: Colors.grey),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF17CE92)),
        ),
      ),
      obscureText: obscureText,
    );
  }

  Widget _buildSignupButton() {
    return Center(
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isLoading ? null : signUp,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF17CE92),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.0),
            ),
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Sign Up',
              style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildGoogleSignupButton() {
    return Center(
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _nativeGoogleSignIn,
          icon: const Icon(Icons.login),
          label: const Text('Sign Up with Google'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.0),
            ),
          ),
        ),
      ),
    );
  }
}
