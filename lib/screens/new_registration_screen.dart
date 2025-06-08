import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/session_manager.dart';
import '../data/states_by_country.dart';
import 'dashboard_screen.dart';

class NewRegistrationScreen extends StatefulWidget {
  final String? referralCode;
  const NewRegistrationScreen({super.key, this.referralCode});

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
  String? _referredBy;
  String? _role;
  String? _uplineAdmin;
  List<String> _availableCountries = [];
  bool _isLoading = false;
  bool isDevMode = true;

  List<String> get states => statesByCountry[_selectedCountry] ?? [];

  @override
  void initState() {
    super.initState();
    _initReferral();
  }

  Future<void> _initReferral() async {
    if (isDevMode) {
      setState(() {
        _referredBy = '537feec3';
      });
    }

    final code = widget.referralCode ?? _referredBy;
    if (code == null || code.isEmpty) {
      setState(() => _role = 'admin');
      return;
    }

    try {
      final uri = Uri.parse(
          'https://us-central1-teambuilder-plus-fe74d.cloudfunctions.net/getUserByReferralCode?code=$code');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final sponsorName =
            '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
        final referredBy = code;
        final uplineAdminUid = data['upline_admin'];

        setState(() {
          _sponsorName = sponsorName;
          _referredBy = referredBy;
          _uplineAdmin = uplineAdminUid;
          _role = null;
        });

        if (uplineAdminUid != null) {
          final countriesResponse = await http.get(Uri.parse(
              'https://us-central1-teambuilder-plus-fe74d.cloudfunctions.net/getCountriesByAdminUid?uid=$uplineAdminUid'));

          if (countriesResponse.statusCode == 200) {
            final countryData = jsonDecode(countriesResponse.body);
            final countries = countryData['countries'];
            if (countries is List) {
              setState(
                  () => _availableCountries = List<String>.from(countries));
            }
          }
        }
      } else {
        debugPrint('❌ Referral lookup failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error in getUserByReferralCode: $e');
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

  Future<int> _getReferrerLevel(String? referralCode) async {
    if (referralCode == null || referralCode.isEmpty) return 1;
    final referrer =
        await FirestoreService().getUserByReferralCode(referralCode);
    if (referrer != null && referrer.level != null) {
      return referrer.level! + 1;
    }
    return 1;
  }

  Future<void> _callSecureSponsorUpdate(String referralCode) async {
    try {
      final uri = Uri.parse(
          'https://us-central1-teambuilder-plus-fe74d.cloudfunctions.net/incrementSponsorCounts');
      final response = await http.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'referralCode': referralCode}));
      debugPrint(
          '🔄 Sponsor update response: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('❌ Error calling incrementSponsorCounts: $e');
    }
  }

  Future<void> _qualifyUpline(String? referredBy) async {
    if (referredBy == null || referredBy.isEmpty) return;
    String? currentUid = referredBy;

    while (currentUid != null && currentUid.isNotEmpty) {
      final userDoc =
          await FirestoreService().getUserByReferralCode(currentUid);
      if (userDoc == null) break;

      final isAdmin = userDoc.role == 'admin';
      final direct = userDoc.directSponsorCount ?? 0;
      final total = userDoc.totalTeamCount ?? 0;
      final directMin = userDoc.directSponsorMin ?? 1;
      final totalMin = userDoc.totalTeamMin ?? 1;
      final qualified = userDoc.qualifiedDate != null;

      if (!isAdmin && !qualified && direct >= directMin && total >= totalMin) {
        await FirestoreService().updateUser(
            userDoc.uid, {'qualified_date': FieldValue.serverTimestamp()});
      }
      currentUid = userDoc.referredBy;
    }
  }

  Future<String> _generateUniqueReferralCode() async {
    const int maxAttempts = 10;
    const int codeLength = 6;
    final random = Uuid();

    for (int i = 0; i < maxAttempts; i++) {
      final code = random
          .v4()
          .replaceAll('-', '')
          .substring(0, codeLength)
          .toUpperCase();
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('referralCode', isEqualTo: code)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return code;
    }
    throw Exception(
        'Unable to generate unique referral code after $maxAttempts attempts');
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      UserModel user = await AuthService().register(email, password);
      final referredBy = _referredBy;
      final level = await _getReferrerLevel(referredBy);
      final referralCode = await _generateUniqueReferralCode();
      final uplineAdmin = _role == 'admin' ? user.uid : _uplineAdmin;

      final newUser = UserModel(
        uid: user.uid,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: email,
        createdAt: DateTime.now(),
        country: _selectedCountry,
        state: _selectedState,
        city: _cityController.text.trim(),
        referralCode: referralCode,
        referredBy: referredBy,
        level: level,
        directSponsorCount: 0,
        totalTeamCount: 0,
        role: _role ?? 'user',
      );

      final userMap = newUser.toMap();
      userMap['upline_admin'] = uplineAdmin;

      await FirestoreService().createUser(userMap);
      if (referredBy != null && referredBy.isNotEmpty) {
        await _callSecureSponsorUpdate(referredBy);
      }
      await _qualifyUpline(referredBy);
      await SessionManager().setCurrentUser(newUser);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } catch (e) {
      debugPrint('❌ Registration error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
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
              else if (_role == 'admin')
                const Padding(
                  padding: EdgeInsets.only(bottom: 12.0),
                  child: Text(
                      'You are creating your own TeamBuild Pro organization.',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'First Name'),
                validator: (value) => value == null || value.isEmpty
                    ? 'Enter your first name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name'),
                validator: (value) => value == null || value.isEmpty
                    ? 'Enter your last name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value == null || !value.contains('@')
                    ? 'Enter a valid email'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) => value == null || value.length < 6
                    ? 'Password must be at least 6 characters'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPasswordController,
                decoration:
                    const InputDecoration(labelText: 'Confirm Password'),
                obscureText: true,
                validator: (value) => value != _passwordController.text
                    ? 'Passwords do not match'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCountry,
                hint: const Text('Select Country'),
                items: _availableCountries
                    .map((country) =>
                        DropdownMenuItem(value: country, child: Text(country)))
                    .toList(),
                onChanged: (value) => setState(() {
                  _selectedCountry = value;
                  _selectedState = null;
                }),
                decoration: const InputDecoration(labelText: 'Country'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedState,
                items: states
                    .map((state) =>
                        DropdownMenuItem(value: state, child: Text(state)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedState = value),
                decoration: const InputDecoration(labelText: 'State/Province'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'City'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter your city' : null,
              ),
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
