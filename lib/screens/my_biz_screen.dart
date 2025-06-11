import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/header_widgets.dart';
// import '../models/user_model.dart'; // Needed for UserModel

class MyBizScreen extends StatefulWidget {
  // Add required parameters for consistency with current app navigation
  final Map<String, dynamic> firebaseConfig;
  final String? initialAuthToken;
  final String appId;

  const MyBizScreen({
    super.key,
    required this.firebaseConfig, // Required
    this.initialAuthToken, // Nullable
    required this.appId, // Required
  });

  @override
  State<MyBizScreen> createState() => _MyBizScreenState();
}

class _MyBizScreenState extends State<MyBizScreen> {
  String? bizOpp;
  String? bizOppRefUrl;
  Timestamp? bizJoinDate; // Keep as Timestamp as per your original file
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('User not authenticated for MyBizScreen.');
      if (!mounted) return;
      setState(() => loading = false); // Ensure loading is off
      return;
    }

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    if (!mounted) return; // Guard against setState after async gap

    final data = doc.data();
    if (data == null) {
      debugPrint('User document data is null for MyBizScreen: $uid');
      if (mounted) setState(() => loading = false);
      return;
    }

    // Check conditions for redirection as per original logic
    // Using direct data access here as UserModel might not immediately have all fields
    // if not fully populated (e.g., from an incomplete registration process).
    if (data['role'] != 'user' || data['biz_opp_ref_url'] == null) {
      debugPrint(
          'User role is not user or biz_opp_ref_url is null. Popping MyBizScreen.');
      if (mounted) {
        Navigator.of(context).pop(); // Go back if conditions not met
      }
      return;
    }

    if (!mounted) return; // Guard before setState after conditions

    setState(() {
      bizOpp = data['biz_opp'] as String?; // Cast to String?
      bizOppRefUrl = data['biz_opp_ref_url'] as String?; // Cast to String?
      bizJoinDate = data['biz_join_date'] as Timestamp?; // Cast to Timestamp?
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeaderWithMenu(
        // Pass required args to AppHeaderWithMenu
        firebaseConfig: widget.firebaseConfig,
        initialAuthToken: widget.initialAuthToken,
        appId: widget.appId,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Your Business Opportunity',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildInfoCard(
                    title: 'Company Name',
                    content: bizOpp ?? 'Not available',
                    icon: Icons.business,
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    title: 'My Referral Link',
                    content: bizOppRefUrl ?? 'Not available',
                    icon: Icons.link,
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    title: 'Join Date',
                    content: bizJoinDate != null
                        ? bizJoinDate!
                            .toDate()
                            .toLocal()
                            .toString()
                            .split(" ")[0]
                        : 'Not available',
                    icon: Icons.calendar_today,
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style:
                            const TextStyle(fontSize: 16, color: Colors.black),
                        children: [
                          const TextSpan(
                            text:
                                "From this point forward, anyone in your TeamBuild Pro downline that joins ",
                          ),
                          TextSpan(
                            text: bizOpp,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(
                            text:
                                " will automatically be placed in your downline.",
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

  Widget _buildInfoCard(
      {required String title,
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
                  Text(title,
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
}
