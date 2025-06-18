// lib/screens/update_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../widgets/header_widgets.dart';
import 'my_biz_screen.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class UpdateProfileScreen extends StatefulWidget {
  final String appId;

  const UpdateProfileScreen({
    super.key,
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
  final FirestoreService _firestoreService = FirestoreService();

  String? baseUrl;
  String? bizOpp;
  bool isSaving = false;
  bool _hasShownInfoModal = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _refLinkController.dispose();
    _refLinkConfirmController.dispose();
    super.dispose();
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
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Important'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Please read carefully.'),
                SizedBox(height: 10),
                Text('Your referral link can only be set once.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadData() async {
    final user = Provider.of<UserModel?>(context, listen: false);
    if (user == null) return;

    final isAdmin = user.role == 'admin';
    String settingsDocId = isAdmin
        ? user.uid
        : (user.uplineRefs.isNotEmpty ? user.uplineRefs.last : user.uid);

    final settingsDoc = await FirebaseFirestore.instance
        .collection('admin_settings')
        .doc(settingsDocId)
        .get();

    if (mounted && settingsDoc.exists) {
      setState(() {
        baseUrl = settingsDoc.data()?['baseUrl'];
        bizOpp = settingsDoc.data()?['bizOpp'];
      });
    }
  }

  Future<void> _saveAndContinue() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => isSaving = true);

    final user = Provider.of<UserModel?>(context, listen: false);
    if (user == null) {
      if (mounted) {
        setState(() => isSaving = false);
      }
      return;
    }

    try {
      await _firestoreService.updateUser(user.uid, {
        'biz_opp_ref_url': _refLinkController.text.trim(),
        'biz_visit_date': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Profile Updated!'), backgroundColor: Colors.green),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MyBizScreen(appId: widget.appId)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeaderWithMenu(appId: widget.appId),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (bizOpp != null)
                      Text('Welcome to $bizOpp!',
                          style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 24),
                    if (baseUrl != null) ...[
                      TextFormField(
                        controller: _refLinkController,
                        onTap: _onReferralLinkTap,
                        decoration: InputDecoration(
                          labelText: 'Referral Link Username',
                          prefixText: '$baseUrl',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your username';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _refLinkConfirmController,
                        decoration: const InputDecoration(
                          labelText: 'Confirm Referral Link Username',
                        ),
                        validator: (value) {
                          if (value != _refLinkController.text) {
                            return 'Usernames do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isSaving ? null : _saveAndContinue,
                        icon: isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.0, color: Colors.white))
                            : const Icon(Icons.save),
                        label: Text(
                          isSaving ? 'Saving...' : 'Save & Continue',
                          style: const TextStyle(fontSize: 18),
                        ),
                        // MODIFIED: Refactored to use modern ElevatedButton.styleFrom
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor:
                              const Color.fromARGB(255, 109, 58, 204),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
