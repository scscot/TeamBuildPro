import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Import for debugPrint
import '../models/user_model.dart';
import '../services/downline_service.dart';
import '../screens/member_detail_screen.dart';
import '../widgets/header_widgets.dart';

// CORRECTED: Unused import removed

enum JoinWindow {
  none,
  all,
  last24,
  last7,
  last30,
  newQualified,
}

class DownlineTeamScreen extends StatefulWidget {
  final String? initialAuthToken;
  final String appId;

  const DownlineTeamScreen({
    super.key,
    this.initialAuthToken,
    required this.appId,
  });

  @override
  State<DownlineTeamScreen> createState() => _DownlineTeamScreenState();
}

class _DownlineTeamScreenState extends State<DownlineTeamScreen> {
  final DownlineService _downlineService = DownlineService();
  bool isLoading = true;
  JoinWindow selectedJoinWindow = JoinWindow.none;
  Map<int, List<UserModel>> downlineByLevel = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int levelOffset = 0;
  List<UserModel> _fullDownlineUsers = [];
  Map<JoinWindow, int> downlineCounts = {
    JoinWindow.all: 0,
    JoinWindow.last24: 0,
    JoinWindow.last7: 0,
    JoinWindow.last30: 0,
    JoinWindow.newQualified: 0,
  };
  String? uplineBizOpp;
  StreamSubscription? _currentUserDocSubscription;
  UserModel? _currentUserModel;

