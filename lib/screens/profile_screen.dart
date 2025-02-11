import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Basic Profile Fields
  String fullName = "";
  String mobileNumber = "";
  String email = "";
  String dateOfBirth = "";
  String profilePhotoUrl = "";

  // Additional Field: Social Links
  String socialLinks = "";

  // Controllers for text fields are initialized immediately.
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _socialLinksController = TextEditingController();

  // Instead of a dropdown for gender, use a text field.
  final TextEditingController _genderController =
  TextEditingController(text: "Male");

  // For image picking.
  final ImagePicker _picker = ImagePicker();

  // Supabase client instance.
  final SupabaseClient supabase = Supabase.instance.client;

  // Loading state variables.
  bool _isLoading = false;
  bool _isImageUploading = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _socialLinksController.dispose();
    _genderController.dispose();
    super.dispose();
  }

  /// Fetch profile data from Supabase and update the UI.
  Future<void> _fetchProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final response = await supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) {
      print("No profile data found for user ${user.id}");
      return;
    }

    setState(() {
      fullName = response['full_name'] ?? "";
      mobileNumber = response['mobile_number'] ?? "";
      email = response['email'] ?? "";
      dateOfBirth = response['date_of_birth'] ?? "";
      profilePhotoUrl = response['profile_photo'] ?? "";

      // Use fetched gender or default to "Male".
      String fetchedGender = response['gender'] ?? "";
      if (fetchedGender.trim().isEmpty) {
        _genderController.text = "Male";
      } else {
        _genderController.text = fetchedGender;
      }

      socialLinks = response['social_links'] ?? "";

      _fullNameController.text = fullName;
      _mobileController.text = mobileNumber;
      _emailController.text = email;
      _dobController.text = dateOfBirth;
      _socialLinksController.text = socialLinks;
    });
  }

  /// Update profile data in Supabase.
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final user = supabase.auth.currentUser;
    if (user == null) return;

    final updates = {
      'full_name': _fullNameController.text,
      'mobile_number': _mobileController.text,
      'email': _emailController.text,
      'date_of_birth': _dobController.text,
      'profile_photo': profilePhotoUrl,
      'gender': _genderController.text,
      'social_links': _socialLinksController.text,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      // Chain .select() so that Supabase returns the updated rows.
      final response = await supabase
          .from('profiles')
          .update(updates)
          .eq('id', user.id)
          .select();

      if (response != null && response is List && response.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        _fetchProfile();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error updating profile: No data returned.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  /// Use image_picker to pick an image and upload it to Supabase Storage.
  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() {
        _isImageUploading = true;
      });

      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final String filePath = 'profile_photos/$fileName';

      // Upload the file to Supabase Storage.
      try {
        final storageResponse = await supabase.storage
            .from('profile-photos')
            .upload(filePath, File(image.path));
        print("File uploaded successfully: $storageResponse");
      } catch (error) {
        throw Exception("Upload failed: $error");
      }

      // Get the public URL of the uploaded image.
      final publicUrl =
      supabase.storage.from('profile-photos').getPublicUrl(filePath);
      setState(() {
        profilePhotoUrl = publicUrl;
        _isImageUploading = false;
      });
    } catch (e) {
      setState(() {
        _isImageUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile photo with an edit icon.
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: profilePhotoUrl.isNotEmpty
                          ? NetworkImage(profilePhotoUrl)
                          : const AssetImage('assets/default_profile.png')
                      as ImageProvider,
                      onBackgroundImageError: (_, __) {
                        // If the network image fails, reset to asset image.
                        setState(() {
                          profilePhotoUrl = "";
                        });
                      },
                    ),
                    Positioned(
                      bottom: 0,
                      right: 4,
                      child: InkWell(
                        onTap: _pickProfileImage,
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.blue,
                          child: _isImageUploading
                              ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          )
                              : const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Full Name field.
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: "Full Name",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? "Please enter your full name"
                    : null,
              ),
              const SizedBox(height: 16),
              // Mobile Number field.
              TextFormField(
                controller: _mobileController,
                decoration: const InputDecoration(
                  labelText: "Mobile Number",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) => value == null || value.isEmpty
                    ? "Please enter your mobile number"
                    : null,
              ),
              const SizedBox(height: 16),
              // Email field.
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter your email";
                  }
                  if (!value.contains('@')) {
                    return "Enter a valid email";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Date of Birth field with date picker.
              GestureDetector(
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.tryParse(_dobController.text) ??
                        DateTime(1990),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      _dobController.text =
                      pickedDate.toIso8601String().split('T')[0];
                    });
                  }
                },
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _dobController,
                    decoration: const InputDecoration(
                      labelText: "Date of Birth",
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Gender field as a text field instead of a dropdown.
              TextFormField(
                controller: _genderController,
                decoration: const InputDecoration(
                  labelText: "Gender",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? "Please enter your gender"
                    : null,
              ),
              const SizedBox(height: 16),
              // Social Links field.
              TextFormField(
                controller: _socialLinksController,
                decoration: const InputDecoration(
                  labelText: "Social Links (Optional)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 24),
              // Update Profile Button.
              ElevatedButton(
                onPressed: _updateProfile,
                child: const Text("Update Profile"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
