import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kDebugMode; // Import kDebugMode
import 'dart:developer' as developer; // Import for logging

import 'package:cloud_firestore/cloud_firestore.dart'; // Explicitly add if needed
import '../widgets/header_widgets.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../services/session_manager.dart';
import 'message_thread_screen.dart';
import '../services/subscription_service.dart';

class MemberDetailScreen extends StatefulWidget {
  final String userId;
  // Add required parameters for consistency with current app navigation
  final Map<String, dynamic> firebaseConfig;
  final String? initialAuthToken;
  final String appId;

  const MemberDetailScreen({
    super.key,
    required this.userId,
    required this.firebaseConfig, // Required
    this.initialAuthToken,       // Nullable
    required this.appId,         // Required
  });

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  UserModel? _user; // The member whose profile is being viewed
  UserModel? _currentUser; // The currently logged-in user
  String? _sponsorName;
  String? _uplineAdminName; // New state variable for upline admin name
  String? _uplineAdminUid; // To store the UID of the upline admin
  bool _isLoading = true; // Added loading state

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // A simple log function that only prints in debug mode
  void _log(String message) {
    if (kDebugMode) {
      developer.log(message, name: 'MemberDetailScreen');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final currentUser = await SessionManager().getCurrentUser(); // Corrected SessionManager access
      final member = await FirestoreService().getUser(widget.userId); // This gets UserModel

      if (!mounted) return; // Guard against setState after async gap

      if (member != null && currentUser != null) {
        setState(() {
          _user = member;
          _currentUser = currentUser;
          _isLoading = false; // Set loading to false once data is available
        });

        // --- Retrieve Sponsor Name ---
        if (member.referredBy != null && member.referredBy!.isNotEmpty) {
          _log('🔎 Looking up sponsor name by referralCode: ${member.referredBy}');
          try {
            // FirestoreService().getUserByReferralCode already returns UserModel?
            final sponsorModel = await FirestoreService().getUserByReferralCode(member.referredBy!);
            if (!mounted) return; // Guarded context usage

            if (sponsorModel != null) {
              final sponsorFirstName = sponsorModel.firstName ?? '';
              final sponsorLastName = sponsorModel.lastName ?? '';
              final String resolvedSponsorName = '$sponsorFirstName $sponsorLastName'.trim();
              if (resolvedSponsorName.isNotEmpty) {
                _log('✅ Sponsor name resolved: $resolvedSponsorName');
                setState(() => _sponsorName = resolvedSponsorName);
              } else {
                _log('⚠️ Sponsor name is empty despite user existing for referralCode: ${member.referredBy}');
                setState(() => _sponsorName = null); // Clear if resolved name is empty
              }
            } else {
              _log('❌ Sponsor user document not found for referralCode: ${member.referredBy}');
              setState(() => _sponsorName = null); // Clear if sponsor not found
            }
          } catch (e) {
            _log('❌ Failed to load sponsor data: $e');
          }
        } else {
          setState(() => _sponsorName = null); // Clear if no referredBy
        }

        // --- Retrieve Upline Admin Name ---
        // Access uplineAdmin directly from the member UserModel for this detail screen
        if (member.uplineAdmin != null && member.uplineAdmin!.isNotEmpty) {
          _uplineAdminUid = member.uplineAdmin; // Store upline admin UID
          _log('🔎 Looking up upline admin name by UID: $_uplineAdminUid');
          try {
            final adminUserDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(_uplineAdminUid)
                .get();

            if (!mounted) return; // Guarded context usage

            if (adminUserDoc.exists) {
              final adminData = adminUserDoc.data();
              if (adminData != null) {
                final adminFirstName = adminData['firstName'] ?? '';
                final adminLastName = adminData['lastName'] ?? '';
                final String resolvedUplineAdminName = '$adminFirstName $adminLastName'.trim();
                if (resolvedUplineAdminName.isNotEmpty) {
                  _log('✅ Upline admin name resolved: $resolvedUplineAdminName');
                  setState(() => _uplineAdminName = resolvedUplineAdminName);
                } else {
                  _log('⚠️ Upline admin name is empty despite user existing for UID: $_uplineAdminUid.');
                }
              }
            } else {
              _log('❌ Upline admin user document not found for UID: $_uplineAdminUid');
            }
          } catch (e) {
            _log('❌ Failed to load upline admin data: $e');
          }
        } else {
          _log('ℹ️ Member has no upline_admin specified.');
          if (mounted) setState(() => _uplineAdminName = null); // Clear if no upline admin
        }

      } else {
        _log('⚠️ User data or current user data is null. Cannot load member details.');
        if (!mounted) setState(() => _isLoading = false); // Ensure loading is off even if data is null
      }
    } catch (e) {
      _log('❌ Failed to load member: $e');
      if (!mounted) setState(() => _isLoading = false); // Ensure loading is off on error
    }
  }

  // PATCH START: Conditional message access logic based on new requirements
  void _handleSendMessage() {
    if (_currentUser == null || _user == null) {
      _log('Cannot send message: Current user or target user is null.');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot send message: User data not loaded.')),
      );
      return;
    }

