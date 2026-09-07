import 'package:cloud_firestore/cloud_firestore.dart';

enum ModerationReportStatus { open, dismissed, postRemoved }

class ModerationReport {
  final String id;
  final String schoolID;
  final String clubID;
  final String clubTitle;
  final String postID;
  final String postTitle;
  final String postBody;
  final String postAuthorId;
  final String postAuthorName;
  final String reporterId;
  final String reporterName;
  final String reporterEmail;
  final String reason;
  final String details;
  final String postType;
  final ModerationReportStatus status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? resolutionNote;

  const ModerationReport({
    required this.id,
    required this.schoolID,
    required this.clubID,
    required this.clubTitle,
    required this.postID,
    required this.postTitle,
    required this.postBody,
    required this.postAuthorId,
    required this.postAuthorName,
    required this.reporterId,
    required this.reporterName,
    required this.reporterEmail,
    required this.reason,
    required this.details,
    this.postType = 'clubPost',
    this.status = ModerationReportStatus.open,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
    this.resolutionNote,
  });

  factory ModerationReport.fromMap(Map<String, dynamic> map, String id) {
    final createdAt = map['createdAt'];
    final reviewedAt = map['reviewedAt'];

    return ModerationReport(
      id: id,
      schoolID: map['schoolID'] as String? ?? '',
      clubID: map['clubID'] as String? ?? '',
      clubTitle: map['clubTitle'] as String? ?? '',
      postID: map['postID'] as String? ?? '',
      postTitle: map['postTitle'] as String? ?? '',
      postBody: map['postBody'] as String? ?? '',
      postAuthorId: map['postAuthorId'] as String? ?? '',
      postAuthorName: map['postAuthorName'] as String? ?? '',
      reporterId: map['reporterId'] as String? ?? '',
      reporterName: map['reporterName'] as String? ?? '',
      reporterEmail: map['reporterEmail'] as String? ?? '',
      reason: map['reason'] as String? ?? 'Other',
      details: map['details'] as String? ?? '',
      postType: map['postType'] as String? ?? 'clubPost',
      status: _statusFromString(map['status'] as String?),
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
      reviewedAt: reviewedAt is Timestamp ? reviewedAt.toDate() : null,
      reviewedBy: map['reviewedBy'] as String?,
      resolutionNote: map['resolutionNote'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schoolID': schoolID,
      'clubID': clubID,
      'clubTitle': clubTitle,
      'postID': postID,
      'postTitle': postTitle,
      'postBody': postBody,
      'postAuthorId': postAuthorId,
      'postAuthorName': postAuthorName,
      'reporterId': reporterId,
      'reporterName': reporterName,
      'reporterEmail': reporterEmail,
      'reason': reason,
      'details': details,
      'postType': postType,
      'status': status.name,
      'createdAt': FieldValue.serverTimestamp(),
      'reviewedAt': reviewedAt,
      'reviewedBy': reviewedBy,
      'resolutionNote': resolutionNote,
    };
  }

  static ModerationReportStatus _statusFromString(String? status) {
    for (final value in ModerationReportStatus.values) {
      if (value.name == status) return value;
    }
    return ModerationReportStatus.open;
  }
}
