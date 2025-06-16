import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import '../services/auth_service.dart';
import '../data/states_by_country.dart';

class NewRegistrationScreen extends StatefulWidget {
  final String? referralCode;
  final String appId;

  const NewRegistrationScreen({
    super.key,
    this.referralCode,
    required this.appId,
  });

  @override
  State<NewRegistrationScreen> createState() => _NewRegistrationScreenState();
}

class _NewRegistrationScreenState extends State<NewRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  String? _selectedCountry;
  String? _selectedState;
  String? _sponsorName;
  String? _initialReferralCode;
  bool _isFirstUser = false;
  List<String> _availableCountries = [];
  bool _isLoading = false;
  bool isDevMode = true;

  List<String> get states => statesByCountry[_selectedCountry] ?? [];

  @override
  void initState() {
    super.initState();
    _initialReferralCode = widget.referralCode;
    _initReferral();
  }

  Future<void> _initReferral() async {
    if (isDevMode && _initialReferralCode == null) {
      _initialReferralCode = 'KJ8uFnlhKhWgBa4NVcwT';
    }
    final code = _initialReferralCode;
    if (code == null || code.isEmpty) {
      setState(() {
        _isFirstUser = true;
        _availableCountries = statesByCountry.keys.toList();
      });
      return;
    }
    try {
      final uri = Uri.parse(
          'https://us-central1-teambuilder-plus-fe74d.cloudfunctions.net/getUserByReferralCode?code=$code');
      final response = await http.get(uri);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final sponsorName =
            '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
        setState(() => _sponsorName = sponsorName);
        final uplineAdminUid = data['upline_admin'];
        if (uplineAdminUid != null) {
          final countriesResponse = await http.get(Uri.parse(
              'https://us-central1-teambuilder-plus-fe74d.cloudfunctions.net/getCountriesByAdminUid?uid=$uplineAdminUid'));
          if (!mounted) return;
          if (countriesResponse.statusCode == 200) {
            final countryData = jsonDecode(countriesResponse.body);
            if (countryData['countries'] is List) {
              setState(() => _availableCountries =
                  List<String>.from(countryData['countries']));
            }
          }
        }
      } else {
        setState(() {
          _isFirstUser = true;
          _availableCountries = statesByCountry.keys.toList();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFirstUser = true;
          _availableCountries = statesByCountry.keys.toList();
        });
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    try {
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('registerUser');
      await callable.call(<String, dynamic>{
        'email': email,
        'password': password,
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'country': _selectedCountry,
        'state': _selectedState,
        'city': _cityController.text.trim(),
        'referralCode': _initialReferralCode,
      });
      // After successful registration, log the user in.
      // The StreamBuilder in main.dart will handle navigation.
      await AuthService().login(email, password);
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message ?? 'An unknown error occurred.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('An unexpected error occurred: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_sponsorName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text('Your Sponsor is $_sponsorName',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                )
              else if (_isFirstUser)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12.0),
                  child: Text(
                      'You are creating your own TeamBuild Pro organization.',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(labelText: 'First Name'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(labelText: 'Last Name'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v == null || !v.contains('@')
                      ? 'Enter a valid email'
                      : null),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (v) => v == null || v.length < 6
                      ? 'Password must be at least 6 characters'
                      : null),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _confirmPasswordController,
                  decoration:
                      const InputDecoration(labelText: 'Confirm Password'),
                  obscureText: true,
                  validator: (v) => v != _passwordController.text
                      ? 'Passwords do not match'
                      : null),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCountry,
                hint: const Text('Select Country'),
                items: _availableCountries
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _selectedCountry = v;
                  _selectedState = null;
                }),
                decoration: const InputDecoration(labelText: 'Country'),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedState,
                hint: const Text('Select State/Province'),
                items: states
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedState = v),
                decoration: const InputDecoration(labelText: 'State/Province'),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(labelText: 'City'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Create Account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
