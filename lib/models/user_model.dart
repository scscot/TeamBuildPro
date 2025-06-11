import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? country;
  final String? state;
  final String? city;
  final String? referralCode;
  final String? referredBy;
  final String? photoUrl;
  final DateTime? joined;
  final DateTime? createdAt;
  final int? level;
  final DateTime? qualifiedDate;
  final String? uplineAdmin;
  final int directSponsorCount; // Changed to lowerCamelCase (Dart style)
  final int totalTeamCount;     // Changed to lowerCamelCase (Dart style)
  final List<String>? downlineIds;
  final String? bizOppRefUrl; // <--- This property is camelCase in Dart
  final String? bizOpp;
  final String? role;
  final DateTime? bizVisitDate;

  UserModel({
    required this.uid,
    this.email,
    this.firstName,
    this.lastName,
    this.country,
    this.state,
    this.city,
    this.referralCode,
    this.referredBy,
    this.photoUrl,
    this.joined,
    this.createdAt,
    this.level,
    this.qualifiedDate,
    this.uplineAdmin,
    this.directSponsorCount = 0, // Default to 0
    this.totalTeamCount = 0,     // Default to 0
    this.downlineIds,
    this.bizOppRefUrl,
    this.bizOpp,
    this.role,
    this.bizVisitDate,
  });

  // Factory method to create a UserModel from a Firestore DocumentSnapshot
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'],
      firstName: data['firstName'],
      lastName: data['lastName'],
      country: data['country'],
      state: data['state'],
      city: data['city'],
      referralCode: data['referralCode'],
      referredBy: data['referredBy'],
      photoUrl: data['photoUrl'],
      joined: (data['createdAt'] is Timestamp) ? (data['createdAt'] as Timestamp).toDate() : DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      createdAt: (data['createdAt'] is Timestamp) ? (data['createdAt'] as Timestamp).toDate() : DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      level: data['level'] is int ? data['level'] : (data['level'] as num?)?.toInt(),
      qualifiedDate: (data['qualified_date'] is Timestamp) ? (data['qualified_date'] as Timestamp).toDate() : DateTime.tryParse(data['qualified_date']?.toString() ?? ''),
      uplineAdmin: data['upline_admin'],
      directSponsorCount: data['direct_sponsor_count'] is int ? data['direct_sponsor_count'] : (data['direct_sponsor_count'] as num?)?.toInt() ?? 0,
      totalTeamCount: data['total_team_count'] is int ? data['total_team_count'] : (data['total_team_count'] as num?)?.toInt() ?? 0,
      downlineIds: (data['downlineIds'] is List) ? List<String>.from(data['downlineIds']) : null,
      bizOppRefUrl: data['biz_opp_ref_url'], // <--- CORRECTED: Access Firestore snake_case
      bizOpp: data['biz_opp'],
      role: data['role'],
      bizVisitDate: (data['biz_visit_date'] is Timestamp) ? (data['biz_visit_date'] as Timestamp).toDate() : DateTime.tryParse(data['biz_visit_date']?.toString() ?? ''),
    );
  }

  // Factory method to create a UserModel from a Map (for SessionManager)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String,
      email: map['email'] as String?,
      firstName: map['firstName'] as String?,
      lastName: map['lastName'] as String?,
      country: map['country'] as String?,
      state: map['state'] as String?,
      city: map['city'] as String?,
      referralCode: map['referralCode'] as String?,
      referredBy: map['referredBy'] as String?,
      photoUrl: map['photoUrl'] as String?,
      joined: (map['joined'] is String) ? DateTime.tryParse(map['joined'] as String) : null,
      createdAt: (map['createdAt'] is String) ? DateTime.tryParse(map['createdAt'] as String) : null,
      level: map['level'] is int ? map['level'] : (map['level'] as num?)?.toInt(),
      qualifiedDate: (map['qualified_date'] is String) ? DateTime.tryParse(map['qualified_date'] as String) : null,
      uplineAdmin: map['upline_admin'] as String?,
      directSponsorCount: map['direct_sponsor_count'] is int ? map['direct_sponsor_count'] : (map['direct_sponsor_count'] as num?)?.toInt() ?? 0,
      totalTeamCount: map['total_team_count'] is int ? map['total_team_count'] : (map['total_team_count'] as num?)?.toInt() ?? 0,
      downlineIds: (map['downlineIds'] is List) ? List<String>.from(map['downlineIds']) : null,
      bizOppRefUrl: map['biz_opp_ref_url'] as String?, // <--- CORRECTED: Access Map snake_case
      bizOpp: map['biz_opp'] as String?,
      role: map['role'] as String?,
      bizVisitDate: (map['biz_visit_date'] is String) ? DateTime.tryParse(map['biz_visit_date'] as String) : null,
    );
  }

  // Method to convert UserModel to a Map (for Firestore writes or session storage)
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'country': country,
      'state': state,
      'city': city,
      'referralCode': referralCode,
      'referredBy': referredBy,
      'photoUrl': photoUrl,
      'joined': joined?.toIso8601String(), // Convert DateTime to String for Firestore
      'createdAt': createdAt?.toIso8601String(), // Convert DateTime to String for Firestore
      'level': level,
      'qualified_date': qualifiedDate?.toIso8601String(), // Convert DateTime to String for Firestore
      'upline_admin': uplineAdmin,
      // Convert Dart camelCase properties to Firestore snake_case for writing
      'direct_sponsor_count': directSponsorCount,
      'total_team_count': totalTeamCount,
      'downlineIds': downlineIds,
      'biz_opp_ref_url': bizOppRefUrl, // <--- CORRECTED: Add 'biz_opp_ref_url' to map
      'biz_opp': bizOpp,
      'role': role,
      'biz_visit_date': bizVisitDate?.toIso8601String(),
    };
  }

  // copyWith method
  UserModel copyWith({
    String? uid,
    String? email,
    String? firstName,
    String? lastName,
    String? country,
    String? state,
    String? city,
    String? referralCode,
    String? referredBy,
    String? photoUrl,
    DateTime? joined,
    DateTime? createdAt,
    int? level,
    DateTime? qualifiedDate,
    String? uplineAdmin,
    int? directSponsorCount,
    int? totalTeamCount,
    List<String>? downlineIds,
    String? bizOppRefUrl,
    String? bizOpp,
    String? role,
    DateTime? bizVisitDate,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      country: country ?? this.country,
      state: state ?? this.state,
      city: city ?? this.city,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
      photoUrl: photoUrl ?? this.photoUrl,
      joined: joined ?? this.joined,
      createdAt: createdAt ?? this.createdAt,
      level: level ?? this.level,
      qualifiedDate: qualifiedDate ?? this.qualifiedDate,
      uplineAdmin: uplineAdmin ?? this.uplineAdmin,
      directSponsorCount: directSponsorCount ?? this.directSponsorCount,
      totalTeamCount: totalTeamCount ?? this.totalTeamCount,
      downlineIds: downlineIds ?? this.downlineIds,
      bizOppRefUrl: bizOppRefUrl ?? this.bizOppRefUrl,
      bizOpp: bizOpp ?? this.bizOpp,
      role: role ?? this.role,
      bizVisitDate: bizVisitDate ?? this.bizVisitDate,
    );
  }
}
