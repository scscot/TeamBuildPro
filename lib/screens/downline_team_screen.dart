import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../screens/member_detail_screen.dart';
import '../widgets/header_widgets.dart';
// import '../services/session_manager.dart'; // Import SessionManager
// import 'package:flutter/foundation.dart'; // Import for debugPrint

enum JoinWindow {
  none,
  all,
  last24,
  last7,
  last30,
  newQualified,
}

class DownlineTeamScreen extends StatefulWidget {
  final Map<String, dynamic> firebaseConfig;
  final String? initialAuthToken;
  final String appId;

  const DownlineTeamScreen({
    super.key,
    required this.firebaseConfig,
    this.initialAuthToken,
    required this.appId,
  });

  @override
  State<DownlineTeamScreen> createState() => _DownlineTeamScreenState();
}

class _DownlineTeamScreenState extends State<DownlineTeamScreen> {
  bool isLoading = true; // Set to true initially to show spinner
  JoinWindow selectedJoinWindow = JoinWindow.none; // Default to 'none'
  Map<int, List<UserModel>> downlineByLevel = {};
  final currentUserAuth = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;
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
    // Reinstated: _fetchAndListenToCurrentUser now calls fetchDownline() immediately.
    _fetchAndListenToCurrentUser();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _currentUserDocSubscription?.cancel();
    super.dispose();
  }

  // Reverted to immediately trigger fetchDownline after current user data is loaded.
  Future<void> _fetchAndListenToCurrentUser() async {
    if (currentUserAuth == null) {
      debugPrint('No authenticated user found for downline screen.');
      if (mounted) setState(() => isLoading = false);
      return;
    }

    _currentUserDocSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserAuth!.uid)
        .snapshots()
        .listen((docSnapshot) async {
      if (docSnapshot.exists) {
        _currentUserModel = UserModel.fromFirestore(docSnapshot);
        debugPrint('Current user model loaded: ${_currentUserModel?.firstName}');
        fetchDownline(); // Reinstated: Trigger downline fetch immediately
      } else {
        debugPrint('Current user document does not exist for downline screen: ${currentUserAuth!.uid}');
        if (mounted) setState(() => isLoading = false);
      }
    }, onError: (error) {
      debugPrint('Error listening to current user doc: $error');
      if (mounted) setState(() => isLoading = false);
    });
  }

  bool userMatchesSearch(UserModel user) {
    final query = _searchQuery.toLowerCase();
    return [user.firstName, user.lastName, user.city, user.state, user.country]
        .any((field) => field != null && field.toLowerCase().contains(query));
  }

  Future<void> fetchDownline() async {
    if (!mounted) return;
    setState(() => isLoading = true); // Ensure loading is true when fetching

    if (_currentUserModel == null || _currentUserModel!.uid.isEmpty) {
      debugPrint('Current user model is not available.');
      if (mounted) setState(() => isLoading = false);
      return;
    }

    final currentUsersDownlineIds = _currentUserModel!.downlineIds;

    if (currentUsersDownlineIds == null || currentUsersDownlineIds.isEmpty) {
      debugPrint('Current user has no downline IDs.');
      if (mounted) {
        setState(() {
          _fullDownlineUsers = [];
          downlineByLevel = {};
          downlineCounts.updateAll((_, __) => 0);
          isLoading = false;
        });
      }
      return;
    }

    try {
      List<UserModel> fetchedDownlineUsers = [];
      const int batchSize = 10;
      for (int i = 0; i < currentUsersDownlineIds.length; i += batchSize) {
        final batchUids = currentUsersDownlineIds.sublist(
          i,
          i + batchSize > currentUsersDownlineIds.length
              ? currentUsersDownlineIds.length
              : i + batchSize,
        );

        final batchSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: batchUids)
            .get();

        fetchedDownlineUsers.addAll(batchSnapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList());
      }
      _fullDownlineUsers = fetchedDownlineUsers;

      final uplineAdminId = _currentUserModel!.uplineAdmin;
      if (uplineAdminId != null && uplineAdminId.isNotEmpty) {
        final uplineAdminDoc = await FirebaseFirestore.instance
            .collection('admin_settings')
            .doc(uplineAdminId)
            .get();
        if (uplineAdminDoc.exists) {
          if (mounted) {
            setState(() {
              uplineBizOpp = uplineAdminDoc.data()?['biz_opp'];
            });
          }
        }
      }

      levelOffset = _currentUserModel!.level ?? 0;
      final now = DateTime.now();

      downlineCounts.updateAll((_, __) => 0);
      final Map<int, List<UserModel>> grouped = {};

      for (var user in _fullDownlineUsers) {
        if (user.level != null && user.level! > levelOffset) {
          final joined = user.joined;
          final qualified = user.qualifiedDate;

          // Update counts
          if (joined != null) {
            if (joined.isAfter(now.subtract(const Duration(days: 1)))) {
              downlineCounts[JoinWindow.last24] = (downlineCounts[JoinWindow.last24] ?? 0) + 1;
            }
            if (joined.isAfter(now.subtract(const Duration(days: 7)))) {
              downlineCounts[JoinWindow.last7] = (downlineCounts[JoinWindow.last7] ?? 0) + 1;
            }
            if (joined.isAfter(now.subtract(const Duration(days: 30)))) {
              downlineCounts[JoinWindow.last30] = (downlineCounts[JoinWindow.last30] ?? 0) + 1;
            }
          }
          if (qualified != null) {
            downlineCounts[JoinWindow.newQualified] = (downlineCounts[JoinWindow.newQualified] ?? 0) + 1;
          }
          downlineCounts[JoinWindow.all] = (downlineCounts[JoinWindow.all] ?? 0) + 1;

          final include = selectedJoinWindow == JoinWindow.none || // Show all if none selected initially
                          selectedJoinWindow == JoinWindow.all ||
                          (selectedJoinWindow == JoinWindow.last24 && joined != null && joined.isAfter(now.subtract(const Duration(days: 1)))) ||
                          (selectedJoinWindow == JoinWindow.last7 && joined != null && joined.isAfter(now.subtract(const Duration(days: 7)))) ||
                          (selectedJoinWindow == JoinWindow.last30 && joined != null && joined.isAfter(now.subtract(const Duration(days: 30)))) ||
                          (selectedJoinWindow == JoinWindow.newQualified && qualified != null);

          if (include && (_searchQuery.isEmpty || userMatchesSearch(user))) {
            final displayLevel = user.level! - levelOffset;
            grouped.putIfAbsent(displayLevel, () => []).add(user);
          }
        }
      }

      grouped.forEach((level, users) {
        users.sort((a, b) => b.joined?.compareTo(a.joined ?? DateTime(1970)) ?? 0);
      });

      if (!mounted) return;
      setState(() {
        downlineByLevel = Map.fromEntries(
            grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
      });

    } catch (e) {
      debugPrint('Error loading downline: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _dropdownLabel(JoinWindow window) {
    switch (window) {
      case JoinWindow.last24:
        return 'Joined Previous 24 Hours (${downlineCounts[JoinWindow.last24]})';
      case JoinWindow.last7:
        return 'Joined Previous 7 Days (${downlineCounts[JoinWindow.last7]})';
      case JoinWindow.last30:
        return 'Joined Previous 30 Days (${downlineCounts[JoinWindow.last30]})';
      case JoinWindow.newQualified:
        return 'Qualified Team Members (${downlineCounts[JoinWindow.newQualified]})';
      case JoinWindow.all:
        return 'All Team Members (${downlineCounts[JoinWindow.all]})';
      case JoinWindow.none:
        return 'Select Downline Report'; // Hint text
    }
  }

  Future<List<Map<String, dynamic>>> fetchEligibleDownlineUsers() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final settingsDoc = await FirebaseFirestore.instance
        .collection('admin_settings')
        .doc(uid)
        .get();
    if (!settingsDoc.exists) return [];

    final settings = settingsDoc.data();
    final directMin = settings?['direct_sponsor_min'] ?? 1;
    final totalMin = settings?['total_team_min'] ?? 1;
    final allowedCountries = List<String>.from(settings?['countries'] ?? []);

    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('upline_admin', isEqualTo: uid)
        .get();

    return querySnapshot.docs
        .map((doc) => doc.data())
        .where((user) =>
            (user['direct_sponsor_count'] ?? 0) >= directMin &&
            (user['total_team_count'] ?? 0) >= totalMin &&
            allowedCountries.contains(user['country']))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeaderWithMenu(
        firebaseConfig: widget.firebaseConfig,
        initialAuthToken: widget.initialAuthToken,
        appId: widget.appId,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 24.0),
                  child: Center(
                    child: Text(
                      'Downline Team',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: DropdownButtonFormField<JoinWindow>(
                    isExpanded: true,
                    value: selectedJoinWindow,
                    decoration: InputDecoration(
                      labelText: 'Downline Report',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                    onChanged: (value) {
                      if (value != null) {
                        if (!mounted) return;
                        setState(() {
                          selectedJoinWindow = value;
                          _searchQuery = ''; // Reset search on new filter
                        });
                        // Always fetch downline when dropdown value changes
                        // (even if 'none' is selected, to update counts to 0 and clear display)
                        _debounce?.cancel();
                        fetchDownline(); // Always re-fetch data based on new filter
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
                // Only show search field if a specific report type is selected or if 'all' is selected
                if (selectedJoinWindow != JoinWindow.none)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search by name, country, state, city, etc.',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        if (_debounce?.isActive ?? false) _debounce!.cancel();
                        _debounce = Timer(const Duration(milliseconds: 500), () {
                          if (!mounted) return;
                          setState(() => _searchQuery = value);
                          fetchDownline(); // Re-fetch on debounce
                        });
                      },
                      onSubmitted: (value) {
                        if (!mounted) return;
                        setState(() => _searchQuery = value);
                        fetchDownline();
                      },
                    ),
                  ),
                // Only show RichText for NewQualified and if the biz opp exists
                if (selectedJoinWindow == JoinWindow.newQualified && uplineBizOpp != null && uplineBizOpp!.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black),
                        children: [
                          const TextSpan(
                              text:
                                  'These downline members are qualified to join '),
                          TextSpan(
                            text: uplineBizOpp!,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const TextSpan(
                              text:
                                  ' however, they have not yet completed their '),
                          TextSpan(
                            text: uplineBizOpp!,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const TextSpan(text: ' registration.'),
                        ],
                      ),
                    ),
                  ),
                // Display the list or messages based on loading/selection/data presence
                if (!isLoading && selectedJoinWindow == JoinWindow.none)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Select a downline report from the dropdown menu to view.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else if (!isLoading && _fullDownlineUsers.isEmpty && selectedJoinWindow != JoinWindow.none)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No team members found for the selected filter.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else if (!isLoading && _searchQuery.isNotEmpty && downlineByLevel.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No matching team members found for your search.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else if (!isLoading) // Display the list if not loading and data is present
                  Expanded(
                    child: ListView(
                      children: [
                        ...downlineByLevel.entries.map((entry) {
                          final adjustedLevel = entry.key;
                          final users = entry.value;
                          int localIndex = 1;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(thickness: 1),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 10),
                                child: Text(
                                  'Level $adjustedLevel (${users.length})',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue),
                                ),
                              ),
                              ...users.map((user) {
                                final index = localIndex++;
                                final spaceCount = index < 10
                                    ? 4
                                    : index < 100
                                        ? 6
                                        : 7;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0, vertical: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '$index) ',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.normal),
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              if (!mounted) return;
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => MemberDetailScreen(
                                                    userId: user.uid,
                                                    firebaseConfig: widget.firebaseConfig,
                                                    initialAuthToken: widget.initialAuthToken,
                                                    appId: widget.appId,
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Text(
                                              '${user.firstName ?? ''} ${user.lastName ?? ''}',
                                              style: const TextStyle(
                                                  color: Colors.blue,
                                                  decoration:
                                                      TextDecoration.underline),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '${' ' * spaceCount}${user.city ?? ''}, ${user.state ?? ''} – ${user.country ?? ''}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.normal),
                                      ),
                                    ],
                                  ),
                                );
                              })
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
