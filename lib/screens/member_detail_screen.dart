// lib/screens/member_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../widgets/header_widgets.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import 'message_thread_screen.dart';

class MemberDetailScreen extends StatefulWidget {
  final String userId;
  final String appId;

  const MemberDetailScreen({
    super.key,
    required this.userId,
    required this.appId,
  });

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  UserModel? _user;
  // MODIFIED: Removed unused _currentUser field. Data is accessed via Provider.
  // UserModel? _currentUser;
  String? _sponsorName;
  String? _teamLeaderName;
  String? _teamLeaderUid;
  String?
      _currentUserId; // Proactive: Added to store the current user's ID safely.
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
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    _currentUserId = authUser.uid;

    try {
      // MODIFIED: Removed fetching of currentUserDoc as it's unused.
      final userDoc = await _firestoreService.getUser(widget.userId);

      if (!mounted) return;

      setState(() {
        _user = userDoc;
      });

      if (_user?.referredBy != null && _user!.referredBy!.isNotEmpty) {
        final sponsorDoc = await _firestoreService.getUser(_user!.referredBy!);
        if (mounted) {
          setState(() => _sponsorName =
              '${sponsorDoc?.firstName ?? ''} ${sponsorDoc?.lastName ?? ''}');
        }
      }

      if (_user != null && _user!.uplineRefs.isNotEmpty) {
        final teamLeaderId = _user!.uplineRefs.last;
        final leaderDoc = await _firestoreService.getUser(teamLeaderId);
        if (mounted && leaderDoc != null) {
          setState(() {
            _teamLeaderUid = leaderDoc.uid;
            _teamLeaderName = '${leaderDoc.firstName} ${leaderDoc.lastName}';
          });
        }
      }
    } catch (e) {
      _log("Error loading user data: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleSendMessage() {
    // MODIFIED: This guard clause now safely checks the state variables.
    if (_currentUserId == null || _user == null) return;

    // MODIFIED: No '!' assertions are needed because of the guard clause above.
    final ids = [_currentUserId!, _user!.uid];
    ids.sort();
    final threadId = ids.join('_');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessageThreadScreen(
          threadId: threadId,
          appId: widget.appId,
          recipientId: _user!.uid,
          recipientName: '${_user!.firstName ?? ''} ${_user!.lastName ?? ''}',
        ),
      ),
    );
  }

  // MODIFIED: Removed the unsafe getter for _currentUserId.

  @override
  Widget build(BuildContext context) {
    final authUser = Provider.of<UserModel?>(context);
    final bool isCurrentUserAnAdmin = authUser?.role == 'admin';

    return Scaffold(
      appBar: AppHeaderWithMenu(appId: widget.appId),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
              ? const Center(child: Text('Member not found.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage: _user!.photoUrl != null &&
                                  _user!.photoUrl!.isNotEmpty
                              ? NetworkImage(_user!.photoUrl!)
                              : null,
                          child: _user!.photoUrl == null ||
                                  _user!.photoUrl!.isEmpty
                              ? const Icon(Icons.person, size: 50)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          '${_user!.firstName ?? ''} ${_user!.lastName ?? ''}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (isCurrentUserAnAdmin) ...[
                        _buildInfoRow('Email', _user!.email ?? 'N/A'),
                        _buildInfoRow('UID', _user!.uid),
                      ],
                      if (_user!.createdAt != null)
                        _buildInfoRow('Joined',
                            DateFormat.yMMMd().format(_user!.createdAt!)),
                      if (_sponsorName != null)
                        _buildClickableInfoRow(
                            'Sponsor', _sponsorName!, _user!.referredBy!),
                      if (_teamLeaderName != null &&
                          _teamLeaderUid != null &&
                          _user!.referredBy != _teamLeaderUid)
                        _buildClickableInfoRow(
                            'Team Leader', _teamLeaderName!, _teamLeaderUid!),
                      const SizedBox(height: 30),
                      if (_currentUserId != widget.userId)
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

  Widget _buildClickableInfoRow(
      String label, String displayName, String userId) {
    if (userId.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 130,
              child: Text('$label:',
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => MemberDetailScreen(
                          userId: userId, appId: widget.appId))),
              child: Text(
                displayName,
                style: const TextStyle(
                    color: Colors.blue, decoration: TextDecoration.underline),
              ),
            ),
          ),
        ],
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
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
