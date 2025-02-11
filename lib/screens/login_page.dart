import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixit/services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controllers for email and password input fields.
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Focus nodes for custom styling when focused.
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _rememberMe = false;
  bool _isLoading = false;

  // Auth service instance.
  final AuthService _authService = AuthService(Supabase.instance.client);

  /// Sign in with email and password.
  Future<void> signIn() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _authService.signInWithEmailPassword(email, password);
      if (user != null) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // If user does not exist, notify and navigate to the signup page.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User does not exist, please sign up')),
        );
        Navigator.pushReplacementNamed(context, '/signup');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Sign in with Google.
  Future<void> googleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    // Replace with your own Web and iOS client IDs.
    const String webClientId =
        '420646018313-4iql2ugkb2s080g1cgbansvugmqnql1k.apps.googleusercontent.com';
    const String iosClientId =
        '420646018313-onbp2q23jm6f7j26ipp2nl1sgeassoki.apps.googleusercontent.com';

    final GoogleSignIn googleSignIn = GoogleSignIn(
      clientId: iosClientId,
      serverClientId: webClientId,
    );

    try {
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw 'Google Sign-In canceled.';
      }

      final googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      if (idToken == null || accessToken == null) {
        throw 'Failed to retrieve Google tokens.';
      }

      // Sign in with Google using Supabase.
      final response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.session == null) {
        throw 'Google Sign-In failed.';
      }

      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-In error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 120),
            const Text(
              'Welcome back 👋',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'Please enter your email and password to log in.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            // Email input field.
            TextField(
              controller: _emailController,
              focusNode: _emailFocusNode,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'Enter your email',
                suffixIcon: Icon(
                  Icons.email,
                  color: _emailFocusNode.hasFocus
                      ? const Color(0xFF17CE92)
                      : Colors.grey,
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF17CE92)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Password input field.
            TextField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                suffixIcon: Icon(
                  Icons.lock,
                  color: _passwordFocusNode.hasFocus
                      ? const Color(0xFF17CE92)
                      : Colors.grey,
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF17CE92)),
                ),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 10),
            // "Remember me" checkbox.
            Row(
              children: [
                Checkbox(
                  value: _rememberMe,
                  onChanged: (value) {
                    setState(() {
                      _rememberMe = value!;
                    });
                  },
                ),
                const Text('Remember me'),
              ],
            ),
            const SizedBox(height: 20),
            // Login button.
            Center(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF17CE92),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Login',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Google sign-in button.
            Center(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : googleSignIn,
                icon: const Icon(Icons.login, color: Colors.white),
                label: const Text('Sign in with Google',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Navigation to the sign-up page.
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/signup');
                },
                child: const Text(
                  'Don’t have an account? Sign up here.',
                  style: TextStyle(
                    color: Color(0xFF17CE92),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
