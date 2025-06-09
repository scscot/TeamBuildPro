import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// import 'package:cloud_firestore/cloud_firestore.dart'; // Added for clarity, though it might be transitive
import 'package:flutter/foundation.dart' show kDebugMode; // Import kDebugMode
import 'dart:developer' as developer; // Import for logging

import '../widgets/header_widgets.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../services/session_manager.dart';
import 'message_thread_screen.dart';
import '../services/subscription_service.dart';

class MemberDetailScreen extends StatefulWidget {
  final String userId;

  const MemberDetailScreen({super.key, required this.userId});

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  UserModel? _user; // The member whose profile is being viewed
  UserModel? _currentUser; // The currently logged-in user
  String? _sponsorName;

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
      final currentUser = await SessionManager().getCurrentUser();
      final member = await FirestoreService().getUser(widget.userId);

      if (member != null && currentUser != null) {
        if (!mounted) return; // Check mounted before setState
        setState(() {
          _user = member;
          _currentUser = currentUser;
        });

        if (member.referredBy != null && member.referredBy!.isNotEmpty) {
          final sponsorName = await FirestoreService()
              .getSponsorNameByReferralCode(member.referredBy!);
          if (mounted) {
            _log('✅ Sponsor name resolved: $sponsorName');
            setState(() => _sponsorName = sponsorName);
          }
        }
      } else {
        _log('⚠️ User data or current user data is null. Cannot load member details.');
      }
    } catch (e) {
      _log('❌ Failed to load member: $e');
    }
  }

  // PATCH START: Conditional message access logic based on new requirements
  void _handleSendMessage() {
    // Check if the current user is an admin
    final isAdminUser = _currentUser!.role == 'admin';

    if (!isAdminUser) {
      // If NOT an admin, no restrictions apply. Proceed to message thread.
      _log('ℹ️ Non-admin user sending message. Proceeding without subscription check.');
      _navigateToMessageThread();
      return;
    }

    // If it IS an admin user, perform the subscription check.
    _log('🔎 Admin user attempting to send message. Checking subscription status...');
    SubscriptionService.checkAdminSubscriptionStatus(_currentUser!.uid)
        .then((status) {
      final isActive = status['isActive'] == true;
      final trialExpired = status['trialExpired'] == true;
      if (!mounted) return; // Check if the widget is still mounted

      // Admin user is restricted if trial has expired AND subscription is not active
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
        // Admin user is either in trial, or subscription is active. Proceed.
        _log('✅ Admin user (UID: ${_currentUser!.uid}) is allowed to send message. Proceeding to message thread.');
        _navigateToMessageThread();
      }
    }).catchError((error) {
      // Handle potential errors during subscription status check
      _log('❌ Error checking admin subscription status: $error');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error'),
          content: const Text('Failed to check subscription status. Please try again later.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }

  // Helper method to navigate to the message thread, to avoid code duplication
  void _navigateToMessageThread() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessageThreadScreen(
          recipientId: _user!.uid,
          recipientName: '${_user!.firstName} ${_user!.lastName}',
        ),
      ),
    );
  }
// PATCH END

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeaderWithMenu(), // Corrected: Removed unnecessary new
      body: _user == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage:
                          _user!.photoUrl != null && _user!.photoUrl!.isNotEmpty
                              ? NetworkImage(_user!.photoUrl!)
                              : const AssetImage(
                                      'assets/images/default_avatar.png') // Corrected path
                                  as ImageProvider,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildInfoRow(
                      'Name', '${_user!.firstName} ${_user!.lastName}'),
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
                  const SizedBox(height: 30),
                  // The button now always shows, and its onPressed directly calls _handleSendMessage
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