import 'package:intl/intl.dart';

/// Single [DateFormat] for time-of-day strings (avoid allocating per row/tile).
final DateFormat appTimeOfDay = DateFormat('h:mm a');

String displaySchoolName({required String schoolID, String? schoolName}) {
  final name = schoolName?.trim();
  if (name != null && name.isNotEmpty) return name;
  return displaySchoolNameFromID(schoolID);
}

String displaySchoolNameFromID(String schoolID) {
  final id = schoolID.trim();
  if (id.isEmpty) return 'Not set';
  if (id == 'troy_high_school') return 'Troy High';

  return id
      .split(RegExp(r'[_\-\s]+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) =>
            part[0].toUpperCase() + (part.length > 1 ? part.substring(1) : ''),
      )
      .join(' ');
}
