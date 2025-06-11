// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import '../widgets/header_widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/states_by_country.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import '../services/subscription_service.dart';
import '../models/user_model.dart';
// Needed for debugPrint

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
  bool _isBizLocked = false;
  bool _isBizSettingsSet = false;

  static const Map<String, String> _countryNameToCode = {
    'United States': 'US',
    'Canada': 'CA',
    'Brazil': 'BR',
    'Albania': 'AL',
  };

  List<String> get allCountries {
    final fullList = statesByCountry.keys.toList();
    final selected = List<String>.from(_selectedCountries);
    final unselected = fullList.where((c) => !selected.contains(c)).toList();
    selected.sort();
    unselected.sort();
    return [...selected, ...unselected];
  }

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  Future<void> _loadUserSettings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint(
          'SettingsScreen: User not authenticated. Showing editable form.');
      if (mounted) {
        setState(() => _isBizSettingsSet = false);
      }
      return;
    }

    try {
      final currentUserDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!mounted) return;
      if (!currentUserDoc.exists) {
        debugPrint(
            'SettingsScreen: Current authenticated user document not found. Showing editable form.');
        if (mounted) setState(() => _isBizSettingsSet = false);
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
        debugPrint(
            'SettingsScreen: User is not admin and has no upline_admin. Falling back to default admin ID.');
        adminUidToFetchSettings =
            "KJ8uFnlhKhWgBa4NVcwT"; // Your primary admin UID from generateUsers.js
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
        if (data != null) {
          final bizOppFromFirestore = data['biz_opp'];
          final bizRefUrlFromFirestore = data['biz_opp_ref_url'];
          final sponsorMinFromFirestore = data['direct_sponsor_min'];
          final teamMinFromFirestore = data['total_team_min'];
          final countriesFromFirestore =
              List<String>.from(data['countries'] ?? []);

          // --- Debugging Logs for _isBizSettingsSet ---
          debugPrint('SettingsScreen: Fetched biz_opp: $bizOppFromFirestore');
          debugPrint(
              'SettingsScreen: Fetched biz_opp_ref_url: $bizRefUrlFromFirestore');
          debugPrint(
              'SettingsScreen: Fetched direct_sponsor_min: $sponsorMinFromFirestore');
          debugPrint(
              'SettingsScreen: Fetched total_team_min: $teamMinFromFirestore');
          debugPrint(
              'SettingsScreen: Is bizOpp from Firestore empty? ${bizOppFromFirestore?.isEmpty ?? true}');
          debugPrint(
              'SettingsScreen: Is bizRefUrl from Firestore empty? ${bizRefUrlFromFirestore?.isEmpty ?? true}');

          // Determine _isBizSettingsSet based on actual values from Firestore
          bool settingsAreSet = (bizOppFromFirestore?.isNotEmpty ?? false) &&
              (bizRefUrlFromFirestore?.isNotEmpty ?? false) &&
              (sponsorMinFromFirestore != null) &&
              (teamMinFromFirestore != null);

          debugPrint(
              'SettingsScreen: Calculated _isBizSettingsSet: $settingsAreSet');

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

            _isBizSettingsSet =
                settingsAreSet; // Update state based on robust check
            _isBizLocked = _isBizSettingsSet;
          });
        } else {
          debugPrint(
              'SettingsScreen: Admin settings document ($adminUidToFetchSettings) data is null. Showing editable form.');
          if (mounted) setState(() => _isBizSettingsSet = false);
        }
      } else {
        debugPrint(
            'SettingsScreen: Admin settings document for $adminUidToFetchSettings not found. Showing editable form.');
        if (mounted) setState(() => _isBizSettingsSet = false);
      }
    } catch (e) {
      debugPrint(
          'SettingsScreen: Error loading user settings: $e. Showing editable form.');
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
      // Only do this check if it's the initial submission
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
      // Always use set with merge: true for settings, as we are managing subsets
      await settingsRef.set({
        'biz_opp': _bizNameController.text.trim(),
        'biz_opp_ref_url': _refLinkController.text.trim(),
        'direct_sponsor_min': _directSponsorMin,
        'total_team_min': _totalTeamMin,
        'countries': _selectedCountries,
      }, SetOptions(merge: true));

      debugPrint(
          'SettingsScreen: Settings saved successfully to Firestore. Reloading UI.');
      await _loadUserSettings(); // Re-load settings to update UI with latest saved values and trigger display-only mode

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
    } finally {
      // No setState here, _isBizSettingsSet is already updated by _loadUserSettings
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
    // Determine which view to show: form or display-only
    Widget content;
    if (!_isBizSettingsSet) {
      // If settings are not yet set, show the form
      debugPrint(
          'SettingsScreen: Rendering form view (_isBizSettingsSet is false)');
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
            if (!_isBizLocked) // Only show confirm field if not locked
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
                    if (!_isBizLocked) // Only show confirm field if not locked
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
            // This MultiSelectDialogField is now conditionally enabled/disabled
            AbsorbPointer(
              // Make it un-interactable when locked
              absorbing: _isBizSettingsSet, // If true, absorbs pointer events
              child: MultiSelectDialogField<String>(
                items: allCountries
                    .map((e) => MultiSelectItem<String>(e, e))
                    .toList(),
                initialValue: _selectedCountries,
                title: const Text("Select Countries"),
                buttonText: Text(_selectedCountries.isEmpty
                    ? "Select Countries"
                    : "Edit Countries"),
                searchable: true,
                decoration: BoxDecoration(
                  color: _isBizSettingsSet
                      ? Colors.grey[100]
                      : Colors.white, // Grey out background when locked
                  border: Border.all(
                    color: _isBizSettingsSet
                        ? Colors.grey.shade300
                        : Colors.deepPurple.shade200,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                buttonIcon: Icon(
                  Icons.arrow_drop_down,
                  color: _isBizSettingsSet ? Colors.grey : Colors.deepPurple,
                ),
                selectedColor: Colors.deepPurple,
                dialogHeight: 500,
                chipDisplay: MultiSelectChipDisplay(
                  chipColor: Colors.deepPurple.shade100,
                  textStyle: const TextStyle(color: Colors.black87),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onConfirm: (values) {
                  setState(() {
                    _selectedCountries = List.from(values);
                  });
                },
              ),
            ),
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
      // If settings are set, show the display-only view
      debugPrint(
          'SettingsScreen: Rendering display-only view (_isBizSettingsSet is true)');
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
          // Display Business Opportunity Name
          _buildInfoRow(
            label: 'Business Opportunity Name',
            content: _bizOpp ?? 'Not Set',
            icon: Icons.business,
          ),
          const SizedBox(height: 16),
          // Display Unique Referral Link URL
          _buildInfoRow(
            label: 'Your Unique Referral Link URL',
            content: _bizRefUrl ?? 'Not Set',
            icon: Icons.link,
          ),
          const SizedBox(height: 24),
          // Display Available Countries
          const Text('Selected Available Countries',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // Display selected countries as text with flags
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
          // Display Direct Sponsors
          _buildInfoRow(
            label: 'Direct Sponsors',
            content: _directSponsorMin.toString(),
            icon: Icons.people,
          ),
          const SizedBox(height: 16),
          // Display Total Team Members
          _buildInfoRow(
            label: 'Total Team Members',
            content: _totalTeamMin.toString(),
            icon: Icons.groups,
          ),
          const SizedBox(height: 24),
          // Optional: Add an "Edit Settings" button here if you want to allow changing ONLY the countries after submission
          // Or if you want a reset feature for bizOpp etc. (which your original request implies are locked).
        ],
      );
    }

    return Scaffold(
      appBar: AppHeaderWithMenu(
        firebaseConfig: widget.firebaseConfig, // Pass required args
        initialAuthToken: widget.initialAuthToken,
        appId: widget.appId,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: content, // Display the chosen content (form or display-only)
      ),
    );
  }

  // Helper widget to build info rows for the display-only view
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

  // Helper to convert country code to flag emoji
  String _countryCodeToEmoji(String countryCode) {
    // Basic check for 2-letter country code
    if (countryCode.length != 2) return '';

    final int firstLetter = countryCode.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = countryCode.codeUnitAt(1) - 0x41 + 0x1F1E6;

    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }
}
