import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Components/confirmation_hub.dart';
import '../Components/block_post_author.dart';
import '../Components/report_post_sheet.dart';
import '../Components/schedulepage.dart';
import '../Components/post_acknowledgement_controls.dart';
import '../Components/userPFP.dart';
import '../Models/club.dart';
import '../Models/platform_event.dart';
import '../Models/post_attachment.dart';
import '../Models/user.dart';
import '../Providers/current_user_profile_notifier.dart';
import '../Service/firebase_service.dart';
import '../Utility/AppSpacing.dart';
import '../Utility/app_decorations.dart';
import 'parent_connect_student_page.dart';
import 'notifications_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.onNavigateToTab, this.onOpenHallPass});

  final ValueChanged<int>? onNavigateToTab;
  final VoidCallback? onOpenHallPass;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileNotifier = context.watch<CurrentUserProfileNotifier>();
    final firebase = context.read<FirebaseService>();
    final profile = profileNotifier.profile;
    final isProspective = profile?.isProspectiveStudent ?? false;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          profile?.isParent == true
              ? 'Parent Dashboard'
              : isProspective
              ? 'Explore Quilt'
              : 'Troy High School',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationsPage(),
                ),
              );
            },
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifications',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              await context.read<CurrentUserProfileNotifier>().signOut();
            },
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppDecorations.screenBackground(context),
        child: SafeArea(
          child: profile == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPaddingH,
                      vertical: AppSpacing.screenPaddingV,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: profile.isParent
                              ? [
                                  _ParentGreetingHeader(profile: profile),
                                  const SizedBox(height: AppSpacing.lg),
                                  _ParentActionGrid(
                                    onConnect: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              ParentConnectStudentPage(
                                                onOpenStudents: () {
                                                  Navigator.of(context).pop();
                                                  widget.onNavigateToTab?.call(
                                                    1,
                                                  );
                                                },
                                              ),
                                        ),
                                      );
                                    },
                                    onStudents: () =>
                                        widget.onNavigateToTab?.call(1),
                                    onSchools: () =>
                                        widget.onNavigateToTab?.call(2),
                                    onEvents: () =>
                                        widget.onNavigateToTab?.call(3),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  _ParentChildEventsPreview(
                                    profile: profile,
                                    firebase: firebase,
                                    onOpenEvents: () =>
                                        widget.onNavigateToTab?.call(3),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  _ParentVolunteerEventsPreview(
                                    profile: profile,
                                    firebase: firebase,
                                    onOpenEvents: () =>
                                        widget.onNavigateToTab?.call(3),
                                  ),
                                  const SizedBox(height: 112),
                                ]
                              : profile.isProspectiveStudent
                              ? [
                                  _ProspectiveGreetingHeader(profile: profile),
                                  const SizedBox(height: AppSpacing.lg),
                                  _ProspectiveBrowseCard(
                                    onBrowseSchools: () =>
                                        widget.onNavigateToTab?.call(1),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  const _ProspectiveAccessNote(),
                                  const SizedBox(height: 112),
                                ]
                              : [
                                  _GreetingHeader(profile: profile),
                                  const SizedBox(height: AppSpacing.lg),
                                  _TodayCard(
                                    profile: profile,
                                    firebase: firebase,
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  _ShortcutGrid(
                                    onSchedule: () => _openUtilityPage(
                                      context,
                                      title: 'Schedule',
                                      child: const SchedulePage(),
                                    ),
                                    onHallPass: () =>
                                        _openHallPassFromProfile(context),
                                    onClubs: () =>
                                        widget.onNavigateToTab?.call(1),
                                    onEvents: () =>
                                        widget.onNavigateToTab?.call(2),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  _UpcomingEventsPreview(
                                    profile: profile,
                                    firebase: firebase,
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  _FromYourClubs(
                                    profile: profile,
                                    firebase: firebase,
                                    onOpenClubs: () =>
                                        widget.onNavigateToTab?.call(1),
                                  ),
                                  const SizedBox(height: 112),
                                ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  void _openUtilityPage(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _DashboardUtilityPage(title: title, child: child),
      ),
    );
  }

  void _openHallPassFromProfile(BuildContext context) {
    final schoolID = context
        .read<CurrentUserProfileNotifier>()
        .profile
        ?.schoolID
        .trim();
    if (schoolID == null || schoolID.isEmpty) {
      QuiltConfirmation.warning(
        context,
        'Join a school before using hall pass.',
      );
      return;
    }

    final openHallPass = widget.onOpenHallPass;
    if (openHallPass != null) {
      openHallPass();
      return;
    }
    widget.onNavigateToTab?.call(3);
  }
}

class _DashboardUtilityPage extends StatelessWidget {
  const _DashboardUtilityPage({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppDecorations.screenBackground(context),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()
        : 'there';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hi, $name',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Here is what is happening around school.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ProspectiveGreetingHeader extends StatelessWidget {
  const _ProspectiveGreetingHeader({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()
        : 'there';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hi, $name',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Browse schools and public club previews without joining a school.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ProspectiveBrowseCard extends StatelessWidget {
  const _ProspectiveBrowseCard({required this.onBrowseSchools});

  final VoidCallback? onBrowseSchools;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.school_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Explore schools',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'See school details, club overviews, leaders, and public updates.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onBrowseSchools,
              icon: const Icon(Icons.travel_explore_outlined),
              label: const Text('Browse schools'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProspectiveAccessNote extends StatelessWidget {
  const _ProspectiveAccessNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'View-only access',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          _InlineInfo(
            icon: Icons.visibility_outlined,
            label: 'Public school and club information only',
          ),
          const SizedBox(height: AppSpacing.sm),
          _InlineInfo(
            icon: Icons.lock_outline,
            label: 'No school membership, club membership, or voting',
          ),
        ],
      ),
    );
  }
}

class _ParentGreetingHeader extends StatelessWidget {
  const _ParentGreetingHeader({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()
        : 'there';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppDecorations.shadow(context).withValues(alpha: 0.08),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.family_restroom_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Parent',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Hi, $name',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'A parent view for keeping track of student connections, schedules, and school events.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.84),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParentActionGrid extends StatelessWidget {
  const _ParentActionGrid({
    required this.onConnect,
    required this.onStudents,
    required this.onSchools,
    required this.onEvents,
  });

  final VoidCallback onConnect;
  final VoidCallback onStudents;
  final VoidCallback onSchools;
  final VoidCallback onEvents;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Parent tools'),
        const SizedBox(height: AppSpacing.sm),
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 1.55,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _ShortcutTile(
              icon: Icons.group_add_outlined,
              title: 'Connect',
              subtitle: 'Add student',
              onTap: onConnect,
            ),
            _ShortcutTile(
              icon: Icons.supervisor_account_outlined,
              title: 'Students',
              subtitle: 'Linked accounts',
              onTap: onStudents,
            ),
            _ShortcutTile(
              icon: Icons.school_outlined,
              title: 'Schools',
              subtitle: 'Public directory',
              onTap: onSchools,
            ),
            _ShortcutTile(
              icon: Icons.event_outlined,
              title: 'Events',
              subtitle: 'Child view',
              onTap: onEvents,
            ),
          ],
        ),
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.profile, required this.firebase});

  final UserProfile profile;
  final FirebaseService firebase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateFormat('EEEE, MMM d').format(DateTime.now());

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today at Troy High',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      today,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(label: profile.accountStatus),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FutureBuilder<int>(
            future: firebase.getTodayEventCount(profile.schoolID),
            builder: (context, snapshot) {
              final eventCount = snapshot.data ?? 0;
              final message = eventCount == 0
                  ? 'No school events listed for today.'
                  : '$eventCount event${eventCount == 1 ? '' : 's'} on the calendar today.';

              return _InlineInfo(
                icon: Icons.event_available_outlined,
                label: message,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ShortcutGrid extends StatelessWidget {
  const _ShortcutGrid({
    required this.onSchedule,
    required this.onHallPass,
    required this.onClubs,
    required this.onEvents,
  });

  final VoidCallback onSchedule;
  final VoidCallback onHallPass;
  final VoidCallback onClubs;
  final VoidCallback onEvents;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Quick actions'),
        const SizedBox(height: AppSpacing.sm),
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 1.55,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _ShortcutTile(
              icon: Icons.calendar_today_outlined,
              title: 'Schedule',
              subtitle: 'Bell times',
              onTap: onSchedule,
            ),
            _ShortcutTile(
              icon: Icons.qr_code_scanner,
              title: 'Hall Pass',
              subtitle: 'Scan room QR',
              onTap: onHallPass,
            ),
            _ShortcutTile(
              icon: Icons.groups_2_outlined,
              title: 'Browse Clubs',
              subtitle: 'Find groups',
              onTap: onClubs,
            ),
            _ShortcutTile(
              icon: Icons.event_outlined,
              title: 'Events',
              subtitle: 'See calendar',
              onTap: onEvents,
            ),
          ],
        ),
      ],
    );
  }
}

