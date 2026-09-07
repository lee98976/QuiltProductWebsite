import 'dart:convert';

import '../Models/platform_event.dart';

class CalendarLinks {
  const CalendarLinks._();

  static Duration defaultEventDuration = const Duration(hours: 1);
  static const List<int> defaultAlertMinutesBefore = [1440, 60];

  static Uri googleCalendarUri(PlatformEvent event) {
    final start = _utcCalendarStamp(event.startTime);
    final end = _utcCalendarStamp(event.startTime.add(defaultEventDuration));
    final details = eventDetails(event);

    return Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': event.title,
      'dates': '$start/$end',
      if (details.isNotEmpty) 'details': details,
      if (event.location.trim().isNotEmpty) 'location': event.location.trim(),
    });
  }

  static Uri icsDataUri(PlatformEvent event) {
    return Uri.dataFromString(
      icsContent(event),
      mimeType: 'text/calendar',
      encoding: utf8,
    );
  }

  static String icsContent(PlatformEvent event) {
    final start = _utcCalendarStamp(event.startTime);
    final end = _utcCalendarStamp(event.startTime.add(defaultEventDuration));
    final now = _utcCalendarStamp(DateTime.now());
    final details = eventDetails(event);
    final uidParts = [
      event.schoolID,
      event.clubID,
      event.id,
      event.startTime.millisecondsSinceEpoch.toString(),
    ].where((part) => part.trim().isNotEmpty);

    final lines = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Quilt//Club Events//EN',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'BEGIN:VEVENT',
      'UID:${_escapeIcs(uidParts.join('-'))}@quilt',
      'DTSTAMP:$now',
      'DTSTART:$start',
      'DTEND:$end',
      'SUMMARY:${_escapeIcs(event.title)}',
      if (details.isNotEmpty) 'DESCRIPTION:${_escapeIcs(details)}',
      if (event.location.trim().isNotEmpty)
        'LOCATION:${_escapeIcs(event.location.trim())}',
      for (final minutes in defaultAlertMinutesBefore) ...[
        'BEGIN:VALARM',
        'ACTION:DISPLAY',
        'DESCRIPTION:${_escapeIcs(event.title)}',
        'TRIGGER:${_icsAlarmTrigger(minutes)}',
        'END:VALARM',
      ],
      'END:VEVENT',
      'END:VCALENDAR',
    ];

    return lines.join('\r\n');
  }

  static String icsFileName(PlatformEvent event) {
    final baseName = event.title.trim().isNotEmpty
        ? event.title.trim()
        : 'club-event';
    final sanitized = baseName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return '${sanitized.isNotEmpty ? sanitized : 'club-event'}.ics';
  }

  static String stableEventId(PlatformEvent event) {
    final input = [
      event.schoolID,
      event.clubID,
      event.id,
      event.startTime.millisecondsSinceEpoch.toString(),
    ].join('|');
    return 'quilt${_fnv1a64Hex(input)}';
  }

  static String eventDetails(PlatformEvent event) {
    return [
      event.description.trim(),
      if (event.clubTitle.trim().isNotEmpty) 'Club: ${event.clubTitle.trim()}',
      if (event.contactName.trim().isNotEmpty)
        'Contact: ${event.contactName.trim()}',
      if (event.contactEmail.trim().isNotEmpty)
        'Contact email: ${event.contactEmail.trim()}',
    ].where((line) => line.isNotEmpty).join('\n');
  }

  static String _utcCalendarStamp(DateTime dateTime) {
    final utc = dateTime.toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${utc.year}${two(utc.month)}${two(utc.day)}T'
        '${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
  }

  static String _escapeIcs(String value) {
    return value
        .replaceAll('\\', r'\\')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,')
        .replaceAll('\r\n', r'\n')
        .replaceAll('\n', r'\n');
  }

  static String _icsAlarmTrigger(int minutesBefore) {
    if (minutesBefore % (24 * 60) == 0) {
      return '-P${minutesBefore ~/ (24 * 60)}D';
    }
    if (minutesBefore % 60 == 0) {
      return '-PT${minutesBefore ~/ 60}H';
    }
    return '-PT${minutesBefore}M';
  }

  static String _fnv1a64Hex(String value) {
    final mask = BigInt.parse('ffffffffffffffff', radix: 16);
    var hash = BigInt.parse('cbf29ce484222325', radix: 16);
    final prime = BigInt.parse('100000001b3', radix: 16);
    for (final byte in utf8.encode(value)) {
      hash = hash ^ BigInt.from(byte);
      hash = (hash * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
