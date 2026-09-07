import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'post_attachment.dart';

class PostAcknowledgement {
  const PostAcknowledgement({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    required this.acknowledgedAt,
  });

  final String uid;
  final String displayName;
  final String? photoUrl;
  final DateTime acknowledgedAt;

  factory PostAcknowledgement.fromMap(Map<String, dynamic> map) {
    final rawAcknowledgedAt = map['acknowledgedAt'];

    return PostAcknowledgement(
      uid: map['uid'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      acknowledgedAt: rawAcknowledgedAt is Timestamp
          ? rawAcknowledgedAt.toDate()
          : rawAcknowledgedAt is DateTime
          ? rawAcknowledgedAt
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'acknowledgedAt': Timestamp.fromDate(acknowledgedAt),
    };
  }
}

class ClubInfo {
  final String id;
  final String title;
  final String tagline;
  final String description;
  final String meetingTime;
  final String location;
  final Color accentColor;
  final String? imageUrl;
  final String groupChatUrl;
  final String supervisorName;
  final String supervisorEmail;
  final String supervisorPhone;
  final String presidentName;
  final String presidentEmail;
  final String presidentPhone;
  final List<String> highlights;
  final List<ClubQuickLink> quickLinks;

  const ClubInfo({
    required this.id,
    required this.title,
    required this.tagline,
    required this.description,
    required this.meetingTime,
    required this.location,
    required this.accentColor,
    required this.highlights,
    this.imageUrl,
    this.groupChatUrl = '',
    this.supervisorName = '',
    this.supervisorEmail = '',
    this.supervisorPhone = '',
    this.presidentName = '',
    this.presidentEmail = '',
    this.presidentPhone = '',
    this.quickLinks = const [],
  });

  static int _accentColorValue(dynamic raw) {
    if (raw == null) return 0xFFB30000;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString()) ?? 0xFFB30000;
  }

