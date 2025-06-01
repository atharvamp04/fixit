import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:uuid/uuid.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _dobController = TextEditingController();
  final _socialLinksController = TextEditingController();
  final _genderController = TextEditingController(text: "Male");

  final SupabaseClient supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool _isImageUploading = false;
  String profilePhotoUrl = "";
  File? _pickedImageFile;

  Locale _selectedLocale = const Locale('en');

  final List<Map<String, dynamic>> _languageOptions = [
    {'locale': const Locale('en'), 'label': 'English'},
    {'locale': const Locale('hi'), 'label': 'हिंदी'},
    {'locale': const Locale('mr'), 'label': 'मराठी'},
    {'locale': const Locale('ta'), 'label': 'தமிழ்'},
    {'locale': const Locale('bn'), 'label': 'বাংলা'},
    {'locale': const Locale('pa'), 'label': 'ਪੰਜਾਬੀ'},
    {'locale': const Locale('es'), 'label': 'Español'},
    {'locale': const Locale('fr'), 'label': 'Français'},
    {'locale': const Locale('de'), 'label': 'Deutsch'},
    {'locale': const Locale('it'), 'label': 'Italiano'},
    {'locale': const Locale('ar'), 'label': 'العربية'},
    {'locale': const Locale('ja'), 'label': '日本語'},
    {'locale': const Locale('ru'), 'label': 'Русский'},
    {'locale': const Locale('zh'), 'label': '中文'},
  ];


  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectedLocale = context.locale;
  }

  Future<void> _fetchProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final response = await supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) return;

    setState(() {
      _fullNameController.text = response['full_name'] ?? "";
      _mobileController.text = response['mobile_number'] ?? "";
      _emailController.text = response['email'] ?? "";
      _dobController.text = response['date_of_birth'] ?? "";
      _socialLinksController.text = response['social_links'] ?? "";
      _genderController.text = response['gender'] ?? "Male";
      profilePhotoUrl = response['profile_photo'] ?? "";
    });
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final user = supabase.auth.currentUser;
    if (user == null) return;

    if (_pickedImageFile != null) {
      await _uploadImageToSupabase(_pickedImageFile!);
    }

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
      await supabase.from('profiles').update(updates).eq('id', user.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('profile_updated'))),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('update_error', args: [e.toString()]))),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() {
      _pickedImageFile = File(pickedFile.path);
    });
  }

  Future<void> _uploadImageToSupabase(File imageFile) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      setState(() => _isImageUploading = true);

      final imageBytes = await imageFile.readAsBytes();
      final imageName = const Uuid().v4();
      final storagePath = 'profile_images/$imageName.jpg';

      await supabase.storage.from('avatars').uploadBinary(
        storagePath,
        imageBytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );

      final publicUrl = supabase.storage.from('avatars').getPublicUrl(storagePath);
      setState(() => profilePhotoUrl = publicUrl);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('image_upload_failed', args: [e.toString()]))),
      );
    } finally {
      setState(() => _isImageUploading = false);
    }
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _changeLanguage(Locale locale) {
    setState(() => _selectedLocale = locale);
    context.setLocale(locale);
  }

  void _showLanguageSelectionCard() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr("select_language")),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SizedBox(
          height: 300,  // Increase height to allow more vertical space
          width: double.maxFinite,
          child: ListView.separated(
            scrollDirection: Axis.vertical,  // Change to vertical scroll
            separatorBuilder: (_, __) => const SizedBox(height: 10),  // Adjust separator height for vertical scrolling
            itemCount: _languageOptions.length,
            itemBuilder: (_, index) {
              final lang = _languageOptions[index];
              final isSelected = _selectedLocale == lang['locale'];

              return GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  _changeLanguage(lang['locale']);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.yellow[600] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      lang['label'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.black,
                        fontSize: isSelected ? 18 : 16,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('profile'), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
        backgroundColor: Colors.yellow[600],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.language, color: Colors.white),
            onPressed: _showLanguageSelectionCard,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: _pickedImageFile != null
                        ? FileImage(_pickedImageFile!)
                        : (profilePhotoUrl.isNotEmpty
                        ? NetworkImage(profilePhotoUrl)
                        : const AssetImage('assets/default_profile.png') as ImageProvider),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.camera_alt, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildTextField(_fullNameController, tr('full_name'), Icons.person),
                  const SizedBox(height: 10),
                  _buildTextField(_emailController, tr('email'), Icons.email, readOnly: true),
                  const SizedBox(height: 10),
                  _buildTextField(_mobileController, tr('mobile_number'), Icons.phone),
                  const SizedBox(height: 10),
                  _buildTextField(_dobController, tr('dob'), Icons.calendar_today),
                  const SizedBox(height: 10),
                  _buildTextField(_genderController, tr('gender'), Icons.person_outline),
                  const SizedBox(height: 10),
                  _buildTextField(_socialLinksController, tr('social_links'), Icons.link),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updateProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.yellow[600],
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(tr('update_profile'), style: const TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
                    ),
                    child: Text(tr('logout'), style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String label,
      IconData icon, {
        bool readOnly = false,
      }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        hintText: "${tr('enter')} $label",
        prefixIcon: Icon(icon, color: Colors.yellow[600]),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFEFE516)),
        ),
      ),
      validator: (value) {
        if (!readOnly && (value == null || value.isEmpty)) {
          return "${tr('please_enter')} $label";
        }
        return null;
      },
    );
  }
}
