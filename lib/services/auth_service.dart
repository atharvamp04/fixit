import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabaseClient;

  AuthService(this._supabaseClient);

  // Sign in with email and password
  Future<User?> signInWithEmailPassword(String email, String password) async {
    final response = await _supabaseClient.auth.signInWithPassword(
      email: email,
      password: password,
    );


    return response.user;
  }

  // Sign up with email and password
  Future<User?> signUpWithEmailPassword(String email, String password) async {
    final response = await _supabaseClient.auth.signUp(
      email: email,
      password: password,
    );


    return response.user;
  }

  // Log out the user
  Future<void> signOut() async {
    await _supabaseClient.auth.signOut();
  }

  // Get current user
  User? getCurrentUser() {
    return _supabaseClient.auth.currentUser;
  }

}
