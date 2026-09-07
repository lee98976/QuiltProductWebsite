import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  static const String eventSignupType = 'eventSignup';

  const AppNotification({
    required this.id,
    required this.recipientUid,
    required this.title,
    required this.body,
    required this.type,
    this.schoolID = '',
    this.clubID = '',
    this.eventID = '',
    this.childUid = '',
    this.childName = '',
    this.createdAt,
    this.readAt,
  });

  final String id;
  final String recipientUid;
  final String title;
  final String body;
  final String type;
  final String schoolID;
  final String clubID;
  final String eventID;
  final String childUid;
  final String childName;
  final DateTime? createdAt;
  final DateTime? readAt;

  bool get isUnread => readAt == null;

  factory AppNotification.fromMap(Map<String, dynamic> map, String id) {
    final createdAt = map['createdAt'];
    final readAt = map['readAt'];
    return AppNotification(
      id: id,
      recipientUid: map['recipientUid'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      type: map['type'] as String? ?? '',
      schoolID: map['schoolID'] as String? ?? '',
      clubID: map['clubID'] as String? ?? '',
      eventID: map['eventID'] as String? ?? '',
      childUid: map['childUid'] as String? ?? '',
      childName: map['childName'] as String? ?? '',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      readAt: readAt is Timestamp ? readAt.toDate() : null,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'recipientUid': recipientUid,
      'title': title,
      'body': body,
      'type': type,
      'schoolID': schoolID,
      'clubID': clubID,
      'eventID': eventID,
      'childUid': childUid,
      'childName': childName,
      'createdAt': FieldValue.serverTimestamp(),
      'readAt': null,
    };
  }
}
