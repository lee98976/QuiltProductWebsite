class BellSchedule {
  const BellSchedule({
    required this.id,
    required this.title,
    required this.periods,
    this.dateNotes = '',
  });

  final String id;
  final String title;
  final List<BellSchedulePeriod> periods;
  final String dateNotes;

  BellSchedulePeriod? currentPeriod(DateTime now) {
    for (final period in periods) {
      if (!now.isBefore(period.startOn(now)) &&
          now.isBefore(period.endOn(now))) {
        return period;
      }
    }
    return null;
  }

  BellSchedulePeriod? nextPeriod(DateTime now) {
    for (final period in periods) {
      if (now.isBefore(period.startOn(now))) return period;
    }
    return null;
  }
}

class BellSchedulePeriod {
  const BellSchedulePeriod({
    required this.title,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.minutes,
  });

  final String title;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final int minutes;

  bool get isBreak {
    final normalized = title.toLowerCase();
    return normalized.contains('break') ||
        normalized.contains('lunch') ||
        normalized.contains('drill') ||
        normalized.contains('plc') ||
        normalized.contains('rally');
  }

  DateTime startOn(DateTime day) {
    return DateTime(day.year, day.month, day.day, startHour, startMinute);
  }

  DateTime endOn(DateTime day) {
    return DateTime(day.year, day.month, day.day, endHour, endMinute);
  }
}
