import 'package:cloud_firestore/cloud_firestore.dart';

enum HallPassScanAction { started, returned }

class HallPassScanResult {
  const HallPassScanResult({required this.action, required this.roomId});

  final HallPassScanAction action;
  final String roomId;
}

class HallPass {
  final String id;
  final String studentId;
  final String roomId;
  final DateTime departTime;
  final DateTime? returnTime;
  final bool isActive;

  const HallPass({
    required this.id,
    required this.studentId,
    required this.roomId,
    required this.departTime,
    this.returnTime,
    required this.isActive,
  });

  factory HallPass.fromMap(Map<String, dynamic> map, String id) {
    final dep = map['departTime'];
    final ret = map['returnTime'];
    return HallPass(
      id: id,
      studentId: map['studentId'] as String? ?? '',
      roomId: map['roomId'] as String? ?? '',
      departTime: dep is Timestamp ? dep.toDate() : DateTime.now(),
      returnTime: ret is Timestamp ? ret.toDate() : null,
      isActive: map['isActive'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    // When writing a new hall pass to Firestore, use ServerTimestamp for accuracy.
    return {
      'studentId': studentId,
      'roomId': roomId,
      'departTime': returnTime == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(departTime),
      'returnTime': returnTime != null ? FieldValue.serverTimestamp() : null,
      'isActive': isActive,
    };
  }
}
