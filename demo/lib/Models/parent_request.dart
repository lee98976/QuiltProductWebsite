import 'package:cloud_firestore/cloud_firestore.dart';

enum ParentRequestStatus { pending, accepted, declined }

class ParentRequest {
  const ParentRequest({
    required this.id,
    required this.parentId,
    required this.parentName,
    required this.parentEmail,
    this.parentPhotoUrl,
    required this.relationship,
    this.parentRelationship = '',
    this.note = '',
    required this.studentUid,
    required this.studentName,
    required this.studentFamilyCode,
    this.status = ParentRequestStatus.pending,
    required this.createdAt,
    this.respondedAt,
    this.isDebug = false,
  });

  final String id;
  final String parentId;
  final String parentName;
  final String parentEmail;
  final String? parentPhotoUrl;
  final String relationship;
  final String parentRelationship;
  final String note;
  final String studentUid;
  final String studentName;
  final String studentFamilyCode;
  final ParentRequestStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final bool isDebug;

  factory ParentRequest.fromMap(Map<String, dynamic> map, String id) {
    final createdAt = map['createdAt'];
    final respondedAt = map['respondedAt'];

    return ParentRequest(
      id: id,
      parentId: map['parentId'] as String? ?? '',
      parentName: map['parentName'] as String? ?? '',
      parentEmail: map['parentEmail'] as String? ?? '',
      parentPhotoUrl: map['parentPhotoUrl'] as String?,
      relationship: map['relationship'] as String? ?? '',
      parentRelationship: map['parentRelationship'] as String? ?? '',
      note: map['note'] as String? ?? '',
      studentUid: map['studentUid'] as String? ?? '',
      studentName: map['studentName'] as String? ?? '',
      studentFamilyCode: map['studentFamilyCode'] as String? ?? '',
      status: _statusFromString(map['status'] as String?),
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
      respondedAt: respondedAt is Timestamp ? respondedAt.toDate() : null,
      isDebug: map['isDebug'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'parentId': parentId,
      'parentName': parentName,
      'parentEmail': parentEmail,
      'parentPhotoUrl': parentPhotoUrl,
      'relationship': relationship,
      'parentRelationship': parentRelationship,
      'note': note,
      'studentUid': studentUid,
      'studentName': studentName,
      'studentFamilyCode': studentFamilyCode,
      'status': status.name,
      'createdAt': FieldValue.serverTimestamp(),
      'respondedAt': respondedAt,
      'isDebug': isDebug,
    };
  }

  static ParentRequestStatus _statusFromString(String? status) {
    for (final value in ParentRequestStatus.values) {
      if (value.name == status) return value;
    }
    return ParentRequestStatus.pending;
  }
}
