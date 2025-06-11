import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart'; // Ensure url_launcher is in pubspec.yaml
import '../widgets/header_widgets.dart';
import 'update_profile_screen.dart'; // Ensure this screen exists
// import '../services/session_manager.dart'; // Removed unused import
import '../models/user_model.dart'; // For UserModel

class JoinOpportunityScreen extends StatefulWidget {
  // Add required parameters for consistency with current app navigation
  final Map<String, dynamic> firebaseConfig;
  final String? initialAuthToken;
  final String appId;

  const JoinOpportunityScreen({
    super.key,
    required this.firebaseConfig, // Required
    this.initialAuthToken, // Nullable
    required this.appId, // Required
  });

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
    if (uid == null) {
      debugPrint('User not authenticated for Join Opportunity screen.');
      if (!mounted) return;
      setState(() => loading = false);
      return;
    }

    try {
      final userDocSnapshot =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!userDocSnapshot.exists) {
        debugPrint('User document does not exist for UID: $uid');
        if (!mounted) return;
        setState(() => loading = false);
        return;
      }
      final userData =
          UserModel.fromFirestore(userDocSnapshot); // Use fromFirestore

      if (!mounted) return; // Guard against setState after async gap

      setState(() {
        firstName = userData.firstName;
        currentDirect = userData.directSponsorCount; // Use camelCase
        currentTeam = userData.totalTeamCount; // Use camelCase
        hasVisitedOpp =
            userData.bizVisitDate != null; // Use bizVisitDate from UserModel
      });

      // Traverse referredBy chain to find the nearest sponsor with bizOppRefUrl
      String? currentTraversalUid = userData.referredBy;
      UserModel? sponsorWithOpp;

      while (currentTraversalUid != null && currentTraversalUid.isNotEmpty) {
        final refDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentTraversalUid)
            .get();
        if (!refDoc.exists) {
          debugPrint(
              'ReferredBy user document not found: $currentTraversalUid');
          break;
        }
        final refUserData =
            UserModel.fromFirestore(refDoc); // Use fromFirestore

