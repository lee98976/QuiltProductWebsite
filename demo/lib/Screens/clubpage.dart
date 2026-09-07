import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_linkify/flutter_linkify.dart';

import '../Components/calendar_event_actions.dart';
import '../Components/confirmation_hub.dart';
import '../Components/deferred_content.dart';
import '../Components/post_acknowledgement_controls.dart';
import '../Components/userPFP.dart';
import '../Components/clubSection.dart';
import '../Components/report_post_sheet.dart';
import '../Components/block_post_author.dart';
import '../Models/club.dart';
import '../Models/platform_event.dart';
import '../Models/post_attachment.dart';
import '../Models/upload_file_data.dart';
import '../Models/user.dart';
import '../Providers/current_user_profile_notifier.dart';
import '../Service/auth_service.dart';
import '../Service/calendar_account_service.dart';
import '../Service/firebase_service.dart';
import '../Service/upload_picker_service.dart';
import '../Utility/AppSpacing.dart';
import '../Utility/app_decorations.dart';
import '../Utility/app_formatters.dart';
import 'qr_scanner_page.dart';
import 'Clubs/polls_tab.dart';
import 'Clubs/create_club_request_page.dart';
import 'Clubs/club_qr_generator_page.dart';
import 'eventpage.dart';

class _FirestoreErrorBox extends StatelessWidget {
  const _FirestoreErrorBox({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          'Could not load from Firebase.\n\n$error',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ),
    );
  }
}

class _DeferredRoutePlaceholder extends StatelessWidget {
  const _DeferredRoutePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: AppDecorations.screenBackground(context),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

String _clubActionErrorMessage(Object error) {
  if (error is FirebaseException && error.code == 'unavailable') {
    return 'check your internet connection and try again.';
  }
  if (error is StateError) return error.message;
  return error.toString();
}

class ClubPage extends StatefulWidget {
  const ClubPage({required this.schoolID, this.viewingStudent, super.key});

  final String schoolID;
  final UserProfile? viewingStudent;

  @override
  State<ClubPage> createState() => _ClubPageState();
}

class _ClubPageState extends State<ClubPage> {
  Widget _header(ThemeData theme) {
    final studentName = _studentName(widget.viewingStudent);
    return Text(
      studentName == null ? 'Clubs' : '$studentName\'s Clubs',
      style: theme.textTheme.headlineMedium,
    );
  }

