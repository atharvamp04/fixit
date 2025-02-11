import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabaseClient;

  AuthService(this._supabaseClient);

  // Sign in with email and password
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      final AuthResponse response = await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        print('Sign-in failed: No user returned');
        return null;
      }

      return response.user;
    } catch (e) {
      print('Error signing in: $e');
      return null;
    }
  }

  // Sign up with email and password, and create a user profile
  Future<User?> signUpWithEmailPassword(
      String email,
      String password,
      String fullName,
      String mobileNumber,
      String gender,
      ) async {
    try {
      final AuthResponse response = await _supabaseClient.auth.signUp(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        print('Signup failed: No user returned');
        return null;
      }

      // Create the user profile in the profiles table by chaining .select()
      final data = await _supabaseClient.from('profiles').upsert({
        'id': user.id,
        'full_name': fullName,
        'email': email,
        'mobile_number': mobileNumber,
        'gender': gender,
      }).select();

      if (data is! List) {
        throw Exception('Profile creation failed: $data');
      }

      return user;
    } catch (e) {
      print('Error during signup or profile creation: $e');

      // Optionally, sign out the user if profile creation fails
      await _supabaseClient.auth.signOut();
      return null;
    }
  }

  // Log out the user
  Future<void> signOut() async {
    try {
      await _supabaseClient.auth.signOut();
      print('User signed out successfully');
    } catch (e) {
      print("Error signing out: $e");
    }
  }

  // Get current user
  User? getCurrentUser() {
    return _supabaseClient.auth.currentUser;
  }
}
