import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Components/deferred_content.dart';
import '../Components/userPFP.dart';
import '../Models/user.dart';
import '../Providers/current_user_profile_notifier.dart';
import '../Service/firebase_service.dart';
import '../Utility/AppSpacing.dart';
import '../Utility/app_decorations.dart';
import '../Utility/app_formatters.dart';
import 'clubpage.dart';
import 'parent_events_page.dart';

class ParentStudentsPage extends StatefulWidget {
  const ParentStudentsPage({super.key});

  @override
  State<ParentStudentsPage> createState() => _ParentStudentsPageState();
}

class _ParentStudentsPageState extends State<ParentStudentsPage> {
  Future<List<UserProfile>>? _studentsFuture;
  String? _loadedParentUid;
  int? _loadedProfileRevision;

  Future<void> _refreshStudents(
    UserProfile profile,
    int profileRevision,
  ) async {
    final firebase = context.read<FirebaseService>();
    final future = firebase.getStudentsForParent(profile);
    setState(() {
      _studentsFuture = future;
      _loadedParentUid = profile.UID;
      _loadedProfileRevision = profileRevision;
    });
    await future;
  }

  Future<List<UserProfile>> _studentsFor(
    UserProfile profile,
    int profileRevision,
  ) {
    if (_studentsFuture == null ||
        _loadedParentUid != profile.UID ||
        _loadedProfileRevision != profileRevision) {
      _studentsFuture = context.read<FirebaseService>().getStudentsForParent(
        profile,
      );
      _loadedParentUid = profile.UID;
      _loadedProfileRevision = profileRevision;
    }
    return _studentsFuture!;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileNotifier = context.watch<CurrentUserProfileNotifier>();
    final profile = profileNotifier.profile;
    final profileRevision = profileNotifier.profileRevision;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Students',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.2),
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
                  child: Builder(
                    builder: (context) {
                      return FutureBuilder<List<UserProfile>>(
                        future: _studentsFor(profile, profileRevision),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final students = snapshot.data ?? [];
                          return RefreshIndicator(
                            onRefresh: () =>
                                _refreshStudents(profile, profileRevision),
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.screenPaddingH,
                                vertical: AppSpacing.screenPaddingV,
                              ),
                              children: [
                                Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 640,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _StudentsSummaryCard(
                                          count: students.length,
                                        ),
                                        const SizedBox(height: AppSpacing.lg),
                                        if (snapshot.hasError)
                                          _StudentsEmptyState(
                                            icon: Icons.error_outline,
                                            title: 'Students could not load',
                                            message:
                                                'Check that this parent account has permission to read linked student profiles.',
                                          )
                                        else if (students.isEmpty)
                                          const _StudentsEmptyState(
                                            icon: Icons.group_add_outlined,
                                            title: 'No students linked yet',
                                            message:
                                                'When a student approves this parent account, they will appear here.',
                                          )
                                        else
                                          for (final student in students) ...[
                                            _StudentCard(student: student),
                                            const SizedBox(
                                              height: AppSpacing.md,
                                            ),
                                          ],
                                        const SizedBox(height: 112),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }
}

class _StudentsSummaryCard extends StatelessWidget {
  const _StudentsSummaryCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppDecorations.shadow(context).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.supervisor_account_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count linked student${count == 1 ? '' : 's'}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Students this parent account can oversee.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
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

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.student});

  final UserProfile student;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = student.realName.trim().isNotEmpty
        ? student.realName.trim()
        : student.displayName.trim().isNotEmpty
        ? student.displayName.trim()
        : 'Student';
    final displayName = student.displayName.trim();
    final studentId = student.studentId.trim();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: AppDecorations.shadow(context).withValues(alpha: 0.05),
            blurRadius: 16,
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
              UserPFP(
                uid: student.UID,
                displayName: name,
                photoUrl: student.pfpURL,
                radius: 28,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (displayName.isNotEmpty && displayName != name) ...[
                      const SizedBox(height: 2),
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _StudentChip(
                          icon: Icons.verified_user_outlined,
                          label: student.accountStatus,
                        ),
                        if (studentId.isNotEmpty)
                          _StudentChip(
                            icon: Icons.badge_outlined,
                            label: studentId,
                          ),
                        if (student.schoolID.isNotEmpty)
                          _StudentSchoolChip(schoolID: student.schoolID),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (student.schoolID.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ClubPage(
                          schoolID: student.schoolID,
                          viewingStudent: student,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.groups_2_outlined),
                  label: const Text('View clubs'),
                ),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ParentEventsPage(student: student),
                      ),
                    );
                  },
                  icon: const Icon(Icons.event_outlined),
                  label: const Text('View events'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StudentSchoolChip extends StatelessWidget {
  const _StudentSchoolChip({required this.schoolID});

  final String schoolID;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: context.read<FirebaseService>().getSchoolByID(schoolID),
      builder: (context, snapshot) {
        return _StudentChip(
          icon: Icons.school_outlined,
          label: displaySchoolName(
            schoolID: schoolID,
            schoolName: snapshot.data?.name,
          ),
        );
      },
    );
  }
}

class _StudentChip extends StatelessWidget {
  const _StudentChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label.trim().isEmpty ? 'Not set' : label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentsEmptyState extends StatelessWidget {
  const _StudentsEmptyState({
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
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: theme.colorScheme.primary),
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