  factory ClubInfo.fromMap(Map<String, dynamic> map, String id) {
    return ClubInfo(
      id: id,
      title: map['title'] as String? ?? '',
      tagline: map['tagline'] as String? ?? '',
      description: map['description'] as String? ?? '',
      meetingTime: map['meetingTime'] as String? ?? '',
      location: map['location'] as String? ?? '',
      accentColor: Color(_accentColorValue(map['accentColor'])),
      highlights:
          (map['highlights'] as List?)?.map((e) => e.toString()).toList() ?? [],
      imageUrl: map['imageUrl'] as String?,
      groupChatUrl:
          map['groupChatUrl'] as String? ??
          map['discordUrl'] as String? ??
          map['chatUrl'] as String? ??
          '',
      supervisorName:
          map['supervisorName'] as String? ??
          map['teacherName'] as String? ??
          map['advisorName'] as String? ??
          '',
      supervisorEmail:
          map['supervisorEmail'] as String? ??
          map['advisorEmail'] as String? ??
          '',
      supervisorPhone:
          map['supervisorPhone'] as String? ??
          map['advisorPhone'] as String? ??
          '',
      presidentName: map['presidentName'] as String? ?? '',
      presidentEmail: map['presidentEmail'] as String? ?? '',
      presidentPhone: map['presidentPhone'] as String? ?? '',
      quickLinks: (map['quickLinks'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((link) => ClubQuickLink.fromMap(Map<String, dynamic>.from(link)))
          .where((link) => link.hasContent)
          .toList(),
    );
  }

  ClubInfo copyWith({
    String? title,
    String? tagline,
    String? description,
    String? meetingTime,
    String? location,
    Color? accentColor,
    String? imageUrl,
    String? groupChatUrl,
    String? supervisorName,
    String? supervisorEmail,
    String? supervisorPhone,
    String? presidentName,
    String? presidentEmail,
    String? presidentPhone,
    List<String>? highlights,
    List<ClubQuickLink>? quickLinks,
  }) {
    return ClubInfo(
      id: id,
      title: title ?? this.title,
      tagline: tagline ?? this.tagline,
      description: description ?? this.description,
      meetingTime: meetingTime ?? this.meetingTime,
      location: location ?? this.location,
      accentColor: accentColor ?? this.accentColor,
      highlights: highlights ?? this.highlights,
      imageUrl: imageUrl ?? this.imageUrl,
      groupChatUrl: groupChatUrl ?? this.groupChatUrl,
      supervisorName: supervisorName ?? this.supervisorName,
      supervisorEmail: supervisorEmail ?? this.supervisorEmail,
      supervisorPhone: supervisorPhone ?? this.supervisorPhone,
      presidentName: presidentName ?? this.presidentName,
      presidentEmail: presidentEmail ?? this.presidentEmail,
      presidentPhone: presidentPhone ?? this.presidentPhone,
      quickLinks: quickLinks ?? this.quickLinks,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'tagline': tagline,
      'description': description,
      'meetingTime': meetingTime,
      'location': location,
      'accentColor': accentColor.toARGB32(),
      'highlights': highlights,
      'imageUrl': imageUrl,
      'groupChatUrl': groupChatUrl,
      'supervisorName': supervisorName,
      'supervisorEmail': supervisorEmail,
      'supervisorPhone': supervisorPhone,
      'presidentName': presidentName,
      'presidentEmail': presidentEmail,
      'presidentPhone': presidentPhone,
      'quickLinks': quickLinks
          .where((link) => link.hasContent)
          .map((link) => link.toMap())
          .toList(),
    };
  }

  // 🔥 Restored useful helpers
  String get initials {
    final words = title
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return words.isEmpty ? '?' : words;
  }
}

class ClubQuickLink {
  static const String publicVisibility = 'public';
  static const String schoolMembersVisibility = 'schoolMembers';
  static const String clubMembersVisibility = 'clubMembers';

  const ClubQuickLink({
    required this.label,
    required this.url,
    this.description = '',
    this.visibility = schoolMembersVisibility,
  });

  final String label;
  final String url;
  final String description;
  final String visibility;

  factory ClubQuickLink.fromMap(Map<String, dynamic> map) {
    return ClubQuickLink(
      label: map['label'] as String? ?? '',
      url: map['url'] as String? ?? '',
      description: map['description'] as String? ?? '',
      visibility: _quickLinkVisibilityFromMap(map),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'label': label.trim(),
      'url': url.trim(),
      if (description.trim().isNotEmpty) 'description': description.trim(),
      'visibility': visibility,
    };
  }

  bool get hasContent => label.trim().isNotEmpty && url.trim().isNotEmpty;

  bool get isPublic => visibility == publicVisibility;

  bool visibleFor({required bool publicOnly, required bool canViewMemberOnly}) {
    if (visibility == publicVisibility) return true;
    if (publicOnly) return false;
    if (visibility == clubMembersVisibility) return canViewMemberOnly;
    return true;
  }

  static String _quickLinkVisibilityFromMap(Map<String, dynamic> map) {
    final raw = map['visibility'] as String?;
    if (raw == publicVisibility ||
        raw == schoolMembersVisibility ||
        raw == clubMembersVisibility) {
      return raw!;
    }
    if (map['isPublic'] == true || map['public'] == true) {
      return publicVisibility;
    }
    return schoolMembersVisibility;
  }
}

// =========================
// 👥 MEMBERS
// =========================

class ClubMember {
  static const String supervisorRole = 'Supervisor';
  static const String presidentRole = 'President';
  static const String officerRole = 'Officer';
  static const String contentManagerRole = 'Content Manager';
  static const String eventCoordinatorRole = 'Event Coordinator';
  static const String memberRole = 'Member';
  static const String legacyLeaderRole = 'Leader';

  final String userId;
  final String name;
  final String role;
  final String subtitle;
  final String email;
  final String phoneNumber;
  final String? photoUrl;
  final bool isImportant;
  final Set<String> permissions;

  const ClubMember({
    required this.userId,
    required this.name,
    required this.role,
    required this.subtitle,
    this.email = '',
    this.phoneNumber = '',
    this.photoUrl,
    this.isImportant = false,
    this.permissions = const {},
  });

  factory ClubMember.fromMap(Map<String, dynamic> map, String id) {
    final permissions = _permissionsFromMap(map);
    return ClubMember(
      userId: id,
      name: map['name'] as String? ?? '',
      role: _normalizedRole(map['role'] as String? ?? memberRole),
      subtitle: map['subtitle'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phoneNumber:
          map['phoneNumber'] as String? ??
          map['phone'] as String? ??
          map['contactPhone'] as String? ??
          map['mobilePhone'] as String? ??
          '',
      photoUrl:
          map['photoUrl'] as String? ??
          map['pfpURL'] as String? ??
          map['imageUrl'] as String?,
      isImportant: map['isImportant'] as bool? ?? false,
      permissions: permissions,
    );
  }

  ClubMember copyWith({
    String? name,
    String? role,
    String? subtitle,
    String? email,
    String? phoneNumber,
    String? photoUrl,
    bool? isImportant,
    Set<String>? permissions,
  }) {
    return ClubMember(
      userId: userId,
      name: name ?? this.name,
      role: role ?? this.role,
      subtitle: subtitle ?? this.subtitle,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      isImportant: isImportant ?? this.isImportant,
      permissions: permissions ?? this.permissions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'role': role,
      'subtitle': subtitle,
      if (email.trim().isNotEmpty) 'email': email.trim(),
      if (phoneNumber.trim().isNotEmpty) 'phoneNumber': phoneNumber.trim(),
      if ((photoUrl ?? '').trim().isNotEmpty) 'photoUrl': photoUrl!.trim(),
      'isImportant': isImportant,
      'permissions': permissions.toList()..sort(),
    };
  }

  bool get canPublishPosts => _hasPermission(ClubPermission.publishPosts);
  bool get canCreatePolls => _hasPermission(ClubPermission.createPolls);
  bool get canCreateEvents => _hasPermission(ClubPermission.createEvents);
  bool get canManageMembers => _hasPermission(ClubPermission.manageMembers);
  bool get canManageSettings => _hasPermission(ClubPermission.manageSettings);
  bool get canModerateContent => _hasPermission(ClubPermission.moderateContent);
  bool get canChangeVisibility =>
      _hasPermission(ClubPermission.changeVisibility);

  bool get isLeadership => ClubRole.roleRank(role) < ClubRole.memberRank;

  bool _hasPermission(String permission) {
    if (permissions.contains(permission)) return true;
    return ClubRole.permissionsFor(role).contains(permission);
  }

  String get initials {
    final words = name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return words.isEmpty ? '?' : words;
  }
}

class ClubPermission {
  static const String publishPosts = 'publishPosts';
  static const String createPolls = 'createPolls';
  static const String createEvents = 'createEvents';
  static const String manageMembers = 'manageMembers';
  static const String manageSettings = 'manageSettings';
  static const String moderateContent = 'moderateContent';
  static const String changeVisibility = 'changeVisibility';
}

class ClubRole {
  static const List<String> editableRoles = [
    ClubMember.supervisorRole,
    ClubMember.presidentRole,
    ClubMember.officerRole,
    ClubMember.contentManagerRole,
    ClubMember.eventCoordinatorRole,
    ClubMember.memberRole,
  ];

  static const int memberRank = 5;

  static Set<String> permissionsFor(String role) {
    switch (_normalizedRole(role)) {
      case ClubMember.supervisorRole:
      case ClubMember.legacyLeaderRole:
        return const {
          ClubPermission.publishPosts,
          ClubPermission.createPolls,
          ClubPermission.createEvents,
          ClubPermission.manageSettings,
          ClubPermission.moderateContent,
          ClubPermission.changeVisibility,
        };
      case ClubMember.presidentRole:
        return const {
          ClubPermission.publishPosts,
          ClubPermission.createPolls,
          ClubPermission.createEvents,
          ClubPermission.manageMembers,
          ClubPermission.manageSettings,
          ClubPermission.moderateContent,
          ClubPermission.changeVisibility,
        };
      case ClubMember.officerRole:
        return const {
          ClubPermission.publishPosts,
          ClubPermission.createPolls,
          ClubPermission.createEvents,
          ClubPermission.changeVisibility,
        };
      case ClubMember.contentManagerRole:
        return const {
          ClubPermission.publishPosts,
          ClubPermission.createPolls,
          ClubPermission.moderateContent,
          ClubPermission.changeVisibility,
        };
      case ClubMember.eventCoordinatorRole:
        return const {
          ClubPermission.createEvents,
          ClubPermission.changeVisibility,
        };
      default:
        return const {};
    }
  }

  static int roleRank(String role) {
    switch (_normalizedRole(role)) {
      case ClubMember.supervisorRole:
        return 0;
      case ClubMember.presidentRole:
        return 1;
      case ClubMember.legacyLeaderRole:
        return 2;
      case ClubMember.officerRole:
        return 3;
      case ClubMember.contentManagerRole:
      case ClubMember.eventCoordinatorRole:
        return 4;
      case ClubMember.memberRole:
        return memberRank;
      default:
        return 6;
    }
  }
}

enum ClubJoinRequestStatus { pending, approved, rejected }

class ClubJoinRequest {
  const ClubJoinRequest({
    required this.id,
    required this.userId,
    required this.name,
    this.email = '',
    this.studentId = '',
    this.photoUrl,
    this.status = ClubJoinRequestStatus.pending,
    required this.createdAt,
    this.resolvedAt,
    this.resolvedBy,
  });

  final String id;
  final String userId;
  final String name;
  final String email;
  final String studentId;
  final String? photoUrl;
  final ClubJoinRequestStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  factory ClubJoinRequest.fromMap(Map<String, dynamic> map, String id) {
    final createdAt = map['createdAt'];
    final resolvedAt = map['resolvedAt'];

    return ClubJoinRequest(
      id: id,
      userId: map['userId'] as String? ?? id,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      studentId: map['studentId'] as String? ?? '',
      photoUrl:
          map['photoUrl'] as String? ??
          map['pfpURL'] as String? ??
          map['imageUrl'] as String?,
      status: _clubJoinRequestStatusFromString(map['status'] as String?),
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
      resolvedAt: resolvedAt is Timestamp ? resolvedAt.toDate() : null,
      resolvedBy: map['resolvedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      if (email.trim().isNotEmpty) 'email': email.trim(),
      if (studentId.trim().isNotEmpty) 'studentId': studentId.trim(),
      if ((photoUrl ?? '').trim().isNotEmpty) 'photoUrl': photoUrl!.trim(),
      'status': status.name,
      'createdAt': FieldValue.serverTimestamp(),
      if (resolvedAt != null) 'resolvedAt': Timestamp.fromDate(resolvedAt!),
      if ((resolvedBy ?? '').trim().isNotEmpty) 'resolvedBy': resolvedBy,
    };
  }
}

ClubJoinRequestStatus _clubJoinRequestStatusFromString(String? status) {
  for (final value in ClubJoinRequestStatus.values) {
    if (value.name == status) return value;
  }
  return ClubJoinRequestStatus.pending;
}

Set<String> _permissionsFromMap(Map<String, dynamic> map) {
  final raw = map['permissions'];
  if (raw is Iterable) {
    return raw
        .map((permission) => permission.toString())
        .where((permission) => permission.trim().isNotEmpty)
        .toSet();
  }
  if (raw is Map) {
    return raw.entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key.toString())
        .where((permission) => permission.trim().isNotEmpty)
        .toSet();
  }
  return const {};
}

String _normalizedRole(String role) {
  final normalized = role.trim();
  if (normalized.isEmpty) return ClubMember.memberRole;
  final lower = normalized.toLowerCase();
  if (lower == 'leader') return ClubMember.legacyLeaderRole;
  if (lower.contains('supervisor') || lower.contains('advisor')) {
    return ClubMember.supervisorRole;
  }
  if (lower.contains('president')) return ClubMember.presidentRole;
  if (lower == 'officer' ||
      lower.contains('secretary') ||
      lower.contains('treasurer') ||
      lower.contains('historian') ||
      lower.contains('public relations') ||
      lower.contains('vice president')) {
    return ClubMember.officerRole;
  }
  if (lower.contains('content') || lower.contains('communications')) {
    return ClubMember.contentManagerRole;
  }
  if (lower.contains('event')) return ClubMember.eventCoordinatorRole;
  if (lower == 'member') return ClubMember.memberRole;
  return normalized;
}

// =========================
// 📝 POSTS
// =========================

class ClubPostEntry {
  static const String publicVisibility = 'public';
  static const String schoolMembersVisibility = 'schoolMembers';
  static const String clubMembersVisibility = 'clubMembers';

  final String id;
  final String schoolID;
  final String clubID;
  final String clubTitle;
  final String title;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String body;
  final String visibility;
  final DateTime timestamp;
  final List<PostAttachment> attachments;
  final List<PostAcknowledgement> acknowledgements;

  const ClubPostEntry({
    required this.id,
    this.schoolID = '',
    this.clubID = '',
    this.clubTitle = '',
    required this.title,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.body,
    this.visibility = schoolMembersVisibility,
    required this.timestamp,
    this.attachments = const [],
    this.acknowledgements = const [],
  });

  factory ClubPostEntry.fromMap(
    Map<String, dynamic> map,
    String id, {
    String schoolID = '',
    String clubID = '',
    String clubTitle = '',
  }) {
    final ts = map['createdAt'];

    final acknowledgements = (map['acknowledgements'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map(
          (acknowledgement) => PostAcknowledgement.fromMap(
            Map<String, dynamic>.from(acknowledgement),
          ),
        )
        .where((acknowledgement) => acknowledgement.uid.isNotEmpty)
        .toList();

    return ClubPostEntry(
      id: id,
      schoolID: schoolID,
      clubID: clubID,
      clubTitle: clubTitle,
      title: map['title'] as String? ?? '',
      authorId: map['authorId'] as String? ?? '',
      authorName: map['authorName'] as String? ?? '',
      authorPhotoUrl: map['authorPhotoUrl'] as String?,
      body: map['body'] as String? ?? '',
      visibility: _visibilityFromMap(map),
      timestamp: ts is Timestamp ? ts.toDate() : DateTime.now(),
      attachments: (map['attachments'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map(
            (attachment) =>
                PostAttachment.fromMap(Map<String, dynamic>.from(attachment)),
          )
          .toList(),
      acknowledgements: acknowledgements,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'schoolID': schoolID,
      'clubID': clubID,
      'clubTitle': clubTitle,
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'body': body,
      'visibility': visibility,
      'attachments': attachments
          .map((attachment) => attachment.toMap())
          .toList(),
      'acknowledgements': acknowledgements
          .map((acknowledgement) => acknowledgement.toMap())
          .toList(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  ClubPostEntry copyWith({
    String? id,
    String? schoolID,
    String? clubID,
    String? clubTitle,
    String? title,
    String? authorId,
    String? authorName,
    String? authorPhotoUrl,
    String? body,
    String? visibility,
    DateTime? timestamp,
    List<PostAttachment>? attachments,
    List<PostAcknowledgement>? acknowledgements,
  }) {
    return ClubPostEntry(
      id: id ?? this.id,
      schoolID: schoolID ?? this.schoolID,
      clubID: clubID ?? this.clubID,
      clubTitle: clubTitle ?? this.clubTitle,
      title: title ?? this.title,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
      body: body ?? this.body,
      visibility: visibility ?? this.visibility,
      timestamp: timestamp ?? this.timestamp,
      attachments: attachments ?? this.attachments,
      acknowledgements: acknowledgements ?? this.acknowledgements,
    );
  }

  bool acknowledgedBy(String uid) {
    return acknowledgements.any(
      (acknowledgement) => acknowledgement.uid == uid,
    );
  }

  bool get isPublic => visibility == publicVisibility;

  static String _visibilityFromMap(Map<String, dynamic> map) {
    final raw = map['visibility'] as String?;
    if (raw == publicVisibility ||
        raw == schoolMembersVisibility ||
        raw == clubMembersVisibility) {
      return raw!;
    }
    if (map['isPublic'] == true || map['public'] == true) {
      return publicVisibility;
    }
    return schoolMembersVisibility;
  }
}
