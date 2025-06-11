import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/header_widgets.dart';
import 'my_biz_screen.dart'; // Ensure this screen exists
import '../models/user_model.dart'; // Still needed for currentUserModel.bizOppRefUrl

class UpdateProfileScreen extends StatefulWidget {
  // Add required parameters for consistency with current app navigation
  final Map<String, dynamic> firebaseConfig;
  final String? initialAuthToken;
  final String appId;

  const UpdateProfileScreen({
    super.key,
    required this.firebaseConfig,
    this.initialAuthToken,
    required this.appId,
  });

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _refLinkController = TextEditingController();
  final TextEditingController _refLinkConfirmController =
      TextEditingController();
  String? baseUrl;
  String? bizOpp;
  bool isSaving = false;
  // bool isUnlocked = false; // REMOVED: isUnlocked declaration
  bool _hasShownInfoModal = false;

  // Define your central admin UID as a constant (still used for fetching admin settings)
  static const String _primaryAdminUid = "KJ8uFnlhKhWgBa4NVcwT";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _onReferralLinkTap() {
    if (!_hasShownInfoModal) {
      _showImportantInfoModal();
      _hasShownInfoModal = true;
    }
  }

  void _showImportantInfoModal() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Very Important!',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('UpdateProfileScreen: User not authenticated.');
      if (mounted) setState(() {});
      return;
    }

    try {
      final currentUserDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!mounted) return;

      if (!currentUserDoc.exists) {
        debugPrint('UpdateProfileScreen: Current user document not found.');
        if (mounted) setState(() {});
        return;
      }
      final currentUserModel = UserModel.fromFirestore(
          currentUserDoc); // Still need UserModel to get bizOppRefUrl

      // Determine the admin UID to fetch base URL and bizOpp name from
      String? adminUidForBizOppSettings = currentUserModel.uplineAdmin;
      if (currentUserModel.role == 'admin') {
        adminUidForBizOppSettings = currentUserModel.uid;
      } else if (adminUidForBizOppSettings == null ||
          adminUidForBizOppSettings.isEmpty) {
        adminUidForBizOppSettings = _primaryAdminUid;
      }

      DocumentSnapshot<Map<String, dynamic>>? adminSettingsDoc;
      if (adminUidForBizOppSettings.isNotEmpty) {
        adminSettingsDoc = await FirebaseFirestore.instance
            .collection('admin_settings')
            .doc(adminUidForBizOppSettings)
            .get();
      }

      if (!mounted) return;

      setState(() {
        // Load bizOpp and baseUrl from admin_settings
        if (adminSettingsDoc != null && adminSettingsDoc.exists) {
          final adminSettingsData = adminSettingsDoc.data();
          final String? fetchedBaseUrl =
              adminSettingsData?['biz_opp_ref_url'] as String?;
          final String? fetchedBizOpp =
              adminSettingsData?['biz_opp'] as String?;

          if (fetchedBaseUrl != null && fetchedBaseUrl.isNotEmpty) {
            final uri = Uri.tryParse(fetchedBaseUrl);
            if (uri != null) {
              baseUrl = uri.path.endsWith('/')
                  ? '${uri.scheme}://${uri.host}${uri.path}'
                  : '${uri.scheme}://${uri.host}${uri.path}/';
            }
          }
          bizOpp = fetchedBizOpp;
        } else {
          debugPrint(
              'UpdateProfileScreen: Admin settings document $adminUidForBizOppSettings not found. Using defaults.');
        }

        // Pre-fill fields with current user's *own* saved link from their user document
        if (currentUserModel.bizOppRefUrl != null &&
            currentUserModel.bizOppRefUrl!.isNotEmpty) {
          _refLinkController.text = currentUserModel.bizOppRefUrl!;
          _refLinkConfirmController.text = currentUserModel.bizOppRefUrl!;
        }
      });
    } catch (e) {
      debugPrint('UpdateProfileScreen: Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load settings: $e')),
        );
      }
    } finally {
      debugPrint(
          'UpdateProfileScreen: FINAL STATE - isSaving=$isSaving, baseUrl=$baseUrl');
      debugPrint(
          'UpdateProfileScreen: _refLinkController.text = ${_refLinkController.text}');
      debugPrint(
          'UpdateProfileScreen: _refLinkConfirmController.text = ${_refLinkConfirmController.text}');
    }
  }

  Future<void> _submitReferral() async {
    // Perform form validation first
    if (!_formKey.currentState!.validate()) {
      debugPrint('UpdateProfileScreen: Form validation failed.');
      return;
    }

    // Now check button-disabling conditions that were not part of Form validation
    if (baseUrl == null) {
      debugPrint(
          'UpdateProfileScreen: Base URL is null, cannot submit. Admin settings not loaded.');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Error: Business opportunity details not loaded. Cannot save.')),
      );
      return;
    }

    // REMOVED: isUnlocked check
    // if (!isUnlocked) {
    //   debugPrint('UpdateProfileScreen: User is not unlocked. Showing upgrade dialog.');
    //   if (!mounted) return;
    //   showDialog(
    //     context: context,
    //     builder: (_) => AlertDialog(
    //       title: const Text('Upgrade Required'),
    //       content: const Text(
    //           'You must upgrade your TeamBuild Pro account to submit your unique business referral link.'),
    //       actions: [
    //         TextButton(
    //           onPressed: () => Navigator.of(context).pop(),
    //           child: const Text('Cancel'),
    //         ),
    //         ElevatedButton(
    //           onPressed: () {
    //             Navigator.of(context).pop();
    //             Navigator.pushNamed(context, '/upgrade');
    //           },
    //           child: const Text('Upgrade Now'),
    //         ),
    //       ],
    //     ),
    //   );
    //   return;
    // }

    final userInput = _refLinkController.text.trim();
    final confirmInput = _refLinkConfirmController.text.trim();

    if (userInput != confirmInput) {
      debugPrint(
          'UpdateProfileScreen: Referral links do not match. (pre-submit check)');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Links Do Not Match'),
          content: const Text(
              'The entered referral URL and confirmation URL do not match.'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK!'),
            ),
          ],
        ),
      );
      return;
    }

    if (!userInput.startsWith(baseUrl!)) {
      debugPrint(
          'UpdateProfileScreen: Referral link does not start with base URL. (pre-submit check)');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Invalid Referral Link'),
          content: Text('Your unique referral link must begin with $baseUrl.'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK!'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => isSaving = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('UpdateProfileScreen: No Firebase user found for submission.');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication required to save link.')),
      );
      setState(() => isSaving = false);
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'biz_opp_ref_url': userInput,
        'biz_join_date': FieldValue.serverTimestamp(),
        'biz_opp': bizOpp, // Save bizOpp name to user's profile
      });

      debugPrint('UpdateProfileScreen: Referral link saved successfully.');
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => MyBizScreen(
                  firebaseConfig: widget.firebaseConfig,
                  initialAuthToken: widget.initialAuthToken,
                  appId: widget.appId,
                )),
      );
    } catch (e) {
      debugPrint('UpdateProfileScreen: Error submitting referral link: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save link: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  void dispose() {
    _refLinkController.dispose();
    _refLinkConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).canvasColor,
      appBar: AppHeaderWithMenu(
        // Pass required args
        firebaseConfig: widget.firebaseConfig,
        initialAuthToken: widget.initialAuthToken,
        appId: widget.appId,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Page Title
            Center(
              child: Text(
                'Add Unique Referral Link',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),

            // Main Content Card
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Instructions
                      Center(
                        child: Text(
                          bizOpp ??
                              'Your Business Opportunity', // Default if bizOpp is null
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.black,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Referral Link Input Field
                      TextFormField(
                        controller: _refLinkController,
                        keyboardType: TextInputType.url,
                        onTap: _onReferralLinkTap, // Show modal on first tap
                        decoration: InputDecoration(
                          labelText: 'Your Unique Referral Link URL',
                          hintText: baseUrl != null
                              ? '$baseUrl...'
                              : 'https://yourcompany.com/your-id',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.public),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your referral link.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(
                          height: 16), // Spacing between the two URL fields

                      // Confirm Referral Link Input Field (NEW)
                      TextFormField(
                        controller: _refLinkConfirmController,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          labelText: 'Confirm Referral Link URL',
                          hintText: 'Re-enter your URL for confirmation',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.public),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your referral link.';
                          }
                          if (value != _refLinkController.text) {
                            return 'URLs do not match!';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      // Submit Button
                      Center(
                        child: ElevatedButton.icon(
                          // Simplified onPressed: removed !isUnlocked condition
                          onPressed: isSaving || baseUrl == null
                              ? null
                              : _submitReferral,
                          icon: isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(
                            isSaving ? 'Saving...' : 'Save & Continue',
                            style: const TextStyle(fontSize: 18),
                          ),
                          style: ButtonStyle(
                            foregroundColor:
                                WidgetStateProperty.all<Color>(Colors.white),
                            backgroundColor: WidgetStateProperty.all<Color>(
                                const Color.fromARGB(
                                    255, 109, 58, 204)), // Lavender hex color
                            padding:
                                WidgetStateProperty.all<EdgeInsetsGeometry>(
                                    const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 16)),
                            shape: WidgetStateProperty.all<OutlinedBorder>(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            elevation: WidgetStateProperty.all<double>(5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
