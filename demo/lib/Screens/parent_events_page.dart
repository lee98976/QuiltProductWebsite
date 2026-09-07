import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../Components/calendar_event_actions.dart';
import '../Components/deferred_content.dart';
import '../Models/platform_event.dart';
import '../Models/user.dart';
import '../Providers/current_user_profile_notifier.dart';
import '../Service/firebase_service.dart';
import '../Utility/AppSpacing.dart';
import '../Utility/app_decorations.dart';

const double _parentEventsBottomGap = AppSpacing.xl * 3;
const int _parentAgendaPreviewLimit = 12;
const String _allChildrenFilterKey = 'all';
const Color _schoolwideEventColor = Color(0xFF0EA5E9);
const List<Color> _parentEventColors = [
  Color(0xFFEF4444),
  Color(0xFFF59E0B),
  Color(0xFF10B981),
  Color(0xFF3B82F6),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
  Color(0xFF14B8A6),
  Color(0xFFF97316),
];

enum _ParentCalendarView { day, week, month }

class ParentEventsPage extends StatelessWidget {
  const ParentEventsPage({this.student, super.key});

  final UserProfile? student;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = context.watch<CurrentUserProfileNotifier>().profile;
    final studentName = _studentDisplayName(student);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          studentName == null ? 'Child Events' : '$studentName Events',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: theme.colorScheme.surface,
        ),
        flexibleSpace: Container(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppDecorations.screenBackground(context),
        child: SafeArea(
          child: profile == null
              ? const Center(child: CircularProgressIndicator())
              : DeferredContent(
                  active: true,
                  delay: const Duration(milliseconds: 140),
                  child: FutureBuilder<_ParentEventsData>(
                    future: _loadParentEvents(
                      context.read<FirebaseService>(),
                      profile,
                      student: student,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return _ParentEventsEmptyState(
                          icon: Icons.event_busy_outlined,
                          message: 'Child events could not load.',
                          theme: theme,
                        );
                      }

                      final data =
                          snapshot.data ?? const _ParentEventsData.empty();
                      if (data.entries.isEmpty) {
                        return _ParentEventsEmptyState(
                          icon: Icons.event_available_outlined,
                          message: studentName == null
                              ? 'No linked child is signed up for an event yet.'
                              : '$studentName is not signed up for an event yet.',
                          theme: theme,
                        );
                      }

                      return _ParentEventsCalendar(data: data, theme: theme);
                    },
                  ),
                ),
        ),
      ),
    );
  }
}

Future<_ParentEventsData> _loadParentEvents(
  FirebaseService firebase,
  UserProfile parent, {
  UserProfile? student,
}) async {
  final linkedStudents = student == null
      ? await firebase.getStudentsForParent(parent)
      : <UserProfile>[student];
  final signedUpEvents = await firebase.getSignedUpEventsForParent(
    parent,
    student: student,
  );
  final volunteeredEvents = await firebase.getVolunteeredEventsForParent(
    parent,
  );
  final volunteeredIds = {
    for (final volunteered in volunteeredEvents) _eventKey(volunteered.event),
  };
  final entriesByEvent = <String, _ParentEventEntry>{};
  final childNamesByUid = <String, String>{
    for (final linkedStudent in linkedStudents)
      linkedStudent.UID: _studentDisplayName(linkedStudent) ?? 'Student',
  };

  for (final signedUpEvent in signedUpEvents) {
    childNamesByUid[signedUpEvent.studentUid] = signedUpEvent.student;
    final key = _eventKey(signedUpEvent.event);
    final existing = entriesByEvent[key];
    if (existing == null) {
      entriesByEvent[key] = _ParentEventEntry(
        event: signedUpEvent.event,
        childNamesByUid: {signedUpEvent.studentUid: signedUpEvent.student},
        volunteered: volunteeredIds.contains(key),
      );
    } else {
      existing.childNamesByUid[signedUpEvent.studentUid] =
          signedUpEvent.student;
    }
  }

  final entries = entriesByEvent.values.toList()
    ..sort((a, b) => a.event.startTime.compareTo(b.event.startTime));
  final childOptions = childNamesByUid.entries.toList()
    ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));

  return _ParentEventsData(entries: entries, childOptions: childOptions);
}

