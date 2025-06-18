import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/downline_service.dart';
import '../screens/member_detail_screen.dart';
import '../widgets/header_widgets.dart';

enum JoinWindow { none, all, last24, last7, last30, newQualified }

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
  bool isLoading = true;
  JoinWindow selectedJoinWindow = JoinWindow.none;
  Map<int, List<UserModel>> downlineByLevel = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int levelOffset = 0;
  List<UserModel> _fullDownlineUsers = [];
  Map<String, int> downlineCounts = {};
  String? uplineBizOpp;
  UserModel? _currentUserModel;

  final DownlineService _downlineService = DownlineService();

  @override
  void initState() {
    super.initState();
    _fetchData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    try {
      final results = await Future.wait([
        _downlineService.getDownline(uid),
        _downlineService.getDownlineCounts(uid),
      ]);

      final allUsers = results[0] as List<UserModel>;
      final counts = results[1] as Map<String, int>;

      if (mounted) {
        try {
          _currentUserModel = allUsers.firstWhere((user) => user.uid == uid);
          // CORRECTED (Line 78): Provide a default value for the nullable 'level'.
          levelOffset = _currentUserModel?.level ?? 1;
        } catch (e) {
          debugPrint(
              "Could not find current user in downline, defaulting level offset.");
          levelOffset = 1;
        }

        _fullDownlineUsers = allUsers.where((user) => user.uid != uid).toList();
        downlineCounts = counts;
        _processDownlineData();
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching downline data: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  bool userMatchesSearch(UserModel user) {
    final query = _searchQuery.toLowerCase();
    return [user.firstName, user.lastName, user.city, user.state, user.country]
        .any((field) => field != null && field.toLowerCase().contains(query));
  }

  void _onSearchChanged() {
    if (_searchQuery != _searchController.text) {
      setState(() {
        _searchQuery = _searchController.text;
        _processDownlineData();
      });
    }
  }

  void _onJoinWindowSelected(JoinWindow window) {
    if (!mounted) return;
    setState(() {
      selectedJoinWindow = window;
    });
    _processDownlineData();
  }

  void _processDownlineData() {
    List<UserModel> filteredUsers = _fullDownlineUsers;

    if (selectedJoinWindow != JoinWindow.all &&
        selectedJoinWindow != JoinWindow.none) {
      final now = DateTime.now();
      DateTime? windowStart;
      switch (selectedJoinWindow) {
        case JoinWindow.last24:
          windowStart = now.subtract(const Duration(hours: 24));
          break;
        case JoinWindow.last7:
          windowStart = now.subtract(const Duration(days: 7));
          break;
        case JoinWindow.last30:
          windowStart = now.subtract(const Duration(days: 30));
          break;
        default:
          break;
      }
      if (windowStart != null) {
        filteredUsers = filteredUsers.where((user) {
          return user.createdAt != null &&
              user.createdAt!.isAfter(windowStart!);
        }).toList();
      }
    }

    if (_searchQuery.isNotEmpty) {
      filteredUsers = filteredUsers.where(userMatchesSearch).toList();
    }

    final newDownlineByLevel = <int, List<UserModel>>{};
    for (var user in filteredUsers) {
      // CORRECTED (Line 164): Provide a default value for the nullable 'level'.
      final int userLevel = user.level;
      (newDownlineByLevel[userLevel] ??= []).add(user);
    }

    newDownlineByLevel.forEach((level, users) {
      users.sort((a, b) => (b.createdAt ?? DateTime(1970))
          .compareTo(a.createdAt ?? DateTime(1970)));
    });

    if (mounted) {
      setState(() {
        downlineByLevel = Map.fromEntries(
          newDownlineByLevel.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key)),
        );
      });
    }
  }

  String _dropdownLabel(JoinWindow window) {
    switch (window) {
      case JoinWindow.last24:
        return 'Joined Previous 24 Hours (${downlineCounts["last24"] ?? 0})';
      case JoinWindow.last7:
        return 'Joined Previous 7 Days (${downlineCounts["last7"] ?? 0})';
      case JoinWindow.last30:
        return 'Joined Previous 30 Days (${downlineCounts["last30"] ?? 0})';
      case JoinWindow.newQualified:
        return 'Qualified Team Members (${downlineCounts["newQualified"] ?? 0})';
      case JoinWindow.all:
        return 'All Team Members (${downlineCounts["all"] ?? 0})';
      case JoinWindow.none:
        return 'Select Downline Report';
    }
  }

  @override
  Widget build(BuildContext context) {
    // CORRECTED (Line 295): Use the non-nullable 'levelOffset' variable.
    final int relativeLevelOffset = levelOffset;

    return Scaffold(
      appBar: AppHeaderWithMenu(appId: widget.appId),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 24.0),
                  child: Center(
                      child: Text('Downline Team',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold))),
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
                    onChanged: (value) => _onJoinWindowSelected(value!),
                    items: JoinWindow.values.map((window) {
                      return DropdownMenuItem(
                          value: window, child: Text(_dropdownLabel(window)));
                    }).toList(),
                  ),
                ),
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
                      onChanged: (value) => _onSearchChanged(),
                    ),
                  ),
                if (uplineBizOpp != null && uplineBizOpp!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8),
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
                                color: Colors.blue),
                          ),
                          const TextSpan(
                              text:
                                  ' however, they have not yet completed their '),
                          TextSpan(
                            text: uplineBizOpp!,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue),
                          ),
                          const TextSpan(text: ' registration.'),
                        ],
                      ),
                    ),
                  ),
                if (!isLoading &&
                    downlineByLevel.isEmpty &&
                    selectedJoinWindow != JoinWindow.none)
                  const Expanded(
                    child: Center(
                      child: Text(
                          'No team members found for the selected filter.',
                          style: TextStyle(fontSize: 16, color: Colors.grey)),
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      children: [
                        ...downlineByLevel.entries.map((entry) {
                          final level = entry.key;
                          final users = entry.value;
                          final displayLevel = level - relativeLevelOffset + 1;
                          int localIndex = 1;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(thickness: 1),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 10),
                                child: Text(
                                    'Level $displayLevel (${users.length})',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue)),
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
                                          Text('$index) ',
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.normal)),
                                          GestureDetector(
                                            onTap: () {
                                              if (!mounted) return;
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      MemberDetailScreen(
                                                    userId: user.uid,
                                                    initialAuthToken:
                                                        widget.initialAuthToken,
                                                    appId: widget.appId,
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Text(
                                              '${user.firstName} ${user.lastName}',
                                              style: const TextStyle(
                                                  color: Colors.blue,
                                                  decoration:
                                                      TextDecoration.underline),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '${' ' * spaceCount}${user.city}, ${user.state} – ${user.country}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.normal),
                                      ),
                                    ],
                                  ),
                                );
                              }),
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
