// lib/screens/edit_profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../data/states_by_country.dart';
import '../widgets/header_widgets.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;
  final String appId;

  const EditProfileScreen({
    super.key,
    required this.user,
    required this.appId,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _cityController;
  String? _selectedCountry;
  String? _selectedState;
  bool _isSaving = false;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  List<String> _allowedCountries = [];
  List<String> get states => statesByCountry[_selectedCountry] ?? [];

  @override
  void initState() {
    super.initState();
    _firstNameController =
        TextEditingController(text: widget.user.firstName ?? '');
    _lastNameController =
        TextEditingController(text: widget.user.lastName ?? '');
    _cityController = TextEditingController(text: widget.user.city ?? '');
    _selectedCountry = widget.user.country;
    _selectedState = widget.user.state;
    _loadAdminSettings();
  }

  Future<void> _loadAdminSettings() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return;

    // This logic correctly determines which admin settings to fetch.
    String? adminUidToFetchSettings;
    if (widget.user.role == 'admin') {
      adminUidToFetchSettings = widget.user.uid;
    } else if (widget.user.uplineAdmin != null &&
        widget.user.uplineAdmin!.isNotEmpty) {
      adminUidToFetchSettings = widget.user.uplineAdmin;
    }

    if (adminUidToFetchSettings != null) {
      try {
        final adminSettingsDoc = await FirebaseFirestore.instance
            .collection('admin_settings')
            .doc(adminUidToFetchSettings)
            .get();
        if (mounted && adminSettingsDoc.exists) {
          final data = adminSettingsDoc.data();
          if (data != null && data['countries'] is List) {
            setState(() {
              _allowedCountries = List<String>.from(data['countries']);
            });
          }
        }
      } catch (e) {
        debugPrint("Error fetching admin countries: $e");
      }
    }
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take a Photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera)),
            ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery)),
          ],
        ),
      ),
    );

    if (source != null) {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() => _imageFile = File(pickedFile.path));
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_imageFile == null &&
        (widget.user.photoUrl == null || widget.user.photoUrl!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please upload a profile picture to continue.')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? newPhotoUrl;
      if (_imageFile != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_photos/${widget.user.uid}/profile.jpg');
        await storageRef.putFile(_imageFile!);
        newPhotoUrl = await storageRef.getDownloadURL();
      }

      final updates = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'city': _cityController.text.trim(),
        'country': _selectedCountry,
        'state': _selectedState,
        'photoUrl': newPhotoUrl ?? widget.user.photoUrl,
      };

      await FirestoreService().updateUser(widget.user.uid, updates);

      // We don't need to manually update session. The stream will do it.
      if (!mounted) return;
      Navigator.of(context).pop(); // Go back to the previous screen
    } catch (e) {
      debugPrint('❌ Failed to update profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeaderWithMenu(appId: widget.appId),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : (widget.user.photoUrl != null &&
                                      widget.user.photoUrl!.isNotEmpty
                                  ? NetworkImage(widget.user.photoUrl!)
                                  : const AssetImage(
                                      'assets/images/default_avatar.png'))
                              as ImageProvider,
                    ),
                    Container(
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: Colors.black54),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'First Name'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'City'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCountry,
                hint: const Text('Select Country'),
                decoration: const InputDecoration(labelText: 'Country'),
                items: _allowedCountries
                    .map((country) =>
                        DropdownMenuItem(value: country, child: Text(country)))
                    .toList(),
                onChanged: (value) => setState(() {
                  _selectedCountry = value;
                  _selectedState = null;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedState,
                decoration: const InputDecoration(labelText: 'State/Province'),
                items: states
                    .map((state) =>
                        DropdownMenuItem(value: state, child: Text(state)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedState = value),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
