class UserProfile {
  static const String nonVerifiedStatus = 'Non Verified';
  static const String verifiedStatus = 'Verified';
  static const String viewOnlyStatus = 'View Only';

  static const String currentStudentRole = 'Current Student';
  static const String parentRole = 'Parent';
  static const String prospectiveStudentRole = 'Prospective Student';
  static const String schoolAdministratorRole = 'School Administrator';

  final String email;
  final String displayName;
  final String realName;
  final String studentId;
  final String familyCode;
  final String accountStatus;
  final String accountRole;
  final String? pfpURL;
  final String schoolID;
  final String UID;
  final List<String> parentStudentIds;
  final List<String> parentIds;
  final List<String> studentUids;
  final List<LinkedAccount> linkedAccounts;
  final bool isAdmin;
  final bool isDebug;
  final bool autoCalendarUpdatesEnabled;
  final String googleCalendarId;
  final bool eventSignupNotificationsEnabled;
  final bool clubVisibilityWarningDismissed;
  final String appThemeId;
  final List<String> blockedUserIds;

  UserProfile({
    required this.email,
    required this.displayName,
    required this.realName,
    this.studentId = '',
    this.familyCode = '',
    this.accountStatus = nonVerifiedStatus,
    this.accountRole = currentStudentRole,
    this.pfpURL,
    required this.schoolID,
    required this.UID,
    this.parentStudentIds = const [],
    this.parentIds = const [],
    this.studentUids = const [],
    this.linkedAccounts = const [],
    this.isAdmin = false,
    this.isDebug = false,
    this.autoCalendarUpdatesEnabled = false,
    this.googleCalendarId = '',
    this.eventSignupNotificationsEnabled = true,
    this.clubVisibilityWarningDismissed = false,
    this.appThemeId = 'quilt',
    this.blockedUserIds = const [],
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final accountRole = (map['accountRole'] as String? ?? currentStudentRole)
        .trim();
    final linkedAccounts = _linkedAccountsFromMap(map);
    final linkedStudents = _mergedStringListsFromMap(
      map,
      const [
        'parentStudentIds',
        'studentIds',
        'managedStudentIds',
        'childrenIds',
        'childStudentIds',
        'studentUids',
        'childUIDs',
        'childUids',
      ],
      extra: [
        for (final account in linkedAccounts)
          if (_isLinkedStudentAccount(account, accountRole)) account.uid,
      ],
    );
    final linkedParents = _mergedStringListsFromMap(
      map,
      const [
        'parentIds',
        'parentUIDs',
        'parentUids',
        'guardianUIDs',
        'guardianUids',
      ],
      extra: [
        for (final account in linkedAccounts)
          if (_isLinkedParentAccount(account, accountRole)) account.uid,
      ],
    );

    return UserProfile(
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      realName: map['realName'] as String? ?? '',
      studentId:
          map['studentId'] as String? ?? map['studentID'] as String? ?? '',
      familyCode: map['familyCode'] as String? ?? '',
      accountStatus: (map['accountStatus'] as String? ?? nonVerifiedStatus)
          .trim(),
      accountRole: accountRole,
      pfpURL: map['pfpURL'] as String?,
      schoolID: map['schoolID'] as String? ?? map['school'] as String? ?? '',
      UID: map['UID'] as String? ?? '',
      parentStudentIds: linkedStudents,
      parentIds: linkedParents,
      studentUids: _mergedStringListsFromMap(map, const [
        'studentUids',
        'childUIDs',
        'childUids',
      ], extra: linkedStudents),
      linkedAccounts: linkedAccounts,
      isAdmin: map['isAdmin'] as bool? ?? false,
      isDebug: map['isDebug'] as bool? ?? false,
      autoCalendarUpdatesEnabled:
          map['autoCalendarUpdatesEnabled'] as bool? ?? false,
      googleCalendarId: map['googleCalendarId'] as String? ?? '',
      eventSignupNotificationsEnabled:
          map['eventSignupNotificationsEnabled'] as bool? ?? true,
      clubVisibilityWarningDismissed:
          map['clubVisibilityWarningDismissed'] as bool? ?? false,
      appThemeId: map['appThemeId'] as String? ?? 'quilt',
      blockedUserIds: _stringListFromMap(map, 'blockedUserIds') ?? const [],
    );
  }

  UserProfile copyWith({
    String? email,
    String? displayName,
    String? realName,
    String? studentId,
    String? familyCode,
    String? accountStatus,
    String? accountRole,
    String? pfpURL,
    String? schoolID,
    String? UID,
    List<String>? parentStudentIds,
    List<String>? parentIds,
    List<String>? studentUids,
    List<LinkedAccount>? linkedAccounts,
    bool? isAdmin,
    bool? isDebug,
    bool? autoCalendarUpdatesEnabled,
    String? googleCalendarId,
    bool? eventSignupNotificationsEnabled,
    bool? clubVisibilityWarningDismissed,
    String? appThemeId,
    List<String>? blockedUserIds,
  }) {
    return UserProfile(
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      realName: realName ?? this.realName,
      studentId: studentId ?? this.studentId,
      familyCode: familyCode ?? this.familyCode,
      accountStatus: accountStatus ?? this.accountStatus,
      accountRole: accountRole ?? this.accountRole,
      pfpURL: pfpURL ?? this.pfpURL,
      schoolID: schoolID ?? this.schoolID,
      UID: UID ?? this.UID,
      parentStudentIds: parentStudentIds ?? this.parentStudentIds,
      parentIds: parentIds ?? this.parentIds,
      studentUids: studentUids ?? this.studentUids,
      linkedAccounts: linkedAccounts ?? this.linkedAccounts,
      isAdmin: isAdmin ?? this.isAdmin,
      isDebug: isDebug ?? this.isDebug,
      autoCalendarUpdatesEnabled:
          autoCalendarUpdatesEnabled ?? this.autoCalendarUpdatesEnabled,
      googleCalendarId: googleCalendarId ?? this.googleCalendarId,
      eventSignupNotificationsEnabled:
          eventSignupNotificationsEnabled ??
          this.eventSignupNotificationsEnabled,
      clubVisibilityWarningDismissed:
          clubVisibilityWarningDismissed ?? this.clubVisibilityWarningDismissed,
      appThemeId: appThemeId ?? this.appThemeId,
      blockedUserIds: blockedUserIds ?? this.blockedUserIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'realName': realName,
      'studentId': studentId,
      'familyCode': familyCode,
      'accountStatus': accountStatus,
      'accountRole': accountRole,
      'pfpURL': pfpURL,
      'schoolID': schoolID,
      'school': schoolID,
      'UID': UID,
      'parentStudentIds': parentStudentIds,
      'parentIds': parentIds,
      'studentUids': studentUids,
      'linkedAccounts': linkedAccounts
          .map((account) => account.toMap())
          .toList(),
      'isAdmin': isAdmin,
      'isDebug': isDebug,
      'autoCalendarUpdatesEnabled': autoCalendarUpdatesEnabled,
      'googleCalendarId': googleCalendarId,
      'eventSignupNotificationsEnabled': eventSignupNotificationsEnabled,
      'clubVisibilityWarningDismissed': clubVisibilityWarningDismissed,
      'appThemeId': appThemeId,
      'blockedUserIds': blockedUserIds,
    };
  }

  bool get isCurrentStudent => accountRole == currentStudentRole;

  bool get isParent => accountRole == parentRole;

  bool get isProspectiveStudent => accountRole == prospectiveStudentRole;

  bool get canParticipate =>
      isAdmin || (isCurrentStudent && accountStatus == verifiedStatus);

  bool get isViewOnly => !canParticipate;
}

class LinkedAccount {
  const LinkedAccount({
    required this.uid,
    required this.name,
    required this.role,
    this.relationship = '',
    this.photoUrl,
  });

