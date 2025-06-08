import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/header_widgets.dart';

class MyBizScreen extends StatefulWidget {
  const MyBizScreen({super.key});

  @override
  State<MyBizScreen> createState() => _MyBizScreenState();
}

class _MyBizScreenState extends State<MyBizScreen> {
  String? bizOpp;
  String? bizOppRefUrl;
  Timestamp? bizJoinDate;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) return;

    if (data['role'] != 'user' || data['biz_opp_ref_url'] == null) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    setState(() {
      bizOpp = data['biz_opp'];
      bizOppRefUrl = data['biz_opp_ref_url'];
      bizJoinDate = data['biz_join_date'];
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeaderWithMenu(),
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
                    child: const Text(
                      "From this point forward, anyone in your TeamBuild Pro downline that completes their business opportunity registration will automatically be placed in your downline.",
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
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
