import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixit/services/auth_service.dart';
import 'package:easy_localization/easy_localization.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({Key? key}) : super(key: key);

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  // Controllers for input fields.
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _mobileNumberController = TextEditingController();

  // Focus nodes for UI behavior.
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _fullNameFocus = FocusNode();
  final FocusNode _mobileNumberFocus = FocusNode();
  final _confirmPasswordController = TextEditingController(); // ← ADD THIS
  final FocusNode _confirmPasswordFocus = FocusNode();

  String? _selectedGender;
  bool _isLoading = false;
  bool _isPasswordVisible = false;       // ← ADD THIS
  bool _isConfirmPasswordVisible = false;
  final AuthService _authService = AuthService(Supabase.instance.client);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _mobileNumberController.dispose();

    _emailFocus.dispose();
    _passwordFocus.dispose();
    _fullNameFocus.dispose();
    _mobileNumberFocus.dispose();
    // Dispose the new controllers/focus nodes:
    _confirmPasswordController.dispose(); // ← ADD THIS
    _confirmPasswordFocus.dispose();

    super.dispose();
  }

  /// Signs up a new user with email and password.
  /// The new profile is created with approved set to false.
  Future<void> signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final fullName = _fullNameController.text.trim();
    final mobileNumber = _mobileNumberController.text.trim();
    final gender = _selectedGender;  // <-- use the dropdown’s value
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        fullName.isEmpty ||
        mobileNumber.isEmpty ||
        gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await _authService.signUpWithEmailPassword(
        email,
        password,
        fullName,
        mobileNumber,
        gender,
      );

      if (user != null) {
        // Inform the user that their account is pending approval.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your account has been created and is pending admin approval. Please wait for approval before logging in.',
            ),
          ),
        );
        // Sign out the new user if they're automatically logged in.
        await _authService.signOut();
        Navigator.pushReplacementNamed(context, '/login');
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

  /// Signs in using Google.
  /// If a profile already exists:
  ///   - If approved, log the user in.
  ///   - If not approved, sign the user out and show a pending approval message.
  /// If no profile exists, create one with approved = false, then sign out.
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
      if (googleUser == null) return; // User cancelled the sign-in

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        throw 'Access Token or ID Token not found.';
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

      final userId = response.user?.id;
      if (userId == null) throw 'User ID is null after Google Sign-In';

      // Check if the user's profile exists.
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('approved')
          .eq('id', userId)
          .maybeSingle();

      // Use null-aware access to safely handle profileResponse.
      final profileData = profileResponse != null ? profileResponse['approved'] : null;
      if (profileData != null) {
        // Profile exists; check approval status.
        final approved = profileData as bool?;
        if (approved == true) {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          await _authService.signOut();
          throw 'Your account is pending admin approval.';
        }
      } else {
        // No profile exists; create a new profile with approved = false.
        final upsertResponse = await Supabase.instance.client
            .from('profiles')
            .upsert({
          'id': userId,
          'full_name': googleUser.displayName ?? '',
          'email': googleUser.email,
          'mobile_number': '',
          'gender': '',
          'approved': false,
        }).select();

        // upsertResponse is expected to be a List.
        if (upsertResponse == null || upsertResponse is! List || upsertResponse.isEmpty) {
          throw Exception('Profile creation failed: $upsertResponse');
        }

        await _authService.signOut();
        throw 'Your account has been created and is pending admin approval. Please wait for approval before logging in.';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-In error: $e')),
      );
    }
  }

  /// Builds a text field with custom styling.
  Widget _buildTextField(
      TextEditingController controller,
      String label,
      IconData icon,
      FocusNode focusNode, {
        bool obscureText = false,
      }) {
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() {}); // Update UI when focus changes.
      },
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'Enter your $label',
          suffixIcon: Icon(
            icon,
            color: focusNode.hasFocus ? Colors.yellow[600] : Colors.grey,
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFEFE516)),
          ),
        ),
        obscureText: obscureText,
      ),
    );
  }

  /// Builds the signup button.
  Widget _buildSignupButton() {
    return Center(
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isLoading ? null : signUp,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.yellow[600],
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

  /// Builds the Google signup button.
  Widget _buildGoogleSignupButton() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30.0),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _nativeGoogleSignIn,
            icon: Image.asset(
              'assets/Google.png', // Ensure this asset exists.
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
              side: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  /// Builds an "OR" separator.
  Widget _buildOrSeparator() {
    return Row(
      children: [
        Expanded(
          child: Divider(thickness: 2, color: Colors.grey.shade400),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'OR'.tr(),
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: Divider(thickness: 2, color: Colors.grey.shade400),
        ),
      ],
    );
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
              const SizedBox(height: 55),
              Text(
                'create_account'.tr(),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              Text(
                'fill_details'.tr(),
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              _buildTextField(_fullNameController, 'full_name'.tr(), Icons.person, _fullNameFocus),
              const SizedBox(height: 10),
              _buildTextField(_emailController, 'email'.tr(), Icons.email, _emailFocus),
              const SizedBox(height: 10),
              Focus(
                onFocusChange: (hasFocus) => setState(() {}),
                child: TextField(
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  obscureText: !_isPasswordVisible, // ← toggle
                  decoration: InputDecoration(
                    labelText: 'password'.tr(),
                    hintText: 'enter_password'.tr(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        color: _passwordFocus.hasFocus ? Colors.yellow[600] : Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFEFE516)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Focus(
                onFocusChange: (hasFocus) => setState(() {}),
                child: TextField(
                  controller: _confirmPasswordController,   // new controller
                  focusNode: _confirmPasswordFocus,         // new focus node
                  obscureText: !_isConfirmPasswordVisible,   // toggle
                  decoration: InputDecoration(
                    labelText: 'confirm_password'.tr(),      // Add key in your JSON as “confirm_password”
                    hintText: 'reenter_password'.tr(),       // Add key in JSON as “reenter_password”
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        color: _confirmPasswordFocus.hasFocus ?Colors.yellow[600] : Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                        });
                      },
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFEFE516)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _buildTextField(_mobileNumberController, 'mobile_number'.tr(), Icons.phone, _mobileNumberFocus),
              const SizedBox(height: 10),
              Text('gender'.tr(), style: const TextStyle(fontSize: 16)),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: InputDecoration(
                  border: const UnderlineInputBorder(),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFEFE516)),
                  ),
                ),
                items: <String>['Male', 'Female', 'Other']
                    .map((g) => DropdownMenuItem(
                  value: g,
                  child: Text(g.tr()), // if you have translations for "Male"/"Female"/"Other"
                ))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedGender = val;
                  });
                },
                validator: (val) => val == null ? 'please_select_gender'.tr() : null,
              ),
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
                  child: Text(
                    'already_account'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEFE516)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Language switch
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  TextButton(onPressed: () => context.setLocale(const Locale('en')), child: const Text("English")),
                  TextButton(onPressed: () => context.setLocale(const Locale('hi')), child: const Text("हिंदी")),
                  TextButton(onPressed: () => context.setLocale(const Locale('mr')), child: const Text("मराठी")),
                  TextButton(onPressed: () => context.setLocale(const Locale('ta')), child: const Text("தமிழ்")),
                  TextButton(onPressed: () => context.setLocale(const Locale('bn')), child: const Text("বাংলা")),
                  TextButton(onPressed: () => context.setLocale(const Locale('pa')), child: const Text("ਪੰਜਾਬੀ")),
                  TextButton(onPressed: () => context.setLocale(const Locale('es')), child: const Text("Español")),
                  TextButton(onPressed: () => context.setLocale(const Locale('fr')), child: const Text("Français")),
                  TextButton(onPressed: () => context.setLocale(const Locale('de')), child: const Text("Deutsch")),
                  TextButton(onPressed: () => context.setLocale(const Locale('it')), child: const Text("Italiano")),
                  TextButton(onPressed: () => context.setLocale(const Locale('ar')), child: const Text("العربية")),
                  TextButton(onPressed: () => context.setLocale(const Locale('ja')), child: const Text("日本語")),
                  TextButton(onPressed: () => context.setLocale(const Locale('ru')), child: const Text("Русский")),
                  TextButton(onPressed: () => context.setLocale(const Locale('zh')), child: const Text("中文")),
                ],
              ),
        ),
            ],
          ),
        ),
      ),
    );
  }
}