class _ParentEventsData {
  const _ParentEventsData({required this.entries, required this.childOptions});

  const _ParentEventsData.empty() : entries = const [], childOptions = const [];

  final List<_ParentEventEntry> entries;
  final List<MapEntry<String, String>> childOptions;
}

class _ParentEventEntry {
  _ParentEventEntry({
    required this.event,
    required this.childNamesByUid,
    required this.volunteered,
  });

  final PlatformEvent event;
  final Map<String, String> childNamesByUid;
  final bool volunteered;

  String get childNames {
    final names =
        childNamesByUid.values
            .map((name) => name.trim())
            .where((name) => name.isNotEmpty)
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names.isEmpty ? 'Student' : names.join(', ');
  }

  bool hasChild(String uid) => childNamesByUid.containsKey(uid);
}

class _ParentEventsCalendar extends StatefulWidget {
  const _ParentEventsCalendar({required this.data, required this.theme});

  final _ParentEventsData data;
  final ThemeData theme;

  @override
  State<_ParentEventsCalendar> createState() => _ParentEventsCalendarState();
}

class _ParentEventsCalendarState extends State<_ParentEventsCalendar> {
  late DateTime _focusedDate = _dateOnly(DateTime.now());
  late DateTime _selectedDate = _focusedDate;
  _ParentCalendarView _view = _ParentCalendarView.month;
  String _selectedChildUid = _allChildrenFilterKey;
  bool _volunteeringOnly = false;
  bool _hasSyncedInitialEventDate = false;

  @override
  void initState() {
    super.initState();
    _syncInitialEventDate();
  }

  @override
  void didUpdateWidget(covariant _ParentEventsCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncInitialEventDate(notify: true);
  }

  void _syncInitialEventDate({bool notify = false}) {
    if (_hasSyncedInitialEventDate || widget.data.entries.isEmpty) return;
    final targetDate = _initialCalendarDate(widget.data.entries, _focusedDate);
    _hasSyncedInitialEventDate = true;
    if (_isSameDay(targetDate, _selectedDate)) return;

    void updateDates() {
      _focusedDate = targetDate;
      _selectedDate = targetDate;
    }

    if (notify) {
      setState(updateDates);
    } else {
      updateDates();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeChildUid =
        _selectedChildUid == _allChildrenFilterKey ||
            widget.data.childOptions.any(
              (child) => child.key == _selectedChildUid,
            )
        ? _selectedChildUid
        : _allChildrenFilterKey;
    final filteredEntries = widget.data.entries.where((entry) {
      final childMatches =
          activeChildUid == _allChildrenFilterKey ||
          entry.hasChild(activeChildUid);
      final volunteerMatches = !_volunteeringOnly || entry.volunteered;
      return childMatches && volunteerMatches;
    }).toList();
    final visibleEntries = _visibleAgendaEntries(filteredEntries);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        AppSpacing.md,
        AppSpacing.screenPaddingH,
        _parentEventsBottomGap,
      ),
      children: [
        _ParentCalendarToolbar(
          focusedDate: _focusedDate,
          selectedDate: _selectedDate,
          view: _view,
          theme: widget.theme,
          onPrevious: () => setState(() {
            _focusedDate = _shiftFocusedDate(-1);
            _selectedDate = _focusedDate;
          }),
          onToday: () => setState(() {
            _focusedDate = _dateOnly(DateTime.now());
            _selectedDate = _focusedDate;
          }),
          onNext: () => setState(() {
            _focusedDate = _shiftFocusedDate(1);
            _selectedDate = _focusedDate;
          }),
          onViewChanged: (view) => setState(() => _view = view),
        ),
        const SizedBox(height: AppSpacing.md),
        _ParentEventFilters(
          childOptions: widget.data.childOptions,
          selectedChildUid: activeChildUid,
          volunteeringOnly: _volunteeringOnly,
          theme: widget.theme,
          onChildChanged: (uid) => setState(() {
            _selectedChildUid = uid;
            final matching = widget.data.entries
                .where(
                  (entry) =>
                      uid == _allChildrenFilterKey || entry.hasChild(uid),
                )
                .toList();
            if (matching.isNotEmpty) {
              final targetDate = _initialCalendarDate(matching, _focusedDate);
              _focusedDate = targetDate;
              _selectedDate = targetDate;
            }
          }),
          onVolunteeringChanged: (value) =>
              setState(() => _volunteeringOnly = value),
        ),
        const SizedBox(height: AppSpacing.md),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: switch (_view) {
            _ParentCalendarView.day => _ParentDayCalendarView(
              key: ValueKey('day-${_selectedDate.toIso8601String()}'),
              date: _selectedDate,
              entries: _entriesForDay(filteredEntries, _selectedDate),
              theme: widget.theme,
              onEventTap: _showEventDetails,
            ),
            _ParentCalendarView.week => _ParentWeekCalendarView(
              key: ValueKey('week-${_weekStart(_focusedDate)}'),
              focusedDate: _focusedDate,
              selectedDate: _selectedDate,
              entries: filteredEntries,
              theme: widget.theme,
              onDateSelected: (date) => setState(() {
                _selectedDate = date;
                _focusedDate = date;
              }),
              onEventTap: _showEventDetails,
            ),
            _ParentCalendarView.month => _ParentMonthCalendarView(
              key: ValueKey('month-${_focusedDate.year}-${_focusedDate.month}'),
              focusedDate: _focusedDate,
              selectedDate: _selectedDate,
              entries: filteredEntries,
              theme: widget.theme,
              onDateSelected: (date) => setState(() {
                _selectedDate = date;
                _focusedDate = date;
              }),
            ),
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        _ParentAgendaSection(
          title: _agendaTitle(context),
          entries: visibleEntries,
          theme: widget.theme,
          onEventTap: _showEventDetails,
        ),
      ],
    );
  }

