// lib/screens/edit_profile_screen.dart
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/session_manager.dart';
import '../data/states_by_country.dart';
import '../widgets/header_widgets.dart'; // AppHeaderWithMenu is here
// import '../main.dart' as main_app; // Removed unused import

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
    final user = widget.user;
    _firstNameController.text = user.firstName ?? '';
    _lastNameController.text = user.lastName ?? '';
    _cityController.text = user.city ?? '';
    _selectedCountry = user.country;
    _selectedState = user.state;

    final currentUser = await SessionManager().getCurrentUser(); // Corrected SessionManager access
    if (!mounted) return;

    if (currentUser != null) {
      if (currentUser.role == 'admin') {
        _allowedCountries = statesByCountry.keys.toList().cast<String>();
      } else if (currentUser.referredBy != null && currentUser.referredBy!.isNotEmpty) {
        final sponsor = await FirestoreService().getUserByReferralCode(currentUser.referredBy!);
        if (!mounted) return;
        if (sponsor != null && sponsor.role == 'admin') {
          _allowedCountries = await FirestoreService().getAdminAllowedCountries(sponsor.uid);
          if (!mounted) return;
          if (_allowedCountries.isEmpty) {
            _allowedCountries = statesByCountry.keys.toList().cast<String>();
          }
        } else {
          _allowedCountries = statesByCountry.keys.toList().cast<String>();
        }
      } else {
        _allowedCountries = statesByCountry.keys.toList().cast<String>();
      }
    } else {
      _allowedCountries = statesByCountry.keys.toList().cast<String>();
    }

    if (!mounted) return;
    setState(() {}); // Rebuild to update dropdown with filtered countries
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

      await SessionManager().setCurrentUser(updatedUser); // Corrected SessionManager access
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
                decoration:
                    const InputDecoration(labelText: 'State/Province'),
                items: states
                    .map((state) =>
                        DropdownMenuItem(value: state, child: Text(state)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedState = value),
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
