import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../Components/calendar_event_actions.dart';
import '../Components/confirmation_hub.dart';
import '../Components/deferred_content.dart';
import '../Models/club.dart';
import '../Models/platform_event.dart';
import '../Models/poll.dart';
import '../Models/user.dart';
import '../Providers/current_user_profile_notifier.dart';
import '../Service/firebase_service.dart';
import '../Utility/AppSpacing.dart';
import '../Utility/app_decorations.dart';
import 'Clubs/polls_tab.dart';
import 'qr_scanner_page.dart';

const double _eventsBottomNavGap = AppSpacing.xl * 3;
const Duration _eventTabDataDelay = Duration.zero;
const int _agendaPreviewLimit = 12;

class EventPage extends StatelessWidget {
  const EventPage({super.key, this.schoolIDOverride});

  final String? schoolIDOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firebase = context.read<FirebaseService>();
    final profileN = context.watch<CurrentUserProfileNotifier>();
    final profile = profileN.profile;
    final schoolID = schoolIDOverride ?? profileN.profile?.schoolID;
    final canParticipate = profile?.canParticipate ?? false;
    final canViewSubmissions =
        canParticipate && schoolIDOverride == null && profile != null;
    final tabCount = canViewSubmissions ? 3 : 2;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          "Events",
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
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
        actions: [
          if (canParticipate)
            IconButton(
              tooltip: 'Check in',
              icon: const Icon(Icons.qr_code_scanner_outlined),
              onPressed: () {
                if (schoolID == null || schoolID.isEmpty) return;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => QrScannerPage(
                      schoolID: schoolID,
                      mode: QrScannerMode.attendanceAndHallPass,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: DefaultTabController(
        length: tabCount,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: AppDecorations.screenBackground(context),
          child: SafeArea(
            child: schoolID == null || schoolID.isEmpty
                ? Center(
                    child: Text(
                      'Please join a school to view events.',
                      style: theme.textTheme.bodyLarge,
                    ),
                  )
                : Column(
                    children: [
                      TabBar(
                        tabs: [
                          const Tab(text: 'Upcoming Events'),
                          const Tab(text: 'School Polls'),
                          if (canViewSubmissions) const Tab(text: 'My Events'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _KeepAliveEventTab(
                              storageKey: 'events_upcoming_$schoolID',
                              child: DeferredTabContent(
                                tabIndex: 0,
                                delay: _eventTabDataDelay,
                                child: _EventsList(
                                  schoolID: schoolID,
                                  theme: theme,
                                  firebase: firebase,
                                  viewer: profile,
                                ),
                              ),
                            ),
                            _KeepAliveEventTab(
                              storageKey: 'events_polls_$schoolID',
                              child: DeferredTabContent(
                                tabIndex: 1,
                                delay: _eventTabDataDelay,
                                child: _PollsList(
                                  schoolID: schoolID,
                                  theme: theme,
                                  firebase: firebase,
                                ),
                              ),
                            ),
                            if (canViewSubmissions)
                              _KeepAliveEventTab(
                                storageKey: 'events_submissions_$schoolID',
                                child: DeferredTabContent(
                                  tabIndex: 2,
                                  delay: _eventTabDataDelay,
                                  child: _MySubmissionsList(
                                    schoolID: schoolID,
                                    creatorId: profile.UID,
                                    theme: theme,
                                    firebase: firebase,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _KeepAliveEventTab extends StatefulWidget {
  const _KeepAliveEventTab({required this.storageKey, required this.child});

  final String storageKey;
  final Widget child;

  @override
  State<_KeepAliveEventTab> createState() => _KeepAliveEventTabState();
}

class _KeepAliveEventTabState extends State<_KeepAliveEventTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(
      key: PageStorageKey(widget.storageKey),
      child: widget.child,
    );
  }
}

Future<void> showCreateEventDialog({
  required BuildContext context,
  required String schoolID,
  required ClubInfo club,
  required UserProfile creator,
  bool canChangeVisibility = false,
}) {
  return showDialog(
    context: context,
    builder: (_) => _CreateEventDialog(
      schoolID: schoolID,
      club: club,
      creator: creator,
      canChangeVisibility: canChangeVisibility,
    ),
  );
}

enum _EventCalendarView { day, week, month }

const String _allEventsSourceKey = 'all';
const String _schoolwideEventsSourceKey = 'schoolwide';
const Color _schoolwideEventColor = Color(0xFF0EA5E9);
const List<Color> _fallbackEventColors = [
  Color(0xFFEF4444),
  Color(0xFFF59E0B),
  Color(0xFF10B981),
  Color(0xFF3B82F6),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
  Color(0xFF14B8A6),
  Color(0xFFF97316),
];

class _EventsList extends StatelessWidget {
  const _EventsList({
    required this.schoolID,
    required this.theme,
    required this.firebase,
    required this.viewer,
  });
  final String schoolID;
  final ThemeData theme;
  final FirebaseService firebase;
  final UserProfile? viewer;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ClubInfo>>(
      stream: firebase.getClubs(schoolID),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _CalendarEmptyState(
            icon: Icons.groups_2_outlined,
            message: 'Event sources could not load.',
            theme: theme,
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final clubs = snapshot.data ?? const <ClubInfo>[];
        final initialStartAt = DateTime.now().subtract(
          const Duration(days: 45),
        );
        final viewer = this.viewer;
        if (viewer == null) {
          return _EventsCalendarFuture(
            future: firebase.getCalendarEventsOnce(
              schoolID,
              const <String>[],
              startAt: initialStartAt,
              perSourceLimit: 80,
            ),
            clubs: clubs,
            theme: theme,
          );
        }

        return FutureBuilder<Set<String>>(
          future: firebase.getMembershipClubIds(
            schoolID,
            viewer.UID,
            clubs.map((club) => club.id),
          ),
          builder: (context, membershipSnapshot) {
            if (membershipSnapshot.connectionState == ConnectionState.waiting &&
                !membershipSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final memberClubIDs = membershipSnapshot.data ?? const <String>{};
            return _EventsCalendarFuture(
              future: firebase.getCalendarEventsOnce(
                schoolID,
                memberClubIDs,
                startAt: initialStartAt,
                perSourceLimit: 80,
              ),
              clubs: clubs,
              theme: theme,
              memberClubIDs: memberClubIDs,
            );
          },
        );
      },
    );
  }
}

class _EventsCalendarFuture extends StatelessWidget {
  const _EventsCalendarFuture({
    required this.future,
    required this.clubs,
    required this.theme,
    this.memberClubIDs,
  });

  final Future<List<PlatformEvent>> future;
  final List<ClubInfo> clubs;
  final ThemeData theme;
  final Set<String>? memberClubIDs;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PlatformEvent>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _CalendarEmptyState(
            icon: Icons.event_busy_outlined,
            message: 'Events could not load.',
            theme: theme,
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return _EventsCalendar(
          events: snapshot.data ?? const <PlatformEvent>[],
          clubs: clubs,
          theme: theme,
          memberClubIDs: memberClubIDs,
        );
      },
    );
  }
}

class _EventsCalendar extends StatefulWidget {
  const _EventsCalendar({
    required this.events,
    required this.clubs,
    required this.theme,
    this.memberClubIDs,
  });

  final List<PlatformEvent> events;
  final List<ClubInfo> clubs;
  final ThemeData theme;
  final Set<String>? memberClubIDs;

  @override
  State<_EventsCalendar> createState() => _EventsCalendarState();
}

class _EventsCalendarState extends State<_EventsCalendar> {
  late DateTime _focusedDate = _dateOnly(DateTime.now());
  late DateTime _selectedDate = _focusedDate;
  _EventCalendarView _view = _EventCalendarView.month;
  String _selectedSourceKey = _allEventsSourceKey;
  bool _hasSyncedInitialEventDate = false;

  @override
  void initState() {
    super.initState();
    _syncInitialEventDate();
  }

  @override
  void didUpdateWidget(covariant _EventsCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncInitialEventDate(notify: true);
  }

  void _syncInitialEventDate({bool notify = false}) {
    if (_hasSyncedInitialEventDate || widget.events.isEmpty) return;
    final targetDate = _initialCalendarDate(widget.events, _focusedDate);
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

  void _applySourceFilter(String sourceKey) {
    final matchingEvents = widget.events
        .where((event) => _sourceMatches(event, sourceKey))
        .toList();
    setState(() {
      _selectedSourceKey = sourceKey;
      if (matchingEvents.isEmpty) return;
      final targetDate = _initialCalendarDate(matchingEvents, _focusedDate);
      _focusedDate = targetDate;
      _selectedDate = targetDate;
    });
  }

  @override
  Widget build(BuildContext context) {
    final clubsById = {for (final club in widget.clubs) club.id: club};
    final memberClubIDs = widget.memberClubIDs;
    final primarySourceOptions = [
      const _EventSourceOption(key: _allEventsSourceKey, label: 'All'),
      const _EventSourceOption(
        key: _schoolwideEventsSourceKey,
        label: 'Schoolwide',
        color: _schoolwideEventColor,
      ),
      ..._clubSourceOptions(
        widget.events,
        widget.clubs,
        includeClub: memberClubIDs == null
            ? null
            : (clubID) => memberClubIDs.contains(clubID),
      ),
    ];
    final overflowSourceOptions = memberClubIDs == null
        ? const <_EventSourceOption>[]
        : _clubSourceOptions(
            widget.events,
            widget.clubs,
            includeClub: (clubID) => !memberClubIDs.contains(clubID),
          );
    final sourceOptions = [...primarySourceOptions, ...overflowSourceOptions];
    final activeSourceKey =
        sourceOptions.any((option) => option.key == _selectedSourceKey)
        ? _selectedSourceKey
        : _allEventsSourceKey;
    final filteredEvents =
        widget.events
            .where((event) => _sourceMatches(event, activeSourceKey))
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final visibleEvents = _visibleAgendaEvents(filteredEvents);

    final toolbar = _CalendarToolbar(
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
    );
    final sourceFilter = _EventSourceFilter(
      options: primarySourceOptions,
      overflowOptions: overflowSourceOptions,
      selectedKey: activeSourceKey,
      theme: widget.theme,
      onSelected: _applySourceFilter,
    );
    final calendarView = AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: switch (_view) {
        _EventCalendarView.day => _DayCalendarView(
          key: ValueKey('day-${_selectedDate.toIso8601String()}'),
          date: _selectedDate,
          events: _eventsForDay(filteredEvents, _selectedDate),
          clubsById: clubsById,
          theme: widget.theme,
          onEventTap: _showEventDetails,
        ),
        _EventCalendarView.week => _WeekCalendarView(
          key: ValueKey('week-${_weekStart(_focusedDate)}'),
          focusedDate: _focusedDate,
          selectedDate: _selectedDate,
          events: filteredEvents,
          clubsById: clubsById,
          theme: widget.theme,
          onDateSelected: (date) => setState(() {
            _selectedDate = date;
            _focusedDate = date;
          }),
          onEventTap: _showEventDetails,
        ),
        _EventCalendarView.month => _MonthCalendarView(
          key: ValueKey('month-${_focusedDate.year}-${_focusedDate.month}'),
          focusedDate: _focusedDate,
          selectedDate: _selectedDate,
          events: filteredEvents,
          clubsById: clubsById,
          theme: widget.theme,
          onDateSelected: (date) => setState(() {
            _selectedDate = date;
            _focusedDate = date;
          }),
        ),
      },
    );
    final agenda = _AgendaSection(
      title: _agendaTitle(context),
      events: visibleEvents,
      clubsById: clubsById,
      theme: widget.theme,
      onEventTap: _showEventDetails,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final useSplitPane = constraints.maxWidth >= 900;
        final useTabletPadding = constraints.maxWidth >= 700;
        final horizontalPadding = useTabletPadding
            ? AppSpacing.xl
            : AppSpacing.screenPaddingH;
        final bottomPadding = useTabletPadding
            ? AppSpacing.xl
            : _eventsBottomNavGap;

        if (useSplitPane) {
          final sidebarWidth = constraints.maxWidth >= 1180 ? 380.0 : 340.0;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              AppSpacing.lg,
              horizontalPadding,
              bottomPadding,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: SingleChildScrollView(child: calendarView)),
                const SizedBox(width: AppSpacing.lg),
                SizedBox(
                  width: sidebarWidth,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        toolbar,
                        const SizedBox(height: AppSpacing.md),
                        sourceFilter,
                        const SizedBox(height: AppSpacing.md),
                        agenda,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: useTabletPadding ? 720 : double.infinity,
            ),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                AppSpacing.md,
                horizontalPadding,
                bottomPadding,
              ),
              children: [
                toolbar,
                const SizedBox(height: AppSpacing.md),
                sourceFilter,
                const SizedBox(height: AppSpacing.md),
                calendarView,
                const SizedBox(height: AppSpacing.lg),
                agenda,
              ],
            ),
          ),
        );
      },
    );
  }

  DateTime _shiftFocusedDate(int amount) {
    return switch (_view) {
      _EventCalendarView.day => _focusedDate.add(Duration(days: amount)),
      _EventCalendarView.week => _focusedDate.add(Duration(days: 7 * amount)),
      _EventCalendarView.month => DateTime(
        _focusedDate.year,
        _focusedDate.month + amount,
        1,
      ),
    };
  }

  List<PlatformEvent> _visibleAgendaEvents(List<PlatformEvent> events) {
    return switch (_view) {
      _EventCalendarView.day => _eventsForDay(events, _selectedDate),
      _EventCalendarView.week => _eventsInRange(
        events,
        _weekStart(_focusedDate),
        _weekStart(_focusedDate).add(const Duration(days: 7)),
      ),
      _EventCalendarView.month => _eventsForDay(events, _selectedDate),
    };
  }

  String _agendaTitle(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return switch (_view) {
      _EventCalendarView.day => localizations.formatFullDate(_selectedDate),
      _EventCalendarView.week => _weekTitle(context, _focusedDate),
      _EventCalendarView.month => localizations.formatFullDate(_selectedDate),
    };
  }

  void _showEventDetails(PlatformEvent event) {
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
            child: _EventCard(event: event, theme: widget.theme),
          ),
        );
      },
    );
  }
}

class _CalendarToolbar extends StatelessWidget {
  const _CalendarToolbar({
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
  final _EventCalendarView view;
  final ThemeData theme;
  final VoidCallback onPrevious;
  final VoidCallback onToday;
  final VoidCallback onNext;
  final ValueChanged<_EventCalendarView> onViewChanged;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final title = switch (view) {
      _EventCalendarView.day => localizations.formatFullDate(selectedDate),
      _EventCalendarView.week => _weekTitle(context, focusedDate),
      _EventCalendarView.month => localizations.formatMonthYear(focusedDate),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
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
            child: SegmentedButton<_EventCalendarView>(
              segments: const [
                ButtonSegment(
                  value: _EventCalendarView.day,
                  icon: Icon(Icons.view_day_outlined),
                  label: Text('Day'),
                ),
                ButtonSegment(
                  value: _EventCalendarView.week,
                  icon: Icon(Icons.view_week_outlined),
                  label: Text('Week'),
                ),
                ButtonSegment(
                  value: _EventCalendarView.month,
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

class _EventSourceFilter extends StatelessWidget {
  const _EventSourceFilter({
    required this.options,
    required this.overflowOptions,
    required this.selectedKey,
    required this.theme,
    required this.onSelected,
  });

  final List<_EventSourceOption> options;
  final List<_EventSourceOption> overflowOptions;
  final String selectedKey;
  final ThemeData theme;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    _EventSourceOption? selectedOverflowOption;
    for (final option in overflowOptions) {
      if (option.key == selectedKey) {
        selectedOverflowOption = option;
        break;
      }
    }
    final itemCount = options.length + (overflowOptions.isEmpty ? 0 : 1);

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          if (index >= options.length) {
            final selected = selectedOverflowOption != null;
            return PopupMenuButton<String>(
              tooltip: 'Other clubs',
              onSelected: onSelected,
              itemBuilder: (context) => [
                for (final option in overflowOptions)
                  PopupMenuItem<String>(
                    value: option.key,
                    child: Row(
                      children: [
                        if (option.color != null) ...[
                          CircleAvatar(
                            backgroundColor: option.color,
                            radius: 5,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Expanded(child: Text(option.label)),
                      ],
                    ),
                  ),
              ],
              child: Chip(
                avatar: Icon(
                  Icons.arrow_drop_down_circle_outlined,
                  size: 18,
                  color: selected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.primary,
                ),
                label: Text(selectedOverflowOption?.label ?? 'Other clubs'),
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  color: selected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
                backgroundColor: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surface,
                side: BorderSide(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }
          final option = options[index];
          final selected = option.key == selectedKey;
          return ChoiceChip(
            avatar: option.color == null
                ? null
                : CircleAvatar(backgroundColor: option.color, radius: 6),
            label: Text(option.label),
            selected: selected,
            onSelected: (_) => onSelected(option.key),
            labelStyle: theme.textTheme.labelLarge?.copyWith(
              color: selected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
            selectedColor: theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.surface,
            side: BorderSide(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          );
        },
      ),
    );
  }
}

class _MonthCalendarView extends StatelessWidget {
  const _MonthCalendarView({
    super.key,
    required this.focusedDate,
    required this.selectedDate,
    required this.events,
    required this.clubsById,
    required this.theme,
    required this.onDateSelected,
  });

  final DateTime focusedDate;
  final DateTime selectedDate;
  final List<PlatformEvent> events;
  final Map<String, ClubInfo> clubsById;
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
              final dayEvents = _eventsForDay(events, date);
              return _MonthDayCell(
                date: date,
                inFocusedMonth: date.month == focusedDate.month,
                selected: _isSameDay(date, selectedDate),
                today: _isSameDay(date, DateTime.now()),
                events: dayEvents,
                clubsById: clubsById,
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
    required this.events,
    required this.clubsById,
    required this.theme,
    required this.onTap,
  });

  final DateTime date;
  final bool inFocusedMonth;
  final bool selected;
  final bool today;
  final List<PlatformEvent> events;
  final Map<String, ClubInfo> clubsById;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visibleEvents = events.take(3).toList();
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
            for (final event in visibleEvents)
              _MonthEventLine(color: _eventColor(event, clubsById)),
            if (events.length > visibleEvents.length)
              Text(
                '+${events.length - visibleEvents.length}',
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

class _WeekCalendarView extends StatelessWidget {
  const _WeekCalendarView({
    super.key,
    required this.focusedDate,
    required this.selectedDate,
    required this.events,
    required this.clubsById,
    required this.theme,
    required this.onDateSelected,
    required this.onEventTap,
  });

  final DateTime focusedDate;
  final DateTime selectedDate;
  final List<PlatformEvent> events;
  final Map<String, ClubInfo> clubsById;
  final ThemeData theme;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<PlatformEvent> onEventTap;

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
                    events: _eventsForDay(events, date),
                    selected: _isSameDay(date, selectedDate),
                    today: _isSameDay(date, DateTime.now()),
                    clubsById: clubsById,
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
    required this.events,
    required this.selected,
    required this.today,
    required this.clubsById,
    required this.theme,
    required this.onTap,
    required this.onEventTap,
  });

  final DateTime date;
  final List<PlatformEvent> events;
  final bool selected;
  final bool today;
  final Map<String, ClubInfo> clubsById;
  final ThemeData theme;
  final VoidCallback onTap;
  final ValueChanged<PlatformEvent> onEventTap;

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
            for (final event in events.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: _CalendarMiniEventPill(
                  event: event,
                  color: _eventColor(event, clubsById),
                  theme: theme,
                  onTap: () => onEventTap(event),
                ),
              ),
            if (events.length > 3)
              Text(
                '+${events.length - 3}',
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

class _DayCalendarView extends StatelessWidget {
  const _DayCalendarView({
    super.key,
    required this.date,
    required this.events,
    required this.clubsById,
    required this.theme,
    required this.onEventTap,
  });

  final DateTime date;
  final List<PlatformEvent> events;
  final Map<String, ClubInfo> clubsById;
  final ThemeData theme;
  final ValueChanged<PlatformEvent> onEventTap;

  @override
  Widget build(BuildContext context) {
    final byHour = <int, List<PlatformEvent>>{};
    for (final event in events) {
      byHour.putIfAbsent(event.startTime.hour, () => []).add(event);
    }

    return _CalendarSurface(
      theme: theme,
      child: Column(
        children: [
          for (var hour = 7; hour <= 20; hour++)
            _HourRow(
              hour: hour,
              events: byHour[hour] ?? const <PlatformEvent>[],
              clubsById: clubsById,
              theme: theme,
              onEventTap: onEventTap,
            ),
          for (final event in events.where(
            (event) => event.startTime.hour < 7 || event.startTime.hour > 20,
          ))
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: _CalendarAgendaEventTile(
                event: event,
                color: _eventColor(event, clubsById),
                theme: theme,
                onTap: () => onEventTap(event),
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
    required this.events,
    required this.clubsById,
    required this.theme,
    required this.onEventTap,
  });

  final int hour;
  final List<PlatformEvent> events;
  final Map<String, ClubInfo> clubsById;
  final ThemeData theme;
  final ValueChanged<PlatformEvent> onEventTap;

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
            child: events.isEmpty
                ? const SizedBox(height: 38)
                : Column(
                    children: [
                      for (final event in events)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: _CalendarAgendaEventTile(
                            event: event,
                            color: _eventColor(event, clubsById),
                            theme: theme,
                            compact: true,
                            onTap: () => onEventTap(event),
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

class _AgendaSection extends StatelessWidget {
  const _AgendaSection({
    required this.title,
    required this.events,
    required this.clubsById,
    required this.theme,
    required this.onEventTap,
  });

  final String title;
  final List<PlatformEvent> events;
  final Map<String, ClubInfo> clubsById;
  final ThemeData theme;
  final ValueChanged<PlatformEvent> onEventTap;

  @override
  Widget build(BuildContext context) {
    final visibleEvents = events.take(_agendaPreviewLimit).toList();
    final hiddenCount = events.length - visibleEvents.length;

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
                '${events.length}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (events.isEmpty)
            _CalendarEmptyState(
              icon: Icons.event_available_outlined,
              message: 'No events here.',
              theme: theme,
              compact: true,
            )
          else
            for (var i = 0; i < visibleEvents.length; i++) ...[
              _CalendarAgendaEventTile(
                event: visibleEvents[i],
                color: _eventColor(visibleEvents[i], clubsById),
                theme: theme,
                onTap: () => onEventTap(visibleEvents[i]),
              ),
              if (i != visibleEvents.length - 1)
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
    required this.event,
    required this.color,
    required this.theme,
    required this.onTap,
    this.compact = false,
  });

  final PlatformEvent event;
  final Color color;
  final ThemeData theme;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(event.startTime).format(context);
    final source = _eventSourceLabel(event);

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
                height: compact ? 42 : 54,
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
                      event.title,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (!compact && event.location.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        event.location.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarMiniEventPill extends StatelessWidget {
  const _CalendarMiniEventPill({
    required this.event,
    required this.color,
    required this.theme,
    required this.onTap,
  });

  final PlatformEvent event;
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
            event.title,
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
  const _CalendarSurface({required this.theme, required this.child});

  final ThemeData theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
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

class _CalendarEmptyState extends StatelessWidget {
  const _CalendarEmptyState({
    required this.icon,
    required this.message,
    required this.theme,
    this.compact = false,
  });

  final IconData icon;
  final String message;
  final ThemeData theme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: compact ? 28 : 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(message, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _EventSourceOption {
  const _EventSourceOption({
    required this.key,
    required this.label,
    this.color,
  });

  final String key;
  final String label;
  final Color? color;
}

List<_EventSourceOption> _clubSourceOptions(
  List<PlatformEvent> events,
  List<ClubInfo> clubs, {
  bool Function(String clubID)? includeClub,
}) {
  final options = <_EventSourceOption>[];
  final eventClubIds = events
      .map((event) => event.clubID.trim())
      .where((clubID) => clubID.isNotEmpty)
      .toSet();
  final includedClubIds = <String>{};
  final sortedClubs = [...clubs]..sort((a, b) => a.title.compareTo(b.title));

  for (final club in sortedClubs) {
    final clubID = club.id.trim();
    if (!eventClubIds.contains(clubID)) continue;
    if (includeClub != null && !includeClub(clubID)) continue;
    includedClubIds.add(clubID);
    options.add(
      _EventSourceOption(
        key: _clubSourceKey(clubID),
        label: club.title.trim().isEmpty ? 'Untitled club' : club.title.trim(),
        color: club.accentColor,
      ),
    );
  }

  final fallbackClubLabels = <String, String>{};
  for (final event in events) {
    final clubID = event.clubID.trim();
    if (clubID.isEmpty || includedClubIds.contains(clubID)) continue;
    if (includeClub != null && !includeClub(clubID)) continue;
    fallbackClubLabels[clubID] = _eventSourceLabel(event);
  }
  for (final entry in fallbackClubLabels.entries) {
    options.add(
      _EventSourceOption(
        key: _clubSourceKey(entry.key),
        label: entry.value,
        color: _fallbackColorForKey(entry.key),
      ),
    );
  }

  return options;
}

bool _sourceMatches(PlatformEvent event, String sourceKey) {
  if (sourceKey == _allEventsSourceKey) return true;
  if (sourceKey == _schoolwideEventsSourceKey) return _isSchoolwideEvent(event);
  if (sourceKey.startsWith('club:')) {
    return event.clubID.trim() == sourceKey.substring(5);
  }
  return true;
}

String _clubSourceKey(String clubID) => 'club:$clubID';

bool _isSchoolwideEvent(PlatformEvent event) => event.clubID.trim().isEmpty;

String _eventSourceLabel(PlatformEvent event) {
  final clubTitle = event.clubTitle.trim();
  if (clubTitle.isNotEmpty) return clubTitle;
  return 'Schoolwide';
}

Color _eventColor(PlatformEvent event, Map<String, ClubInfo> clubsById) {
  if (_isSchoolwideEvent(event)) return _schoolwideEventColor;
  final clubID = event.clubID.trim();
  final clubColor = clubsById[clubID]?.accentColor;
  if (clubColor != null) return clubColor;
  return _fallbackColorForKey(clubID.isNotEmpty ? clubID : event.clubTitle);
}

Color _fallbackColorForKey(String key) {
  final hash = key.codeUnits.fold<int>(0, (value, unit) => value + unit);
  return _fallbackEventColors[hash % _fallbackEventColors.length];
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime _weekStart(DateTime date) {
  final normalized = _dateOnly(date);
  return normalized.subtract(Duration(days: normalized.weekday % 7));
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

List<PlatformEvent> _eventsForDay(List<PlatformEvent> events, DateTime date) {
  return events.where((event) => _isSameDay(event.startTime, date)).toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
}

List<PlatformEvent> _eventsInRange(
  List<PlatformEvent> events,
  DateTime start,
  DateTime end,
) {
  return events
      .where(
        (event) =>
            !event.startTime.isBefore(start) && event.startTime.isBefore(end),
      )
      .toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
}

DateTime _initialCalendarDate(List<PlatformEvent> events, DateTime fallback) {
  final sortedEvents = [...events]
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
  final visibleMonthStart = DateTime(fallback.year, fallback.month);
  final visibleMonthEnd = DateTime(fallback.year, fallback.month + 1);
  final eventsThisMonth = _eventsInRange(
    sortedEvents,
    visibleMonthStart,
    visibleMonthEnd,
  );
  final today = _dateOnly(DateTime.now());
  final targetEvent =
      _firstEventOnOrAfter(eventsThisMonth, today) ??
      _firstEventOnOrAfter(sortedEvents, today) ??
      sortedEvents.first;
  return _dateOnly(targetEvent.startTime);
}

PlatformEvent? _firstEventOnOrAfter(List<PlatformEvent> events, DateTime date) {
  for (final event in events) {
    if (!event.startTime.isBefore(date)) return event;
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

class _MySubmissionsList extends StatelessWidget {
  const _MySubmissionsList({
    required this.schoolID,
    required this.creatorId,
    required this.theme,
    required this.firebase,
  });

  final String schoolID;
  final String creatorId;
  final ThemeData theme;
  final FirebaseService firebase;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PlatformEvent>>(
      stream: firebase.getEventSubmissions(schoolID, creatorId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final events = snapshot.data ?? [];
        if (events.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.event_note_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  "No club event submissions yet.",
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPaddingH,
            AppSpacing.screenPaddingH,
            AppSpacing.screenPaddingH,
            _eventsBottomNavGap,
          ),
          itemCount: events.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            final event = events[index];
            return _EventCard(event: event, theme: theme, showStatus: true);
          },
        );
      },
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.theme,
    this.showStatus = false,
  });

  final PlatformEvent event;
  final ThemeData theme;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final dateText = MaterialLocalizations.of(
      context,
    ).formatFullDate(event.startTime);
    final timeText = TimeOfDay.fromDateTime(event.startTime).format(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppDecorations.shadow(context).withValues(alpha: 0.06),
            blurRadius: 20,
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
                  event.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (showStatus) _StatusPill(status: event.status, theme: theme),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(event.description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          _EventInfoRow(
            icon: Icons.access_time_rounded,
            label: '$dateText at $timeText',
            theme: theme,
          ),
          if (event.location.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            _EventInfoRow(
              icon: Icons.place_outlined,
              label: event.location.trim(),
              theme: theme,
            ),
          ],
          if (event.clubTitle.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            _EventInfoRow(
              icon: Icons.groups_2_outlined,
              label: event.clubTitle.trim(),
              theme: theme,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: CalendarEventActions(event: event),
          ),
        ],
      ),
    );
  }
}

class _EventInfoRow extends StatelessWidget {
  const _EventInfoRow({
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.theme});

  final String status;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      PlatformEvent.approvedStatus => theme.colorScheme.primaryContainer,
      PlatformEvent.rejectedStatus => theme.colorScheme.errorContainer,
      _ => theme.colorScheme.surfaceContainerHighest,
    };
    final textColor = switch (status) {
      PlatformEvent.approvedStatus => theme.colorScheme.onPrimaryContainer,
      PlatformEvent.rejectedStatus => theme.colorScheme.onErrorContainer,
      _ => theme.colorScheme.onSurfaceVariant,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: theme.textTheme.labelMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _CreateEventDialog extends StatefulWidget {
  const _CreateEventDialog({
    required this.schoolID,
    required this.club,
    required this.creator,
    this.canChangeVisibility = false,
  });

  final String schoolID;
  final ClubInfo club;
  final UserProfile creator;
  final bool canChangeVisibility;

  @override
  State<_CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<_CreateEventDialog> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _chaperonesNeeded = TextEditingController(text: '0');

  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 15, minute: 30);
  String _visibility = PlatformEvent.clubMembersVisibility;
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _chaperonesNeeded.dispose();
    super.dispose();
  }

  DateTime get _startTime =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final description = _description.text.trim();
    if (title.isEmpty || description.isEmpty) {
      QuiltConfirmation.warning(context, 'Add a title and description.');
      return;
    }
    if (_startTime.isBefore(DateTime.now())) {
      QuiltConfirmation.warning(context, 'Choose a future date and time.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final chaperonesNeeded =
          (int.tryParse(_chaperonesNeeded.text.trim()) ?? 0)
              .clamp(0, 20)
              .toInt();
      await context.read<FirebaseService>().createClubEvent(
        widget.schoolID,
        widget.club.id,
        PlatformEvent(
          id: '',
          schoolID: widget.schoolID,
          clubID: widget.club.id,
          clubTitle: widget.club.title,
          title: title,
          description: description,
          location: _location.text.trim(),
          startTime: _startTime,
          creatorId: widget.creator.UID,
          creatorName: widget.creator.realName.trim().isNotEmpty
              ? widget.creator.realName.trim()
              : widget.creator.displayName.trim(),
          status: PlatformEvent.pendingStatus,
          visibility: _visibility,
          chaperonesNeeded: chaperonesNeeded,
          contactName: widget.creator.realName.trim().isNotEmpty
              ? widget.creator.realName.trim()
              : widget.creator.displayName.trim(),
          contactEmail: widget.creator.email.trim(),
          requiresParentConnection: true,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      QuiltConfirmation.success(context, 'Event sent for admin review.');
    } catch (e) {
      if (!mounted) return;
      QuiltConfirmation.error(context, 'Could not create event: $e');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateText = MaterialLocalizations.of(context).formatFullDate(_date);
    final timeText = _time.format(context);

    return AlertDialog(
      title: const Text('Create event'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                enabled: !_submitting,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.event_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _description,
                enabled: !_submitting,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _location,
                enabled: !_submitting,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _chaperonesNeeded,
                enabled: !_submitting,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Parent chaperones needed',
                  prefixIcon: Icon(Icons.volunteer_activism_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _submitting ? null : _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(dateText, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: _submitting ? null : _pickTime,
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text(timeText),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: PlatformEvent.clubMembersVisibility,
                    icon: Icon(Icons.groups_2_outlined),
                    label: Text('Club'),
                  ),
                  ButtonSegment(
                    value: PlatformEvent.schoolMembersVisibility,
                    icon: Icon(Icons.school_outlined),
                    label: Text('School'),
                  ),
                  ButtonSegment(
                    value: PlatformEvent.publicVisibility,
                    icon: Icon(Icons.public_outlined),
                    label: Text('Public'),
                  ),
                ],
                selected: {_visibility},
                onSelectionChanged: _submitting || !widget.canChangeVisibility
                    ? null
                    : (selection) =>
                          setState(() => _visibility = selection.first),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Student-created events appear after an administrator approves them.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
          label: const Text('Submit'),
        ),
      ],
    );
  }
}

class _PollsList extends StatelessWidget {
  const _PollsList({
    required this.schoolID,
    required this.theme,
    required this.firebase,
  });
  final String schoolID;
  final ThemeData theme;
  final FirebaseService firebase;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ClubPoll>>(
      stream: firebase.getSchoolPolls(schoolID),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final polls = snapshot.data ?? [];
        if (polls.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.how_to_vote,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  "No active school polls.",
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPaddingH,
            AppSpacing.screenPaddingH,
            AppSpacing.screenPaddingH,
            _eventsBottomNavGap,
          ),
          itemCount: polls.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            return PollCard(
              poll: polls[index],
              schoolID: schoolID,
              isSchoolPoll: true,
            );
          },
        );
      },
    );
  }
}