  @override
  void initState() {
    super.initState();
    _fetchAndListenToCurrentUser();
    _searchController.addListener(() {
      if (_searchQuery != _searchController.text) {
        setState(() {
          _searchQuery = _searchController.text;
        });
        _processDownlineData();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _currentUserDocSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchAndListenToCurrentUser() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    _currentUserDocSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(authUser.uid)
        .snapshots()
        .listen((docSnapshot) {
      if (docSnapshot.exists && mounted) {
        final newUserModel = UserModel.fromMap(docSnapshot.data()!);
        if (_currentUserModel == null ||
            _currentUserModel!.level != newUserModel.level) {
          setState(() {
            _currentUserModel = newUserModel;
            levelOffset = _currentUserModel?.level ?? 1;
          });
          fetchDataForSelectedWindow();
        } else {
          _currentUserModel = newUserModel;
        }
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    }, onError: (error) {
      if (mounted) setState(() => isLoading = false);
    });
  }

  Future<void> fetchDataForSelectedWindow() async {
    if (selectedJoinWindow == JoinWindow.none || !mounted) {
      setState(() => isLoading = false);
      return;
    }

    setState(() => isLoading = true);

    try {
      final results = await Future.wait([
        _downlineService.getDownline(),
        _downlineService.getDownlineCounts(),
      ]);

      if (!mounted) return;

      final downlineUsers = results[0] as List<UserModel>;
      final counts = results[1] as Map<String, int>;

      setState(() {
        _fullDownlineUsers = downlineUsers;
        downlineCounts = {
          JoinWindow.all: counts['all'] ?? 0,
          JoinWindow.last24: counts['last24'] ?? 0,
          JoinWindow.last7: counts['last7'] ?? 0,
          JoinWindow.last30: counts['last30'] ?? 0,
          JoinWindow.newQualified: counts['newQualified'] ?? 0,
        };
      });

      _processDownlineData();
    } catch (e) {
      // CORRECTED: avoid_print
      debugPrint('Error fetching downline data: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _processDownlineData() {
    if (_currentUserModel == null || !mounted) return;

    final Map<int, List<UserModel>> grouped = {};
    final now = DateTime.now();

    for (var user in _fullDownlineUsers) {
      final joined = user.createdAt;
      final qualified = user.qualifiedDate;

      bool include = false;
      switch (selectedJoinWindow) {
        case JoinWindow.all:
          include = true;
          break;
        case JoinWindow.last24:
          include = joined != null &&
              joined.isAfter(now.subtract(const Duration(days: 1)));
          break;
        case JoinWindow.last7:
          include = joined != null &&
              joined.isAfter(now.subtract(const Duration(days: 7)));
          break;
        case JoinWindow.last30:
          include = joined != null &&
              joined.isAfter(now.subtract(const Duration(days: 30)));
          break;
        case JoinWindow.newQualified:
          include = qualified != null;
          break;
        case JoinWindow.none:
          break;
      }

      if (include && (_searchQuery.isEmpty || userMatchesSearch(user))) {
        final displayLevel = user.level - levelOffset;
        if (displayLevel > 0) {
          grouped.putIfAbsent(displayLevel, () => []).add(user);
        }
      }
    }

    grouped.forEach((level, users) {
      users.sort((a, b) => (b.createdAt ?? DateTime(1970))
          .compareTo(a.createdAt ?? DateTime(1970)));
    });

    setState(() {
      downlineByLevel = Map.fromEntries(
          grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    });
  }

  bool userMatchesSearch(UserModel user) {
    final query = _searchQuery.toLowerCase();
    return [
      user.firstName,
      user.lastName,
      user.email,
      user.city,
      user.state,
      user.country
    ].any((field) => field != null && field.toLowerCase().contains(query));
  }

  String _dropdownLabel(JoinWindow window) {
    final count = downlineCounts[window] ?? 0;
    switch (window) {
      case JoinWindow.last24:
        return 'Joined in last 24 Hours ($count)';
      case JoinWindow.last7:
        return 'Joined in last 7 Days ($count)';
      case JoinWindow.last30:
        return 'Joined in last 30 Days ($count)';
      case JoinWindow.newQualified:
        return 'Qualified Team Members ($count)';
      case JoinWindow.all:
        return 'All Team Members ($count)';
      case JoinWindow.none:
        return 'Select Downline Report';
    }
  }

  @override
  Widget build(BuildContext context) {
    // UI Code remains the same...
    return Scaffold(
      appBar: AppHeaderWithMenu(appId: widget.appId),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 24.0, bottom: 8.0),
            child: Center(
              child: Text(
                'Downline Team',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: DropdownButtonFormField<JoinWindow>(
              isExpanded: true,
              value: selectedJoinWindow,
              decoration: InputDecoration(
                labelText: 'Downline Report',
                filled: true,
                fillColor: Colors.grey.shade100,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedJoinWindow = value;
                    _searchController.clear();
                    _searchQuery = '';
                    downlineByLevel.clear();
                  });
                  fetchDataForSelectedWindow();
                }
              },
              items: JoinWindow.values.map((window) {
                return DropdownMenuItem(
                  value: window,
                  child: Text(_dropdownLabel(window)),
                );
              }).toList(),
            ),
          ),
          if (selectedJoinWindow != JoinWindow.none)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search your downline...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (selectedJoinWindow == JoinWindow.none) {
      return const Center(
        child: Text(
          'Select a downline report to begin.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (downlineByLevel.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isNotEmpty
              ? 'No team members match your search.'
              : 'No team members found for this filter.',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView(
      children: downlineByLevel.entries.map((entry) {
        final level = entry.key;
        final users = entry.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
              child: Text(
                'Level $level (${users.length})',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue),
              ),
            ),
            const Divider(thickness: 1, height: 1),
            ...users.map((user) => _buildUserTile(user)),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildUserTile(UserModel user) {
    return ListTile(
      contentPadding: EdgeInsets.only(
          left: 16.0 + (10 * (user.level - levelOffset - 1)), right: 16.0),
      leading: CircleAvatar(
        backgroundImage: (user.photoUrl != null && user.photoUrl!.isNotEmpty)
            ? NetworkImage(user.photoUrl!)
            : null,
        child: (user.photoUrl == null || user.photoUrl!.isEmpty)
            ? const Icon(Icons.person)
            : null,
      ),
      title: Text('${user.firstName ?? ''} ${user.lastName ?? ''}'),
      subtitle: Text('${user.city ?? ''}, ${user.state ?? ''}'),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MemberDetailScreen(
              userId: user.uid,
              appId: widget.appId,
            ),
          ),
        );
      },
    );
  }
}