  DateTime _shiftFocusedDate(int amount) {
    return switch (_view) {
      _ParentCalendarView.day => _focusedDate.add(Duration(days: amount)),
      _ParentCalendarView.week => _focusedDate.add(Duration(days: 7 * amount)),
      _ParentCalendarView.month => DateTime(
        _focusedDate.year,
        _focusedDate.month + amount,
        1,
      ),
    };
  }

  List<_ParentEventEntry> _visibleAgendaEntries(
    List<_ParentEventEntry> entries,
  ) {
    return switch (_view) {
      _ParentCalendarView.day => _entriesForDay(entries, _selectedDate),
      _ParentCalendarView.week => _entriesInRange(
        entries,
        _weekStart(_focusedDate),
        _weekStart(_focusedDate).add(const Duration(days: 7)),
      ),
      _ParentCalendarView.month => _entriesForDay(entries, _selectedDate),
    };
  }

  String _agendaTitle(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return switch (_view) {
      _ParentCalendarView.day => localizations.formatFullDate(_selectedDate),
      _ParentCalendarView.week => _weekTitle(context, _focusedDate),
      _ParentCalendarView.month => localizations.formatFullDate(_selectedDate),
    };
  }

  void _showEventDetails(_ParentEventEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom:
                  MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.md,
            ),
            child: _ParentSignedUpEventCard(entry: entry, theme: widget.theme),
          ),
        );
      },
    );
  }
}

class _ParentCalendarToolbar extends StatelessWidget {
  const _ParentCalendarToolbar({
    required this.focusedDate,
    required this.selectedDate,
    required this.view,
    required this.theme,
    required this.onPrevious,
    required this.onToday,
    required this.onNext,
    required this.onViewChanged,
  });

  final DateTime focusedDate;
  final DateTime selectedDate;
  final _ParentCalendarView view;
  final ThemeData theme;
  final VoidCallback onPrevious;
  final VoidCallback onToday;
  final VoidCallback onNext;
  final ValueChanged<_ParentCalendarView> onViewChanged;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final title = switch (view) {
      _ParentCalendarView.day => localizations.formatFullDate(selectedDate),
      _ParentCalendarView.week => _weekTitle(context, focusedDate),
      _ParentCalendarView.month => localizations.formatMonthYear(focusedDate),
    };