  PreferredSizeWidget _appBar(ThemeData theme) {
    final canParticipate =
        context.watch<CurrentUserProfileNotifier>().profile?.canParticipate ??
        false;

    return AppBar(
      title: Text(
        _studentName(widget.viewingStudent) == null
            ? 'Troy High School'
            : '${_studentName(widget.viewingStudent)}\'s Clubs',
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
      ),
      actions: [
        if (canParticipate)
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan Attendance QR',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DeferredContent(
                    active: true,
                    placeholder: const _DeferredRoutePlaceholder(),
                    child: QrScannerPage(schoolID: widget.schoolID),
                  ),
                ),
              );
            },
          ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_outlined),
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await context.read<CurrentUserProfileNotifier>().signOut();
          },
        ),
      ],
    );
  }

  void _openDiscoverClubs(List<ClubInfo> clubs, Set<String> joinedClubIds) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return DeferredContent(
          active: true,
          placeholder: const _DiscoverClubsSheetPlaceholder(),
          child: _DiscoverClubsSheet(
            schoolID: widget.schoolID,
            clubs: clubs,
            joinedClubIds: joinedClubIds,
          ),
        );
      },
    );
  }

  Widget _clubSections(BuildContext context) {
    final firebase = context.read<FirebaseService>();
    final profileNotifier = context.watch<CurrentUserProfileNotifier>();
    final profile = profileNotifier.profile;
    final viewingProfile = widget.viewingStudent ?? profile;
    final theme = Theme.of(context);

    if (profile == null || viewingProfile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<List<ClubInfo>>(
      stream: firebase.getClubs(widget.schoolID),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _FirestoreErrorBox(error: snapshot.error!);
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final clubs = snapshot.data ?? [];
        if (clubs.isEmpty) {
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPaddingH,
                  vertical: AppSpacing.screenPaddingV,
                ),
                sliver: SliverList.list(
                  children: [
                    _header(theme),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'No clubs for this school yet.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return FutureBuilder<Set<String>>(
          key: ValueKey(
            '${viewingProfile.UID}_${profileNotifier.profileRevision}_${clubs.map((club) => club.id).join('|')}',
          ),
          future: firebase.getMembershipClubIds(
            widget.schoolID,
            viewingProfile.UID,
            clubs.map((club) => club.id),
          ),
          builder: (context, membershipSnapshot) {
            if (membershipSnapshot.connectionState == ConnectionState.waiting &&
                !membershipSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final joinedClubIds = membershipSnapshot.data ?? const <String>{};
            final joinedClubs =
                clubs.where((c) => joinedClubIds.contains(c.id)).toList()
                  ..sort((a, b) => a.title.compareTo(b.title));
            final canDiscoverMore =
                widget.viewingStudent == null && profile.canParticipate;

            if (widget.viewingStudent != null && joinedClubs.isEmpty) {
              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPaddingH,
                      vertical: AppSpacing.screenPaddingV,
                    ),
                    sliver: SliverList.list(
                      children: [
                        _header(theme),
                        const SizedBox(height: AppSpacing.md),
                        Center(
                          child: Text(
                            'No clubs found for ${_studentName(widget.viewingStudent)}.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPaddingH,
                    vertical: AppSpacing.screenPaddingV,
                  ),
                  sliver: SliverList.list(
                    children: [
                      _header(theme),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.viewingStudent == null
                                  ? 'Your Clubs'
                                  : '${_studentName(widget.viewingStudent)}\'s Clubs',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (canDiscoverMore)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: AppSpacing.sm,
                              ),
                              child: FilledButton.tonalIcon(
                                onPressed: () =>
                                    _openDiscoverClubs(clubs, joinedClubIds),
                                icon: const Icon(Icons.explore_outlined),
                                label: const Text('Discover more'),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 44),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (joinedClubs.isEmpty)
                        _NoJoinedClubsCard(
                          onDiscover: canDiscoverMore
                              ? () => _openDiscoverClubs(clubs, joinedClubIds)
                              : null,
                        ),
                    ],
                  ),
                ),
                if (joinedClubs.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPaddingH,
                    ),
                    sliver: SliverList.separated(
                      itemCount: joinedClubs.length,
                      itemBuilder: (context, index) {
                        return ClubSection(
                          club: joinedClubs[index],
                          schoolID: widget.schoolID,
                        );
                      },
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.md),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canParticipate =
        context.watch<CurrentUserProfileNotifier>().profile?.canParticipate ??
        false;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: _appBar(theme),
      floatingActionButton: canParticipate
          ? Padding(
              padding: const EdgeInsets.only(bottom: 80.0),
              child: FloatingActionButton.extended(
                heroTag: 'request_club_fab',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DeferredContent(
                        active: true,
                        placeholder: const _DeferredRoutePlaceholder(),
                        child: CreateClubRequestPage(schoolID: widget.schoolID),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Request Club'),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppDecorations.screenBackground(context),
        child: SafeArea(
          child: DeferredContent(
            active: true,
            delay: Duration.zero,
            child: _clubSections(context),
          ),
        ),
      ),
    );
  }

  String? _studentName(UserProfile? student) {
    if (student == null) return null;
    final realName = student.realName.trim();
    if (realName.isNotEmpty) return realName;
    final displayName = student.displayName.trim();
    if (displayName.isNotEmpty) return displayName;
    return 'Student';
  }
}

class _NoJoinedClubsCard extends StatelessWidget {
  const _NoJoinedClubsCard({this.onDiscover});

  final VoidCallback? onDiscover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.groups_2_outlined,
            size: 40,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'You are not in any clubs yet.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Discover clubs at your school and join one to see it here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (onDiscover != null) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onDiscover,
              icon: const Icon(Icons.explore_outlined),
              label: const Padding(
                padding: EdgeInsetsDirectional.only(start: AppSpacing.xs),
                child: Text('Discover clubs'),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiscoverClubsSheetPlaceholder extends StatelessWidget {
  const _DiscoverClubsSheetPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return SafeArea(
          top: false,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPaddingH,
              0,
              AppSpacing.screenPaddingH,
              AppSpacing.xl,
            ),
            children: [
              Text(
                'Discover Clubs',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Center(child: CircularProgressIndicator()),
            ],
          ),
        );
      },
    );
  }
}

class _DiscoverClubsSheet extends StatefulWidget {
  const _DiscoverClubsSheet({
    required this.schoolID,
    required this.clubs,
    required this.joinedClubIds,
  });

  final String schoolID;
  final List<ClubInfo> clubs;
  final Set<String> joinedClubIds;

  @override
  State<_DiscoverClubsSheet> createState() => _DiscoverClubsSheetState();
}

class _DiscoverClubsSheetState extends State<_DiscoverClubsSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final joinedIds = widget.joinedClubIds;
    final query = _query.trim().toLowerCase();
    final discoverableClubs = widget.clubs.where((club) {
      if (joinedIds.contains(club.id)) return false;
      if (query.isEmpty) return true;
      return club.title.toLowerCase().contains(query) ||
          club.description.toLowerCase().contains(query) ||
          club.tagline.toLowerCase().contains(query) ||
          club.highlights.any(
            (highlight) => highlight.toLowerCase().contains(query),
          );
    }).toList()..sort((a, b) => a.title.compareTo(b.title));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        final resultCount = discoverableClubs.isEmpty
            ? 1
            : discoverableClubs.length;
        return SafeArea(
          top: false,
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPaddingH,
              0,
              AppSpacing.screenPaddingH,
              AppSpacing.xl,
            ),
            itemCount: resultCount + 3,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Text(
                  'Discover Clubs',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                );
              }
              if (index == 1) return const SizedBox(height: AppSpacing.md);
              if (index == 2) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Search clubs',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.45),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                );
              }

              if (discoverableClubs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Text(
                    query.isEmpty
                        ? 'You are already in every listed club.'
                        : 'No clubs match that search.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }

              final clubIndex = index - 3;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: clubIndex == discoverableClubs.length - 1
                      ? 0
                      : AppSpacing.md,
                ),
                child: _DiscoverClubTile(
                  club: discoverableClubs[clubIndex],
                  schoolID: widget.schoolID,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _DiscoverClubTile extends StatelessWidget {
  const _DiscoverClubTile({required this.club, required this.schoolID});

  final ClubInfo club;
  final String schoolID;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DeferredContent(
                active: true,
                placeholder: const _DeferredRoutePlaceholder(),
                child: ClubDetailPage(club: club, schoolID: schoolID),
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              _ClubListAvatar(club: club),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      club.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (club.tagline.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        club.tagline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClubListAvatar extends StatelessWidget {
  const _ClubListAvatar({required this.club});

  final ClubInfo club;

  @override
  Widget build(BuildContext context) {
    final textColor =
        ThemeData.estimateBrightnessForColor(club.accentColor) ==
            Brightness.dark
        ? Colors.white
        : Colors.black87;

    return CircleAvatar(
      radius: 28,
      backgroundColor: club.accentColor,
      backgroundImage: club.imageUrl != null && club.imageUrl!.isNotEmpty
          ? NetworkImage(club.imageUrl!)
          : null,
      child: club.imageUrl == null || club.imageUrl!.isEmpty
          ? Text(
              club.initials,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w900,
              ),
            )
          : null,
    );
  }
}

class ClubDetailPage extends StatefulWidget {
  const ClubDetailPage({
    required this.club,
    required this.schoolID,
    this.publicView = false,
    super.key,
  });

  final ClubInfo club;
  final String schoolID;
  final bool publicView;

  @override
  State<ClubDetailPage> createState() => _ClubDetailPageState();
}

class _ClubDetailPageState extends State<ClubDetailPage>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  int _tabIndex = 0;
  bool _didPrecacheClubImage = false;
  bool _didScheduleTabWarmup = false;
  bool _didOfferLimitedVisibilityWarning = false;
  bool _requestingJoin = false;
  bool _pendingJoinRequest = false;
  String? _pendingJoinRequestUid;
  final Set<int> _warmedTabIndexes = <int>{};
  int get _tabCount => widget.publicView ? 4 : 5;
  int get _aboutTabIndex => _tabCount - 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this)
      ..addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (_tabIndex != _tabController.index) {
      setState(() => _tabIndex = _tabController.index);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleTabWarmup();

    if (!_didPrecacheClubImage) {
      _didPrecacheClubImage = true;
      final imageUrl = widget.club.imageUrl;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        precacheImage(NetworkImage(imageUrl), context);
      }
    }
  }

  void _scheduleTabWarmup() {
    if (_didScheduleTabWarmup) return;
    _didScheduleTabWarmup = true;

    final firebase = context.read<FirebaseService>();
    final tasks = <Future<void> Function()>[
      () async {
        final stream = widget.publicView
            ? firebase.getPublicPosts(widget.schoolID, widget.club.id)
            : firebase.getPosts(widget.schoolID, widget.club.id);
        await stream.first.timeout(const Duration(seconds: 5));
      },
      () async {
        final stream = widget.publicView
            ? firebase.getPublicPolls(widget.schoolID, widget.club.id)
            : firebase.getPolls(widget.schoolID, widget.club.id);
        await stream.first.timeout(const Duration(seconds: 5));
      },
      if (!widget.publicView)
        () async {
          await firebase
              .getClubEvents(widget.schoolID, widget.club.id)
              .first
              .timeout(const Duration(seconds: 5));
        },
      () async {
        final stream = widget.publicView
            ? firebase.getLeaderMembers(widget.schoolID, widget.club.id)
            : firebase.getMembers(widget.schoolID, widget.club.id);
        await stream.first.timeout(const Duration(seconds: 5));
      },
    ];

    for (var i = 0; i < tasks.length; i++) {
      unawaited(
        Future<void>.delayed(Duration(milliseconds: 450 + (i * 650)), () async {
          if (!mounted) return;
          try {
            await tasks[i]();
          } catch (e) {
            debugPrint('Club tab warmup skipped: $e');
          }
        }),
      );
    }

    for (var i = 1; i < _tabCount; i++) {
      unawaited(
        Future<void>.delayed(Duration(milliseconds: 900 + (i * 650)), () {
          if (!mounted || _warmedTabIndexes.contains(i)) return;
          setState(() => _warmedTabIndexes.add(i));
        }),
      );
    }
  }

  void _loadPendingJoinRequestFor(UserProfile? profile) {
    final uid = profile?.UID;
    if (uid == null ||
        uid.isEmpty ||
        uid == _pendingJoinRequestUid ||
        widget.publicView) {
      return;
    }
    _pendingJoinRequestUid = uid;
    unawaited(_loadPendingJoinRequest(uid));
  }

  Future<void> _loadPendingJoinRequest(String uid) async {
    try {
      final pendingIds = await context
          .read<FirebaseService>()
          .getPendingClubJoinRequestIds(
            schoolID: widget.schoolID,
            userID: uid,
            clubIDs: [widget.club.id],
          );
      if (!mounted) return;
      setState(() => _pendingJoinRequest = pendingIds.contains(widget.club.id));
    } catch (_) {
      // The request button still works if this lightweight status check fails.
    }
  }

  Future<void> _requestClubJoin() async {
    final profile = context.read<CurrentUserProfileNotifier>().profile;
    if (profile == null) return;

    setState(() => _requestingJoin = true);
    try {
      await context.read<FirebaseService>().requestClubJoin(
        schoolID: widget.schoolID,
        clubID: widget.club.id,
        user: profile,
      );
      if (!mounted) return;
      setState(() => _pendingJoinRequest = true);
      QuiltConfirmation.success(
        context,
        'Request sent to ${widget.club.title}.',
      );
    } catch (e) {
      if (!mounted) return;
      final message = _clubActionErrorMessage(e);
      QuiltConfirmation.error(
        context,
        'Could not request ${widget.club.title}: $message',
      );
    } finally {
      if (mounted) setState(() => _requestingJoin = false);
    }
  }

  void _maybeOfferLimitedVisibilityWarning({
    required UserProfile? profile,
    required bool canViewMemberOnly,
  }) {
    if (_didOfferLimitedVisibilityWarning ||
        widget.publicView ||
        profile == null ||
        profile.clubVisibilityWarningDismissed ||
        canViewMemberOnly) {
      return;
    }
    _didOfferLimitedVisibilityWarning = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showLimitedVisibilityWarning(profile);
    });
  }

  Future<void> _showLimitedVisibilityWarning(UserProfile profile) async {
    final firebase = context.read<FirebaseService>();
    final profileNotifier = context.read<CurrentUserProfileNotifier>();
    var neverShowAgain = false;
    final suppress = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              icon: const Icon(Icons.visibility_outlined),
              title: const Text('Limited club preview'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'You may not see every post, poll, or event for this club. Some content is visible only to club members.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CheckboxListTile(
                    value: neverShowAgain,
                    onChanged: (value) {
                      setDialogState(() => neverShowAgain = value ?? false);
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      'Do not show this again',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(neverShowAgain),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || suppress != true) return;
    try {
      await firebase.dismissClubVisibilityWarning(profile.UID);
      await profileNotifier.refresh();
    } catch (e) {
      if (!mounted) return;
      QuiltConfirmation.error(context, 'Could not save preference: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget? _buildCreateButton(BuildContext context, ClubMember? currentMember) {
    if (widget.publicView) return null;
    final profile = context.read<CurrentUserProfileNotifier>().profile;
    final isAdmin = profile?.isAdmin == true;

    return switch (_tabIndex) {
      0 when isAdmin || currentMember?.canPublishPosts == true =>
        FloatingActionButton.extended(
          heroTag: 'create_post_fab',
          onPressed: () => _showCreatePostDialog(
            context,
            widget.club,
            widget.schoolID,
            canChangeVisibility:
                isAdmin || currentMember?.canChangeVisibility == true,
          ),
          icon: const Icon(Icons.post_add_outlined),
          label: const Text('Create post'),
        ),
      1 when isAdmin || currentMember?.canCreatePolls == true =>
        FloatingActionButton.extended(
          heroTag: 'create_poll_fab',
          onPressed: () => showCreatePollDialog(
            context,
            club: widget.club,
            schoolID: widget.schoolID,
            canChangeVisibility:
                isAdmin || currentMember?.canChangeVisibility == true,
          ),
          icon: const Icon(Icons.how_to_vote_outlined),
          label: const Text('Create poll'),
        ),
      2 when isAdmin || currentMember?.canCreateEvents == true =>
        FloatingActionButton.extended(
          heroTag: 'create_event_fab',
          onPressed: () {
            final creator = context.read<CurrentUserProfileNotifier>().profile;
            if (creator == null) return;
            showCreateEventDialog(
              context: context,
              schoolID: widget.schoolID,
              club: widget.club,
              creator: creator,
              canChangeVisibility:
                  isAdmin || currentMember?.canChangeVisibility == true,
            );
          },
          icon: const Icon(Icons.event_outlined),
          label: const Text('Create event'),
        ),
      _ => null,
    };
  }

  void _openClubSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DeferredContent(
          active: true,
          placeholder: const _DeferredRoutePlaceholder(),
          child: _ClubSettingsPage(
            schoolID: widget.schoolID,
            club: widget.club,
          ),
        ),
      ),
    );
  }

  double get _aboutHeaderProgress {
    final tabPosition =
        _tabController.animation?.value ?? _tabController.index.toDouble();
    return (tabPosition - (_aboutTabIndex - 1)).clamp(0.0, 1.0);
  }

  Widget _buildJoinRequestButton({
    required UserProfile? profile,
    required bool canViewMemberOnly,
    required bool rolesLoaded,
  }) {
    if (widget.publicView ||
        !rolesLoaded ||
        profile?.canParticipate != true ||
        canViewMemberOnly ||
        _pendingJoinRequest) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.tonalIcon(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 16,
          ),
        ),
        onPressed: _requestingJoin ? null : _requestClubJoin,
        icon: _requestingJoin
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.person_add_alt_1_outlined),
        label: Text(_requestingJoin ? 'Requesting' : 'Request to join'),
      ),
    );
  }

  Widget _buildCollapsingClubHero({
    required UserProfile? profile,
    required bool canViewMemberOnly,
    required bool rolesLoaded,
  }) {
    final action = _pendingJoinRequest
        ? const _PendingJoinRequestPill()
        : _buildJoinRequestButton(
            profile: profile,
            canViewMemberOnly: canViewMemberOnly,
            rolesLoaded: rolesLoaded,
          );
    return AnimatedBuilder(
      animation: _tabController.animation ?? _tabController,
      child: _ClubHero(club: widget.club, action: action),
      builder: (context, child) {
        final aboutProgress = _aboutHeaderProgress;
        final visibleProgress = 1.0 - aboutProgress;

        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: visibleProgress,
            child: Opacity(
              opacity: visibleProgress,
              child: Transform.translate(
                offset: Offset(0, -24 * aboutProgress),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _roleAwareScaffold(BuildContext context, ThemeData theme) {
    final profile = context.watch<CurrentUserProfileNotifier>().profile;
    final canLoadRoles =
        !widget.publicView && (profile?.canParticipate == true);
    if (!canLoadRoles) {
      return _buildScaffold(context, theme, null);
    }

    return StreamBuilder<List<ClubMember>>(
      stream: context.read<FirebaseService>().getMembers(
        widget.schoolID,
        widget.club.id,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildScaffold(context, theme, null, rolesLoaded: false);
        }
        final uid = profile?.UID;
        final members = snapshot.data ?? const <ClubMember>[];
        final currentMember = uid == null
            ? null
            : members
                  .where((member) => member.userId == uid)
                  .cast<ClubMember?>()
                  .firstOrNull;
        return _buildScaffold(context, theme, currentMember);
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    ThemeData theme,
    ClubMember? currentMember, {
    bool rolesLoaded = true,
  }) {
    final profile = context.watch<CurrentUserProfileNotifier>().profile;
    final isAdmin = profile?.isAdmin == true;
    final canManageClub =
        !widget.publicView &&
        (isAdmin || currentMember?.canManageSettings == true);
    final canGenerateQr =
        !widget.publicView &&
        (isAdmin || currentMember?.canCreateEvents == true);
    final canManageMembers =
        !widget.publicView &&
        (isAdmin || _isPresidentRole(currentMember?.role ?? ''));
    final canApproveJoinRequests =
        !widget.publicView &&
        (isAdmin ||
            currentMember?.canManageMembers == true ||
            _isPresidentOrSupervisor(currentMember?.role ?? ''));
    final canModerateContent =
        !widget.publicView &&
        (isAdmin || currentMember?.canModerateContent == true);
    final canViewMemberOnly =
        isAdmin || currentMember != null || profile?.isParent == true;
    _loadPendingJoinRequestFor(profile);
    if (rolesLoaded) {
      _maybeOfferLimitedVisibilityWarning(
        profile: profile,
        canViewMemberOnly: canViewMemberOnly,
      );
    }

    final thirdTabLabel = widget.publicView ? 'Leaders' : 'Members';
    List<Widget> buildTabChildren(String keyPrefix) {
      return [
        _KeepAliveTab(
          storageKey: '${keyPrefix}_posts_${widget.club.id}',
          child: _PostsTab(
            club: widget.club,
            schoolID: widget.schoolID,
            publicOnly: widget.publicView,
            schoolVisibleOnly: !widget.publicView && !canViewMemberOnly,
            canAcknowledge: currentMember != null,
            canModerate: canModerateContent,
          ),
        ),
        _KeepAliveTab(
          storageKey: '${keyPrefix}_polls_${widget.club.id}',
          child: PollsTab(
            club: widget.club,
            schoolID: widget.schoolID,
            publicOnly: widget.publicView,
            schoolVisibleOnly: !widget.publicView && !canViewMemberOnly,
            canModerate: canModerateContent,
          ),
        ),
        if (!widget.publicView)
          _KeepAliveTab(
            storageKey: '${keyPrefix}_events_${widget.club.id}',
            child: _ClubEventsTab(
              club: widget.club,
              schoolID: widget.schoolID,
              schoolVisibleOnly: !canViewMemberOnly,
              canGenerateAttendanceQr: canGenerateQr,
            ),
          ),
        _KeepAliveTab(
          storageKey: '${keyPrefix}_members_${widget.club.id}',
          child: _MembersTab(
            club: widget.club,
            schoolID: widget.schoolID,
            leadersOnly: widget.publicView,
            allowContactActions: !widget.publicView,
            canManageRoles: canManageMembers,
            canApproveJoinRequests: canApproveJoinRequests,
          ),
        ),
        _KeepAliveTab(
          storageKey: '${keyPrefix}_about_${widget.club.id}',
          child: _AboutTab(
            club: widget.club,
            schoolID: widget.schoolID,
            publicOnly: widget.publicView,
            canViewMemberOnly: canViewMemberOnly,
            canManageQuickLinks: canManageClub,
          ),
        ),
      ];
    }

    final visibleTabChildren = buildTabChildren('visible');
    final warmTabChildren = buildTabChildren('warm');

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      floatingActionButton: _buildCreateButton(context, currentMember),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      appBar: AppBar(
        title: Text(widget.club.title),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: theme.colorScheme.surface,
        ),
        actions: [
          if (canManageClub)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Club settings',
              onPressed: () => _openClubSettings(context),
            ),
          if (canGenerateQr)
            IconButton(
              icon: const Icon(Icons.qr_code_2),
              tooltip: 'Generate Attendance QR',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ClubQrGeneratorPage(club: widget.club),
                  ),
                );
              },
            ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppDecorations.screenBackground(context),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
            child: Column(
              children: [
                _buildCollapsingClubHero(
                  profile: profile,
                  canViewMemberOnly: canViewMemberOnly,
                  rolesLoaded: rolesLoaded,
                ),
                AnimatedBuilder(
                  animation: _tabController.animation ?? _tabController,
                  builder: (context, child) {
                    final aboutProgress = _aboutHeaderProgress;
                    return SizedBox(
                      height: AppSpacing.xs * (1.0 - aboutProgress),
                    );
                  },
                ),
                TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  padding: EdgeInsets.zero,
                  labelPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs / 2,
                  ),
                  tabs: [
                    _fixedClubTab('Posts'),
                    _fixedClubTab('Polls'),
                    if (!widget.publicView) _fixedClubTab('Events'),
                    _fixedClubTab(thirdTabLabel),
                    _fixedClubTab('About'),
                  ],
                ),
                Expanded(
                  child: Stack(
                    children: [
                      TabBarView(
                        controller: _tabController,
                        children: visibleTabChildren,
                      ),
                      for (final tabIndex in _warmedTabIndexes)
                        if (tabIndex < warmTabChildren.length)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Offstage(
                                offstage: true,
                                child: TickerMode(
                                  enabled: false,
                                  child: warmTabChildren[tabIndex],
                                ),
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

  Widget _fixedClubTab(String label) {
    return Tab(
      height: 36,
      child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _roleAwareScaffold(context, theme);
  }
}

class _KeepAliveTab extends StatefulWidget {
  const _KeepAliveTab({required this.storageKey, required this.child});

  final String storageKey;
  final Widget child;

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
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

class _PendingJoinRequestPill extends StatelessWidget {
  const _PendingJoinRequestPill();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        avatar: Icon(
          Icons.hourglass_top_outlined,
          size: 18,
          color: theme.colorScheme.onSecondaryContainer,
        ),
        label: const Text('Request pending'),
        backgroundColor: theme.colorScheme.secondaryContainer,
        labelStyle: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide.none,
      ),
    );
  }
}

class _ClubHero extends StatelessWidget {
  const _ClubHero({required this.club, required this.action});

  final ClubInfo club;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: _ClubImage(club: club),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      club.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (club.tagline.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        club.tagline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (action is! SizedBox) ...[
            const SizedBox(height: AppSpacing.md),
            action,
          ],
        ],
      ),
    );
  }
}

class _ClubImage extends StatelessWidget {
  const _ClubImage({required this.club});

  final ClubInfo club;

  @override
  Widget build(BuildContext context) {
    if (club.imageUrl != null && club.imageUrl!.isNotEmpty) {
      return Image.network(
        club.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _ClubHeroFallback(club: club),
      );
    }

    return _ClubHeroFallback(club: club);
  }
}

class _ClubAboutBanner extends StatelessWidget {
  const _ClubAboutBanner({required this.club});

  final ClubInfo club;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppDecorations.shadow(context).withValues(alpha: 0.07),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _ClubImage(club: club),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    club.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (club.tagline.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      club.tagline,
                      style: theme.textTheme.bodyMedium?.copyWith(
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
    );
  }
}

class _ClubHeroFallback extends StatelessWidget {
  const _ClubHeroFallback({required this.club});

  final ClubInfo club;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor =
        ThemeData.estimateBrightnessForColor(club.accentColor) ==
            Brightness.dark
        ? Colors.white
        : Colors.black87;

    return ColoredBox(
      color: club.accentColor,
      child: Center(
        child: Text(
          club.initials,
          style: theme.textTheme.displaySmall?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab({
    required this.club,
    required this.schoolID,
    this.publicOnly = false,
    this.canViewMemberOnly = false,
    this.canManageQuickLinks = false,
  });

  final ClubInfo club;
  final String schoolID;
  final bool publicOnly;
  final bool canViewMemberOnly;
  final bool canManageQuickLinks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quickLinks = club.quickLinks
        .where(
          (link) => link.visibleFor(
            publicOnly: publicOnly,
            canViewMemberOnly: canViewMemberOnly,
          ),
        )
        .toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        bottom: AppSpacing.xl * 2,
      ),
      children: [
        _ClubAboutBanner(club: club),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Overview',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          club.description.trim().isEmpty
              ? 'No description yet.'
              : club.description,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: club.description.trim().isEmpty
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onSurface,
            height: 1.45,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (club.meetingTime.trim().isNotEmpty ||
            club.location.trim().isNotEmpty) ...[
          Text(
            'When and where',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _AboutDetailRow(
            icon: Icons.schedule_outlined,
            label: 'Meeting time',
            value: club.meetingTime,
            theme: theme,
          ),
          _AboutDetailRow(
            icon: Icons.place_outlined,
            label: 'Location',
            value: club.location,
            theme: theme,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _ClubContactCard(club: club),
        if (club.groupChatUrl.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _GroupChatCard(url: club.groupChatUrl.trim()),
        ],
        if (quickLinks.isNotEmpty || canManageQuickLinks) ...[
          const SizedBox(height: AppSpacing.lg),
          _ClubQuickLinksCard(
            club: club,
            schoolID: schoolID,
            links: quickLinks,
            canManageQuickLinks: canManageQuickLinks,
          ),
        ],
        if (club.highlights.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Highlights',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: club.highlights
                .map(
                  (highlight) => Chip(
                    label: Text(highlight),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    side: BorderSide.none,
                    labelStyle: theme.textTheme.bodySmall,
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _ClubContactCard extends StatelessWidget {
  const _ClubContactCard({required this.club});

  final ClubInfo club;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contacts = [
      _ClubContact(
        icon: Icons.school_outlined,
        role: 'Supervisor',
        name: club.supervisorName,
        email: club.supervisorEmail,
        phone: club.supervisorPhone,
      ),
      _ClubContact(
        icon: Icons.workspace_premium_outlined,
        role: 'President',
        name: club.presidentName,
        email: club.presidentEmail,
        phone: club.presidentPhone,
      ),
    ].where((contact) => contact.hasContent).toList();

    if (contacts.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Key contacts',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final contact in contacts) contact,
        ],
      ),
    );
  }
}

class _ClubContact extends StatelessWidget {
  const _ClubContact({
    required this.icon,
    required this.role,
    required this.name,
    required this.email,
    required this.phone,
  });

  final IconData icon;
  final String role;
  final String name;
  final String email;
  final String phone;

  bool get hasContent =>
      name.trim().isNotEmpty ||
      email.trim().isNotEmpty ||
      phone.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (name.trim().isNotEmpty)
                  Text(
                    name.trim(),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (email.trim().isNotEmpty)
                  Text(email.trim(), style: theme.textTheme.bodyMedium),
                if (phone.trim().isNotEmpty)
                  Text(phone.trim(), style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupChatCard extends StatelessWidget {
  const _GroupChatCard({required this.url});

  final String url;

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      QuiltConfirmation.error(context, 'Could not open chat.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.forum_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Open club group chat',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.open_in_new),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClubQuickLinksCard extends StatefulWidget {
  const _ClubQuickLinksCard({
    required this.club,
    required this.schoolID,
    required this.links,
    required this.canManageQuickLinks,
  });

  final ClubInfo club;
  final String schoolID;
  final List<ClubQuickLink> links;
  final bool canManageQuickLinks;

  @override
  State<_ClubQuickLinksCard> createState() => _ClubQuickLinksCardState();
}

class _ClubQuickLinksCardState extends State<_ClubQuickLinksCard> {
  final List<_QuickLinkDraft> _drafts = [];
  List<ClubQuickLink>? _savedLinks;
  bool _editing = false;
  bool _saving = false;

  @override
  void dispose() {
    _disposeDrafts();
    super.dispose();
  }

  void _disposeDrafts() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    _drafts.clear();
  }

  void _startEditing() {
    _disposeDrafts();
    _drafts.addAll(
      (_savedLinks ?? widget.club.quickLinks).map(
        _QuickLinkDraft.fromQuickLink,
      ),
    );
    setState(() => _editing = true);
  }

  void _cancelEditing() {
    setState(() => _editing = false);
    _disposeDrafts();
  }

  void _addQuickLink() {
    if (_drafts.length >= 20) return;
    setState(() => _drafts.add(_QuickLinkDraft()));
  }

  void _removeQuickLink(int index) {
    final removed = _drafts.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  Future<void> _saveQuickLinks() async {
    final editedLinks = _drafts.map((draft) => draft.toQuickLink()).toList();
    final hasIncompleteLink = editedLinks.any(
      (link) =>
          !link.hasContent &&
          (link.label.trim().isNotEmpty || link.url.trim().isNotEmpty),
    );
    if (hasIncompleteLink) {
      QuiltConfirmation.warning(
        context,
        'Each quick link needs a label and URL.',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final savedLinks = editedLinks
          .where((link) => link.hasContent)
          .take(20)
          .toList();
      await context.read<FirebaseService>().updateClubQuickLinks(
        schoolID: widget.schoolID,
        clubID: widget.club.id,
        quickLinks: savedLinks,
      );
      if (!mounted) return;
      setState(() {
        _editing = false;
        _savedLinks = savedLinks;
      });
      _disposeDrafts();
      QuiltConfirmation.success(context, 'Quick links saved.');
    } catch (e) {
      if (!mounted) return;
      QuiltConfirmation.error(context, 'Could not save quick links: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayLinks = _savedLinks ?? widget.links;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Quick links',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (_editing) ...[
                IconButton(
                  onPressed: _saving ? null : _cancelEditing,
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancel quick link edits',
                ),
                IconButton.filledTonal(
                  onPressed: _saving ? null : _saveQuickLinks,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  tooltip: 'Save quick links',
                ),
              ] else if (widget.canManageQuickLinks)
                IconButton(
                  onPressed: _startEditing,
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Edit quick links',
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_editing)
            _QuickLinksInlineEditor(
              links: _drafts,
              saving: _saving,
              onAdd: _addQuickLink,
              onRemove: _removeQuickLink,
              onChanged: () => setState(() {}),
            )
          else if (displayLinks.isEmpty)
            Text(
              'No quick links yet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (var i = 0; i < displayLinks.length; i++) ...[
              _ClubQuickLinkTile(link: displayLinks[i]),
              if (i < displayLinks.length - 1)
                const Divider(height: AppSpacing.md),
            ],
        ],
      ),
    );
  }
}

class _QuickLinksInlineEditor extends StatelessWidget {
  const _QuickLinksInlineEditor({
    required this.links,
    required this.saving,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
  });

  final List<_QuickLinkDraft> links;
  final bool saving;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (links.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'Add Discord invites, signup forms, shared folders, or recurring club resources.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (var i = 0; i < links.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            _QuickLinkDraftEditor(
              draft: links[i],
              index: i,
              saving: saving,
              onRemove: () => onRemove(i),
              onChanged: onChanged,
            ),
          ],
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: saving || links.length >= 20 ? null : onAdd,
          icon: const Icon(Icons.add_link_outlined),
          label: const Text('Add quick link'),
        ),
      ],
    );
  }
}

class _ClubQuickLinkTile extends StatelessWidget {
  const _ClubQuickLinkTile({required this.link});

  final ClubQuickLink link;

  Future<void> _open(BuildContext context) async {
    final uri = _uriWithScheme(link.url);
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      QuiltConfirmation.error(context, 'Could not open ${link.label.trim()}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _quickLinkIcon(link.url),
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.label.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (link.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        link.description.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.open_in_new,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutDetailRow extends StatelessWidget {
  const _AboutDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
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

class _MembersTab extends StatelessWidget {
  const _MembersTab({
    required this.club,
    required this.schoolID,
    this.leadersOnly = false,
    this.allowContactActions = true,
    this.canManageRoles = false,
    this.canApproveJoinRequests = false,
  });

  final ClubInfo club;
  final String schoolID;
  final bool leadersOnly;
  final bool allowContactActions;
  final bool canManageRoles;
  final bool canApproveJoinRequests;

  @override
  Widget build(BuildContext context) {
    final firebase = context.read<FirebaseService>();
    final profile = context.watch<CurrentUserProfileNotifier>().profile;
    final uid = profile?.UID;

    return StreamBuilder<List<ClubMember>>(
      stream: leadersOnly
          ? firebase.getLeaderMembers(schoolID, club.id)
          : firebase.getMembers(schoolID, club.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _FirestoreErrorBox(error: snapshot.error!);
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final visibleMembers = List<ClubMember>.from(snapshot.data ?? []);
        final members = List<ClubMember>.from(visibleMembers)
          ..sort((a, b) {
            final roleCompare = _clubMemberRoleRank(
              a.role,
            ).compareTo(_clubMemberRoleRank(b.role));
            if (roleCompare != 0) return roleCompare;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
        final canSeeContactActions =
            allowContactActions &&
            (profile?.isParent == true ||
                (uid != null && members.any((m) => m.userId == uid)));

        if (members.isEmpty && !canApproveJoinRequests) {
          return Center(
            child: Text(
              'No members yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.xl * 3,
          ),
          children: [
            if (canApproveJoinRequests)
              _JoinRequestsSection(schoolID: schoolID, clubID: club.id),
            if (members.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(
                  child: Text(
                    'No members yet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              for (final member in members)
                _MemberListTile(
                  member: member,
                  schoolID: schoolID,
                  clubID: club.id,
                  showContactActions: canSeeContactActions,
                  canManageRole: canManageRoles,
                ),
          ],
        );
      },
    );
  }
}

class _JoinRequestsSection extends StatelessWidget {
  const _JoinRequestsSection({required this.schoolID, required this.clubID});

  final String schoolID;
  final String clubID;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firebase = context.read<FirebaseService>();

    return StreamBuilder<List<ClubJoinRequest>>(
      stream: firebase.getPendingClubJoinRequests(schoolID, clubID),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              'Could not load join requests.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          );
        }

        final requests = snapshot.data ?? const <ClubJoinRequest>[];
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: LinearProgressIndicator(),
          );
        }
        if (requests.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Join Requests',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final request in requests) ...[
                _JoinRequestCard(
                  request: request,
                  schoolID: schoolID,
                  clubID: clubID,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              const Divider(height: AppSpacing.lg),
            ],
          ),
        );
      },
    );
  }
}

class _JoinRequestCard extends StatefulWidget {
  const _JoinRequestCard({
    required this.request,
    required this.schoolID,
    required this.clubID,
  });

  final ClubJoinRequest request;
  final String schoolID;
  final String clubID;

  @override
  State<_JoinRequestCard> createState() => _JoinRequestCardState();
}

class _JoinRequestCardState extends State<_JoinRequestCard> {
  bool _busy = false;

  Future<void> _resolve({required bool approve}) async {
    final approverId = context.read<AuthService>().currentUser?.uid;
    if (approverId == null || _busy) return;

    setState(() => _busy = true);
    try {
      final firebase = context.read<FirebaseService>();
      if (approve) {
        await firebase.approveClubJoinRequest(
          schoolID: widget.schoolID,
          clubID: widget.clubID,
          request: widget.request,
          approverId: approverId,
        );
      } else {
        await firebase.rejectClubJoinRequest(
          schoolID: widget.schoolID,
          clubID: widget.clubID,
          request: widget.request,
          approverId: approverId,
        );
      }
      if (!mounted) return;
      QuiltConfirmation.success(
        context,
        approve
            ? '${widget.request.name} was added to the club.'
            : '${widget.request.name} was declined.',
      );
    } catch (e) {
      if (!mounted) return;
      QuiltConfirmation.error(context, 'Could not update join request: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final request = widget.request;
    final subtitleParts = [
      if (request.studentId.trim().isNotEmpty) request.studentId.trim(),
      if (request.email.trim().isNotEmpty) request.email.trim(),
      'Requested ${appTimeOfDay.format(request.createdAt)}',
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserPFP(
            uid: request.userId,
            displayName: request.name,
            photoUrl: request.photoUrl,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.name.trim().isEmpty
                      ? 'Unnamed student'
                      : request.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleParts.join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _resolve(approve: true),
                      icon: _busy
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.onPrimary,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Approve'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _resolve(approve: false),
                      icon: const Icon(Icons.close),
                      label: const Text('Decline'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberListTile extends StatelessWidget {
  const _MemberListTile({
    required this.member,
    required this.schoolID,
    required this.clubID,
    required this.showContactActions,
    required this.canManageRole,
  });

  final ClubMember member;
  final String schoolID;
  final String clubID;
  final bool showContactActions;
  final bool canManageRole;

  Future<void> _emailMember(BuildContext context) async {
    final email = member.email.trim();
    if (email.isEmpty) return;

    final launched = await launchUrl(
      Uri(scheme: 'mailto', path: email),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      QuiltConfirmation.error(context, 'Could not open email for $email.');
    }
  }

  Future<void> _textMember(BuildContext context) async {
    final phone = _normalizedPhone(member.phoneNumber);
    if (phone.isEmpty) return;

    final launched = await launchUrl(
      Uri(scheme: 'sms', path: phone),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      QuiltConfirmation.error(context, 'Could not open messages for $phone.');
    }
  }

  Future<void> _copyContact(BuildContext context) async {
    final lines = [
      member.name,
      if (member.role.trim().isNotEmpty) member.role.trim(),
      if (member.email.trim().isNotEmpty) member.email.trim(),
      if (member.phoneNumber.trim().isNotEmpty) member.phoneNumber.trim(),
    ].where((line) => line.trim().isNotEmpty).join('\n');
    await Clipboard.setData(ClipboardData(text: lines));
    if (!context.mounted) return;
    QuiltConfirmation.success(context, 'Contact details copied.');
  }

  void _showPhoneOptions(BuildContext context) {
    final phone = member.phoneNumber.trim();
    if (phone.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.sms_outlined),
                  title: const Text('Text message'),
                  subtitle: Text(phone),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _textMember(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_add_alt_1_outlined),
                  title: const Text('Copy contact details'),
                  subtitle: const Text('Use in Contacts or another app'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _copyContact(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _changeRole(BuildContext context, String role) async {
    try {
      await context.read<FirebaseService>().updateMemberRole(
        schoolID: schoolID,
        clubID: clubID,
        userID: member.userId,
        role: role,
      );
      if (!context.mounted) return;
      QuiltConfirmation.success(context, '${member.name} is now $role.');
    } catch (e) {
      if (!context.mounted) return;
      QuiltConfirmation.error(context, 'Could not update role: $e');
    }
  }

  void _showRoleMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.58,
          minChildSize: 0.35,
          maxChildSize: 0.88,
          builder: (context, scrollController) {
            return SafeArea(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                children: [
                  for (final role in ClubRole.editableRoles)
                    ListTile(
                      leading: Icon(
                        role == member.role
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      title: Text(role),
                      subtitle: Text(_roleSummary(role)),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _changeRole(context, role);
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canEmail = showContactActions && member.email.trim().isNotEmpty;
    final canPhone =
        showContactActions &&
        _isPresidentOrSupervisor(member.role) &&
        member.phoneNumber.trim().isNotEmpty;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      leading: UserPFP(
        uid: member.userId,
        displayName: member.name,
        photoUrl: member.photoUrl,
        radius: member.isImportant || _isPresidentOrSupervisor(member.subtitle)
            ? 25
            : 22,
      ),
      title: Text(
        member.name.trim().isEmpty ? 'Unnamed member' : member.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            member.subtitle.trim().isEmpty ? member.userId : member.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (showContactActions && member.email.trim().isNotEmpty)
            Text(
              member.email.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canEmail)
            IconButton(
              icon: const Icon(Icons.mail_outline),
              tooltip: 'Email member',
              onPressed: () => _emailMember(context),
            ),
          if (canPhone)
            IconButton(
              icon: const Icon(Icons.sms_outlined),
              tooltip: 'Phone options',
              onPressed: () => _showPhoneOptions(context),
            ),
          if (canManageRole)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              tooltip: 'Change club role',
              onPressed: () => _showRoleMenu(context),
            ),
          Container(
            constraints: const BoxConstraints(maxWidth: 112),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              member.role.trim().isEmpty ? 'Member' : member.role,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

int _clubMemberRoleRank(String role) {
  return ClubRole.roleRank(role);
}

bool _isPresidentRole(String role) {
  return role.toLowerCase().trim() == ClubMember.presidentRole.toLowerCase();
}

bool _isPresidentOrSupervisor(String role) {
  final normalized = role.toLowerCase().trim();
  return normalized.contains('president') ||
      normalized.contains('supervisor') ||
      normalized.contains('leader') ||
      normalized.contains('advisor');
}

String _roleSummary(String role) {
  final permissions = ClubRole.permissionsFor(role);
  if (_isPresidentRole(role)) {
    return 'Full club management';
  }
  if (permissions.contains(ClubPermission.manageSettings)) {
    return 'Can manage settings and club content';
  }
  if (permissions.contains(ClubPermission.publishPosts) &&
      permissions.contains(ClubPermission.createEvents)) {
    return 'Can publish and create events';
  }
  if (permissions.contains(ClubPermission.publishPosts)) {
    return 'Can publish and moderate updates';
  }
  if (permissions.contains(ClubPermission.createEvents)) {
    return 'Can create club events';
  }
  return 'Can attend, vote, and view member-only content';
}

String _normalizedPhone(String phone) {
  final buffer = StringBuffer();
  for (final unit in phone.runes) {
    final char = String.fromCharCode(unit);
    if ('0123456789+'.contains(char)) buffer.write(char);
  }
  return buffer.toString();
}

Uri? _uriWithScheme(String rawUrl) {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return null;
  final parsed = Uri.tryParse(trimmed);
  if (parsed == null) return null;
  if (parsed.hasScheme) return parsed;
  return Uri.tryParse('https://$trimmed');
}

IconData _quickLinkIcon(String url) {
  final lower = url.toLowerCase();
  if (lower.contains('discord')) return Icons.forum_outlined;
  if (lower.contains('forms.gle') || lower.contains('docs.google.com/forms')) {
    return Icons.assignment_outlined;
  }
  if (lower.contains('drive.google') || lower.contains('dropbox')) {
    return Icons.folder_shared_outlined;
  }
  if (lower.contains('calendar')) return Icons.event_outlined;
  if (lower.contains('instagram') || lower.contains('linktr.ee')) {
    return Icons.public_outlined;
  }
  return Icons.link_outlined;
}

class _ClubEventsTab extends StatelessWidget {
  const _ClubEventsTab({
    required this.club,
    required this.schoolID,
    this.schoolVisibleOnly = false,
    this.canGenerateAttendanceQr = false,
  });

  final ClubInfo club;
  final String schoolID;
  final bool schoolVisibleOnly;
  final bool canGenerateAttendanceQr;

  @override
  Widget build(BuildContext context) {
    final firebase = context.read<FirebaseService>();
    final theme = Theme.of(context);

    return StreamBuilder<List<PlatformEvent>>(
      stream: schoolVisibleOnly
          ? firebase.getSchoolVisibleClubEvents(schoolID, club.id)
          : firebase.getClubEvents(schoolID, club.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _FirestoreErrorBox(error: snapshot.error!);
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final now = DateTime.now();
        final events = (snapshot.data ?? [])
            .where((event) => event.startTime.isAfter(now))
            .toList();
        if (events.isEmpty) {
          return Center(
            child: Text(
              'No upcoming events yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.xl * 3,
          ),
          itemCount: events.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            return _ClubEventCard(
              event: events[index],
              schoolID: schoolID,
              clubID: club.id,
              club: club,
              canGenerateAttendanceQr: canGenerateAttendanceQr,
            );
          },
        );
      },
    );
  }
}

class _ClubEventCard extends StatelessWidget {
  const _ClubEventCard({
    required this.event,
    required this.schoolID,
    required this.clubID,
    required this.club,
    required this.canGenerateAttendanceQr,
  });

  final PlatformEvent event;
  final String schoolID;
  final String clubID;
  final ClubInfo club;
  final bool canGenerateAttendanceQr;

  Future<bool> _volunteer(BuildContext context) async {
    final profile = context.read<CurrentUserProfileNotifier>().profile;
    if (profile == null) return false;
    try {
      await context.read<FirebaseService>().volunteerForEvent(
        schoolID: schoolID,
        clubID: clubID,
        eventID: event.id,
        parent: profile,
      );
      if (!context.mounted) return true;
      QuiltConfirmation.success(context, "You're volunteering for this event.");
      if (profile.autoCalendarUpdatesEnabled) {
        try {
          final calendarsUpdated = await context
              .read<CalendarAccountService>()
              .addEventToConnectedCalendars(profile, event);
          if (!context.mounted) return true;
          QuiltConfirmation.success(
            context,
            calendarsUpdated == 1
                ? 'Event added to your connected calendar.'
                : 'Event added to your connected calendars.',
          );
        } catch (e) {
          if (!context.mounted) return true;
          QuiltConfirmation.error(context, 'Calendar update skipped: $e');
        }
      }
      return true;
    } catch (e) {
      if (!context.mounted) return false;
      QuiltConfirmation.error(context, 'Could not volunteer: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateText = MaterialLocalizations.of(
      context,
    ).formatFullDate(event.startTime);
    final timeText = TimeOfDay.fromDateTime(event.startTime).format(context);
    final profile = context.watch<CurrentUserProfileNotifier>().profile;
    final canVolunteer = profile?.isParent == true;
    final seededAttendees = event.attendeeNames.take(4).join(', ');
    final seededVolunteers = event.parentVolunteerNames.take(3).join(', ');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((event.imageUrl ?? '').trim().isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  event.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            event.title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(event.description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          _AboutDetailRow(
            icon: Icons.access_time_rounded,
            label: 'Time',
            value: '$dateText at $timeText',
            theme: theme,
          ),
          if (event.location.trim().isNotEmpty)
            _AboutDetailRow(
              icon: Icons.place_outlined,
              label: 'Location',
              value: event.location.trim(),
              theme: theme,
            ),
          if (event.goingCount > 0 || seededAttendees.isNotEmpty)
            _AboutDetailRow(
              icon: Icons.how_to_reg_outlined,
              label: 'Going',
              value: [
                if (event.goingCount > 0) '${event.goingCount} attending',
                if (seededAttendees.isNotEmpty) seededAttendees,
              ].join(' · '),
              theme: theme,
            ),
          if (event.chaperonesNeeded > 0 ||
              event.parentVolunteerCount > 0 ||
              seededVolunteers.isNotEmpty)
            _AboutDetailRow(
              icon: Icons.volunteer_activism_outlined,
              label: 'Parent volunteers',
              value: [
                if (event.chaperonesNeeded > 0)
                  '${event.chaperonesNeeded} requested',
                if (event.parentVolunteerCount > 0)
                  '${event.parentVolunteerCount} signed up',
                if (seededVolunteers.isNotEmpty) seededVolunteers,
              ].join(' · '),
              theme: theme,
            ),
          _EventRoster(
            schoolID: schoolID,
            clubID: clubID,
            eventID: event.id,
            fallbackAttendees: event.attendeeNames,
          ),
          _VolunteerRoster(
            schoolID: schoolID,
            clubID: clubID,
            eventID: event.id,
            fallbackVolunteers: event.parentVolunteerNames,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              CalendarEventActions(event: event),
              if (canGenerateAttendanceQr)
                OutlinedButton.icon(
                  icon: const Icon(Icons.qr_code_2_outlined),
                  label: const Text('Check-in QR'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            EventQrGeneratorPage(club: club, event: event),
                      ),
                    );
                  },
                ),
              if (canVolunteer)
                _VolunteerAction(
                  schoolID: schoolID,
                  clubID: clubID,
                  eventID: event.id,
                  parentUID: profile!.UID,
                  onVolunteer: () => _volunteer(context),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VolunteerAction extends StatefulWidget {
  const _VolunteerAction({
    required this.schoolID,
    required this.clubID,
    required this.eventID,
    required this.parentUID,
    required this.onVolunteer,
  });

  final String schoolID;
  final String clubID;
  final String eventID;
  final String parentUID;
  final Future<bool> Function() onVolunteer;

  @override
  State<_VolunteerAction> createState() => _VolunteerActionState();
}

class _VolunteerActionState extends State<_VolunteerAction> {
  bool _recorded = false;
  bool _submitting = false;

  Future<void> _volunteer() async {
    setState(() => _submitting = true);
    try {
      final recorded = await widget.onVolunteer();
      if (!mounted) return;
      setState(() => _recorded = recorded);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebase = context.read<FirebaseService>();
    return StreamBuilder<List<EventParticipant>>(
      stream: firebase.getEventVolunteers(
        schoolID: widget.schoolID,
        clubID: widget.clubID,
        eventID: widget.eventID,
      ),
      builder: (context, snapshot) {
        final isVolunteering =
            _recorded ||
            (snapshot.data ?? const <EventParticipant>[]).any(
              (volunteer) => volunteer.uid == widget.parentUID,
            );

        if (isVolunteering) {
          return const _VolunteerStatusChip();
        }

        return FilledButton.icon(
          onPressed: _submitting ? null : _volunteer,
          icon: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.volunteer_activism_outlined),
          label: Text(_submitting ? 'Recording...' : 'Volunteer as chaperone'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
          ),
        );
      },
    );
  }
}

class _VolunteerStatusChip extends StatelessWidget {
  const _VolunteerStatusChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 18,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            "You're volunteering",
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventRoster extends StatelessWidget {
  const _EventRoster({
    required this.schoolID,
    required this.clubID,
    required this.eventID,
    required this.fallbackAttendees,
  });

  final String schoolID;
  final String clubID;
  final String eventID;
  final List<String> fallbackAttendees;

  @override
  Widget build(BuildContext context) {
    final firebase = context.read<FirebaseService>();
    return StreamBuilder<List<EventParticipant>>(
      stream: firebase.getEventAttendees(
        schoolID: schoolID,
        clubID: clubID,
        eventID: eventID,
      ),
      builder: (context, snapshot) {
        final names = snapshot.hasData
            ? snapshot.data!.map((attendee) => attendee.name).toList()
            : fallbackAttendees;
        return _CompactNameChips(
          icon: Icons.people_outline,
          names: names,
          emptyText: '',
        );
      },
    );
  }
}

class _VolunteerRoster extends StatelessWidget {
  const _VolunteerRoster({
    required this.schoolID,
    required this.clubID,
    required this.eventID,
    required this.fallbackVolunteers,
  });

  final String schoolID;
  final String clubID;
  final String eventID;
  final List<String> fallbackVolunteers;

  @override
  Widget build(BuildContext context) {
    final firebase = context.read<FirebaseService>();
    return StreamBuilder<List<EventParticipant>>(
      stream: firebase.getEventVolunteers(
        schoolID: schoolID,
        clubID: clubID,
        eventID: eventID,
      ),
      builder: (context, snapshot) {
        final names = snapshot.hasData
            ? snapshot.data!.map((volunteer) => volunteer.name).toList()
            : fallbackVolunteers;
        return _CompactNameChips(
          icon: Icons.supervisor_account_outlined,
          names: names,
          emptyText: '',
        );
      },
    );
  }
}

class _CompactNameChips extends StatelessWidget {
  const _CompactNameChips({
    required this.icon,
    required this.names,
    required this.emptyText,
  });

  final IconData icon;
  final List<String> names;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final visibleNames = names
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .take(6)
        .toList();
    if (visibleNames.isEmpty && emptyText.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          if (visibleNames.isEmpty)
            Text(
              emptyText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final name in visibleNames)
              Chip(
                label: Text(name),
                visualDensity: VisualDensity.compact,
                side: BorderSide.none,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
        ],
      ),
    );
  }
}

class _ClubSettingsPage extends StatefulWidget {
  const _ClubSettingsPage({required this.schoolID, required this.club});

  final String schoolID;
  final ClubInfo club;

  @override
  State<_ClubSettingsPage> createState() => _ClubSettingsPageState();
}

class _ClubSettingsPageState extends State<_ClubSettingsPage> {
  late final TextEditingController _title;
  late final TextEditingController _tagline;
  late final TextEditingController _description;
  late final TextEditingController _meetingTime;
  late final TextEditingController _location;
  late final TextEditingController _groupChatUrl;
  late final TextEditingController _highlights;
  String? _imageUrl;
  bool _saving = false;
  bool _uploadingImage = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.club.title);
    _tagline = TextEditingController(text: widget.club.tagline);
    _description = TextEditingController(text: widget.club.description);
    _meetingTime = TextEditingController(text: widget.club.meetingTime);
    _location = TextEditingController(text: widget.club.location);
    _groupChatUrl = TextEditingController(text: widget.club.groupChatUrl);
    _highlights = TextEditingController(
      text: widget.club.highlights.join(', '),
    );
    _imageUrl = widget.club.imageUrl;
  }

  @override
  void dispose() {
    _title.dispose();
    _tagline.dispose();
    _description.dispose();
    _meetingTime.dispose();
    _location.dispose();
    _groupChatUrl.dispose();
    _highlights.dispose();
    super.dispose();
  }

  ClubInfo _editedClub() {
    return widget.club.copyWith(
      title: _title.text.trim(),
      tagline: _tagline.text.trim(),
      description: _description.text.trim(),
      meetingTime: _meetingTime.text.trim(),
      location: _location.text.trim(),
      imageUrl: _imageUrl,
      groupChatUrl: _groupChatUrl.text.trim(),
      highlights: _highlights.text
          .split(',')
          .map((highlight) => highlight.trim())
          .where((highlight) => highlight.isNotEmpty)
          .toList(),
    );
  }

  Future<void> _pickImage() async {
    final picker = context.read<UploadPickerService>();
    final firebase = context.read<FirebaseService>();
    final picked = await picker.pickSingleImage();
    if (picked == null) return;

    setState(() => _uploadingImage = true);
    try {
      final url = await firebase.uploadClubPicture(
        schoolID: widget.schoolID,
        clubID: widget.club.id,
        image: picked,
      );
      if (!mounted) return;
      setState(() => _imageUrl = url);
      QuiltConfirmation.success(context, 'Club picture updated.');
    } catch (e) {
      if (!mounted) return;
      QuiltConfirmation.error(context, 'Could not upload picture: $e');
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      QuiltConfirmation.warning(context, 'Club title is required.');
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<FirebaseService>().updateClubSettings(
        schoolID: widget.schoolID,
        club: _editedClub(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      QuiltConfirmation.success(context, 'Club settings saved.');
    } catch (e) {
      if (!mounted) return;
      QuiltConfirmation.error(context, 'Could not save settings: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Club settings'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppDecorations.screenBackground(context),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.cardPadding),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.45,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppDecorations.shadow(
                                context,
                              ).withValues(alpha: 0.05),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: (_imageUrl ?? '').trim().isNotEmpty
                                    ? Image.network(
                                        _imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                _ClubHeroFallback(
                                                  club: widget.club,
                                                ),
                                      )
                                    : _ClubHeroFallback(club: widget.club),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            OutlinedButton.icon(
                              onPressed: _uploadingImage ? null : _pickImage,
                              icon: _uploadingImage
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.add_photo_alternate_outlined,
                                    ),
                              label: const Text('Change picture'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        controller: _title,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          labelText: 'Club name',
                          prefixIcon: Icon(Icons.groups_2_outlined),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _tagline,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          labelText: 'Tagline',
                          prefixIcon: Icon(Icons.short_text_outlined),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _description,
                        enabled: !_saving,
                        minLines: 4,
                        maxLines: 7,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _meetingTime,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          labelText: 'Meeting time',
                          prefixIcon: Icon(Icons.schedule_outlined),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _location,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _groupChatUrl,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          labelText: 'Group chat link',
                          prefixIcon: Icon(Icons.forum_outlined),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _highlights,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          labelText: 'Highlights',
                          helperText: 'Separate highlights with commas.',
                          prefixIcon: Icon(Icons.sell_outlined),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl * 2),
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

class _QuickLinkDraft {
  _QuickLinkDraft({
    String label = '',
    String url = '',
    String description = '',
    this.visibility = ClubQuickLink.schoolMembersVisibility,
  }) : label = TextEditingController(text: label),
       url = TextEditingController(text: url),
       description = TextEditingController(text: description);

  factory _QuickLinkDraft.fromQuickLink(ClubQuickLink link) {
    return _QuickLinkDraft(
      label: link.label,
      url: link.url,
      description: link.description,
      visibility: link.visibility,
    );
  }

  final TextEditingController label;
  final TextEditingController url;
  final TextEditingController description;
  String visibility;

  ClubQuickLink toQuickLink() {
    return ClubQuickLink(
      label: label.text.trim(),
      url: url.text.trim(),
      description: description.text.trim(),
      visibility: visibility,
    );
  }

  void dispose() {
    label.dispose();
    url.dispose();
    description.dispose();
  }
}

class _QuickLinkDraftEditor extends StatelessWidget {
  const _QuickLinkDraftEditor({
    required this.draft,
    required this.index,
    required this.saving,
    required this.onRemove,
    required this.onChanged,
  });

  final _QuickLinkDraft draft;
  final int index;
  final bool saving;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Link ${index + 1}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                onPressed: saving ? null : onRemove,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove quick link',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: draft.label,
            enabled: !saving,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              labelText: 'Label',
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: draft.url,
            enabled: !saving,
            onChanged: (_) => onChanged(),
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'URL',
              prefixIcon: Icon(Icons.link_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: draft.description,
            enabled: !saving,
            onChanged: (_) => onChanged(),
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<String>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
                EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
            ),
            segments: const [
              ButtonSegment(
                value: ClubQuickLink.clubMembersVisibility,
                icon: Icon(Icons.groups_2_outlined, size: 18),
                label: Text(
                  'Club',
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                ),
              ),
              ButtonSegment(
                value: ClubQuickLink.schoolMembersVisibility,
                icon: Icon(Icons.school_outlined, size: 18),
                label: Text(
                  'School',
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                ),
              ),
              ButtonSegment(
                value: ClubQuickLink.publicVisibility,
                icon: Icon(Icons.public_outlined, size: 18),
                label: Text(
                  'Public',
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                ),
              ),
            ],
            selected: {draft.visibility},
            onSelectionChanged: saving
                ? null
                : (selection) {
                    draft.visibility = selection.first;
                    onChanged();
                  },
          ),
        ],
      ),
    );
  }
}

Future<void> _showCreatePostDialog(
  BuildContext context,
  ClubInfo club,
  String schoolID, {
  bool canChangeVisibility = false,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _CreatePostDialog(
      club: club,
      schoolID: schoolID,
      canChangeVisibility: canChangeVisibility,
    ),
  );
}

class _CreatePostDialog extends StatefulWidget {
  const _CreatePostDialog({
    required this.club,
    required this.schoolID,
    required this.canChangeVisibility,
  });

  final ClubInfo club;
  final String schoolID;
  final bool canChangeVisibility;

  @override
  State<_CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<_CreatePostDialog> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final List<UploadFileData> _selectedFiles = [];

  String _visibility = ClubPostEntry.clubMembersVisibility;
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  String _authorName(AuthService auth, CurrentUserProfileNotifier profileN) {
    final profile = profileN.profile;
    if ((profile?.displayName ?? '').isNotEmpty) return profile!.displayName;
    if ((profile?.realName ?? '').isNotEmpty) return profile!.realName;
    return auth.currentUser?.email ?? 'Member';
  }

  Future<void> _pickFiles() async {
    final picker = context.read<UploadPickerService>();
    final files = await picker.pickPostFiles();
    if (!mounted || files.isEmpty) return;
    setState(() {
      _selectedFiles.addAll(files);
    });
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) return;

    final auth = context.read<AuthService>();
    final profileNotifier = context.read<CurrentUserProfileNotifier>();
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      QuiltConfirmation.warning(context, 'You need to be signed in to post.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await context.read<FirebaseService>().createPostWithAttachments(
        schoolID: widget.schoolID,
        clubID: widget.club.id,
        title: title,
        body: body,
        authorId: uid,
        authorName: _authorName(auth, profileNotifier),
        authorPhotoUrl: profileNotifier.profile?.pfpURL,
        clubTitle: widget.club.title,
        visibility: _visibility,
        files: _selectedFiles,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      QuiltConfirmation.success(context, 'Post published');
    } catch (e) {
      if (!mounted) return;
      QuiltConfirmation.error(context, 'Could not publish: $e');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: theme.colorScheme.surfaceTint,
      elevation: 24,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.mode_edit_outline_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create Post',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        widget.club.title,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _submitting ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            TextField(
              controller: _title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: "What's the latest?",
                hintStyle: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.6,
                  ),
                  fontWeight: FontWeight.w500,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _body,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Share updates, announcements, or meeting notes...',
                hintStyle: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.6,
                  ),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
              ),
              minLines: 4,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.lg),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: ClubPostEntry.clubMembersVisibility,
                  icon: Icon(Icons.groups_2_outlined),
                  label: Text('Club'),
                ),
                ButtonSegment(
                  value: ClubPostEntry.schoolMembersVisibility,
                  icon: Icon(Icons.school_outlined),
                  label: Text('School'),
                ),
                ButtonSegment(
                  value: ClubPostEntry.publicVisibility,
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
            const SizedBox(height: AppSpacing.lg),

            // Attachments
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: _selectedFiles.isEmpty ? 0.0 : 0.3,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              padding: EdgeInsets.all(
                _selectedFiles.isEmpty ? 0 : AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_selectedFiles.isNotEmpty) ...[
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: _selectedFiles
                          .map(
                            (file) => Chip(
                              label: Text(
                                file.fileName,
                                style: const TextStyle(fontSize: 12),
                              ),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: _submitting
                                  ? null
                                  : () => setState(
                                      () => _selectedFiles.remove(file),
                                    ),
                              backgroundColor: theme.colorScheme.surface,
                              side: BorderSide(
                                color: theme.colorScheme.outlineVariant,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  TextButton.icon(
                    onPressed: _submitting ? null : _pickFiles,
                    icon: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    label: Text(
                      _selectedFiles.isEmpty
                          ? 'Attach Images or PDFs'
                          : 'Add more files',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: _selectedFiles.isEmpty
                          ? theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.3)
                          : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _submitting
                    ? null
                    : () async {
                        if (_title.text.trim().isEmpty ||
                            _body.text.trim().isEmpty) {
                          QuiltConfirmation.warning(
                            context,
                            'Add a title and body to your post.',
                          );
                          return;
                        }
                        await _submit();
                      },
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _submitting
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : const Text(
                        'Publish Post',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostsTab extends StatelessWidget {
  const _PostsTab({
    required this.club,
    required this.schoolID,
    this.publicOnly = false,
    this.schoolVisibleOnly = false,
    this.canAcknowledge = false,
    this.canModerate = false,
  });

  final ClubInfo club;
  final String schoolID;
  final bool publicOnly;
  final bool schoolVisibleOnly;
  final bool canAcknowledge;
  final bool canModerate;

  @override
  Widget build(BuildContext context) {
    final firebase = context.read<FirebaseService>();
    final currentProfile = context.watch<CurrentUserProfileNotifier>().profile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: StreamBuilder<List<ClubPostEntry>>(
            stream: publicOnly
                ? firebase.getPublicPosts(schoolID, club.id)
                : schoolVisibleOnly
                ? firebase.getSchoolVisiblePosts(schoolID, club.id)
                : firebase.getPosts(schoolID, club.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _FirestoreErrorBox(error: snapshot.error!);
              }
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final blocked =
                  currentProfile?.blockedUserIds ?? const <String>[];
              final posts = (snapshot.data ?? [])
                  .where((post) => !blocked.contains(post.authorId))
                  .toList();

              if (posts.isEmpty) {
                return Center(
                  child: Text(
                    publicOnly ? 'No public posts yet.' : 'No posts yet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.only(
                  top: AppSpacing.sm,
                  bottom: AppSpacing.xl * 3,
                ),
                itemCount: posts.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) => _PostCard(
                  post: posts[i],
                  club: club,
                  schoolID: schoolID,
                  currentProfile: currentProfile,
                  canAcknowledge: canAcknowledge,
                  allowActions: !publicOnly,
                  canModerate: canModerate,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PostCard extends StatefulWidget {
  const _PostCard({
    required this.post,
    required this.club,
    required this.schoolID,
    required this.currentProfile,
    required this.canAcknowledge,
    this.allowActions = true,
    this.canModerate = false,
  });

  final ClubPostEntry post;
  final ClubInfo club;
  final String schoolID;
  final UserProfile? currentProfile;
  final bool canAcknowledge;
  final bool allowActions;
  final bool canModerate;

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  late ClubPostEntry _post;
  bool _acknowledging = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  @override
  void didUpdateWidget(covariant _PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        widget.post.acknowledgements.length >= _post.acknowledgements.length) {
      _post = widget.post;
    }
  }

  Future<void> _confirmRead() async {
    final profile = widget.currentProfile;
    if (!widget.canAcknowledge ||
        profile == null ||
        _acknowledging ||
        _post.acknowledgedBy(profile.UID)) {
      return;
    }

    setState(() => _acknowledging = true);
    try {
      final updated = await context.read<FirebaseService>().acknowledgePost(
        schoolID: widget.schoolID,
        clubID: widget.club.id,
        post: _post,
        user: profile,
      );
      if (!mounted) return;
      setState(() => _post = updated);
      QuiltConfirmation.success(context, 'Post acknowledged.');
    } catch (e) {
      if (!mounted) return;
      QuiltConfirmation.error(context, 'Could not acknowledge post: $e');
    } finally {
      if (mounted) setState(() => _acknowledging = false);
    }
  }

  Future<void> _deletePost(BuildContext context) async {
    final firebase = context.read<FirebaseService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete post?'),
        content: Text(
          'This removes "${_post.title}" from ${widget.club.title}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;

    try {
      await firebase.deletePost(widget.schoolID, widget.club.id, _post.id);
      if (!context.mounted) return;
      QuiltConfirmation.success(context, 'Post deleted.');
    } catch (e) {
      if (!context.mounted) return;
      QuiltConfirmation.error(context, 'Could not delete post: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentProfile = widget.currentProfile;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppDecorations.shadow(context).withValues(alpha: 0.08),
            blurRadius: 36,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserPFP(
                uid: _post.authorId,
                displayName: _post.authorName,
                photoUrl: _post.authorPhotoUrl,
                radius: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _post.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_post.authorName} · ${appTimeOfDay.format(_post.timestamp)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.allowActions)
                PopupMenuButton<String>(
                  tooltip: 'Post actions',
                  onSelected: (value) {
                    if (value == 'report') {
                      showReportPostSheet(
                        context,
                        post: _post,
                        schoolID: widget.schoolID,
                        clubID: widget.club.id,
                        clubTitle: widget.club.title,
                      );
                    } else if (value == 'delete') {
                      _deletePost(context);
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
                        _post.authorId != currentProfile?.UID)
                      const PopupMenuItem(
                        value: 'block',
                        child: ListTile(
                          leading: Icon(Icons.block_outlined),
                          title: Text('Block author'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (widget.canModerate ||
                        currentProfile?.UID == _post.authorId)
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Delete post'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Linkify(
            onOpen: (link) async {
              final uri = Uri.tryParse(link.url);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
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
          if (_post.attachments.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            ..._post.attachments.map((attachment) {
              if (attachment.isImage) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _ImageAttachmentCard(attachment: attachment),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _FileAttachmentTile(attachment: attachment),
              );
            }),
          ],
          if (currentProfile != null) ...[
            const SizedBox(height: AppSpacing.sm),
            PostAcknowledgementRow(
              post: _post,
              currentUserID: currentProfile.UID,
              isLoading: _acknowledging,
              onConfirm: _confirmRead,
              onShowAll: () => showPostAcknowledgementsDialog(context, _post),
              canConfirm: widget.canAcknowledge,
            ),
          ],
        ],
      ),
    );
  }
}

class _ImageAttachmentCard extends StatelessWidget {
  const _ImageAttachmentCard({required this.attachment});

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
            return _FileAttachmentTile(attachment: attachment);
          },
        ),
      ),
    );
  }
}

class _FileAttachmentTile extends StatelessWidget {
  const _FileAttachmentTile({required this.attachment});

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
