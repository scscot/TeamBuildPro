// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import '../widgets/header_widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/states_by_country.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import '../services/subscription_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

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
  // Removed: bool _selectAllCountries = false;

  // Removed: List<String> _originalSelectedCountries = [];
  int _directSponsorMin = 5;
  int _totalTeamMin = 10;
  String? _userCountry;
  String? _bizOpp;
  String? _bizRefUrl;
  bool _isBizLocked = false;
  bool _isBizSettingsSet = false;

  List<String> get allCountries {
    final fullList = statesByCountry.keys.toList();
    final selected = List<String>.from(_selectedCountries);
    final unselected = fullList.where((c) => !selected.contains(c)).toList();

    selected.remove(_userCountry);
    unselected.remove(_userCountry);

    selected.sort();
    unselected.sort();

    if (_userCountry != null) {
      return [_userCountry!, ...selected, ...unselected];
    }
    return [...selected, ...unselected];
  }

  Future<void> _loadUserSettings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('admin_settings')
        .doc(uid)
        .get();
    final data = doc.data();

    if (data != null) {
      final country = data['country'];
      final countries = List<String>.from(data['countries'] ?? []);
      final bizOpp = data['biz_opp'];
      final bizRefUrl = data['biz_opp_ref_url'];
      final sponsorMin = data['direct_sponsor_min'];
      final teamMin = data['total_team_min'];

      setState(() {
        if (country is String) {
          _userCountry = country;
          if (!countries.contains(country)) countries.insert(0, country);
        }
        _selectedCountries = countries;
        // Removed: _originalSelectedCountries = List.from(countries);
        _bizOpp = bizOpp;
        _bizRefUrl = bizRefUrl;
        _directSponsorMin = sponsorMin ?? 5;
        _totalTeamMin = teamMin ?? 10;
        _directSponsorMinController.text = _directSponsorMin.toString();
        _totalTeamMinController.text = _totalTeamMin.toString();

        _bizNameController.text = _bizOpp ?? '';
        _bizNameConfirmController.text = _bizOpp ?? '';
        _refLinkController.text = _bizRefUrl ?? '';
        _refLinkConfirmController.text = _refLinkController.text;
        _isBizLocked =
            (_bizOpp?.isNotEmpty ?? false) || (_bizRefUrl?.isNotEmpty ?? false);

        // Determine if biz settings have been set
        _isBizSettingsSet = (_bizOpp?.isNotEmpty ?? false) &&
            (_bizRefUrl?.isNotEmpty ?? false) &&
            (sponsorMin != null) &&
            (teamMin != null);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isBizLocked && !_isBizSettingsSet) {
      // Only validate confirmation fields if not locked and not set
      if (_bizNameController.text != _bizNameConfirmController.text ||
          _refLinkController.text != _refLinkConfirmController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fields must match for confirmation.')),
        );
        return;
      }
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final status = await SubscriptionService.checkAdminSubscriptionStatus(uid);
    final isActive = status['isActive'] == true;

    if (!isActive) {
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

    // Only update these fields if they haven't been set yet
    if (!_isBizSettingsSet) {
      await settingsRef.set(
          {
            'biz_opp': _bizNameController.text.trim(),
            'biz_opp_ref_url': _refLinkController.text.trim(),
            'direct_sponsor_min': _directSponsorMin,
            'total_team_min': _totalTeamMin,
            'countries': _selectedCountries,
          },
          SetOptions(
              merge: true)); // Use merge to avoid overwriting other fields
    } else {
      await settingsRef.set({
        'countries': _selectedCountries,
      }, SetOptions(merge: true));
    }

    await _loadUserSettings();
    Scrollable.ensureVisible(_formKey.currentContext ?? context,
        duration: const Duration(milliseconds: 300));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved successfully.')),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeaderWithMenu(),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        controller: ScrollController(),
        padding: const EdgeInsets.all(16),
        child: Form(
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
                readOnly: _isBizLocked || _isBizSettingsSet,
                maxLines: _isBizSettingsSet ? null : 1,
                keyboardType: _isBizSettingsSet
                    ? TextInputType.multiline
                    : TextInputType.text,
                decoration: InputDecoration(
                  labelText: 'Business Opportunity Name',
                  filled: _isBizLocked || _isBizSettingsSet,
                  fillColor: (_isBizLocked || _isBizSettingsSet)
                      ? Colors.grey[200]
                      : null,
                ),
                validator: (value) => (_isBizLocked || _isBizSettingsSet)
                    ? null
                    : (value!.isEmpty ? 'Required' : null),
              ),
              if (!_isBizLocked && !_isBizSettingsSet)
                TextFormField(
                  controller: _bizNameConfirmController,
                  decoration: const InputDecoration(
                      labelText: 'Confirm Business Opportunity Name'),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: (_isBizLocked || _isBizSettingsSet)
                    ? null
                    : () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text(
                              'Very Important!',
                              style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold),
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
                  absorbing: _isBizLocked || _isBizSettingsSet,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _refLinkController,
                        readOnly: _isBizLocked || _isBizSettingsSet,
                        maxLines: _isBizSettingsSet ? null : 1,
                        keyboardType: _isBizSettingsSet
                            ? TextInputType.multiline
                            : TextInputType.url,
                        decoration: InputDecoration(
                          labelText: 'Your Unique Referral Link URL',
                          filled: _isBizLocked || _isBizSettingsSet,
                          fillColor: (_isBizLocked || _isBizSettingsSet)
                              ? Colors.grey[200]
                              : null,
                        ),
                        validator: (value) =>
                            (_isBizLocked || _isBizSettingsSet)
                                ? null
                                : (value!.isEmpty ? 'Required' : null),
                      ),
                      if (!_isBizLocked && !_isBizSettingsSet)
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
              MultiSelectDialogField<String>(
                items: allCountries
                    .map((e) => MultiSelectItem<String>(e, e))
                    .toList(),
                initialValue: _selectedCountries,
                title: const Text("Select Countries"),
                buttonText: const Text("Select Countries"),
                searchable: true,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: Colors.deepPurple.shade200,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                buttonIcon: const Icon(
                  Icons.arrow_drop_down,
                  color: Colors.deepPurple,
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
        ),
      ),
    );
  }
}
