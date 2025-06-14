// lib/screens/edit_profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/session_manager.dart';
import '../data/states_by_country.dart';
import '../widgets/header_widgets.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;
  // final Map<String, dynamic> firebaseConfig;
  final String? initialAuthToken;
  final String appId;

  const EditProfileScreen({
    super.key,
    required this.user,
    // required this.firebaseConfig,
    this.initialAuthToken,
    required this.appId,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  String? _selectedCountry;
  String? _selectedState;
  bool _isSaving = false;

  // --- NEW: State for image handling ---
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  List<String> _allowedCountries = [];

  List<String> get states => statesByCountry[_selectedCountry] ?? [];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final user = widget.user;
    _firstNameController.text = user.firstName ?? '';
    _lastNameController.text = user.lastName ?? '';
    _cityController.text = user.city ?? '';
    _selectedCountry = user.country;
    _selectedState = user.state;

    final currentUserFirebase = FirebaseAuth.instance.currentUser;
    if (currentUserFirebase == null) {
      if (mounted) {
        setState(() =>
            _allowedCountries = statesByCountry.keys.toList().cast<String>());
      }
      return;
    }

    try {
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserFirebase.uid)
          .get();
      if (!mounted) return;

      if (!currentUserDoc.exists) {
        if (mounted) {
          setState(() =>
              _allowedCountries = statesByCountry.keys.toList().cast<String>());
        }
        return;
      }

      final currentUserModel = UserModel.fromFirestore(currentUserDoc);
      String? adminUidToFetchSettings;

      if (currentUserModel.role == 'admin') {
        adminUidToFetchSettings = currentUserModel.uid;
      } else if (currentUserModel.uplineAdmin != null &&
          currentUserModel.uplineAdmin!.isNotEmpty) {
        adminUidToFetchSettings = currentUserModel.uplineAdmin;
      } else {
        if (mounted) {
          setState(() =>
              _allowedCountries = statesByCountry.keys.toList().cast<String>());
        }
        return;
      }

      DocumentSnapshot<Map<String, dynamic>>? adminSettingsDoc;
      if (adminUidToFetchSettings != null &&
          adminUidToFetchSettings.isNotEmpty) {
        adminSettingsDoc = await FirebaseFirestore.instance
            .collection('admin_settings')
            .doc(adminUidToFetchSettings)
            .get();
      }

      if (!mounted) return;

      if (adminSettingsDoc != null && adminSettingsDoc.exists) {
        final data = adminSettingsDoc.data();
        if (data != null && data['countries'] is List) {
          setState(() {
            _allowedCountries = List<String>.from(data['countries']);
          });
        } else {
          if (mounted) {
            setState(() => _allowedCountries =
                statesByCountry.keys.toList().cast<String>());
          }
        }
      } else {
        if (mounted) {
          setState(() =>
              _allowedCountries = statesByCountry.keys.toList().cast<String>());
        }
      }
    } catch (e) {
      debugPrint(
          'EditProfileScreen: Error fetching admin allowed countries: $e');
      if (!mounted) return;
      setState(() =>
          _allowedCountries = statesByCountry.keys.toList().cast<String>());
    }

    if (!mounted) return;
    setState(() {});
  }

  // --- NEW: Function to pick an image, adapted from profile_screen.dart ---
  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    // --- NEW: Require profile picture before form validation ---
    if (_imageFile == null &&
        (widget.user.photoUrl == null || widget.user.photoUrl!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please upload a profile picture to continue.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      String? newPhotoUrl;
      // --- NEW: Upload image if a new one was selected ---
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
        // --- NEW: Add photoUrl to the updates map ---
        'photoUrl': newPhotoUrl ?? widget.user.photoUrl,
      };

      await FirestoreService().updateUser(widget.user.uid, updates);
      if (!mounted) return;

      final updatedUser = widget.user.copyWith(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        city: _cityController.text.trim(),
        country: _selectedCountry,
        state: _selectedState,
        // --- NEW: Update user model with new photoUrl ---
        photoUrl: newPhotoUrl ?? widget.user.photoUrl,
      );

      await SessionManager().setCurrentUser(updatedUser);
      if (!mounted) return;
      Navigator.of(context).pop(updatedUser);
    } catch (e) {
      debugPrint('❌ Failed to update profile: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeaderWithMenu(
        // firebaseConfig: widget.firebaseConfig,
        initialAuthToken: widget.initialAuthToken,
        appId: widget.appId,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // --- NEW: Profile picture UI, adapted from profile_screen.dart ---
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
                        shape: BoxShape.circle,
                        color: Colors.black54,
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // --- End of new UI ---

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