    return _CalendarSurface(
      theme: theme,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Previous',
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                tooltip: 'Today',
                onPressed: onToday,
                icon: const Icon(Icons.today_outlined),
              ),
              IconButton(
                tooltip: 'Next',
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<_ParentCalendarView>(
              segments: const [
                ButtonSegment(
                  value: _ParentCalendarView.day,
                  icon: Icon(Icons.view_day_outlined),
                  label: Text('Day'),
                ),
                ButtonSegment(
                  value: _ParentCalendarView.week,
                  icon: Icon(Icons.view_week_outlined),
                  label: Text('Week'),
                ),
                ButtonSegment(
                  value: _ParentCalendarView.month,
                  icon: Icon(Icons.calendar_month_outlined),
                  label: Text('Month'),
                ),
              ],
              selected: {view},
              onSelectionChanged: (selection) => onViewChanged(selection.first),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParentEventFilters extends StatelessWidget {
  const _ParentEventFilters({
    required this.childOptions,
    required this.selectedChildUid,
    required this.volunteeringOnly,
    required this.theme,
    required this.onChildChanged,
    required this.onVolunteeringChanged,
  });

  final List<MapEntry<String, String>> childOptions;
  final String selectedChildUid;
  final bool volunteeringOnly;
  final ThemeData theme;
  final ValueChanged<String> onChildChanged;
  final ValueChanged<bool> onVolunteeringChanged;

  @override
  Widget build(BuildContext context) {
    final childValue =
        selectedChildUid == _allChildrenFilterKey ||
            childOptions.any((child) => child.key == selectedChildUid)
        ? selectedChildUid
        : _allChildrenFilterKey;

    return _CalendarSurface(
      theme: theme,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 210,
            child: DropdownButtonFormField<String>(
              key: ValueKey(childValue),
              initialValue: childValue,
              borderRadius: BorderRadius.circular(18),
              decoration: const InputDecoration(
                labelText: 'Child',
                prefixIcon: Icon(Icons.supervisor_account_outlined),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(
                  value: _allChildrenFilterKey,
                  child: Text('All children'),
                ),
                for (final child in childOptions)
                  DropdownMenuItem(value: child.key, child: Text(child.value)),
              ],
              onChanged: (value) {
                if (value != null) onChildChanged(value);
              },
            ),
          ),
          FilterChip(
            avatar: const Icon(Icons.volunteer_activism_outlined, size: 18),
            label: const Text('Volunteering'),
            selected: volunteeringOnly,
            onSelected: onVolunteeringChanged,
            labelStyle: theme.textTheme.labelLarge?.copyWith(
              color: volunteeringOnly
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
            selectedColor: theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.surface,
            side: BorderSide(
              color: volunteeringOnly
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParentMonthCalendarView extends StatelessWidget {
  const _ParentMonthCalendarView({
    super.key,
    required this.focusedDate,
    required this.selectedDate,
    required this.entries,
    required this.theme,
    required this.onDateSelected,
  });

  final DateTime focusedDate;
  final DateTime selectedDate;
  final List<_ParentEventEntry> entries;
  final ThemeData theme;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final monthStart = DateTime(focusedDate.year, focusedDate.month);
    final gridStart = monthStart.subtract(
      Duration(days: monthStart.weekday % 7),
    );
    final days = List.generate(
      42,
      (index) => _dateOnly(gridStart.add(Duration(days: index))),
    );

    return _CalendarSurface(
      theme: theme,
      child: Column(
        children: [
          const _WeekdayHeader(),
          const SizedBox(height: AppSpacing.xs),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.86,
            ),
            itemBuilder: (context, index) {
              final date = days[index];
              final dayEntries = _entriesForDay(entries, date);
              return _MonthDayCell(
                date: date,
                inFocusedMonth: date.month == focusedDate.month,
                selected: _isSameDay(date, selectedDate),
                today: _isSameDay(date, DateTime.now()),
                entries: dayEntries,
                theme: theme,
                onTap: () => onDateSelected(date),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    required this.date,
    required this.inFocusedMonth,
    required this.selected,
    required this.today,
    required this.entries,
    required this.theme,
    required this.onTap,
  });

  final DateTime date;
  final bool inFocusedMonth;
  final bool selected;
  final bool today;
  final List<_ParentEventEntry> entries;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visibleEntries = entries.take(3).toList();
    final dayColor = !inFocusedMonth
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.36)
        : selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : today
              ? theme.colorScheme.primary.withValues(alpha: 0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${date.day}',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: dayColor,
                fontWeight: today || selected
                    ? FontWeight.w900
                    : FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            for (final entry in visibleEntries)
              _MonthEventLine(color: _eventColor(entry.event)),
            if (entries.length > visibleEntries.length)
              Text(
                '+${entries.length - visibleEntries.length}',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MonthEventLine extends StatelessWidget {
  const _MonthEventLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      margin: const EdgeInsets.only(bottom: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _ParentWeekCalendarView extends StatelessWidget {
  const _ParentWeekCalendarView({
    super.key,
    required this.focusedDate,
    required this.selectedDate,
    required this.entries,
    required this.theme,
    required this.onDateSelected,
    required this.onEventTap,
  });

  final DateTime focusedDate;
  final DateTime selectedDate;
  final List<_ParentEventEntry> entries;
  final ThemeData theme;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<_ParentEventEntry> onEventTap;

  @override
  Widget build(BuildContext context) {
    final start = _weekStart(focusedDate);
    final days = List.generate(7, (index) => start.add(Duration(days: index)));

    return _CalendarSurface(
      theme: theme,
      child: Column(
        children: [
          const _WeekdayHeader(),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final date in days)
                Expanded(
                  child: _WeekDayColumn(
                    date: date,
                    entries: _entriesForDay(entries, date),
                    selected: _isSameDay(date, selectedDate),
                    today: _isSameDay(date, DateTime.now()),
                    theme: theme,
                    onTap: () => onDateSelected(_dateOnly(date)),
                    onEventTap: onEventTap,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekDayColumn extends StatelessWidget {
  const _WeekDayColumn({
    required this.date,
    required this.entries,
    required this.selected,
    required this.today,
    required this.theme,
    required this.onTap,
    required this.onEventTap,
  });

  final DateTime date;
  final List<_ParentEventEntry> entries;
  final bool selected;
  final bool today;
  final ThemeData theme;
  final VoidCallback onTap;
  final ValueChanged<_ParentEventEntry> onEventTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 154),
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.09)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${date.day}',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: today
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
                fontWeight: today ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final entry in entries.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: _CalendarMiniEventPill(
                  entry: entry,
                  color: _eventColor(entry.event),
                  theme: theme,
                  onTap: () => onEventTap(entry),
                ),
              ),
            if (entries.length > 3)
              Text(
                '+${entries.length - 3}',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ParentDayCalendarView extends StatelessWidget {
  const _ParentDayCalendarView({
    super.key,
    required this.date,
    required this.entries,
    required this.theme,
    required this.onEventTap,
  });

  final DateTime date;
  final List<_ParentEventEntry> entries;
  final ThemeData theme;
  final ValueChanged<_ParentEventEntry> onEventTap;

  @override
  Widget build(BuildContext context) {
    final byHour = <int, List<_ParentEventEntry>>{};
    for (final entry in entries) {
      byHour.putIfAbsent(entry.event.startTime.hour, () => []).add(entry);
    }

    return _CalendarSurface(
      theme: theme,
      child: Column(
        children: [
          for (var hour = 7; hour <= 20; hour++)
            _HourRow(
              hour: hour,
              entries: byHour[hour] ?? const <_ParentEventEntry>[],
              theme: theme,
              onEventTap: onEventTap,
            ),
          for (final entry in entries.where(
            (entry) =>
                entry.event.startTime.hour < 7 ||
                entry.event.startTime.hour > 20,
          ))
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: _CalendarAgendaEventTile(
                entry: entry,
                color: _eventColor(entry.event),
                theme: theme,
                onTap: () => onEventTap(entry),
              ),
            ),
        ],
      ),
    );
  }
}

class _HourRow extends StatelessWidget {
  const _HourRow({
    required this.hour,
    required this.entries,
    required this.theme,
    required this.onEventTap,
  });

  final int hour;
  final List<_ParentEventEntry> entries;
  final ThemeData theme;
  final ValueChanged<_ParentEventEntry> onEventTap;

  @override
  Widget build(BuildContext context) {
    final hourLabel = TimeOfDay(hour: hour, minute: 0).format(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Text(
              hourLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? const SizedBox(height: 38)
                : Column(
                    children: [
                      for (final entry in entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: _CalendarAgendaEventTile(
                            entry: entry,
                            color: _eventColor(entry.event),
                            theme: theme,
                            compact: true,
                            onTap: () => onEventTap(entry),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ParentAgendaSection extends StatelessWidget {
  const _ParentAgendaSection({
    required this.title,
    required this.entries,
    required this.theme,
    required this.onEventTap,
  });

  final String title;
  final List<_ParentEventEntry> entries;
  final ThemeData theme;
  final ValueChanged<_ParentEventEntry> onEventTap;

  @override
  Widget build(BuildContext context) {
    final visibleEntries = entries.take(_parentAgendaPreviewLimit).toList();
    final hiddenCount = entries.length - visibleEntries.length;

    return _CalendarSurface(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${entries.length}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (entries.isEmpty)
            _CalendarInlineEmptyState(theme: theme)
          else
            for (var i = 0; i < visibleEntries.length; i++) ...[
              _CalendarAgendaEventTile(
                entry: visibleEntries[i],
                color: _eventColor(visibleEntries[i].event),
                theme: theme,
                onTap: () => onEventTap(visibleEntries[i]),
              ),
              if (i != visibleEntries.length - 1)
                const SizedBox(height: AppSpacing.xs),
            ],
          if (hiddenCount > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '+$hiddenCount more in this view',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CalendarAgendaEventTile extends StatelessWidget {
  const _CalendarAgendaEventTile({
    required this.entry,
    required this.color,
    required this.theme,
    required this.onTap,
    this.compact = false,
  });

  final _ParentEventEntry entry;
  final Color color;
  final ThemeData theme;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final event = entry.event;
    final time = TimeOfDay.fromDateTime(event.startTime).format(context);
    final source = event.clubTitle.trim().isEmpty
        ? 'Schoolwide'
        : event.clubTitle.trim();

    return Material(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 8 : AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: compact ? 48 : 62,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          time,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            source,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      event.title.trim().isEmpty
                          ? 'Untitled event'
                          : event.title,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.childNames,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (entry.volunteered) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.volunteer_activism_outlined,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarMiniEventPill extends StatelessWidget {
  const _CalendarMiniEventPill({
    required this.entry,
    required this.color,
    required this.theme,
    required this.onTap,
  });

  final _ParentEventEntry entry;
  final Color color;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Text(
            entry.event.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }
}

class _ParentSignedUpEventCard extends StatelessWidget {
  const _ParentSignedUpEventCard({required this.entry, required this.theme});

  final _ParentEventEntry entry;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final event = entry.event;
    final dateText = MaterialLocalizations.of(
      context,
    ).formatFullDate(event.startTime);
    final timeText = TimeOfDay.fromDateTime(event.startTime).format(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: AppDecorations.shadow(context).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  event.title.trim().isEmpty ? 'Untitled event' : event.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StudentPill(name: entry.childNames, theme: theme),
            ],
          ),
          if (entry.volunteered) ...[
            const SizedBox(height: AppSpacing.sm),
            _VolunteerPill(theme: theme),
          ],
          if (event.description.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(event.description, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.md),
          _InfoRow(
            icon: Icons.access_time_rounded,
            label: '$dateText at $timeText',
            theme: theme,
          ),
          if (event.location.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            _InfoRow(
              icon: Icons.place_outlined,
              label: event.location.trim(),
              theme: theme,
            ),
          ],
          if (event.clubTitle.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            _InfoRow(
              icon: Icons.groups_2_outlined,
              label: event.clubTitle.trim(),
              theme: theme,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          CalendarEventActions(event: event),
        ],
      ),
    );
  }
}

class _StudentPill extends StatelessWidget {
  const _StudentPill({required this.name, required this.theme});

  final String name;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        name.trim().isEmpty ? 'Student' : name.trim(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _VolunteerPill extends StatelessWidget {
  const _VolunteerPill({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'You are volunteering',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Row(
      children: [
        for (final label in labels)
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

class _CalendarSurface extends StatelessWidget {
  const _CalendarSurface({
    required this.theme,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.sm),
  });

  final ThemeData theme;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: AppDecorations.shadow(context).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CalendarInlineEmptyState extends StatelessWidget {
  const _CalendarInlineEmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 28,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('No events here.', style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ParentEventsEmptyState extends StatelessWidget {
  const _ParentEventsEmptyState({
    required this.icon,
    required this.message,
    required this.theme,
  });

  final IconData icon;
  final String message;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

String? _studentDisplayName(UserProfile? student) {
  if (student == null) return null;
  final realName = student.realName.trim();
  if (realName.isNotEmpty) return realName;
  final displayName = student.displayName.trim();
  if (displayName.isNotEmpty) return displayName;
  return 'Student';
}

String _eventKey(PlatformEvent event) {
  return '${event.schoolID}:${event.clubID}:${event.id}';
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime _weekStart(DateTime date) {
  final normalized = _dateOnly(date);
  return normalized.subtract(Duration(days: normalized.weekday % 7));
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

List<_ParentEventEntry> _entriesForDay(
  List<_ParentEventEntry> entries,
  DateTime date,
) {
  return entries
      .where((entry) => _isSameDay(entry.event.startTime, date))
      .toList()
    ..sort((a, b) => a.event.startTime.compareTo(b.event.startTime));
}

List<_ParentEventEntry> _entriesInRange(
  List<_ParentEventEntry> entries,
  DateTime start,
  DateTime end,
) {
  return entries
      .where(
        (entry) =>
            !entry.event.startTime.isBefore(start) &&
            entry.event.startTime.isBefore(end),
      )
      .toList()
    ..sort((a, b) => a.event.startTime.compareTo(b.event.startTime));
}

DateTime _initialCalendarDate(
  List<_ParentEventEntry> entries,
  DateTime fallback,
) {
  final sortedEntries = [...entries]
    ..sort((a, b) => a.event.startTime.compareTo(b.event.startTime));
  final visibleMonthStart = DateTime(fallback.year, fallback.month);
  final visibleMonthEnd = DateTime(fallback.year, fallback.month + 1);
  final entriesThisMonth = _entriesInRange(
    sortedEntries,
    visibleMonthStart,
    visibleMonthEnd,
  );
  final today = _dateOnly(DateTime.now());
  final targetEntry =
      _firstEntryOnOrAfter(entriesThisMonth, today) ??
      _firstEntryOnOrAfter(sortedEntries, today) ??
      sortedEntries.first;
  return _dateOnly(targetEntry.event.startTime);
}

_ParentEventEntry? _firstEntryOnOrAfter(
  List<_ParentEventEntry> entries,
  DateTime date,
) {
  for (final entry in entries) {
    if (!entry.event.startTime.isBefore(date)) return entry;
  }
  return null;
}

String _weekTitle(BuildContext context, DateTime focusedDate) {
  final localizations = MaterialLocalizations.of(context);
  final start = _weekStart(focusedDate);
  final end = start.add(const Duration(days: 6));
  final sameMonth = start.month == end.month && start.year == end.year;
  if (sameMonth) {
    return '${localizations.formatMonthYear(start)} ${start.day}-${end.day}';
  }
  return '${localizations.formatShortDate(start)} - ${localizations.formatShortDate(end)}';
}

Color _eventColor(PlatformEvent event) {
  final clubID = event.clubID.trim();
  if (clubID.isEmpty) return _schoolwideEventColor;
  final key = clubID.isNotEmpty ? clubID : event.clubTitle;
  final hash = key.codeUnits.fold<int>(0, (value, unit) => value + unit);
  return _parentEventColors[hash % _parentEventColors.length];
}
