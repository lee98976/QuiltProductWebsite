import 'package:cloud_firestore/cloud_firestore.dart';

class CalEvent {
  // final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String type;
  final bool allDay;

  CalEvent({
    // required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.type,
    required this.allDay,
  });

  factory CalEvent.fromMap(Map<String, dynamic> map) {
    return CalEvent(
      // id: id,
      title: map['title'],
      type: map['type'],
      start: DateTime.parse(map['start']),
      end: DateTime.parse(map['end']),
      allDay: map['allDay'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type,
      'start': Timestamp.fromDate(start),
      'end': Timestamp.fromDate(end),
      'allDay': allDay,
    };
  }
}
