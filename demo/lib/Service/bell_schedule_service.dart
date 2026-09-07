import 'package:http/http.dart' as http;

import '../Models/bell_schedule.dart';

class BellScheduleService {
  const BellScheduleService({http.Client? client});

  Future<List<BellSchedule>> loadSampleSchedules() async => fallbackSchedules;

  static List<BellSchedule> parsePublishedCsv(String source) {
    final rows = _parseCsv(source);
    final schedules = <_MutableSchedule>[];
    final idCounts = <String, int>{};
    final activeByColumn = <int, _MutableSchedule>{};

    for (final row in rows) {
      for (final startColumn in const [1, 8]) {
        final title = _cell(row, startColumn).trim();
        final minHeader = _cell(row, startColumn + 5).trim().toLowerCase();
        if (title.isNotEmpty &&
            title.toLowerCase().contains('schedule') &&
            minHeader == 'min') {
          final baseId = _scheduleId(title);
          final count = (idCounts[baseId] ?? 0) + 1;
          idCounts[baseId] = count;
          final schedule = _MutableSchedule(
            id: count == 1 ? baseId : '${baseId}_$count',
            title: title.replaceAll(RegExp(r'\s+'), ' ').trim(),
          );
          activeByColumn[startColumn] = schedule;
          schedules.add(schedule);
          continue;
        }

        final active = activeByColumn[startColumn];
        if (active == null) continue;

        final label = _cell(row, startColumn + 4).trim();
        final firstCell = _cell(row, startColumn).trim();
        if (firstCell.toLowerCase().startsWith('date')) {
          active.dateNotes = _cell(row, startColumn + 1).trim();
          continue;
        }
        if (label.isEmpty || firstCell.isEmpty) continue;

        final start = _parseTime(firstCell);
        final end = _parseTime(_cell(row, startColumn + 2));
        if (start == null || end == null) continue;

        final minutes =
            int.tryParse(_cell(row, startColumn + 5).trim()) ??
            _durationMinutes(start, end);
        active.periods.add(
          BellSchedulePeriod(
            title: label,
            startHour: start.hour,
            startMinute: start.minute,
            endHour: end.hour,
            endMinute: end.minute,
            minutes: minutes,
          ),
        );
      }
    }

    return schedules
        .where((schedule) => schedule.periods.isNotEmpty)
        .map((schedule) => schedule.toSchedule())
        .toList(growable: false);
  }

  static List<BellSchedule> get fallbackSchedules {
    return [
      const BellSchedule(
        id: 'regular_schedule',
        title: 'Regular Schedule',
        periods: [
          BellSchedulePeriod(
            title: 'Zero period',
            startHour: 7,
            startMinute: 28,
            endHour: 8,
            endMinute: 25,
            minutes: 57,
          ),
          BellSchedulePeriod(
            title: 'Period 1',
            startHour: 8,
            startMinute: 30,
            endHour: 9,
            endMinute: 27,
            minutes: 57,
          ),
          BellSchedulePeriod(
            title: 'Period 2',
            startHour: 9,
            startMinute: 32,
            endHour: 10,
            endMinute: 37,
            minutes: 65,
          ),
          BellSchedulePeriod(
            title: 'BREAK',
            startHour: 10,
            startMinute: 37,
            endHour: 10,
            endMinute: 47,
            minutes: 10,
          ),
          BellSchedulePeriod(
            title: 'Period 3',
            startHour: 10,
            startMinute: 57,
            endHour: 11,
            endMinute: 54,
            minutes: 57,
          ),
          BellSchedulePeriod(
            title: 'Period 4',
            startHour: 11,
            startMinute: 59,
            endHour: 12,
            endMinute: 56,
            minutes: 57,
          ),
          BellSchedulePeriod(
            title: 'LUNCH',
            startHour: 12,
            startMinute: 56,
            endHour: 13,
            endMinute: 26,
            minutes: 30,
          ),
          BellSchedulePeriod(
            title: 'Period 5',
            startHour: 13,
            startMinute: 31,
            endHour: 14,
            endMinute: 28,
            minutes: 57,
          ),
          BellSchedulePeriod(
            title: 'Period 6',
            startHour: 14,
            startMinute: 33,
            endHour: 15,
            endMinute: 30,
            minutes: 57,
          ),
          BellSchedulePeriod(
            title: 'Period 7',
            startHour: 15,
            startMinute: 45,
            endHour: 17,
            endMinute: 30,
            minutes: 105,
          ),
        ],
      ),
    ];
  }

  static List<List<String>> _parseCsv(String source) {
    final rows = <List<String>>[];
    final row = <String>[];
    final cell = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < source.length; i++) {
      final char = source[i];
      if (char == '"') {
        if (inQuotes && i + 1 < source.length && source[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        row.add(cell.toString());
        cell.clear();
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && i + 1 < source.length && source[i + 1] == '\n') {
          i++;
        }
        row.add(cell.toString());
        cell.clear();
        rows.add(List<String>.from(row));
        row.clear();
      } else {
        cell.write(char);
      }
    }

    if (cell.isNotEmpty || row.isNotEmpty) {
      row.add(cell.toString());
      rows.add(row);
    }
    return rows;
  }

  static String _cell(List<String> row, int index) {
    return index >= 0 && index < row.length ? row[index] : '';
  }

  static _ParsedTime? _parseTime(String raw) {
    final match = RegExp(
      r'(\d{1,2})\s*:\s*(\d{2})\s*([AP]M)',
      caseSensitive: false,
    ).firstMatch(raw.trim());
    if (match == null) return null;

    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)!.toUpperCase();
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return _ParsedTime(hour, minute);
  }

  static int _durationMinutes(_ParsedTime start, _ParsedTime end) {
    final startMinutes = start.hour * 60 + start.minute;
    var endMinutes = end.hour * 60 + end.minute;
    if (endMinutes < startMinutes) endMinutes += 24 * 60;
    return endMinutes - startMinutes;
  }

  static String _scheduleId(String title) {
    final id = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return id.isEmpty ? 'schedule' : id;
  }
}

class _MutableSchedule {
  _MutableSchedule({required this.id, required this.title});

  final String id;
  final String title;
  final List<BellSchedulePeriod> periods = [];
  String dateNotes = '';

  BellSchedule toSchedule() {
    return BellSchedule(
      id: id,
      title: title,
      periods: List.unmodifiable(periods),
      dateNotes: dateNotes,
    );
  }
}

class _ParsedTime {
  const _ParsedTime(this.hour, this.minute);

  final int hour;
  final int minute;
}
