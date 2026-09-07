import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Models/bell_schedule.dart';
import '../Providers/current_user_profile_notifier.dart';
import '../Service/firebase_service.dart';
import '../Utility/AppSpacing.dart';
import '../Utility/app_decorations.dart';
import '../Utility/app_formatters.dart';

const Color _scheduleAccent = Color(0xFF0F766E);

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  Future<_SchedulePageData>? _scheduleFuture;
  String? _scheduleFutureKey;

  Future<_SchedulePageData> _schedulesFor(
    FirebaseService firebase,
    String schoolID,
    DateTime today,
  ) {
    final key = [schoolID, today.year, today.month, today.day].join(':');
    if (_scheduleFutureKey != key || _scheduleFuture == null) {
      final tomorrow = today.add(const Duration(days: 1));
      _scheduleFutureKey = key;
      _scheduleFuture =
          Future.wait<BellSchedule?>([
            firebase.getBellScheduleForDate(schoolID: schoolID, date: today),
            firebase.getBellScheduleForDate(schoolID: schoolID, date: tomorrow),
          ]).then(
            (schedules) => _SchedulePageData(
              today: today,
              todaySchedule: schedules[0],
              tomorrow: tomorrow,
              tomorrowSchedule: schedules[1],
            ),
          );
    }
    return _scheduleFuture!;
  }

  Widget _scheduleCard(
    BuildContext context,
    BellSchedule schedule,
    ThemeData theme,
  ) {
    final now = DateTime.now();
    final current = schedule.currentPeriod(now);
    final next = schedule.nextPeriod(now);

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Today',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              _StatusPill(text: schedule.title, theme: theme),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _NowPanel(schedule: schedule, current: current, next: next),
          const SizedBox(height: AppSpacing.lg),
          for (final period in schedule.periods) ...[
            _PeriodRow(
              period: period,
              isCurrent: identical(period, current),
              theme: theme,
            ),
            if (period != schedule.periods.last)
              const SizedBox(height: AppSpacing.sm),
          ],
          if (schedule.dateNotes.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              schedule.dateNotes.trim(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = context.watch<CurrentUserProfileNotifier>().profile;
    final schoolID = profile?.schoolID.trim() ?? '';

    if (schoolID.isEmpty) {
      return Center(
        child: Text(
          'Your profile is not connected to a school yet.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    final today = DateTime.now();
    return FutureBuilder<_SchedulePageData>(
      future: _schedulesFor(context.read<FirebaseService>(), schoolID, today),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: theme.colorScheme.primary),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Could not load today\'s school schedule.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final data = snapshot.data;
        final todaySchedule = data?.todaySchedule;
        if (data == null ||
            todaySchedule == null ||
            todaySchedule.periods.isEmpty) {
          return Center(
            child: Text(
              'No schedule for today.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl * 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TomorrowSchoolDayCard(
                  date: data.tomorrow,
                  schedule: data.tomorrowSchedule,
                ),
                const SizedBox(height: AppSpacing.md),
                _scheduleCard(context, todaySchedule, theme),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SchedulePageData {
  const _SchedulePageData({
    required this.today,
    required this.todaySchedule,
    required this.tomorrow,
    required this.tomorrowSchedule,
  });

  final DateTime today;
  final BellSchedule? todaySchedule;
  final DateTime tomorrow;
  final BellSchedule? tomorrowSchedule;
}

class _TomorrowSchoolDayCard extends StatelessWidget {
  const _TomorrowSchoolDayCard({required this.date, required this.schedule});

  final DateTime date;
  final BellSchedule? schedule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schedule = this.schedule;
    final dateText = MaterialLocalizations.of(context).formatShortDate(date);

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
      child: schedule == null || schedule.periods.isEmpty
          ? _InfoPanel(
              icon: Icons.event_busy_outlined,
              title: 'Tomorrow',
              message: 'No school day schedule found for $dateText.',
              theme: theme,
            )
          : _TomorrowSchoolDaySummary(
              date: date,
              schedule: schedule,
              theme: theme,
            ),
    );
  }
}

class _TomorrowSchoolDaySummary extends StatelessWidget {
  const _TomorrowSchoolDaySummary({
    required this.date,
    required this.schedule,
    required this.theme,
  });

  final DateTime date;
  final BellSchedule schedule;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final firstPeriod = schedule.periods.first;
    final lastPeriod = schedule.periods.last;
    final start = firstPeriod.startOn(date);
    final end = lastPeriod.endOn(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Tomorrow',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            _StatusPill(text: schedule.title, theme: theme),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          localizations.formatFullDate(date),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _SchoolDayTimeBlock(
                label: 'Starts',
                time: appTimeOfDay.format(start),
                icon: Icons.play_arrow_rounded,
                theme: theme,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _SchoolDayTimeBlock(
                label: 'Ends',
                time: appTimeOfDay.format(end),
                icon: Icons.flag_outlined,
                theme: theme,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SchoolDayTimeBlock extends StatelessWidget {
  const _SchoolDayTimeBlock({
    required this.label,
    required this.time,
    required this.icon,
    required this.theme,
  });

  final String label;
  final String time;
  final IconData icon;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: _scheduleAccent),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
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

class _NowPanel extends StatelessWidget {
  const _NowPanel({
    required this.schedule,
    required this.current,
    required this.next,
  });

  final BellSchedule schedule;
  final BellSchedulePeriod? current;
  final BellSchedulePeriod? next;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final currentPeriod = current;

    if (currentPeriod == null) {
      final nextPeriod = next;
      return _InfoPanel(
        icon: Icons.schedule_outlined,
        title: nextPeriod == null ? 'School day complete' : 'Before school',
        message: nextPeriod == null
            ? 'Last period ended at ${appTimeOfDay.format(schedule.periods.last.endOn(now))}.'
            : '${nextPeriod.title} starts at ${appTimeOfDay.format(nextPeriod.startOn(now))}.',
        theme: theme,
      );
    }

    final start = currentPeriod.startOn(now);
    final end = currentPeriod.endOn(now);
    final total = end.difference(start).inSeconds;
    final elapsed = now.difference(start).inSeconds.clamp(0, total);
    final progress = total <= 0 ? 0.0 : elapsed / total;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currentPeriod.title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${appTimeOfDay.format(start)} - ${appTimeOfDay.format(end)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surface,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({
    required this.period,
    required this.isCurrent,
    required this.theme,
  });

  final BellSchedulePeriod period;
  final bool isCurrent;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final color = isCurrent
        ? theme.colorScheme.primary
        : period.isBreak
        ? _scheduleAccent
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isCurrent
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent
              ? theme.colorScheme.primary.withValues(alpha: 0.25)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  period.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${period.minutes} min',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${appTimeOfDay.format(period.startOn(now))}\n${appTimeOfDay.format(period.endOn(now))}',
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.message,
    required this.theme,
  });

  final IconData icon;
  final String title;
  final String message;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.theme});

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _scheduleAccent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: _scheduleAccent,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