class _UpcomingEventsPreview extends StatelessWidget {
  const _UpcomingEventsPreview({required this.profile, required this.firebase});

  final UserProfile profile;
  final FirebaseService firebase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Upcoming events'),
        const SizedBox(height: AppSpacing.sm),
        FutureBuilder<List<PlatformEvent>>(
          future: firebase.getSignedUpEventsForStudent(
            profile,
            upcomingOnly: true,
            eventScanLimit: 80,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const _LoadingPanel();
            }
            final events = _upcomingEvents(
              snapshot.data ?? [],
            ).take(3).toList();
            if (events.isEmpty) {
              return const _EmptyPanel(
                icon: Icons.event_available_outlined,
                message: 'No upcoming signed-up events yet.',
              );
            }

            return _DashboardCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (int i = 0; i < events.length; i++) ...[
                    _EventPreviewRow(event: events[i]),
                    if (i != events.length - 1)
                      Divider(
                        height: 1,
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ParentChildEventsPreview extends StatelessWidget {
  const _ParentChildEventsPreview({
    required this.profile,
    required this.firebase,
    required this.onOpenEvents,
  });

  final UserProfile profile;
  final FirebaseService firebase;
  final VoidCallback onOpenEvents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _SectionWithChild(
      title: 'Child events',
      trailing: TextButton(onPressed: onOpenEvents, child: const Text('Open')),
      child: FutureBuilder<List<ParentSignedUpEvent>>(
        future: firebase.getSignedUpEventsForParent(
          profile,
          upcomingOnly: true,
          eventScanLimit: 80,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const _LoadingPanel();
          }
          if (snapshot.hasError) {
            return const _EmptyPanel(
              icon: Icons.error_outline,
              message: 'Could not load child events.',
            );
          }

          final events =
              (snapshot.data ?? [])
                  .where(
                    (entry) => entry.event.startTime.isAfter(DateTime.now()),
                  )
                  .toList()
                ..sort(
                  (a, b) => a.event.startTime.compareTo(b.event.startTime),
                );
          final preview = events.take(3).toList();
          if (preview.isEmpty) {
            return const _EmptyPanel(
              icon: Icons.event_available_outlined,
              message: 'No upcoming child event signups yet.',
            );
          }

          return _DashboardCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < preview.length; i++) ...[
                  _EventPreviewRow(
                    event: preview[i].event,
                    badgeLabel: preview[i].student,
                  ),
                  if (i != preview.length - 1)
                    Divider(
                      height: 1,
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ParentVolunteerEventsPreview extends StatelessWidget {
  const _ParentVolunteerEventsPreview({
    required this.profile,
    required this.firebase,
    required this.onOpenEvents,
  });

  final UserProfile profile;
  final FirebaseService firebase;
  final VoidCallback onOpenEvents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _SectionWithChild(
      title: 'Your volunteering',
      trailing: TextButton(onPressed: onOpenEvents, child: const Text('Open')),
      child: FutureBuilder<List<ParentVolunteeredEvent>>(
        future: firebase.getVolunteeredEventsForParent(
          profile,
          upcomingOnly: true,
          eventScanLimit: 80,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const _LoadingPanel();
          }
          if (snapshot.hasError) {
            return const _EmptyPanel(
              icon: Icons.error_outline,
              message: 'Could not load volunteer events.',
            );
          }

          final events =
              (snapshot.data ?? [])
                  .where(
                    (entry) => entry.event.startTime.isAfter(DateTime.now()),
                  )
                  .toList()
                ..sort(
                  (a, b) => a.event.startTime.compareTo(b.event.startTime),
                );
          final preview = events.take(3).toList();
          if (preview.isEmpty) {
            return const _EmptyPanel(
              icon: Icons.volunteer_activism_outlined,
              message: 'No upcoming volunteer events yet.',
            );
          }

          return _DashboardCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < preview.length; i++) ...[
                  _EventPreviewRow(
                    event: preview[i].event,
                    badgeLabel: 'Volunteering',
                    leadingIcon: Icons.volunteer_activism_outlined,
                  ),
                  if (i != preview.length - 1)
                    Divider(
                      height: 1,
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FromYourClubs extends StatelessWidget {
  const _FromYourClubs({
    required this.profile,
    required this.firebase,
    required this.onOpenClubs,
  });

  final UserProfile profile;
  final FirebaseService firebase;
  final VoidCallback onOpenClubs;

  @override
  Widget build(BuildContext context) {
    return _SectionWithChild(
      title: 'From your clubs',
      trailing: TextButton(onPressed: onOpenClubs, child: const Text('Browse')),
      child: FutureBuilder<List<ClubPostEntry>>(
        future: firebase.getPostsForJoinedClubs(profile, perClubLimit: 4),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingPanel();
          }
          if (snapshot.hasError) {
            return _EmptyPanel(
              icon: Icons.error_outline,
              message: 'Could not load club posts.',
              actionLabel: 'Try again',
              onAction: () {},
            );
          }

          final posts = (snapshot.data ?? []).take(3).toList();
          if (posts.isEmpty) {
            return const _EmptyPanel(
              icon: Icons.article_outlined,
              message: 'No posts from clubs you have joined yet.',
            );
          }

          return Column(
            children: posts
                .map(
                  (post) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _FeedPostCard(
                      post: post,
                      fallbackSchoolID: profile.schoolID,
                      profile: profile,
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: padding,
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
      child: child,
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppDecorations.shadow(context).withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 26),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventPreviewRow extends StatelessWidget {
  const _EventPreviewRow({
    required this.event,
    this.badgeLabel,
    this.leadingIcon = Icons.event_outlined,
  });

  final PlatformEvent event;
  final String? badgeLabel;
  final IconData leadingIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = DateFormat.MMMd().add_jm().format(event.startTime);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              leadingIcon,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  date,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if ((badgeLabel ?? '').trim().isNotEmpty) ...[
            const SizedBox(width: AppSpacing.sm),
            _EventPreviewBadge(label: badgeLabel!.trim()),
          ],
        ],
      ),
    );
  }
}

class _EventPreviewBadge extends StatelessWidget {
  const _EventPreviewBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(maxWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SectionWithChild extends StatelessWidget {
  const _SectionWithChild({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: title, trailing: trailing),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeLabel = label.trim().isEmpty ? 'Not set' : label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        safeLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InlineInfo extends StatelessWidget {
  const _InlineInfo({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const _DashboardCard(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _DashboardCard(
      child: Column(
        children: [
          Icon(
            icon,
            size: 36,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _FeedPostCard extends StatefulWidget {
  const _FeedPostCard({
    required this.post,
    required this.fallbackSchoolID,
    required this.profile,
  });

  final ClubPostEntry post;
  final String fallbackSchoolID;
  final UserProfile profile;

  @override
  State<_FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends State<_FeedPostCard> {
  late ClubPostEntry _post;
  bool _acknowledging = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  @override
  void didUpdateWidget(covariant _FeedPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        widget.post.acknowledgements.length >= _post.acknowledgements.length) {
      _post = widget.post;
    }
  }

  String get _schoolID =>
      _post.schoolID.isNotEmpty ? _post.schoolID : widget.fallbackSchoolID;

  Future<void> _confirmRead() async {
    if (_acknowledging || _post.acknowledgedBy(widget.profile.UID)) return;

    setState(() => _acknowledging = true);
    final updated = await _recordPostAcknowledgement(
      context,
      post: _post,
      profile: widget.profile,
      fallbackSchoolID: widget.fallbackSchoolID,
    );
    if (!mounted) return;
    setState(() {
      if (updated != null) _post = updated;
      _acknowledging = false;
    });
  }

  Future<void> _showFullPost() async {
    final updated = await showGeneralDialog<ClubPostEntry>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Center(
            child: _FullFeedPostDialog(
              post: _post,
              profile: widget.profile,
              fallbackSchoolID: widget.fallbackSchoolID,
              onPostChanged: (post) {
                if (mounted) setState(() => _post = post);
              },
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );

    if (!mounted || updated == null) return;
    setState(() => _post = updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.profile.blockedUserIds.contains(_post.authorId)) {
      return const SizedBox.shrink();
    }

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserPFP(radius: 20, photoUrl: _post.authorPhotoUrl),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _post.authorName.isNotEmpty ? _post.authorName : 'Member',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      DateFormat.yMMMd().add_jm().format(_post.timestamp),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Post actions',
                onSelected: (value) {
                  if (value == 'report') {
                    showReportPostSheet(
                      context,
                      post: _post,
                      schoolID: _schoolID,
                      clubID: _post.clubID,
                      clubTitle: _post.clubTitle,
                    );
                  } else if (value == 'block') {
                    blockPostAuthor(context, post: _post);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'report',
                    child: ListTile(
                      leading: Icon(Icons.flag_outlined),
                      title: Text('Report post'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  if (_post.authorId.isNotEmpty &&
                      _post.authorId != widget.profile.UID)
                    const PopupMenuItem(
                      value: 'block',
                      child: ListTile(
                        leading: Icon(Icons.block_outlined),
                        title: Text('Block author'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _post.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (_post.body.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Linkify(
              onOpen: (link) async {
                final uri = Uri.tryParse(link.url);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              text: _post.body,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              options: const LinkifyOptions(humanize: false),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              linkStyle: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _showFullPost,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                textStyle: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: const Icon(Icons.open_in_full, size: 14),
              label: const Text('Show more'),
            ),
          ),
          const SizedBox(height: 4),
          PostAcknowledgementRow(
            post: _post,
            currentUserID: widget.profile.UID,
            isLoading: _acknowledging,
            onConfirm: _confirmRead,
            onShowAll: () => showPostAcknowledgementsDialog(context, _post),
          ),
        ],
      ),
    );
  }
}

Future<ClubPostEntry?> _recordPostAcknowledgement(
  BuildContext context, {
  required ClubPostEntry post,
  required UserProfile profile,
  required String fallbackSchoolID,
}) async {
  try {
    final updated = await context.read<FirebaseService>().acknowledgePost(
      schoolID: post.schoolID.isNotEmpty ? post.schoolID : fallbackSchoolID,
      clubID: post.clubID,
      post: post,
      user: profile,
    );
    if (!context.mounted) return updated;
    QuiltConfirmation.success(context, 'Post acknowledged.');
    return updated;
  } catch (e) {
    if (!context.mounted) return null;
    QuiltConfirmation.error(context, 'Could not acknowledge post: $e');
    return null;
  }
}

class _FullFeedPostDialog extends StatefulWidget {
  const _FullFeedPostDialog({
    required this.post,
    required this.profile,
    required this.fallbackSchoolID,
    required this.onPostChanged,
  });

  final ClubPostEntry post;
  final UserProfile profile;
  final String fallbackSchoolID;
  final ValueChanged<ClubPostEntry> onPostChanged;

  @override
  State<_FullFeedPostDialog> createState() => _FullFeedPostDialogState();
}

class _FullFeedPostDialogState extends State<_FullFeedPostDialog> {
  late ClubPostEntry _post;
  bool _acknowledging = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  Future<void> _confirmRead() async {
    if (_acknowledging || _post.acknowledgedBy(widget.profile.UID)) return;

    setState(() => _acknowledging = true);
    final updated = await _recordPostAcknowledgement(
      context,
      post: _post,
      profile: widget.profile,
      fallbackSchoolID: widget.fallbackSchoolID,
    );
    if (!mounted) return;
    setState(() {
      if (updated != null) {
        _post = updated;
        widget.onPostChanged(updated);
      }
      _acknowledging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: 620,
            maxHeight: media.size.height * 0.86,
          ),
          margin: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppDecorations.shadow(context).withValues(alpha: 0.18),
                blurRadius: 40,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.cardPadding,
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    UserPFP(
                      radius: 22,
                      photoUrl: _post.authorPhotoUrl,
                      uid: _post.authorId,
                      displayName: _post.authorName,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _post.authorName.isNotEmpty
                                ? _post.authorName
                                : 'Member',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            DateFormat.yMMMd().add_jm().format(_post.timestamp),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(_post),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.cardPadding,
                    0,
                    AppSpacing.cardPadding,
                    AppSpacing.cardPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _post.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (_post.body.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Linkify(
                          onOpen: (link) async {
                            final uri = Uri.tryParse(link.url);
                            if (uri != null) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          text: _post.body,
                          options: const LinkifyOptions(humanize: false),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            height: 1.4,
                          ),
                          linkStyle: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            height: 1.4,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                      if (_post.attachments.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        _FeedPostAttachments(attachments: _post.attachments),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      PostAcknowledgementRow(
                        post: _post,
                        currentUserID: widget.profile.UID,
                        isLoading: _acknowledging,
                        onConfirm: _confirmRead,
                        onShowAll: () =>
                            showPostAcknowledgementsDialog(context, _post),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedPostAttachments extends StatelessWidget {
  const _FeedPostAttachments({required this.attachments});

  final List<PostAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: attachments
          .map(
            (attachment) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: attachment.isImage
                  ? _FeedImageAttachmentCard(attachment: attachment)
                  : _FeedFileAttachmentTile(attachment: attachment),
            ),
          )
          .toList(),
    );
  }
}

class _FeedImageAttachmentCard extends StatelessWidget {
  const _FeedImageAttachmentCard({required this.attachment});

  final PostAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          attachment.url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _FeedFileAttachmentTile(attachment: attachment);
          },
        ),
      ),
    );
  }
}

class _FeedFileAttachmentTile extends StatelessWidget {
  const _FeedFileAttachmentTile({required this.attachment});

  final PostAttachment attachment;

  Future<void> _openAttachment(BuildContext context) async {
    final uri = Uri.tryParse(attachment.url);
    if (uri == null) return;

    final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!launched && context.mounted) {
      QuiltConfirmation.error(context, 'Could not open ${attachment.label}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = attachment.isPdf
        ? Icons.picture_as_pdf_outlined
        : Icons.link_outlined;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openAttachment(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      attachment.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.open_in_new),
            ],
          ),
        ),
      ),
    );
  }
}

List<PlatformEvent> _upcomingEvents(List<PlatformEvent> events) {
  final now = DateTime.now();
  return events.where((event) => event.startTime.isAfter(now)).toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
}
