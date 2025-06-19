// lib/screens/edit_profile_screen.dart

import 'package:flutter/material.dart';
//import 'package:flutter/foundation.dart'; // MODIFIED: Added for debugPrint
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../widgets/header_widgets.dart';
import '../data/states_by_country.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;
  final String appId;

  const EditProfileScreen({
    super.key,
    required this.user,
    required this.appId,
  });

  @override
  EditProfileScreenState createState() => EditProfileScreenState();
}

class EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _cityController;

  String? _selectedCountry;
  String? _selectedState;

  bool _isLoading = false;

  List<String> get statesForSelectedCountry =>
      statesByCountry[_selectedCountry] ?? [];

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.user.firstName);
    _lastNameController = TextEditingController(text: widget.user.lastName);
    _cityController = TextEditingController(text: widget.user.city);

    _selectedCountry = widget.user.country;
    _selectedState = widget.user.state;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    final updatedData = {
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'city': _cityController.text.trim(),
      'country': _selectedCountry,
      'state': _selectedState,
    };

    // MODIFIED: Added logging to diagnose the issue.
    debugPrint("Attempting to save data for user ${widget.user.uid}");
    debugPrint("Data to save: $updatedData");

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await _firestoreService.updateUser(widget.user.uid, updatedData);
      debugPrint("Firestore update call completed successfully.");

      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green),
      );
      navigator.pop();
    } catch (e) {
      debugPrint("Firestore update FAILED with error: $e");
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeaderWithMenu(appId: widget.appId),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit Profile',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'First Name'),
                validator: (value) =>
                    value!.isEmpty ? 'First name cannot be empty' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name'),
                validator: (value) =>
                    value!.isEmpty ? 'Last name cannot be empty' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCountry,
                hint: const Text('Select Country'),
                isExpanded: true,
                items: statesByCountry.keys
                    .map((country) =>
                        DropdownMenuItem(value: country, child: Text(country)))
                    .toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedCountry = newValue;
                    _selectedState = null;
                  });
                },
                decoration: const InputDecoration(labelText: 'Country'),
                validator: (value) =>
                    value == null ? 'Please select a country' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedState,
                hint: const Text('Select State/Province'),
                isExpanded: true,
                disabledHint: _selectedCountry == null
                    ? const Text('Select a country first')
                    : null,
                items: statesForSelectedCountry
                    .map((state) =>
                        DropdownMenuItem(value: state, child: Text(state)))
                    .toList(),
                onChanged: _selectedCountry == null
                    ? null
                    : (newValue) {
                        setState(() {
                          _selectedState = newValue;
                        });
                      },
                decoration: const InputDecoration(labelText: 'State/Province'),
                validator: (value) =>
                    value == null ? 'Please select a state/province' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'City'),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ))
                    : const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
