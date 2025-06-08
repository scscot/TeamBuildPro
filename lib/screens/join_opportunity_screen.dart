import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/header_widgets.dart';
import 'update_profile_screen.dart';

class JoinOpportunityScreen extends StatefulWidget {
  const JoinOpportunityScreen({super.key});

  @override
  State<JoinOpportunityScreen> createState() => _JoinOpportunityScreenState();
}

class _JoinOpportunityScreenState extends State<JoinOpportunityScreen> {
  String? firstName;
  String? bizOpp;
  String? bizOppRefUrl;
  String? sponsorName;
  int directSponsorMin = 0;
  int totalTeamMin = 0;
  int currentDirect = 0;
  int currentTeam = 0;
  bool loading = true;
  bool hasVisitedOpp = false;

  @override
  void initState() {
    super.initState();
    _loadOpportunityData();
  }

  Future<void> _loadOpportunityData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final userData = userDoc.data();
    if (userData == null) return;

    setState(() {
      firstName = userData['firstName'];
      currentDirect = userData['direct_sponsor_count'] ?? 0;
      currentTeam = userData['total_team_count'] ?? 0;
      hasVisitedOpp = userData['biz_visit_date'] != null;
    });

    String? currentUid = userData['referredBy'];
    while (currentUid != null) {
      final refDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      final refData = refDoc.data();
      if (refData != null) {
        if (refData['biz_opp_ref_url'] != null) {
          setState(() {
            bizOppRefUrl = refData['biz_opp_ref_url'];
            sponsorName = '${refData['firstName']} ${refData['lastName']}';
            bizOpp = refData['biz_opp'];
            directSponsorMin = refData['direct_sponsor_min'] ?? 0;
            totalTeamMin = refData['total_team_min'] ?? 0;
          });
          break;
        }
        currentUid = refData['referredBy'];
      } else {
        break;
      }
    }

    setState(() {
      loading = false;
    });
  }

  Future<void> _confirmAndLaunchOpportunity() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Before You Continue'),
        content: Text(
            "Important: After completing your $bizOpp registration, you must add your new $bizOpp referral link to your TeamBuild Pro profile. This will ensure downline members who join $bizOpp after you are automatically placed in your $bizOpp downline."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('I Understand!'),
          ),
        ],
      ),
    );

    if (confirmed == true && bizOppRefUrl != null) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'biz_visit_date': Timestamp.now(),
        });
        setState(() => hasVisitedOpp = true);
      }
      await launchUrl(Uri.parse(bizOppRefUrl!));
    }
  }

  void _handleCompletedRegistrationClick() {
    if (hasVisitedOpp) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const UpdateProfileScreen(),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Visit Required First'),
          content: Text(
              "Before updating your TeamBuild Pro profile with your ‘$bizOpp’ referral link, you must first use the ‘Join Now’ button on this page to visit ‘$bizOpp’ and complete your registration.\n\nThen return to this page to update your TeamBuild Pro profile with your unique ‘$bizOpp’ referral link."),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('I Understand!'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        appBar: AppHeaderWithMenu(),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: const AppHeaderWithMenu(),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Congratulations, $firstName!',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              "You've reached a key milestone in TeamBuild Pro — you've personally sponsored $currentDirect members and your total downline is now $currentTeam.\n\nYou're now eligible to register for $bizOpp!\n\nYour sponsor will be $sponsorName — the first person in your TeamBuild Pro upline who has already registered for $bizOpp. This might be different from your original TeamBuild Pro sponsor.",
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed:
                    bizOppRefUrl != null ? _confirmAndLaunchOpportunity : null,
                child: Text('Join $bizOpp Now!'),
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: GestureDetector(
                onTap: _handleCompletedRegistrationClick,
                child: Text(
                  "I have completed my '$bizOpp' registration.",
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.deepPurple,
                    decoration: TextDecoration.underline,
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