    final isAdminUser = _currentUser!.role == 'admin';

    if (!isAdminUser) {
      _log('ℹ️ Non-admin user sending message. Proceeding without subscription check.');
      _navigateToMessageThread();
      return;
    }

    _log('🔎 Admin user attempting to send message. Checking subscription status...');
    SubscriptionService.checkAdminSubscriptionStatus(_currentUser!.uid)
        .then((status) {
      final isActive = status['isActive'] == true;
      final trialExpired = status['trialExpired'] == true;
      if (!mounted) return;

      if (trialExpired && !isActive) {
        _log('⚠️ Admin user (UID: ${_currentUser!.uid}) is restricted: Trial expired AND subscription not active. Showing subscription dialog.');
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Subscription Required'),
            content: const Text(
                'Your admin trial has ended or your subscription is not active. Please activate your subscription to continue messaging.'),
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
      } else {
        _log('✅ Admin user (UID: ${_currentUser!.uid}) is allowed to send message. Proceeding to message thread.');
        _navigateToMessageThread();
      }
    }).catchError((error) {
      _log('❌ Error checking admin subscription status: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to check subscription status: ${error.toString()}. Please try again later.')),
      );
    });
  }

  // Helper method to navigate to the message thread, to avoid code duplication
  void _navigateToMessageThread() {
    if (!mounted) return;
    if (_user == null || _currentUser == null) {
      debugPrint('Target user or current user is null, cannot navigate to message thread.');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot open chat: User data missing.')),
      );
      return;
    }

    final threadId = _currentUser!.uid.compareTo(_user!.uid) < 0
        ? '${_currentUser!.uid}_${_user!.uid}'
        : '${_user!.uid}_${_currentUser!.uid}';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessageThreadScreen(
          threadId: threadId,
          firebaseConfig: widget.firebaseConfig,
          initialAuthToken: widget.initialAuthToken,
          appId: widget.appId,
          recipientId: _user!.uid, // Pass recipient's UID
          recipientName: '${_user!.firstName ?? ''} ${_user!.lastName ?? ''}'.trim(), // Pass recipient's full name
        ),
      ),
    );
  }
// PATCH END

  @override
  void dispose() {
    // Cancel the subscription if it was initialized
    // Ensure you also cancel _userProfileSubscription if you have one active from _loadUserData
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isCurrentUserUserRole = _currentUser?.role == 'user'; // For 'Team Leader' conditional display

    if (_isLoading) {
      return Scaffold(
        appBar: AppHeaderWithMenu( // Pass required args
          firebaseConfig: widget.firebaseConfig,
          initialAuthToken: widget.initialAuthToken,
          appId: widget.appId,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null || _currentUser == null) {
      return Scaffold(
        appBar: AppHeaderWithMenu( // Pass required args
          firebaseConfig: widget.firebaseConfig,
          initialAuthToken: widget.initialAuthToken,
          appId: widget.appId,
        ),
        body: const Center(child: Text('Error loading member details or current user data.')),
      );
    }

    return Scaffold(
      appBar: AppHeaderWithMenu( // Pass required args
        firebaseConfig: widget.firebaseConfig,
        initialAuthToken: widget.initialAuthToken,
        appId: widget.appId,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundImage:
                    _user!.photoUrl != null && _user!.photoUrl!.isNotEmpty
                        ? NetworkImage(_user!.photoUrl!)
                        : const AssetImage(
                                'assets/images/default_avatar.png') // Ensure this asset exists or provide placeholder
                            as ImageProvider,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                '${_user!.firstName ?? ''} ${_user!.lastName ?? ''}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            // These info rows are based on your original request for this file
            // _buildInfoRow('Name', '${_user!.firstName} ${_user!.lastName}'),
            _buildInfoRow('City', _user!.city ?? 'N/A'),
            _buildInfoRow('State/Province', _user!.state ?? 'N/A'),
            _buildInfoRow('Country', _user!.country ?? 'N/A'),
            _buildInfoRow(
                'Join Date',
                _user!.createdAt != null
                    ? DateFormat.yMMMMd().format(_user!.createdAt!)
                    : 'N/A',
            ),
            if (_sponsorName != null && _sponsorName!.isNotEmpty)
              _buildInfoRow('Sponsor Name', _sponsorName!),
            // START: Conditional Team Leader display based on your original code snippet
            if (_uplineAdminName != null &&
                _uplineAdminName!.isNotEmpty &&
                _uplineAdminUid != null &&
                _user!.referredBy != _user!.uplineAdmin && // Only if directly referred by someone else
                isCurrentUserUserRole) // Only display for 'user' role current user
              _buildInfoRow('Team Leader', _uplineAdminName!),
            // END: Conditional Team Leader display

            const SizedBox(height: 30),
            Center(
              child: ElevatedButton.icon(
                onPressed: _handleSendMessage, // This is where the new logic triggers
                icon: const Icon(Icons.message),
                label: const Text('Send Message'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 12.0),
                  textStyle: const TextStyle(fontSize: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
