import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/header_widgets.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import 'message_thread_screen.dart';
import '../services/subscription_service.dart';

class MemberDetailScreen extends StatefulWidget {
  final String userId;
  final String? initialAuthToken;
  final String appId;

  const MemberDetailScreen({
    super.key,
    required this.userId,
    this.initialAuthToken,
    required this.appId,
  });

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  UserModel? _user;
  UserModel? _currentUser;
  String? _sponsorName;
  String? _uplineAdminName;
  String? _uplineAdminUid;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _log(String message) {
    if (kDebugMode) {
      developer.log(message, name: 'MemberDetailScreen');
    }
  }

  Future<void> _loadUserData() async {
    // FIX: Use FirebaseAuth as the source of truth for the current user
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      _log('❌ Current user is not authenticated.');
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(authUser.uid)
          .get();
      final member = await FirestoreService().getUser(widget.userId);

      if (!mounted) return;

      if (member != null && currentUserDoc.exists) {
        setState(() {
          _user = member;
          _currentUser = UserModel.fromFirestore(currentUserDoc);
          _isLoading = false;
        });

        // ... rest of the logic to fetch sponsor/upline names is safe to run now
        _fetchSponsorAndUplineNames(member);
      } else {
        _log('⚠️ Member or current user document not found.');
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      _log('❌ Failed to load user data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSponsorAndUplineNames(UserModel member) async {
    if (member.referredBy != null && member.referredBy!.isNotEmpty) {
      try {
        final sponsorModel =
            await FirestoreService().getUserByReferralCode(member.referredBy!);
        if (mounted && sponsorModel != null) {
          setState(() => _sponsorName =
              '${sponsorModel.firstName ?? ''} ${sponsorModel.lastName ?? ''}'
                  .trim());
        }
      } catch (e) {
        _log('❌ Failed to load sponsor data: $e');
      }
    }

    if (member.uplineAdmin != null && member.uplineAdmin!.isNotEmpty) {
      _uplineAdminUid = member.uplineAdmin;
      try {
        final adminUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_uplineAdminUid)
            .get();
        if (mounted && adminUserDoc.exists) {
          final adminData = adminUserDoc.data();
          if (adminData != null) {
            setState(() => _uplineAdminName =
                '${adminData['firstName'] ?? ''} ${adminData['lastName'] ?? ''}'
                    .trim());
          }
        }
      } catch (e) {
        _log('❌ Failed to load upline admin data: $e');
      }
    }
  }

  // ... The rest of your file (_handleSendMessage, build, etc.) remains the same
  void _handleSendMessage() {
    if (_currentUser == null || _user == null) {
      _log('Cannot send message: Current user or target user is null.');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cannot send message: User data not loaded.')),
      );
      return;
    }

    final isAdminUser = _currentUser!.role == 'admin';

    if (!isAdminUser) {
      _log(
          'ℹ️ Non-admin user sending message. Proceeding without subscription check.');
      _navigateToMessageThread();
      return;
    }

    _log(
        '🔎 Admin user attempting to send message. Checking subscription status...');
    SubscriptionService.checkAdminSubscriptionStatus(_currentUser!.uid)
        .then((status) {
      final isActive = status['isActive'] == true;
      final trialExpired = status['trialExpired'] == true;
      if (!mounted) return;

      if (trialExpired && !isActive) {
        _log(
            '⚠️ Admin user (UID: ${_currentUser!.uid}) is restricted: Trial expired AND subscription not active. Showing subscription dialog.');
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
        _log(
            '✅ Admin user (UID: ${_currentUser!.uid}) is allowed to send message. Proceeding to message thread.');
        _navigateToMessageThread();
      }
    }).catchError((error) {
      _log('❌ Error checking admin subscription status: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Failed to check subscription status: ${error.toString()}. Please try again later.')),
      );
    });
  }

  void _navigateToMessageThread() {
    if (!mounted) return;
    if (_user == null || _currentUser == null) {
      debugPrint(
          'Target user or current user is null, cannot navigate to message thread.');
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
          appId: widget.appId,
          recipientId: _user!.uid,
          recipientName:
              '${_user!.firstName ?? ''} ${_user!.lastName ?? ''}'.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isCurrentUserUserRole = _currentUser?.role == 'user';

    if (_isLoading) {
      return Scaffold(
        appBar: AppHeaderWithMenu(
          appId: widget.appId,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null || _currentUser == null) {
      return Scaffold(
        appBar: AppHeaderWithMenu(
          appId: widget.appId,
        ),
        body: const Center(
            child: Text('Error loading member details or current user data.')),
      );
    }

    return Scaffold(
      appBar: AppHeaderWithMenu(
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
                        : const AssetImage('assets/images/default_avatar.png')
                            as ImageProvider,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                '${_user!.firstName ?? ''} ${_user!.lastName ?? ''}',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
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
            if (_uplineAdminName != null &&
                _uplineAdminName!.isNotEmpty &&
                _uplineAdminUid != null &&
                _user!.referredBy != _user!.uplineAdmin &&
                isCurrentUserUserRole)
              _buildInfoRow('Team Leader', _uplineAdminName!),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton.icon(
                onPressed: _handleSendMessage,
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
