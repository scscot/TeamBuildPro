import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_constants.dart';
import '../models/user_model.dart';
import '../services/subscription_service.dart';
import '../widgets/header_widgets.dart';

class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic> firebaseConfig;
  final String? initialAuthToken;
  final String appId;

  const SettingsScreen({
    super.key,
    required this.firebaseConfig,
    this.initialAuthToken,
    required this.appId,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _bizNameController = TextEditingController();
  final TextEditingController _bizNameConfirmController =
      TextEditingController();
  final TextEditingController _refLinkController = TextEditingController();
  final TextEditingController _refLinkConfirmController =
      TextEditingController();

  List<String> _selectedCountries = [];
  String? _bizOpp;
  String? _bizRefUrl;
  String? _adminFirstName;
  bool _isBizLocked = false;
  bool _isBizSettingsSet = false;
  bool _isLoading = true;

  static const Map<String, String> _countryNameToCode = {
    'United States': 'US',
    'Canada': 'CA',
    'Brazil': 'BR',
    'Albania': 'AL',
    'Germany': 'DE',
    'United Kingdom': 'GB',
    'Australia': 'AU',
    'Mexico': 'MX',
  };

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  void _openCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      onSelect: (Country country) {
        setState(() {
          if (!_selectedCountries.contains(country.name)) {
            _selectedCountries.add(country.name);
            _selectedCountries.sort();
          }
        });
      },
    );
  }

  Future<void> _loadUserSettings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('SettingsScreen: User not authenticated.');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Authentication required.')),
          );
          Navigator.of(context).pop();
        }
      });
      return;
    }

    try {
      final currentUserDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!mounted) return;

      if (!currentUserDoc.exists) {
        debugPrint('SettingsScreen: Current user document not found.');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User profile not found.')),
            );
            Navigator.of(context).pop();
          }
        });
        return;
      }

      final currentUserModel = UserModel.fromFirestore(currentUserDoc);

      if (currentUserModel.role != 'admin') {
        debugPrint('SettingsScreen: Access Denied. User is not an admin.');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Access Denied: Admin role required.')),
            );
            Navigator.of(context).pop();
          }
        });
        return;
      }

      _adminFirstName = currentUserModel.firstName;

      String adminUidToFetchSettings = currentUserModel.uid;

      DocumentSnapshot<Map<String, dynamic>>? adminSettingsDoc =
          await FirebaseFirestore.instance
              .collection('admin_settings')
              .doc(adminUidToFetchSettings)
              .get();

      if (!mounted) return;

      if (adminSettingsDoc.exists) {
        final data = adminSettingsDoc.data();
        if (data != null) {
          final bizOppFromFirestore = data['biz_opp'];
          final bizRefUrlFromFirestore = data['biz_opp_ref_url'];
          final countriesFromFirestore =
              List<String>.from(data['countries'] ?? []);

          bool settingsAreSet = (bizOppFromFirestore?.isNotEmpty ?? false) &&
              (bizRefUrlFromFirestore?.isNotEmpty ?? false) &&
              (countriesFromFirestore.isNotEmpty);

          _selectedCountries = countriesFromFirestore;
          _bizOpp = bizOppFromFirestore;
          _bizRefUrl = bizRefUrlFromFirestore;
          _bizNameController.text = _bizOpp ?? '';
          _bizNameConfirmController.text = _bizOpp ?? '';
          _refLinkController.text = _bizRefUrl ?? '';
          _refLinkConfirmController.text = _refLinkController.text;

          _isBizSettingsSet = settingsAreSet;
          _isBizLocked = _isBizSettingsSet;
        } else {
          _isBizSettingsSet = false;
        }
      } else {
        _isBizSettingsSet = false;
      }
    } catch (e) {
      debugPrint('SettingsScreen: Error loading user settings: $e.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load settings: ${e.toString()}')),
        );
      }
      _isBizSettingsSet = false;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    // Basic form validation (checks for empty fields)
    if (!_formKey.currentState!.validate()) {
      debugPrint('SettingsScreen: Form validation failed locally.');
      return;
    }

    // --- NEW: Business Name Content Validation ---
    final businessName = _bizNameController.text.trim();
    // Allows letters, numbers, spaces, and common characters: & ' - . ,
    final RegExp businessNameRegExp = RegExp(r"^[a-zA-Z0-9\s&'\-.,]+$");

    if (!businessNameRegExp.hasMatch(businessName)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Business name can only contain letters, numbers, and common punctuation.')),
      );
      return;
    }

    // --- NEW: Referral Link URL Validation ---
    final referralLink = _refLinkController.text.trim();
    try {
      final uri = Uri.parse(referralLink);
      // Check if the URI has a scheme (like http/https) and a host (like example.com)
      if (!uri.isAbsolute || uri.host.isEmpty) {
        throw const FormatException('Invalid URL format');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please enter a valid referral link (e.g., https://example.com).')),
      );
      return;
    }

    // Confirmation field validation
    if (!_isBizSettingsSet) {
      if (_bizNameController.text != _bizNameConfirmController.text) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Business Name fields must match for confirmation.')),
        );
        return;
      }
      if (_refLinkController.text != _refLinkConfirmController.text) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Referral Link fields must match for confirmation.')),
        );
        return;
      }
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('SettingsScreen: User not authenticated for submission.');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated.')),
      );
      return;
    }

    // Subscription and Firestore submission logic...
    final status = await SubscriptionService.checkAdminSubscriptionStatus(uid);
    final isActive = status['isActive'] == true;

    if (!isActive) {
      debugPrint(
          'SettingsScreen: Subscription not active. Showing upgrade dialog.');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Upgrade Required'),
          content: const Text(
              'Upgrade your Admin subscription to save these changes.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/upgrade');
              },
              child: const Text('Upgrade Now'),
            ),
          ],
        ),
      );
      return;
    }

    final settingsRef =
        FirebaseFirestore.instance.collection('admin_settings').doc(uid);

    try {
      debugPrint('SettingsScreen: Attempting to save settings to Firestore.');
      await settingsRef.set({
        'biz_opp': _bizNameController.text.trim(),
        'biz_opp_ref_url': _refLinkController.text.trim(),
        'countries': _selectedCountries,
      }, SetOptions(merge: true));

      debugPrint('SettingsScreen: Settings saved successfully. Reloading UI.');
      await _loadUserSettings();

      if (!mounted) return;
      Scrollable.ensureVisible(
        _formKey.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully.')),
      );
    } catch (e) {
      debugPrint('SettingsScreen: Error submitting settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _bizNameController.dispose();
    _bizNameConfirmController.dispose();
    _refLinkController.dispose();
    _refLinkConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeaderWithMenu(
        firebaseConfig: widget.firebaseConfig,
        initialAuthToken: widget.initialAuthToken,
        appId: widget.appId,
      ),
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildContent(),
            ),
    );
  }

  Widget _buildContent() {
    if (!_isBizSettingsSet) {
      // --- EDITABLE FORM VIEW ---
      return Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'Business Opportunity Settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: "Hello ${_adminFirstName ?? 'Admin'}!\n\n",
                  ),
                  const TextSpan(
                    text: "Carefully complete and review your settings, as ",
                  ),
                  TextSpan(
                    text: "once submitted, they cannot be changed. ",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  const TextSpan(
                    text:
                        "These values will apply to every member of your downline team, ensuring the highest level of integrity, consistency, and fairness across your organization.",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Divider(
              color: Colors.blue,
              thickness: 2,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _bizNameController,
              readOnly: _isBizLocked,
              maxLines: null,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: 'Your Business Opportunity Name',
                filled: _isBizLocked,
                fillColor: _isBizLocked ? Colors.grey[200] : null,
              ),
              validator: (value) =>
                  _isBizLocked ? null : (value!.isEmpty ? 'Required' : null),
            ),
            if (!_isBizLocked)
              TextFormField(
                controller: _bizNameConfirmController,
                decoration: const InputDecoration(
                    labelText: 'Confirm Business Opportunity Name'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _isBizLocked
                  ? null
                  : () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text(
                            'Very Important!',
                            style: TextStyle(
                                color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                          content: const Text(
                              'You must enter the exact referral link you received from your company. '
                              'This will ensure your TeamBuild Pro downline members that join your business opportunity '
                              'are automatically placed in your business opportunity downline.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('I Understand'),
                            ),
                          ],
                        ),
                      );
                    },
              child: AbsorbPointer(
                absorbing: _isBizLocked,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _refLinkController,
                      readOnly: _isBizLocked,
                      maxLines: null,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        labelText: 'Your Referral Link',
                        filled: _isBizLocked,
                        fillColor: _isBizLocked ? Colors.grey[200] : null,
                      ),
                      validator: (value) => _isBizLocked
                          ? null
                          : (value!.isEmpty ? 'Required' : null),
                    ),
                    if (!_isBizLocked)
                      TextFormField(
                        controller: _refLinkConfirmController,
                        decoration: const InputDecoration(
                          labelText: 'Confirm Referral Link URL',
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Required' : null,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Available Countries',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Important:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  const TextSpan(
                    text:
                        ' Only select the countries where your business opportunity is currently available.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minHeight: 100),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: [
                  ..._selectedCountries.map((country) => Chip(
                        label: Text(country),
                        onDeleted: () {
                          setState(() {
                            _selectedCountries.remove(country);
                          });
                        },
                      )),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text("Add a Country"),
              onPressed: _openCountryPicker,
            ),
            const SizedBox(height: 24),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Save Settings'),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // --- DISPLAY-ONLY VIEW ---
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'Business Opportunity Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.business, color: Colors.blue),
                  title: const Text('Your Business Opportunity'),
                  subtitle: Text(
                    _bizOpp ?? 'Not Set',
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.link, color: Colors.blue),
                  title: const Text('Your Referral Link'),
                  subtitle: SelectableText(
                    _bizRefUrl ?? 'Not Set',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Selected Available Countries',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_selectedCountries.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _selectedCountries.map((country) {
                final countryCode = _countryNameToCode[country];
                final flagEmoji =
                    countryCode != null ? _countryCodeToEmoji(countryCode) : '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Text(
                        flagEmoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          country,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            )
          else
            const Text('No countries selected.',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 10),
          const Text(
            'TeamBuild Pro Feeder System',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          // FIXED: Wrapped the Text.rich widget in a Row and Expanded
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                          text:
                              "When your downline members meet the minimum eligibility criteria, they are automatically invited to join your "),
                      TextSpan(
                        text: _bizOpp ?? 'business opportunity',
                        style: const TextStyle(
                            color: Colors.blue, fontWeight: FontWeight.w500),
                      ),
                      const TextSpan(
                          text:
                              " team — with their growing TeamBuild Pro downlines ready to follow."),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Minimum Eligibility Requirements',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricCard(
                icon: Icons.people,
                value: AppConstants.projectWideDirectSponsorMin.toString(),
                label: 'Direct Sponsors',
              ),
              const SizedBox(width: 16),
              _buildMetricCard(
                icon: Icons.groups,
                value: AppConstants.projectWideTotalTeamMin.toString(),
                label: 'Total Team Members',
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      );
    }
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: Colors.blue),
              const SizedBox(height: 8),
              Text(
                value,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _countryCodeToEmoji(String countryCode) {
    if (countryCode.length != 2) return '';
    final int firstLetter = countryCode.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = countryCode.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }
}
