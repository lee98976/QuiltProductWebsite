import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../Models/school.dart';
import '../Models/user.dart';
import '../Components/confirmation_hub.dart';
import '../Providers/current_user_profile_notifier.dart';
import '../Service/auth_service.dart';
import '../Service/firebase_service.dart';
import '../Utility/AppSpacing.dart';
import '../Utility/app_formatters.dart';
import '../Utility/debug_flags.dart';

Future<void> showDebugAccountSwitcher(
  BuildContext context, {
  bool signInFirst = false,
}) async {
  if (!kShowDebugTools) return;

  final auth = context.read<AuthService>();
  final profileNotifier = context.read<CurrentUserProfileNotifier>();

  if (auth.currentUser == null) {
    if (!signInFirst) {
      QuiltConfirmation.warning(context, 'Sign in before using fake accounts.');
      return;
    }
    await auth.signInWithGoogle();
    if (!context.mounted) return;
    await profileNotifier.refresh();
  }

  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _DebugAccountSwitcherSheet(),
  );
}

class _DebugAccountSwitcherSheet extends StatefulWidget {
  const _DebugAccountSwitcherSheet();

  @override
  State<_DebugAccountSwitcherSheet> createState() =>
      _DebugAccountSwitcherSheetState();
}

class _DebugAccountSwitcherSheetState
    extends State<_DebugAccountSwitcherSheet> {
  Future<List<UserProfile>>? _accountsFuture;
  Future<List<School>>? _schoolsFuture;
  String _selectedSchoolID = 'troy_high_school';
  bool _seeding = false;

  String get _profileSchoolID {
    final profile = context.read<CurrentUserProfileNotifier>().profile;
    final schoolID = profile?.schoolID.trim();
    return schoolID == null || schoolID.isEmpty ? 'troy_high_school' : schoolID;
  }

  Future<List<UserProfile>> _loadAccounts() {
    return context.read<FirebaseService>().getDebugUsers(_selectedSchoolID);
  }

  Future<List<School>> _loadSchools() async {
    final schools = await context
        .read<FirebaseService>()
        .getSchoolsFromServer();
    schools.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return schools;
  }

  void _reloadAccounts() {
    setState(() {
      _accountsFuture = _loadAccounts();
    });
  }

  void _selectSchool(String schoolID) {
    if (_selectedSchoolID == schoolID) return;
    setState(() {
      _selectedSchoolID = schoolID;
      _accountsFuture = _loadAccounts();
    });
  }

  Future<void> _seedFamily() async {
    setState(() => _seeding = true);
    try {
      await context.read<FirebaseService>().createDebugFamilyAccounts(
        schoolID: _selectedSchoolID,
      );
      _reloadAccounts();
      if (!mounted) return;
      QuiltConfirmation.success(context, 'Fake family created.');
    } catch (e) {
      if (!mounted) return;
      QuiltConfirmation.error(context, 'Could not create fake family: $e');
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  Future<void> _useAccount(UserProfile account) async {
    await context.read<CurrentUserProfileNotifier>().useDebugProfile(
      account.UID,
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _stopDebugProfile() async {
    await context.read<CurrentUserProfileNotifier>().stopUsingDebugProfile();
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
    _selectedSchoolID = _profileSchoolID;
    _schoolsFuture = _loadSchools();
    _accountsFuture = _loadAccounts();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileNotifier = context.watch<CurrentUserProfileNotifier>();
    final activeUid = profileNotifier.profile?.UID;
    final sheetHeight = math.min(
      MediaQuery.of(context).size.height * 0.85,
      620.0,
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.screenPaddingH,
          right: AppSpacing.screenPaddingH,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
        ),
        child: SizedBox(
          height: sheetHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Debug fake accounts',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Choose a seeded school, then choose a fake account.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _DebugSchoolPicker(
                selectedSchoolID: _selectedSchoolID,
                schoolsFuture: _schoolsFuture,
                onSelected: _selectSchool,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _seeding ? null : _seedFamily,
                      icon: _seeding
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.group_add_outlined),
                      label: const Text('Create fake family'),
                    ),
                  ),
                  if (profileNotifier.isUsingDebugProfile) ...[
                    const SizedBox(width: AppSpacing.sm),
                    IconButton.outlined(
                      tooltip: 'Use Google account',
                      onPressed: _stopDebugProfile,
                      icon: const Icon(Icons.person_off_outlined),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: FutureBuilder<List<UserProfile>>(
                  future: _accountsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return _DebugEmptyState(
                        icon: Icons.error_outline,
                        title: 'Fake accounts could not load',
                        message: snapshot.error.toString(),
                      );
                    }

                    final accounts = snapshot.data ?? [];
                    if (accounts.isEmpty) {
                      return const _DebugEmptyState(
                        icon: Icons.person_search_outlined,
                        title: 'No fake accounts yet',
                        message:
                            'Create a fake family, then choose the parent or either student.',
                      );
                    }

                    return ListView.separated(
                      itemCount: accounts.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final account = accounts[index];
                        return _DebugAccountTile(
                          account: account,
                          isActive: account.UID == activeUid,
                          onUse: () => _useAccount(account),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DebugSchoolPicker extends StatelessWidget {
  const _DebugSchoolPicker({
    required this.selectedSchoolID,
    required this.schoolsFuture,
    required this.onSelected,
  });

  final String selectedSchoolID;
  final Future<List<School>>? schoolsFuture;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<List<School>>(
      future: schoolsFuture,
      builder: (context, snapshot) {
        final schools = snapshot.data ?? const <School>[];
        if (schools.isEmpty &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }

        if (schools.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.school_outlined),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    displaySchoolNameFromID(selectedSchoolID),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final selectedExists = schools.any(
          (school) => school.id == selectedSchoolID,
        );
        final value = selectedExists ? selectedSchoolID : schools.first.id;
        if (!selectedExists) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onSelected(value);
          });
        }

        return DropdownButtonFormField<String>(
          initialValue: value,
          borderRadius: BorderRadius.circular(18),
          decoration: const InputDecoration(
            labelText: 'Debug school',
            prefixIcon: Icon(Icons.school_outlined),
          ),
          items: [
            for (final school in schools)
              DropdownMenuItem<String>(
                value: school.id,
                child: Text(
                  displaySchoolName(
                    schoolID: school.id,
                    schoolName: school.name,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) onSelected(value);
          },
        );
      },
    );
  }
}

class _DebugAccountTile extends StatelessWidget {
  const _DebugAccountTile({
    required this.account,
    required this.isActive,
    required this.onUse,
  });

  final UserProfile account;
  final bool isActive;
  final VoidCallback onUse;

  Future<void> _copyFamilyCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: account.familyCode));
    if (!context.mounted) return;
    QuiltConfirmation.success(context, 'Family code copied.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleParts = [
      account.accountRole,
      if (account.familyCode.isNotEmpty) 'Code ${account.familyCode}',
      if (account.studentUids.isNotEmpty)
        '${account.studentUids.length} linked student${account.studentUids.length == 1 ? '' : 's'}',
      if (account.parentIds.isNotEmpty)
        '${account.parentIds.length} parent${account.parentIds.length == 1 ? '' : 's'}',
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            child: Text(
              account.displayName.trim().isEmpty
                  ? '?'
                  : account.displayName.trim()[0].toUpperCase(),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleParts.join(' - '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (account.familyCode.isNotEmpty)
            IconButton(
              tooltip: 'Copy family code',
              onPressed: () => _copyFamilyCode(context),
              icon: const Icon(Icons.copy_outlined),
            ),
          IconButton.filledTonal(
            tooltip: isActive ? 'Current fake account' : 'Use fake account',
            onPressed: isActive ? null : onUse,
            icon: Icon(isActive ? Icons.check : Icons.login_outlined),
          ),
        ],
      ),
    );
  }
}

class _DebugEmptyState extends StatelessWidget {
  const _DebugEmptyState({
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