  final String uid;
  final String name;
  final String role;
  final String relationship;
  final String? photoUrl;

  factory LinkedAccount.fromMap(Map<String, dynamic> map) {
    return LinkedAccount(
      uid: map['uid'] as String? ?? '',
      name: map['name'] as String? ?? '',
      role: map['role'] as String? ?? '',
      relationship: map['relationship'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
    );
  }

  Map<String, String> toMap() {
    return {
      'uid': uid,
      'name': name,
      'role': role,
      'relationship': relationship,
      if (photoUrl != null && photoUrl!.isNotEmpty) 'photoUrl': photoUrl!,
    };
  }
}

List<String>? _stringListFromMap(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is Iterable) {
    return value
        .whereType<String>()
        .where((id) => id.trim().isNotEmpty)
        .toList();
  }
  return null;
}

List<String> _mergedStringListsFromMap(
  Map<String, dynamic> map,
  Iterable<String> keys, {
  Iterable<String> extra = const [],
}) {
  final ids = <String>{};
  for (final key in keys) {
    final values = _stringListFromMap(map, key);
    if (values == null) continue;
    ids.addAll(values.map((id) => id.trim()).where((id) => id.isNotEmpty));
  }
  ids.addAll(extra.map((id) => id.trim()).where((id) => id.isNotEmpty));
  return ids.toList(growable: false);
}

bool _isLinkedStudentAccount(LinkedAccount account, String ownerRole) {
  final role = account.role.trim();
  if (ownerRole != UserProfile.parentRole) {
    return role == UserProfile.currentStudentRole;
  }
  return role != UserProfile.parentRole;
}

bool _isLinkedParentAccount(LinkedAccount account, String ownerRole) {
  final role = account.role.trim();
  return ownerRole == UserProfile.currentStudentRole &&
      role == UserProfile.parentRole;
}

List<LinkedAccount> _linkedAccountsFromMap(Map<String, dynamic> map) {
  final value = map['linkedAccounts'];
  if (value is! Iterable) return const [];

  return value
      .whereType<Map>()
      .map(
        (account) => LinkedAccount.fromMap(Map<String, dynamic>.from(account)),
      )
      .where((account) => account.uid.trim().isNotEmpty)
      .toList();
}
