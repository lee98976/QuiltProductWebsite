import 'package:cloud_firestore/cloud_firestore.dart';

enum ClubRequestStatus { pending, approved, rejected }

class ClubRequest {
  final String id;
  final String applicantId;
  final String applicantName;
  final String title;
  final String description;
  final String meetingTime;
  final String location;
  final ClubRequestStatus status;
  final DateTime createdAt;

  const ClubRequest({
    required this.id,
    required this.applicantId,
    required this.applicantName,
    required this.title,
    required this.description,
    required this.meetingTime,
    required this.location,
    this.status = ClubRequestStatus.pending,
    required this.createdAt,
  });

  factory ClubRequest.fromMap(Map<String, dynamic> map, String id) {
    final ts = map['createdAt'];
    
    ClubRequestStatus parsedStatus = ClubRequestStatus.pending;
    final statusStr = map['status'] as String?;
    if (statusStr == 'approved') parsedStatus = ClubRequestStatus.approved;
    if (statusStr == 'rejected') parsedStatus = ClubRequestStatus.rejected;

    return ClubRequest(
      id: id,
      applicantId: map['applicantId'] as String? ?? '',
      applicantName: map['applicantName'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      meetingTime: map['meetingTime'] as String? ?? '',
      location: map['location'] as String? ?? '',
      status: parsedStatus,
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'applicantId': applicantId,
      'applicantName': applicantName,
      'title': title,
      'description': description,
      'meetingTime': meetingTime,
      'location': location,
      'status': status.name,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
