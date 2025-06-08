import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/header_widgets.dart';
import 'my_biz_screen.dart';

class UpdateProfileScreen extends StatefulWidget {
  const UpdateProfileScreen({super.key});

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _refLinkController = TextEditingController();
  String? baseUrl;
  String? bizOpp;
  bool isSaving = false;
  bool isUnlocked = false;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    final adminSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .limit(1)
        .get();

    if (adminSnapshot.docs.isNotEmpty) {
      final adminData = adminSnapshot.docs.first.data();
      final fullUrl = adminData['biz_opp_ref_url'];
      if (fullUrl != null && fullUrl is String) {
        final uri = Uri.tryParse(fullUrl);
        if (uri != null) {
          setState(() {
            baseUrl = uri.path.endsWith('/')
                ? '${uri.scheme}://${uri.host}${uri.path}'
                : '${uri.scheme}://${uri.host}${uri.path}/';
            bizOpp = adminData['biz_opp'];
          });
        }
      }
    }
  }

  Future<void> _submitReferral() async {
    if (!isUnlocked) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Upgrade Required'),
          content: const Text(
              'You must upgrade your TeamBuild Pro account to submit your unique business referral link.'),
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

    if (!_formKey.currentState!.validate() || baseUrl == null) return;
    final userInput = _refLinkController.text.trim();

    if (!userInput.startsWith(baseUrl!)) {
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
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'biz_opp_ref_url': userInput,
      'biz_join_date': FieldValue.serverTimestamp(),
      'biz_opp': bizOpp,
    });

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MyBizScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeaderWithMenu(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Enter your unique business referral link:',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _refLinkController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'https://yourcompany.com/your-id',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a referral link.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: isSaving ? null : _submitReferral,
                  child: isSaving
                      ? const CircularProgressIndicator()
                      : const Text('Save & Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
