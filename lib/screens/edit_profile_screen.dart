// lib/screens/edit_profile_screen.dart
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/session_manager.dart';
import '../data/states_by_country.dart';
import '../widgets/header_widgets.dart'; // AppHeaderWithMenu is here
import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Needed to get current user UID

class EditProfileScreen extends StatefulWidget {
  final UserModel user;
  final Map<String, dynamic> firebaseConfig;
  final String? initialAuthToken;
  final String appId;

  const EditProfileScreen({
    super.key,
    required this.user,
    required this.firebaseConfig,
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

  List<String> _allowedCountries = []; // Holds countries allowed by admin

  List<String> get states => statesByCountry[_selectedCountry] ?? [];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final user = widget.user; // This is the user whose profile is being edited
    _firstNameController.text = user.firstName ?? '';
    _lastNameController.text = user.lastName ?? '';
    _cityController.text = user.city ?? '';
    _selectedCountry = user.country;
    _selectedState = user.state;

    // --- NEW LOGIC: Fetch allowed countries based on current user's upline_admin ---
    final currentUserFirebase = FirebaseAuth.instance.currentUser;
    if (currentUserFirebase == null) {
      debugPrint(
          'EditProfileScreen: No authenticated user. Cannot load dynamic allowed countries.');
      if (mounted) {
        setState(() => _allowedCountries =
            statesByCountry.keys.toList().cast<String>()); // Fallback
      }
      return;
    }

    try {
      // Get the full UserModel for the authenticated user to find their uplineAdmin
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserFirebase.uid)
          .get();
      if (!mounted) return;

      if (!currentUserDoc.exists) {
        debugPrint(
            'EditProfileScreen: Current authenticated user document not found. Falling back to all countries.');
        if (mounted) {
          setState(() => _allowedCountries =
              statesByCountry.keys.toList().cast<String>()); // Fallback
        }
        return;
      }

      final currentUserModel = UserModel.fromFirestore(currentUserDoc);
      String? adminUidToFetchSettings;

      // Determine which admin's settings to use
      if (currentUserModel.role == 'admin') {
        adminUidToFetchSettings = currentUserModel
            .uid; // If current user is admin, use their own UID for settings
      } else if (currentUserModel.uplineAdmin != null &&
          currentUserModel.uplineAdmin!.isNotEmpty) {
        adminUidToFetchSettings =
            currentUserModel.uplineAdmin; // Use their assigned upline_admin
      } else {
        debugPrint(
            'EditProfileScreen: User is not admin and has no upline_admin. Falling back to all countries.');
        if (mounted) {
          setState(() => _allowedCountries =
              statesByCountry.keys.toList().cast<String>()); // Fallback
        }
        return;
      }

      // Fetch the admin settings document
      DocumentSnapshot<Map<String, dynamic>>? adminSettingsDoc;
      if (adminUidToFetchSettings != null &&
          adminUidToFetchSettings.isNotEmpty) {
        adminSettingsDoc = await FirebaseFirestore.instance
            .collection('admin_settings')
            .doc(adminUidToFetchSettings)
            .get();
      }

      if (!mounted) return; // Guard against setState after async gap

      if (adminSettingsDoc != null && adminSettingsDoc.exists) {
        final data = adminSettingsDoc.data();
        if (data != null && data['countries'] is List) {
          setState(() {
            _allowedCountries = List<String>.from(data['countries']);
            debugPrint(
                'Allowed countries loaded from admin settings ($adminUidToFetchSettings): $_allowedCountries');
          });
        } else {
          debugPrint(
              'Admin settings document ($adminUidToFetchSettings) exists but "countries" field is missing or not a List. Falling back to all countries.');
          if (mounted) {
            setState(() => _allowedCountries = statesByCountry.keys
                .toList()
                .cast<String>()); // Fallback to all countries
          }
        }
      } else {
        debugPrint(
            'Admin settings document for $adminUidToFetchSettings not found. Falling back to all countries.');
        if (mounted) {
          setState(() => _allowedCountries = statesByCountry.keys
              .toList()
              .cast<String>()); // Fallback to all countries
        }
      }
    } catch (e) {
      debugPrint(
          'EditProfileScreen: Error fetching admin allowed countries: $e');
      if (!mounted) return;
      setState(() => _allowedCountries = statesByCountry.keys
          .toList()
          .cast<String>()); // Fallback to all countries on error
    }

    // Retain this setState to ensure the dropdowns re-render with selected values and loaded countries
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final updates = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'city': _cityController.text.trim(),
        'country': _selectedCountry,
        'state': _selectedState,
      };

      await FirestoreService().updateUser(widget.user.uid, updates);
      if (!mounted) return;

      final updatedUser = widget.user.copyWith(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        city: _cityController.text.trim(),
        country: _selectedCountry,
        state: _selectedState,
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
        firebaseConfig: widget.firebaseConfig,
        initialAuthToken: widget.initialAuthToken,
        appId: widget.appId,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
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
