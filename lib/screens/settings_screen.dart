// ignore_for_file: use_build_context_synchronously, unnecessary_null_comparison

import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart'; // Import country_picker package
import '../widgets/header_widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import '../data/states_by_country.dart';
import '../services/subscription_service.dart';
import '../models/user_model.dart';

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
  final TextEditingController _directSponsorMinController =
      TextEditingController();
  final TextEditingController _totalTeamMinController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _bizNameController = TextEditingController();
  final TextEditingController _bizNameConfirmController =
      TextEditingController();
  final TextEditingController _refLinkController = TextEditingController();
  final TextEditingController _refLinkConfirmController =
      TextEditingController();

  List<String> _selectedCountries = [];
  int _directSponsorMin = 5;
  int _totalTeamMin = 10;
  String? _bizOpp; // Business Opportunity Name
  String? _bizRefUrl; // Business Opportunity Referral URL
  String? _adminFirstName; // Holds the admin's first name from Firestore
  bool _isBizLocked =
      false; // Indicates if bizOpp and bizRefUrl fields are locked for editing
  bool _isBizSettingsSet =
      false; // Indicates if bizOpp settings (name, url, mins) have been initially set

  // This map is still required to render flags in the display-only view after saving.
  // Ensure it is populated with all countries you intend to support.
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

  // Implemented function to use the country_picker package
  void _openCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: false, // You can customize what is shown
      onSelect: (Country country) {
        // Update state with the selected country
        setState(() {
          // Add the country only if it's not already in the list
          if (!_selectedCountries.contains(country.name)) {
            _selectedCountries.add(country.name);
            _selectedCountries.sort(); // Keep the list sorted alphabetically
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

      if (adminSettingsDoc != null && adminSettingsDoc.exists) {
        final data = adminSettingsDoc.data();
        if (data != null) {
          final bizOppFromFirestore = data['biz_opp'];
          final bizRefUrlFromFirestore = data['biz_opp_ref_url'];
          final sponsorMinFromFirestore = data['direct_sponsor_min'];
          final teamMinFromFirestore = data['total_team_min'];
          final countriesFromFirestore =
              List<String>.from(data['countries'] ?? []);

          bool settingsAreSet = (bizOppFromFirestore?.isNotEmpty ?? false) &&
              (bizRefUrlFromFirestore?.isNotEmpty ?? false) &&
              (sponsorMinFromFirestore != null) &&
              (teamMinFromFirestore != null);

          setState(() {
            _selectedCountries = countriesFromFirestore;
            _bizOpp = bizOppFromFirestore;
            _bizRefUrl = bizRefUrlFromFirestore;
            _directSponsorMin = sponsorMinFromFirestore ?? 5;
            _totalTeamMin = teamMinFromFirestore ?? 10;

            _directSponsorMinController.text = _directSponsorMin.toString();
            _totalTeamMinController.text = _totalTeamMin.toString();
            _bizNameController.text = _bizOpp ?? '';
            _bizNameConfirmController.text = _bizOpp ?? '';
            _refLinkController.text = _bizRefUrl ?? '';
            _refLinkConfirmController.text = _refLinkController.text;

            _isBizSettingsSet = settingsAreSet;
            _isBizLocked = _isBizSettingsSet;
          });
        } else {
          if (mounted) setState(() => _isBizSettingsSet = false);
        }
      } else {
        if (mounted) setState(() => _isBizSettingsSet = false);
      }
    } catch (e) {
      debugPrint('SettingsScreen: Error loading user settings: $e.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load settings: ${e.toString()}')),
        );
      }
      if (mounted) setState(() => _isBizSettingsSet = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      debugPrint('SettingsScreen: Form validation failed locally.');
      return;
    }

    if (!_isBizSettingsSet) {
      if (_bizNameController.text != _bizNameConfirmController.text ||
          _refLinkController.text != _refLinkConfirmController.text) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Business Name and Referral Link fields must match for confirmation.')),
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
        'direct_sponsor_min': _directSponsorMin,
        'total_team_min': _totalTeamMin,
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
    _directSponsorMinController.dispose();
    _totalTeamMinController.dispose();
    _bizNameController.dispose();
    _bizNameConfirmController.dispose();
    _refLinkController.dispose();
    _refLinkConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (!_isBizSettingsSet) {
      content = Form(
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
            RichText(
              textAlign: TextAlign.start,
              text: TextSpan(
                style: DefaultTextStyle.of(context)
                    .style
                    .copyWith(fontSize: 14, color: Colors.black87),
                children: [
                  TextSpan(
                    text: "Hello ${_adminFirstName ?? 'Admin'}!\n\n",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: "Welcome to your Business Opportunity Settings.\n\n",
                    style: const TextStyle(fontWeight: FontWeight.normal),
                  ),
                  const TextSpan(
                    text: "Please review these settings carefully, as ",
                    style: TextStyle(fontWeight: FontWeight.normal),
                  ),
                  TextSpan(
                    text: "once submitted, they cannot be changed.",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  const TextSpan(
                    text:
                        " These values will apply to every member of your downline team, ensuring the highest level of integrity, consistency, and fairness across your organization. Your thoughtful setup here is key to their long-term success.",
                    style: TextStyle(fontWeight: FontWeight.normal),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _bizNameController,
              readOnly: _isBizLocked,
              maxLines: null,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: 'Business Opportunity Name',
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

            // --- REVISED COUNTRY SELECTION UI ---
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
            // --- END OF REVISED UI ---

            const SizedBox(height: 20),
            const Center(
              child: Text(
                'TeamBuild Pro is your downline’s launchpad!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                      text:
                          "It helps each member pre-build their team for free—before ever joining "),
                  TextSpan(
                    text: _bizOpp ?? 'your business opportunity',
                    style: const TextStyle(
                        color: Colors.blue, fontWeight: FontWeight.w500),
                  ),
                  const TextSpan(
                      text:
                          ".\n\nOnce they meet the eligibility criteria you set below, they’ll automatically receive an invitation to join "),
                  TextSpan(
                    text: _bizOpp ?? 'business opportunity',
                    style: const TextStyle(
                        color: Colors.blue, fontWeight: FontWeight.w500),
                  ),
                  const TextSpan(
                      text:
                          " with their entire pre-built TeamBuild Pro downline ready to follow them into your "),
                  TextSpan(
                    text: _bizOpp ?? 'your business opportunity',
                    style: const TextStyle(
                        color: Colors.blue, fontWeight: FontWeight.w500),
                  ),
                  const TextSpan(
                      text:
                          ' organization.\n\nSet challenging requirements to ensure your downline members enter '),
                  TextSpan(
                    text: _bizOpp ?? 'your business opportunity',
                    style: const TextStyle(
                        color: Colors.blue, fontWeight: FontWeight.w500),
                  ),
                  const TextSpan(
                      text:
                          " strong, aligned, and positioned for long-term success!\n\nImportant! To maintain consistency, integrity, and fairness, once these values are set, they cannot be changed"),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'Set Minimum Eligibility Requirements',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _directSponsorMinController,
                    readOnly: _isBizSettingsSet,
                    decoration: InputDecoration(
                      labelText: 'Direct Sponsors',
                      filled: _isBizSettingsSet,
                      fillColor: _isBizSettingsSet ? Colors.grey[200] : null,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: _isBizSettingsSet
                        ? null
                        : (value) {
                            _directSponsorMin = int.tryParse(value) ?? 5;
                          },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _totalTeamMinController,
                    readOnly: _isBizSettingsSet,
                    decoration: InputDecoration(
                      labelText: 'Total Team Members',
                      filled: _isBizSettingsSet,
                      fillColor: _isBizSettingsSet ? Colors.grey[200] : null,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: _isBizSettingsSet
                        ? null
                        : (value) {
                            _totalTeamMin = int.tryParse(value) ?? 10;
                          },
                  ),
                ),
              ],
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
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'Business Opportunity Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoRow(
            label: 'Business Opportunity Name',
            content: _bizOpp ?? 'Not Set',
            icon: Icons.business,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            label: 'Your Unique Referral Link URL',
            content: _bizRefUrl ?? 'Not Set',
            icon: Icons.link,
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
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'TeamBuild Pro is your downline’s launchpad!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                    text:
                        "It helps each member pre-build their team for free—before ever joining "),
                TextSpan(
                  text: _bizOpp ?? 'your business opportunity',
                  style: const TextStyle(
                      color: Colors.blue, fontWeight: FontWeight.w500),
                ),
                const TextSpan(
                    text:
                        ".\n\nOnce they meet the eligibility criteria you set below, they’ll automatically receive an invitation to join "),
                TextSpan(
                  text: _bizOpp ?? 'business opportunity',
                  style: const TextStyle(
                      color: Colors.blue, fontWeight: FontWeight.w500),
                ),
                const TextSpan(
                    text:
                        " with their entire pre-built TeamBuild Pro downline ready to follow them into your "),
                TextSpan(
                  text: _bizOpp ?? 'your business opportunity',
                  style: const TextStyle(
                      color: Colors.blue, fontWeight: FontWeight.w500),
                ),
                const TextSpan(
                    text:
                        ' organization.\n\nSet challenging requirements to ensure your downline members enter '),
                TextSpan(
                  text: _bizOpp ?? 'your business opportunity',
                  style: const TextStyle(
                      color: Colors.blue, fontWeight: FontWeight.w500),
                ),
                const TextSpan(
                    text:
                        " strong, aligned, and positioned for long-term success!\n\nImportant! To maintain consistency, integrity, and fairness, once these values are set, they cannot be changed"),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Minimum Eligibility Requirements',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            label: 'Direct Sponsors',
            content: _directSponsorMin.toString(),
            icon: Icons.people,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            label: 'Total Team Members',
            content: _totalTeamMin.toString(),
            icon: Icons.groups,
          ),
          const SizedBox(height: 24),
        ],
      );
    }

    return Scaffold(
      appBar: AppHeaderWithMenu(
        firebaseConfig: widget.firebaseConfig,
        initialAuthToken: widget.initialAuthToken,
        appId: widget.appId,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: content,
      ),
    );
  }

  Widget _buildInfoRow(
      {required String label,
      required String content,
      required IconData icon}) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 28, color: Colors.blue),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(content, style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ],
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
