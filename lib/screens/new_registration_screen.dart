import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../services/auth_service.dart';
import '../data/states_by_country.dart';
import '../widgets/header_widgets.dart';

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
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _cityController = TextEditingController();

  String? _selectedCountry;
  String? _selectedState;
  String? _sponsorName;
  String? _initialReferralCode;
  bool _isFirstUser = false;
  List<String> _availableCountries = [];
  bool _isLoading = false;
  bool isDevMode = false;

  List<String> get states => statesByCountry[_selectedCountry] ?? [];

  @override
  void initState() {
    super.initState();
    _initScreenData();
  }

  Future<void> _initScreenData() async {
    setState(() => _isLoading = true);
    _initialReferralCode = widget.referralCode;
    if (isDevMode && _initialReferralCode == null) {
      _initialReferralCode = '1F2BD4A5';
    }
    final code = _initialReferralCode;

    if (code == null || code.isEmpty) {
      setState(() {
        _isFirstUser = true;
        _availableCountries = statesByCountry.keys.toList();
        _isLoading = false;
      });
      return;
    }
    try {
      final uri = Uri.parse(
          'https://us-central1-teambuilder-plus-fe74d.cloudfunctions.net/getUserByReferralCode?code=$code');
      final response = await http.get(uri);

      if (mounted && response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final sponsorName =
            '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
        final uplineAdminUid = data['upline_admin'];

        if (uplineAdminUid != null) {
          final docSnapshot = await FirebaseFirestore.instance
              .collection('admin_settings')
              .doc(uplineAdminUid)
              .get();
          if (mounted &&
              docSnapshot.exists &&
              docSnapshot.data()?['countries'] is List) {
            setState(() {
              _sponsorName = sponsorName;
              _availableCountries =
                  List<String>.from(docSnapshot.data()!['countries']);
              _isFirstUser = false;
              _isLoading = false;
            });
            return;
          }
        }
      }
      throw Exception('Could not resolve referral and country data.');
    } catch (e) {
      debugPrint("Error in non-admin flow, falling back to admin defaults: $e");
      if (mounted) {
        setState(() {
          _isFirstUser = true;
          _availableCountries = statesByCountry.keys.toList();
          _isLoading = false;
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
    if (_isLoading) return;
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

      await Future.delayed(const Duration(seconds: 1));
      await AuthService().login(email, password);

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('An unexpected error occurred: $e')));
      }
    }
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
