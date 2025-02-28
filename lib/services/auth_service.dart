import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabaseClient;

  AuthService(this._supabaseClient);

  // Sign in with email and password.
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      final AuthResponse response = await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        print('Sign-in failed: No user returned');
        return null;
      }

      // Check if the user's profile is approved.
      final approved = await isUserApproved(user.id);
      if (!approved) {
        print('User not approved. Signing out...');
        await _supabaseClient.auth.signOut();
        // Optionally, handle this case in your UI.
        return null;
      }

      return user;
    } catch (e) {
      print('Error signing in: $e');
      return null;
    }
  }

  // Sign up with email and password, and create a user profile with approved = false.
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

      // Create the user profile in the profiles table.
      // New users are not approved by default.
      final result = await _supabaseClient.from('profiles').upsert({
        'id': user.id,
        'full_name': fullName,
        'email': email,
        'mobile_number': mobileNumber,
        'gender': gender,
        'approved': false,
      }).select();

      // The result is returned as a Map or List. We expect a List here.
      if (result is! List) {
        throw Exception('Profile creation failed: $result');
      }

      return user;
    } catch (e) {
      print('Error during signup or profile creation: $e');
      // Optionally, sign out the user if profile creation fails.
      await _supabaseClient.auth.signOut();
      return null;
    }
  }

  // Check whether the user's profile is approved.
  Future<bool> isUserApproved(String userId) async {
    try {
      final response = await _supabaseClient
          .from('profiles')
          .select('approved')
          .eq('id', userId)
          .single();

      // Here, response is a Map<String, dynamic>.
      if (response is Map<String, dynamic>) {
        final approved = response['approved'];
        return approved == true;
      } else {
        print('Unexpected response type in isUserApproved: $response');
        return false;
      }
    } catch (e) {
      print('Error in isUserApproved: $e');
      return false;
    }
  }

  // Log out the user.
  Future<void> signOut() async {
    try {
      await _supabaseClient.auth.signOut();
      print('User signed out successfully');
    } catch (e) {
      print("Error signing out: $e");
    }
  }

  // Get the current user.
  User? getCurrentUser() {
    return _supabaseClient.auth.currentUser;
  }
}
