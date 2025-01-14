class UserModel {
  final String id;
  final String email;
  final String fullName;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
  });

  // Factory method to create a UserModel from Supabase data
  factory UserModel.fromSupabase(Map<String, dynamic> data) {
    return UserModel(
      id: data['id'],
      email: data['email'],
      fullName: data['full_name'] ?? 'No name provided',
    );
  }
}
