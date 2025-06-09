// lib/screens/edit_profile_screen.dart
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/session_manager.dart';
import '../data/states_by_country.dart';
import '../widgets/header_widgets.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;
  const EditProfileScreen({super.key, required this.user});

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

    // Fetch current user details to determine if they are a downline or admin
    final currentUser = await SessionManager().getCurrentUser();

    if (currentUser != null) {
      if (currentUser.role == 'admin') {
        // If current user is an admin, they can see all countries
        _allowedCountries = statesByCountry.keys.toList().cast<String>();
      } else if (currentUser.referredBy != null && currentUser.referredBy!.isNotEmpty) {
        // If it's a downline user, find their sponsor (upline admin)
        final sponsor = await FirestoreService().getUserByReferralCode(currentUser.referredBy!);
        if (sponsor != null && sponsor.role == 'admin') {
          // If sponsor is an admin, fetch their allowed countries
          _allowedCountries = await FirestoreService().getAdminAllowedCountries(sponsor.uid);
          // If admin has not set any countries, assume all are allowed
          if (_allowedCountries.isEmpty) {
            _allowedCountries = statesByCountry.keys.toList().cast<String>();
          }
        } else {
          // If no admin sponsor or sponsor is not an admin, allow all countries (default behavior)
          _allowedCountries = statesByCountry.keys.toList().cast<String>();
        }
      } else {
        // If no referrer or not an admin, allow all countries
        _allowedCountries = statesByCountry.keys.toList().cast<String>();
      }
    } else {
      // If current user somehow not found, fallback to all countries
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
      appBar: const AppHeaderWithMenu(),
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
              // Use _allowedCountries to populate the dropdown
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
                // Disable state dropdown if no country is selected
                // or if the selected country has no states
                // or if the selected country is not in the allowed countries for which states are defined
                // (e.g. if _selectedCountry is 'Canada' but statesByCountry['Canada'] is null or empty)
                // This logic correctly reflects the `states` getter.
                // Re-enabling for general usage, as the current implementation handles empty states list gracefully.
                // The issue was showing all countries; now restricted via _allowedCountries
                // The states dropdown should still show only states for the selected *allowed* country.
                // No additional logic needed here, as `states` getter handles it.
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