        // Check if this sponsor has the bizOppRefUrl
        if (refUserData.bizOppRefUrl != null &&
            refUserData.bizOppRefUrl!.isNotEmpty) {
          sponsorWithOpp = refUserData;
          break; // Found the closest sponsor with an opportunity
        }
        currentTraversalUid = refUserData.referredBy; // Move up the chain
      }

      // If no direct upline sponsor has bizOppRefUrl, fallback to the top-level admin
      // (as per your generateUsers.js, where upline_admin is the top-level admin)
      if (sponsorWithOpp == null &&
          userData.uplineAdmin != null &&
          userData.uplineAdmin!.isNotEmpty) {
        final adminDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userData.uplineAdmin)
            .get();
        if (adminDoc.exists) {
          final adminData = UserModel.fromFirestore(adminDoc);
          if (adminData.bizOppRefUrl != null &&
              adminData.bizOppRefUrl!.isNotEmpty) {
            sponsorWithOpp = adminData;
          }
        }
      }

      if (!mounted) return; // Guard against setState after async gap

      setState(() {
        if (sponsorWithOpp != null) {
          bizOppRefUrl = sponsorWithOpp.bizOppRefUrl;
          sponsorName =
              '${sponsorWithOpp.firstName ?? ''} ${sponsorWithOpp.lastName ?? ''}'
                  .trim();
          bizOpp = sponsorWithOpp
              .bizOpp; // Now accessing the bizOpp field from UserModel
          directSponsorMin = sponsorWithOpp.directSponsorCount;
          totalTeamMin = sponsorWithOpp.totalTeamCount;
        }
        loading = false;
      });
    } catch (e) {
      debugPrint('Error loading opportunity data: $e');
      if (!mounted) return;
      setState(() => loading = false);
      // Optionally show error to user
    }
  }

  // Removed _parseTimestamp method as it's no longer used.

  Future<void> _confirmAndLaunchOpportunity() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Before You Continue'),
        content: Text(
            "Important: After completing your ${bizOpp ?? 'business opportunity'} registration, you must add your new ${bizOpp ?? 'business opportunity'} referral link to your TeamBuild Pro profile. This will ensure downline members who join ${bizOpp ?? 'business opportunity'} after you are automatically placed in your ${bizOpp ?? 'business opportunity'} downline."),
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

    if (!mounted) return; // Guard before using context after dialog

    if (confirmed == true && bizOppRefUrl != null) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'biz_visit_date':
              FieldValue.serverTimestamp(), // Update biz_visit_date
        });
        if (!mounted) return; // Guard before setState
        setState(() => hasVisitedOpp = true);
      }
      // Check if URL can be launched before attempting
      if (await canLaunchUrl(Uri.parse(bizOppRefUrl!))) {
        await launchUrl(Uri.parse(bizOppRefUrl!));
      } else {
        debugPrint('Could not launch $bizOppRefUrl');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $bizOppRefUrl')),
        );
      }
    }
  }

  void _handleCompletedRegistrationClick() {
    if (hasVisitedOpp) {
      if (!mounted) return; // Guarded context usage
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UpdateProfileScreen(
            // Pass required args
            firebaseConfig: widget.firebaseConfig,
            initialAuthToken: widget.initialAuthToken,
            appId: widget.appId,
          ),
        ),
      );
    } else {
      if (!mounted) return; // Guarded context usage
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Visit Required First'),
          content: Text(
              "Before updating your TeamBuild Pro profile with your ‘${bizOpp ?? 'business opportunity'}’ referral link, you must first use the ‘Join Now’ button on this page to visit ‘${bizOpp ?? 'business opportunity'}’ and complete your registration.\n\nThen return to this page to update your TeamBuild Pro profile with your unique ‘${bizOpp ?? 'business opportunity'}’ referral link."),
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
      return Scaffold(
        appBar: AppHeaderWithMenu(
          // Pass required args
          firebaseConfig: widget.firebaseConfig,
          initialAuthToken: widget.initialAuthToken,
          appId: widget.appId,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppHeaderWithMenu(
        // Pass required args
        firebaseConfig: widget.firebaseConfig,
        initialAuthToken: widget.initialAuthToken,
        appId: widget.appId,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              // Center the entire row horizontally
              child: Row(
                // Row to arrange icon, text, icon horizontally
                mainAxisSize: MainAxisSize
                    .min, // Make the Row only as wide as its children
                children: [
                  Icon(
                    Icons.celebration, // Left icon
                    color: Colors.amber,
                    size: 28,
                  ),
                  const SizedBox(width: 8), // Space between left icon and text
                  Text(
                    'Congratulations', // Your Text
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8), // Space between text and right icon
                  Icon(
                    Icons.celebration, // Right icon
                    color: Colors.amber,
                    size: 28,
                  ),
                ],
              ),
            ),

            const SizedBox(
                width: 8), // Add some spacing between the icon and text

            Center(
              child: Text(
                firstName ?? 'Team Member',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black, fontSize: 16),
                children: [
                  const TextSpan(
                    text:
                        "You've reached a key milestone in TeamBuild Pro — you've personally sponsored ",
                  ),
                  TextSpan(
                      text: '$currentDirect',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(
                      text: " members and your total downline is now "),
                  TextSpan(
                      text: '$currentTeam',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(
                      text: ".\n\nYou're now eligible to register for "),
                  TextSpan(
                    text: bizOpp ?? 'your business opportunity',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: "!\n\nYour sponsor will be "),
                  TextSpan(
                    text: sponsorName ?? 'an upline Team Leader',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(
                      text:
                          " — the first person in your TeamBuild Pro upline who has already registered for "),
                  TextSpan(
                    text: bizOpp ?? 'your business opportunity',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(
                      text:
                          ". This might be different from your original TeamBuild Pro sponsor."),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed:
                    bizOppRefUrl != null ? _confirmAndLaunchOpportunity : null,
                child: Text(
                  'Join ${bizOpp ?? 'Opportunity'} Now!',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 32),

            Center(
              child: Text(
                'Very Important Followup Step!',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red, // Added color: Colors.red
                ),
              ),
            ),

            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black, fontSize: 16),
                children: [
                  const TextSpan(
                    text: "After joining ",
                  ),
                  TextSpan(
                    text: bizOpp ?? 'your business opportunity',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(
                    text:
                        ", add your referral link to your TeamBuild Pro profile. This ensures any downline members who join after you are automatically placed in your ",
                  ),
                  TextSpan(
                    text: bizOpp ?? 'your business opportunity',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(
                    text: " downline.",
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),
            Center(
              child: ElevatedButton(
                onPressed: _handleCompletedRegistrationClick,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(8.0), // Internal padding
                ),
                child: const Text(
                  "I have completed my 'business opportunity' registration. Add my referral link now!",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
