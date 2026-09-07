import 'package:cloud_firestore/cloud_firestore.dart';

class PlatformEvent {
  static const String pendingStatus = 'pending';
  static const String approvedStatus = 'approved';
  static const String rejectedStatus = 'rejected';
  static const String publicVisibility = 'public';
  static const String schoolMembersVisibility = 'schoolMembers';
  static const String clubMembersVisibility = 'clubMembers';

  final String id;
  final String schoolID;
  final String clubID;
  final String clubTitle;
  final String title;
  final String description;
  final String location;
  final DateTime startTime;
  final String creatorId;
  final String creatorName;
  final String status;
  final String visibility;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? imageUrl;
  final List<String> attendeeNames;
  final int goingCount;
  final List<String> parentVolunteerNames;
  final int parentVolunteerCount;
  final int chaperonesNeeded;
  final String contactName;
  final String contactEmail;
  final bool requiresParentConnection;

  const PlatformEvent({
    required this.id,
    this.schoolID = '',
    this.clubID = '',
    this.clubTitle = '',
    required this.title,
    required this.description,
    this.location = '',
    required this.startTime,
    this.creatorId = '',
    this.creatorName = '',
    this.status = approvedStatus,
    this.visibility = schoolMembersVisibility,
    this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
    this.imageUrl,
    this.attendeeNames = const [],
    this.goingCount = 0,
    this.parentVolunteerNames = const [],
    this.parentVolunteerCount = 0,
    this.chaperonesNeeded = 0,
    this.contactName = '',
    this.contactEmail = '',
    this.requiresParentConnection = true,
  });

  factory PlatformEvent.fromMap(Map<String, dynamic> map, String id) {
    final ts = map['startTime'];
    final createdTs = map['createdAt'];
    final reviewedTs = map['reviewedAt'];
    return PlatformEvent(
      id: id,
      schoolID: map['schoolID'] as String? ?? '',
      clubID: map['clubID'] as String? ?? '',
      clubTitle: map['clubTitle'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      location: map['location'] as String? ?? '',
      startTime: ts is Timestamp ? ts.toDate() : DateTime.now(),
      creatorId: map['creatorId'] as String? ?? '',
      creatorName: map['creatorName'] as String? ?? '',
      status: _statusFromMap(map),
      visibility: _visibilityFromMap(map),
      createdAt: createdTs is Timestamp ? createdTs.toDate() : null,
      reviewedAt: reviewedTs is Timestamp ? reviewedTs.toDate() : null,
      reviewedBy: map['reviewedBy'] as String?,
      imageUrl: map['imageUrl'] as String?,
      attendeeNames:
          (map['attendeeNames'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      goingCount:
          map['goingCount'] as int? ??
          (map['attendeeUIDs'] as List?)?.length ??
          (map['attendeeNames'] as List?)?.length ??
          0,
      parentVolunteerNames:
          (map['parentVolunteerNames'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      parentVolunteerCount:
          map['parentVolunteerCount'] as int? ??
          (map['parentVolunteerUIDs'] as List?)?.length ??
          (map['parentVolunteerNames'] as List?)?.length ??
          0,
      chaperonesNeeded: map['chaperonesNeeded'] as int? ?? 0,
      contactName: map['contactName'] as String? ?? '',
      contactEmail: map['contactEmail'] as String? ?? '',
      requiresParentConnection:
          map['requiresParentConnection'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'schoolID': schoolID,
      'clubID': clubID,
      'clubTitle': clubTitle,
      'description': description,
      'location': location,
      'startTime': Timestamp.fromDate(startTime),
      'creatorId': creatorId,
      'creatorName': creatorName,
      'status': status,
      'visibility': visibility,
      'createdAt': FieldValue.serverTimestamp(),
      'reviewedAt': reviewedAt == null ? null : Timestamp.fromDate(reviewedAt!),
      'reviewedBy': reviewedBy,
      'imageUrl': imageUrl,
      'attendeeNames': attendeeNames,
      'goingCount': goingCount,
      'parentVolunteerNames': parentVolunteerNames,
      'parentVolunteerCount': parentVolunteerCount,
      'chaperonesNeeded': chaperonesNeeded,
      'contactName': contactName,
      'contactEmail': contactEmail,
      'requiresParentConnection': requiresParentConnection,
    };
  }

  bool get isPending => status == pendingStatus;
  bool get isApproved => status == approvedStatus;
  bool get isRejected => status == rejectedStatus;
  bool get isPublic => visibility == publicVisibility;

  static String _statusFromMap(Map<String, dynamic> map) {
    final raw = map['status'] as String?;
    if (raw == pendingStatus ||
        raw == approvedStatus ||
        raw == rejectedStatus) {
      return raw!;
    }
    return approvedStatus;
  }

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

class EventParticipant {
  final String uid;
  final String name;
  final String email;
  final String status;
  final String? photoUrl;
  final DateTime? timestamp;

  const EventParticipant({
    required this.uid,
    required this.name,
    this.email = '',
    this.status = 'going',
    this.photoUrl,
    this.timestamp,
  });

  factory EventParticipant.fromMap(Map<String, dynamic> map, String id) {
    final ts = map['timestamp'] ?? map['createdAt'] ?? map['requestedAt'];
    return EventParticipant(
      uid: map['uid'] as String? ?? id,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      status: map['status'] as String? ?? 'going',
      photoUrl: map['photoUrl'] as String?,
      timestamp: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

class ParentSignedUpEvent {
  const ParentSignedUpEvent({
    required this.event,
    required this.studentUid,
    required this.student,
    this.signupTime,
  });

  final PlatformEvent event;
  final String studentUid;
  final String student;
  final DateTime? signupTime;
}

class ParentVolunteeredEvent {
  const ParentVolunteeredEvent({required this.event, this.volunteerTime});

  final PlatformEvent event;
  final DateTime? volunteerTime;
}
