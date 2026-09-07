import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Components/deferred_content.dart';
import '../Models/club.dart';
import '../Models/school.dart';
import '../Service/firebase_service.dart';
import '../Utility/AppSpacing.dart';
import '../Utility/app_decorations.dart';
import '../Utility/app_formatters.dart';
import 'clubpage.dart';

class ProspectiveSchoolsPage extends StatefulWidget {
  const ProspectiveSchoolsPage({super.key});

  @override
  State<ProspectiveSchoolsPage> createState() => _ProspectiveSchoolsPageState();
}

class _ProspectiveSchoolsPageState extends State<ProspectiveSchoolsPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firebase = context.read<FirebaseService>();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Schools',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppDecorations.screenBackground(context),
        child: SafeArea(
          child: DeferredContent(
            active: true,
            delay: const Duration(milliseconds: 140),
            child: StreamBuilder<List<School>>(
              stream: firebase.getSchools(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _ProspectiveEmptyState(
                    icon: Icons.error_outline,
                    title: 'Schools could not load',
                    message: snapshot.error.toString(),
                  );
                }

                final query = _searchQuery.toLowerCase();
                final schools = (snapshot.data ?? []).where((school) {
                  final haystack = [
                    school.name,
                    school.city ?? '',
                    school.state ?? '',
                    school.description,
                  ].join(' ').toLowerCase();
                  return haystack.contains(query);
                }).toList()..sort((a, b) => a.name.compareTo(b.name));

                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenPaddingH,
                      AppSpacing.screenPaddingV,
                      AppSpacing.screenPaddingH,
                      AppSpacing.screenPaddingV + 112,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Browse schools',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Explore public club previews before joining a school.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            TextField(
                              onChanged: (value) =>
                                  setState(() => _searchQuery = value),
                              decoration: const InputDecoration(
                                hintText: 'Search schools',
                                prefixIcon: Icon(Icons.search),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            if (schools.isEmpty)
                              const _ProspectiveEmptyState(
                                icon: Icons.school_outlined,
                                title: 'No schools found',
                                message:
                                    'Try another search or check back after schools are added.',
                              )
                            else
                              for (final school in schools) ...[
                                _SchoolCard(school: school),
                                const SizedBox(height: AppSpacing.md),
                              ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SchoolCard extends StatelessWidget {
  const _SchoolCard({required this.school});

  final School school;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = [
      if ((school.city ?? '').trim().isNotEmpty) school.city!.trim(),
      if ((school.state ?? '').trim().isNotEmpty) school.state!.trim(),
    ].join(', ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ProspectiveSchoolDetailPage(school: school),
            ),
          );
        },
        child: Ink(
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
          child: Row(
            children: [
              _SchoolAvatar(school: school),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displaySchoolName(
                        schoolID: school.id,
                        schoolName: school.name,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        location,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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

class ProspectiveSchoolDetailPage extends StatelessWidget {
  const ProspectiveSchoolDetailPage({required this.school, super.key});

  final School school;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firebase = context.read<FirebaseService>();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(school.name.isEmpty ? school.id : school.name),
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
          child: DeferredContent(
            active: true,
            delay: const Duration(milliseconds: 140),
            child: StreamBuilder<List<ClubInfo>>(
              stream: firebase.getClubs(school.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final clubs = (snapshot.data ?? [])
                  ..sort((a, b) => a.title.compareTo(b.title));

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SchoolDetailHeader(school: school),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'Clubs',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (snapshot.hasError)
                            _ProspectiveEmptyState(
                              icon: Icons.error_outline,
                              title: 'Clubs could not load',
                              message: snapshot.error.toString(),
                            )
                          else if (clubs.isEmpty)
                            const _ProspectiveEmptyState(
                              icon: Icons.groups_outlined,
                              title: 'No clubs yet',
                              message:
                                  'This school does not have public club listings yet.',
                            )
                          else
                            for (final club in clubs) ...[
                              _PublicClubCard(schoolID: school.id, club: club),
                              const SizedBox(height: AppSpacing.md),
                            ],
                          const SizedBox(height: 112),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SchoolDetailHeader extends StatelessWidget {
  const _SchoolDetailHeader({required this.school});

  final School school;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = [
      if ((school.city ?? '').trim().isNotEmpty) school.city!.trim(),
      if ((school.state ?? '').trim().isNotEmpty) school.state!.trim(),
    ].join(', ');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppDecorations.shadow(context).withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SchoolAvatar(school: school, size: 64),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      school.name.isEmpty ? school.id : school.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (location.isNotEmpty)
                      Text(
                        location,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (school.description.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              school.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ],
          if (school.address.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _DetailChip(icon: Icons.place_outlined, label: school.address),
          ],
        ],
      ),
    );
  }
}

class _PublicClubCard extends StatelessWidget {
  const _PublicClubCard({required this.schoolID, required this.club});

  final String schoolID;
  final ClubInfo club;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DeferredContent(
                active: true,
                child: ClubDetailPage(
                  club: club,
                  schoolID: schoolID,
                  publicView: true,
                ),
              ),
            ),
          );
        },
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: club.accentColor,
                backgroundImage: club.imageUrl != null
                    ? NetworkImage(club.imageUrl!)
                    : null,
                child: club.imageUrl == null
                    ? Text(
                        club.initials,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
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
              Icon(
                Icons.visibility_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SchoolAvatar extends StatelessWidget {
  const _SchoolAvatar({required this.school, this.size = 52});

  final School school;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = (school.name.isEmpty ? school.id : school.name)
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: school.imageUrl != null && school.imageUrl!.isNotEmpty
            ? Image.network(
                school.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _SchoolAvatarFallback(initials: initials),
              )
            : _SchoolAvatarFallback(initials: initials),
      ),
    );
  }
}

class _SchoolAvatarFallback extends StatelessWidget {
  const _SchoolAvatarFallback({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ColoredBox(
      color: theme.colorScheme.primary,
      child: Center(
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProspectiveEmptyState extends StatelessWidget {
  const _ProspectiveEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 38, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
