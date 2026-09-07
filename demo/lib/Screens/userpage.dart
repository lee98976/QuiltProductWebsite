import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'debug_account_switcher.dart';
import '../Components/confirmation_hub.dart';
import '../Components/deferred_content.dart';
import '../Components/userPFP.dart';
import '../Models/parent_connection_link.dart';
import '../Models/parent_request.dart';
import '../Providers/current_user_profile_notifier.dart';
import '../Service/auth_service.dart';
import '../Service/calendar_account_service.dart';
import '../Service/firebase_service.dart';
import '../Service/upload_picker_service.dart';
import '../Utility/AppSpacing.dart';
import '../Utility/app_decorations.dart';
import '../Utility/app_formatters.dart';
import '../Utility/app_theme.dart';
import '../Utility/debug_flags.dart';
import '../Models/hall_pass.dart';
import '../Models/user.dart';
import '../Components/schedulepage.dart';
import 'parent_connection_request_dialog.dart';
import 'parent_connection_scanner_page.dart';
import 'parent_students_page.dart';
import 'qr_scanner_page.dart';
import 'signup.dart';
import 'legal_and_support_page.dart';

Future<void> _openHallPassScanner(BuildContext context) async {
  final schoolID = context
      .read<CurrentUserProfileNotifier>()
      .profile
      ?.schoolID
      .trim();
  if (schoolID == null || schoolID.isEmpty) {
    QuiltConfirmation.warning(context, 'Join a school before using hall pass.');
    return;
  }

  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          QrScannerPage(schoolID: schoolID, mode: QrScannerMode.hallPass),
    ),
  );
}

class _DeferredProfileRoutePlaceholder extends StatelessWidget {
  const _DeferredProfileRoutePlaceholder();

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

class HallPassButton extends StatelessWidget {
  const HallPassButton({super.key, this.onScan});

  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    final firebase = context.read<FirebaseService>();
    final profileN = context.watch<CurrentUserProfileNotifier>();
    final profile = profileN.profile;
    final uid = profile?.UID;
    final schoolID = profile?.schoolID;

    if (uid == null || schoolID == null || schoolID.isEmpty) {
      return const Center(child: Text('Missing data to load hall pass.'));
    }

    // print("Got Here in the hall pass");

    return StreamBuilder<HallPass?>(
      stream: firebase.getActiveHallPass(schoolID, uid),
      builder: (context, snapshot) {
        return _HallPassScanCard(
          activePass: snapshot.data,
          onScan: onScan ?? () => _openHallPassScanner(context),
        );
      },
    );
  }
}

class _HallPassScanCard extends StatelessWidget {
  const _HallPassScanCard({required this.activePass, required this.onScan});

  final HallPass? activePass;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pass = activePass;
    final hasActivePass = pass != null;
    final title = hasActivePass ? 'Active hall pass' : 'No active hall pass';
    final message = hasActivePass
        ? 'Room ${pass.roomId} since ${TimeOfDay.fromDateTime(pass.departTime).format(context)}. Scan the same room QR code to return the pass.'
        : 'Scan a room QR code when you leave.';
    final buttonLabel = hasActivePass ? 'Return hall pass' : 'Scan room QR';
    final icon = hasActivePass
        ? Icons.directions_run_rounded
        : Icons.qr_code_scanner;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: _panelDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onScan,
            icon: const Icon(Icons.qr_code_scanner_outlined),
            label: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => UserPageState();
}

class UserPageState extends State<UserPage>
    with SingleTickerProviderStateMixin {
  static const int _hallPassTabIndex = 0;
  static const int _familyTabIndex = 1;
  static const int _scheduleTabIndex = 2;

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> openHallPassScanner() async {
    _tabController.animateTo(_hallPassTabIndex);
    await _openHallPassScanner(context);
  }

  Widget _familyTabContent(BuildContext context, ThemeData theme) {
    final profile = context.watch<CurrentUserProfileNotifier>().profile;
    if (profile == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (profile.isCurrentStudent) {
      return const _StudentFamilyCodeCard();
    }
    if (profile.isParent) {
      return const ParentFamilyRequestCard();
    }
    return _InfoPanel(
      icon: Icons.family_restroom_outlined,
      title: 'Family access',
      message: 'Family requests are available for student and parent accounts.',
    );
  }

  Widget _tabContent(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        AppSpacing.xs,
        AppSpacing.screenPaddingH,
        AppSpacing.screenPaddingV + 102,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = context.watch<CurrentUserProfileNotifier>().profile;
    final isParent = profile?.isParent ?? false;
    final isProspective = profile?.isProspectiveStudent ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          isParent ? 'Parent Profile' : 'Profile',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (kShowDebugTools)
            IconButton(
              tooltip: 'Fake accounts',
              icon: const Icon(Icons.bug_report_outlined),
              onPressed: () => showDebugAccountSwitcher(context),
            ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<CurrentUserProfileNotifier>().signOut();
            },
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DeferredContent(
                    active: true,
                    placeholder: _DeferredProfileRoutePlaceholder(),
                    child: _ProfileSettingsPage(),
                  ),
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
          child: isParent
              ? const _ParentProfileView()
              : isProspective
              ? const _ProspectiveProfileView()
              : Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenPaddingH,
                      ),
                      child: _ProfileOverviewCard(),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenPaddingH,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppDecorations.shadow(
                              context,
                            ).withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TabBar(
                        controller: _tabController,
                        dividerColor: Colors.transparent,
                        indicator: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        labelColor: theme.colorScheme.onPrimaryContainer,
                        unselectedLabelColor:
                            theme.colorScheme.onSurfaceVariant,
                        indicatorSize: TabBarIndicatorSize.tab,
                        tabs: const [
                          Tab(
                            text: 'Hall Pass',
                            icon: Icon(Icons.qr_code_scanner),
                          ),
                          Tab(
                            text: 'Family',
                            icon: Icon(Icons.family_restroom_outlined),
                          ),
                          Tab(
                            text: 'Schedule',
                            icon: Icon(Icons.calendar_today),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _tabContent(
                            DeferredTabContent(
                              tabIndex: _hallPassTabIndex,
                              child: HallPassButton(
                                onScan: () => _openHallPassScanner(context),
                              ),
                            ),
                          ),
                          _tabContent(
                            DeferredTabContent(
                              tabIndex: _familyTabIndex,
                              child: _familyTabContent(context, theme),
                            ),
                          ),
                          _tabContent(
                            const DeferredTabContent(
                              tabIndex: _scheduleTabIndex,
                              child: SchedulePage(),
                            ),
                          ),
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

class _ProspectiveProfileView extends StatelessWidget {
  const _ProspectiveProfileView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingH,
        vertical: AppSpacing.screenPaddingV,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _ProfileOverviewCard(),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DeferredContent(
                          active: true,
                          placeholder: _DeferredProfileRoutePlaceholder(),
                          child: SignUpPage(
                            initialRole: UserProfile.parentRole,
                          ),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.family_restroom_outlined),
                  label: const Text('Create guardian profile'),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DeferredContent(
                          active: true,
                          placeholder: _DeferredProfileRoutePlaceholder(),
                          child: SignUpPage(
                            initialRole: UserProfile.currentStudentRole,
                          ),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.school_outlined),
                  label: const Text('Create student profile'),
                ),
                const SizedBox(height: 112),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ParentProfileView extends StatelessWidget {
  const _ParentProfileView();

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<CurrentUserProfileNotifier>().profile;

    if (profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingH,
        vertical: AppSpacing.screenPaddingV,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _ParentIdentityCard(),
                const SizedBox(height: AppSpacing.lg),
                _StudentFacingDetailsCard(profile: profile),
                const SizedBox(height: 112),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ParentIdentityCard extends StatelessWidget {
  const _ParentIdentityCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = context.watch<CurrentUserProfileNotifier>().profile;
    final email = profile?.email ?? '';
    final displayName = (profile?.displayName ?? '').trim();
    final realName = (profile?.realName ?? '').trim();
    final name = displayName.isNotEmpty
        ? displayName
        : realName.isNotEmpty
        ? realName
        : 'Parent';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppDecorations.shadow(context).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const _EditableProfilePhoto(radius: 48),
          const SizedBox(height: AppSpacing.md),
          Text(
            name,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (realName.isNotEmpty && realName != name) ...[
            const SizedBox(height: 4),
            Text(
              realName,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.84),
              ),
            ),
          ],
          if (email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              email,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Parent account',
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentFacingDetailsCard extends StatelessWidget {
  const _StudentFacingDetailsCard({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final email = profile.email;

    return _SettingsSection(
      title: 'Student-facing identity',
      children: [
        _SettingsInfoRow(
          icon: Icons.person_outline,
          label: 'Display name',
          value: profile.displayName.trim().isNotEmpty
              ? profile.displayName.trim()
              : 'Not set',
        ),
        _SettingsInfoRow(
          icon: Icons.badge_outlined,
          label: 'Full name',
          value: profile.realName.trim().isNotEmpty
              ? profile.realName.trim()
              : 'Not set',
        ),
        if (email.isNotEmpty)
          _SettingsInfoRow(
            icon: Icons.alternate_email_outlined,
            label: 'Email',
            value: email,
          ),
        _SettingsInfoRow(
          icon: Icons.verified_user_outlined,
          label: 'Status',
          value: profile.accountStatus,
        ),
      ],
    );
  }
}

class _EditableProfilePhoto extends StatefulWidget {
  const _EditableProfilePhoto({this.radius = 34});

  final double radius;

  @override
  State<_EditableProfilePhoto> createState() => _EditableProfilePhotoState();
}

class _EditableProfilePhotoState extends State<_EditableProfilePhoto> {
  bool _uploading = false;

  Future<void> _changePhoto() async {
    final firebase = context.read<FirebaseService>();
    final picker = context.read<UploadPickerService>();
    final profileNotifier = context.read<CurrentUserProfileNotifier>();
    if (profileNotifier.isUsingDebugProfile) {
      QuiltConfirmation.warning(
        context,
        'Switch to your signed-in account first.',
      );
      return;
    }
    final uid = profileNotifier.profile?.UID;
    if (uid == null) return;

    final picked = await picker.pickSingleImage();
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      await firebase.uploadProfilePicture(uid: uid, image: picked);
      await profileNotifier.refresh();
      if (!mounted) return;
      QuiltConfirmation.success(context, 'Profile photo updated.');
    } catch (e) {
      if (!mounted) return;
      QuiltConfirmation.error(context, 'Could not upload profile photo: $e');
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = context.watch<CurrentUserProfileNotifier>().profile;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        UserPFP(
          uid: profile?.UID,
          displayName: profile?.displayName,
          photoUrl: profile?.pfpURL,
          radius: widget.radius,
        ),
        Positioned(
          right: -4,
          bottom: -4,
          child: Material(
            color: theme.colorScheme.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _uploading ? null : _changePhoto,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StudentFamilyCodeCard extends StatefulWidget {
  const _StudentFamilyCodeCard();

  @override
  State<_StudentFamilyCodeCard> createState() => _StudentFamilyCodeCardState();
}

class _StudentFamilyCodeCardState extends State<_StudentFamilyCodeCard> {
  bool _creatingCode = false;

  Future<void> _createFamilyCode() async {
    final profileNotifier = context.read<CurrentUserProfileNotifier>();
    final profile = profileNotifier.profile;
    if (profile == null) return;

    final firebase = context.read<FirebaseService>();

    setState(() => _creatingCode = true);
    try {
      await firebase.ensureStudentFamilyCode(profile);
      if (!mounted) return;
      QuiltConfirmation.success(context, 'Family code created.');
    } catch (e) {
      if (!mounted) return;
      QuiltConfirmation.error(context, 'Could not create family code: $e');
    } finally {
      if (mounted) {
        setState(() => _creatingCode = false);
      }
    }
  }

  Future<void> _copyInviteLink(String code) async {
    final link = ParentConnectionLink.create(code).toString();
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    QuiltConfirmation.success(context, 'Invite link copied.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firebase = context.read<FirebaseService>();
    final profile = context.watch<CurrentUserProfileNotifier>().profile;
    final familyCode = profile?.familyCode ?? '';

    if (profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: _panelDecoration(theme),
          child: Column(
            children: [
              if (familyCode.isNotEmpty)
                QrImageView(
                  data: ParentConnectionLink.create(familyCode).toString(),
                  size: 150,
                  backgroundColor: theme.colorScheme.surface,
                )
              else
                Icon(
                  Icons.family_restroom_outlined,
                  size: 88,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                familyCode.isNotEmpty ? familyCode : 'No family code yet',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                familyCode.isNotEmpty
                    ? 'A guardian can scan this in Quilt or with their phone camera. You finish each request by scanning their QR.'
                    : 'Create a family code before connecting with a guardian.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (familyCode.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _copyInviteLink(familyCode),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy invite link'),
                )
              else
                FilledButton.icon(
                  onPressed: _creatingCode ? null : _createFamilyCode,
                  icon: _creatingCode
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_link_outlined),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    child: Text('Create family code'),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ConnectedGuardiansCard(profile: profile),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Connection requests',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        StreamBuilder<List<ParentRequest>>(
          stream: firebase.watchIncomingParentRequests(profile.UID),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final requests = snapshot.data ?? [];
            if (requests.isEmpty) {
              return _InfoPanel(
                icon: Icons.mark_email_unread_outlined,
                title: 'No pending requests',
                message: 'Guardian requests will appear here to finish.',
              );
            }

            return Column(
              children: requests
                  .map(
                    (request) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _ParentRequestReviewCard(request: request),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class ParentFamilyRequestCard extends StatefulWidget {
  const ParentFamilyRequestCard({super.key, this.onOpenStudents});

  final VoidCallback? onOpenStudents;

  @override
  State<ParentFamilyRequestCard> createState() =>
      _ParentFamilyRequestCardState();
}

class _ParentFamilyRequestCardState extends State<ParentFamilyRequestCard> {
  bool _submitting = false;

  Future<void> _scanStudentQr() async {
    final familyCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const DeferredContent(
          active: true,
          placeholder: _DeferredProfileRoutePlaceholder(),
          child: ParentConnectionScannerPage(),
        ),
      ),
    );
    if (!mounted || familyCode == null) return;

    setState(() => _submitting = true);
    final requestSent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ParentConnectionRequestDialog(familyCode: familyCode),
    );
    if (mounted) {
      setState(() => _submitting = false);
      if (requestSent == true) {
        QuiltConfirmation.success(
          context,
          'Request sent. Ask the student to scan your QR.',
        );
      }
    }
  }

  Future<void> _dismissRequest(ParentRequest request) async {
    final profile = context.read<CurrentUserProfileNotifier>().profile;
    if (profile == null) return;

    try {
      await context.read<FirebaseService>().deleteParentRequest(
        requestId: request.id,
        parentId: profile.UID,
      );
      if (!mounted) return;
      QuiltConfirmation.success(context, 'Request removed.');
    } catch (e) {
      if (!mounted) return;
      QuiltConfirmation.error(context, 'Could not remove request: $e');
    }
  }

  void _openStudents() {
    final callback = widget.onOpenStudents;
    if (callback != null) {
      callback();
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const DeferredContent(
          active: true,
          placeholder: _DeferredProfileRoutePlaceholder(),
          child: ParentStudentsPage(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firebase = context.read<FirebaseService>();
    final profile = context.watch<CurrentUserProfileNotifier>().profile;

    if (profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: _panelDecoration(theme),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Connect with a student',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Scan the student\'s QR, choose who they are to you, then show them the pending request QR below.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: _submitting ? null : _scanStudentQr,
                icon: const Icon(Icons.qr_code_scanner_outlined),
                label: const Text('Scan student QR'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ParentStudentsOverview(
          profile: profile,
          firebase: firebase,
          onOpenStudents: _openStudents,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Your requests',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        StreamBuilder<List<ParentRequest>>(
          stream: firebase.watchParentRequestsForParent(profile.UID),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final requests = snapshot.data ?? [];
            if (requests.isEmpty) {
              return _InfoPanel(
                icon: Icons.outgoing_mail,
                title: 'No requests sent',
                message: 'Send a request after your student shares a code.',
              );
            }

            return Column(
              children: requests
                  .map(
                    (request) => Dismissible(
                      key: ValueKey('parent-request-${request.id}'),
                      direction: DismissDirection.horizontal,
                      background: const _DismissRequestBackground(
                        alignment: Alignment.centerLeft,
                      ),
                      secondaryBackground: const _DismissRequestBackground(
                        alignment: Alignment.centerRight,
                      ),
                      confirmDismiss: (_) async {
                        await _dismissRequest(request);
                        return false;
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _OutgoingParentRequestCard(request: request),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ParentStudentsOverview extends StatelessWidget {
  const _ParentStudentsOverview({
    required this.profile,
    required this.firebase,
    required this.onOpenStudents,
  });

  final UserProfile profile;
  final FirebaseService firebase;
  final VoidCallback onOpenStudents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Students you oversee',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            TextButton(
              onPressed: onOpenStudents,
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        FutureBuilder<List<UserProfile>>(
          future: firebase.getStudentsForParent(profile),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _InfoPanel(
                icon: Icons.error_outline,
                title: 'Students could not load',
                message: 'Check that this parent account has permission.',
              );
            }

            final students = snapshot.data ?? [];
            if (students.isEmpty) {
              return _InfoPanel(
                icon: Icons.group_add_outlined,
                title: 'No linked students',
                message: 'Accepted student connections will appear here.',
              );
            }

            return Container(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              decoration: _panelDecoration(theme),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.school_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${students.length} linked student${students.length == 1 ? '' : 's'}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final student in students.take(3)) ...[
                    _ParentStudentRow(student: student),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (students.length > 3)
                    Text(
                      '+${students.length - 3} more',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ParentStudentRow extends StatelessWidget {
  const _ParentStudentRow({required this.student});

  final UserProfile student;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = student.realName.trim().isNotEmpty
        ? student.realName.trim()
        : student.displayName.trim().isNotEmpty
        ? student.displayName.trim()
        : 'Student';

    return Row(
      children: [
        UserPFP(
          uid: student.UID,
          displayName: name,
          photoUrl: student.pfpURL,
          radius: 20,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _StatusPill(label: student.accountStatus),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DismissRequestBackground extends StatelessWidget {
  const _DismissRequestBackground({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      alignment: alignment,
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        Icons.delete_outline,
        color: theme.colorScheme.onErrorContainer,
      ),
    );
  }
}

class _ParentRequestReviewCard extends StatefulWidget {
  const _ParentRequestReviewCard({required this.request});

  final ParentRequest request;

  @override
  State<_ParentRequestReviewCard> createState() =>
      _ParentRequestReviewCardState();
}

class _ParentRequestReviewCardState extends State<_ParentRequestReviewCard> {
  static const List<String> _guardianRelationshipOptions = [
    'Guardian',
    'Parent',
    'Mother',
    'Father',
    'Step-parent',
    'Caregiver',
    'Mentor',
    'Other',
  ];

  bool _saving = false;

  Future<void> _scanAndApprove() async {
    final scannedRequestId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const DeferredContent(
          active: true,
          placeholder: _DeferredProfileRoutePlaceholder(),
          child: ParentConnectionScannerPage(
            mode: ParentConnectionScanMode.parentRequestQr,
          ),
        ),
      ),
    );
    if (!mounted || scannedRequestId == null) return;

    if (scannedRequestId != widget.request.id) {
      QuiltConfirmation.warning(
        context,
        'That QR belongs to a different connection request.',
      );
      return;
    }

    final relationship = await _chooseGuardianRelationship();
    if (!mounted || relationship == null) return;

    await _respond(accept: true, parentRelationship: relationship);
  }

  Future<String?> _chooseGuardianRelationship() {
    var selectedRelationship = _guardianRelationshipOptions.first;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final guardianName = widget.request.parentName.isNotEmpty
            ? widget.request.parentName
            : 'This guardian';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              icon: Icon(
                Icons.verified_user_outlined,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Confirm connection'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Choose who $guardianName is to you.'),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRelationship,
                      borderRadius: BorderRadius.circular(18),
                      items: _guardianRelationshipOptions
                          .map(
                            (relationship) => DropdownMenuItem(
                              value: relationship,
                              child: Text(relationship),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedRelationship = value;
                          });
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Guardian is my',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(selectedRelationship),
                  icon: const Icon(Icons.check_outlined),
                  label: const Text('Complete'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _respond({
    required bool accept,
    String parentRelationship = '',
  }) async {
    final profile = context.read<CurrentUserProfileNotifier>().profile;
    if (profile == null) return;

    final firebase = context.read<FirebaseService>();
    final profileNotifier = context.read<CurrentUserProfileNotifier>();

    setState(() => _saving = true);
    try {
      if (accept) {
        await firebase.acceptParentRequest(
          requestId: widget.request.id,
          studentUid: profile.UID,
          parentRelationship: parentRelationship,
        );
      } else {
        await firebase.declineParentRequest(
          requestId: widget.request.id,
          studentUid: profile.UID,
        );
      }
      await profileNotifier.refresh();
      if (!mounted) return;
      QuiltConfirmation.success(
        context,
        accept ? 'Connection complete.' : 'Request declined.',
      );
    } catch (e) {
      if (!mounted) return;
      QuiltConfirmation.error(context, 'Could not update request: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final request = widget.request;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _panelDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserPFP(
                uid: request.parentId,
                displayName: request.parentName,
                photoUrl: request.parentPhotoUrl,
                radius: 24,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.parentName.isNotEmpty
                          ? request.parentName
                          : 'Parent',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (request.parentEmail.isNotEmpty)
                      Text(
                        request.parentEmail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _DetailLine(label: 'Student is their', value: request.relationship),
          if (request.note.isNotEmpty)
            _DetailLine(label: 'Note', value: request.note),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : () => _respond(accept: false),
                  icon: const Icon(Icons.close_outlined),
                  label: const Text('Decline'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving ? null : _scanAndApprove,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.qr_code_scanner_outlined),
                  label: const Text('Scan QR'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutgoingParentRequestCard extends StatelessWidget {
  const _OutgoingParentRequestCard({required this.request});

  final ParentRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = switch (request.status) {
      ParentRequestStatus.accepted => theme.colorScheme.primaryContainer,
      ParentRequestStatus.declined => theme.colorScheme.errorContainer,
      ParentRequestStatus.pending => theme.colorScheme.surfaceContainerHighest,
    };
    final foregroundColor = switch (request.status) {
      ParentRequestStatus.accepted => theme.colorScheme.onPrimaryContainer,
      ParentRequestStatus.declined => theme.colorScheme.onErrorContainer,
      ParentRequestStatus.pending => theme.colorScheme.onSurfaceVariant,
    };
    final isPending = request.status == ParentRequestStatus.pending;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _panelDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.school_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.studentName.isNotEmpty
                          ? request.studentName
                          : 'Student',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      request.relationship.isNotEmpty
                          ? request.relationship
                          : 'Relationship not set',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  request.status.name,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: AppSpacing.md),
            Center(
              child: QrImageView(
                data: ParentConnectionLink.createParentRequest(
                  request.id,
                ).toString(),
                size: 150,
                backgroundColor: theme.colorScheme.surface,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Ask the student to scan this QR from their pending request.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else if (request.parentRelationship.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _DetailLine(
              label: 'Guardian is their',
              value: request.parentRelationship,
            ),
          ],
        ],
      ),
    );
  }
}

class _ConnectedGuardiansCard extends StatelessWidget {
  const _ConnectedGuardiansCard({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final guardians =
        profile.linkedAccounts
            .where((account) => account.role == UserProfile.parentRole)
            .toList()
          ..sort((a, b) {
            final aName = a.name.trim().isNotEmpty ? a.name : a.uid;
            final bName = b.name.trim().isNotEmpty ? b.name : b.uid;
            return aName.toLowerCase().compareTo(bName.toLowerCase());
          });

    if (guardians.isEmpty) {
      return _InfoPanel(
        icon: Icons.supervisor_account_outlined,
        title: 'No connected guardians',
        message: 'When you complete a guardian request, they will appear here.',
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: _panelDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.supervisor_account_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Connected guardians',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final guardian in guardians) ...[
            _ConnectedGuardianRow(guardian: guardian),
            if (guardian != guardians.last)
              Divider(
                height: AppSpacing.lg,
                color: theme.colorScheme.outline.withValues(alpha: 0.22),
              ),
          ],
        ],
      ),
    );
  }
}

class _ConnectedGuardianRow extends StatelessWidget {
  const _ConnectedGuardianRow({required this.guardian});

  final LinkedAccount guardian;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = guardian.name.trim().isNotEmpty
        ? guardian.name.trim()
        : 'Guardian';
    final relationship = guardian.relationship.trim().isNotEmpty
        ? guardian.relationship.trim()
        : guardian.role.trim().isNotEmpty
        ? guardian.role.trim()
        : 'Connected account';

    return Row(
      children: [
        UserPFP(
          uid: guardian.uid,
          displayName: name,
          photoUrl: guardian.photoUrl ?? '',
          radius: 22,
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
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                relationship,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
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
      decoration: _panelDecoration(theme),
      child: Column(
        children: [
          Icon(icon, size: 36, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
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

BoxDecoration _panelDecoration(ThemeData theme) {
  return BoxDecoration(
    color: theme.colorScheme.surface,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: AppDecorations.shadowFromTheme(theme).withValues(alpha: 0.06),
        blurRadius: 20,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

class _ProfileOverviewCard extends StatefulWidget {
  const _ProfileOverviewCard();

  @override
  State<_ProfileOverviewCard> createState() => _ProfileOverviewCardState();
}

class _ProfileSettingsPage extends StatelessWidget {
  const _ProfileSettingsPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = context.watch<CurrentUserProfileNotifier>().profile;
    final email = profile?.email ?? '';
    final isUsingDebugProfile = context
        .watch<CurrentUserProfileNotifier>()
        .isUsingDebugProfile;
    final isGuestSession = context
        .watch<CurrentUserProfileNotifier>()
        .isGuestSession;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Settings'),
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
                children: [
                  _SettingsSection(
                    title: 'Account',
                    children: [
                      _SettingsInfoRow(
                        icon: Icons.person_outline,
                        label: 'Display name',
                        value: (profile?.displayName ?? '').isNotEmpty
                            ? profile!.displayName
                            : 'Student',
                      ),
                      if (email.isNotEmpty)
                        _SettingsInfoRow(
                          icon: Icons.alternate_email_outlined,
                          label: 'Email',
                          value: email,
                        ),
                      if ((profile?.accountRole ?? '').isNotEmpty)
                        _SettingsInfoRow(
                          icon: Icons.verified_user_outlined,
                          label: 'Role',
                          value: profile!.accountRole,
                        ),
                      if (profile?.isCurrentStudent == true)
                        _SettingsSchoolInfoRow(schoolID: profile!.schoolID),
                      const SizedBox(height: AppSpacing.sm),
                      const _SignOutButton(),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _SettingsSection(
                    title: 'Appearance',
                    children: [_ThemePreferencePicker()],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _SettingsSection(
                    title: 'Calendar',
                    children: [
                      _CalendarAutoUpdatesSwitch(),
                      SizedBox(height: AppSpacing.md),
                      _CalendarIntegrationButtons(),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (profile?.isParent == true) ...[
                    const _SettingsSection(
                      title: 'Notifications',
                      children: [_EventSignupNotificationsSwitch()],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (kShowDebugTools) ...[
                    _SettingsSection(
                      title: 'Debug',
                      children: [
                        Text(
                          isUsingDebugProfile
                              ? 'You are using a fake Firestore profile.'
                              : 'Use a fake parent or student profile for testing.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => showDebugAccountSwitcher(context),
                            icon: const Icon(Icons.bug_report_outlined),
                            label: const Text('Choose fake account'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  _SettingsSection(
                    title: 'Privacy, safety & support',
                    children: [
                      Text(
                        'Review Quilt’s privacy notice and community safety rules, or contact support.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const LegalAndSupportPage(),
                            ),
                          ),
                          icon: const Icon(Icons.privacy_tip_outlined),
                          label: const Text(
                            'Open privacy and safety information',
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const _BlockedUsersControl(),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (!isGuestSession)
                    _SettingsSection(
                      title: 'Danger zone',
                      children: [
                        Text(
                          'Delete your Quilt profile and Firebase login account.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const _DeleteAccountButton(),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarIntegrationButtons extends StatefulWidget {
  const _CalendarIntegrationButtons();

  @override
  State<_CalendarIntegrationButtons> createState() =>
      _CalendarIntegrationButtonsState();
}

class _ThemePreferencePicker extends StatefulWidget {
  const _ThemePreferencePicker();

  @override
  State<_ThemePreferencePicker> createState() => _ThemePreferencePickerState();
}

class _ThemePreferencePickerState extends State<_ThemePreferencePicker> {
  String? _savingThemeId;

  Future<void> _selectTheme(QuiltThemeOption option) async {
    setState(() => _savingThemeId = option.id);
    try {
      await context.read<CurrentUserProfileNotifier>().updateThemePreference(
        option.id,
      );
    } catch (e) {
      if (!mounted) return;
      QuiltConfirmation.error(context, 'Could not save theme: $e');
    } finally {
      if (mounted) {
        setState(() => _savingThemeId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<CurrentUserProfileNotifier>().profile;
    final selectedId = QuiltThemeOption.byId(profile?.appThemeId).id;
    final canEdit = profile != null;

    return Column(
      children: [
        for (var i = 0; i < QuiltThemeOption.options.length; i++) ...[
          _ThemeOptionTile(
            option: QuiltThemeOption.options[i],
            selected: selectedId == QuiltThemeOption.options[i].id,
            saving: _savingThemeId == QuiltThemeOption.options[i].id,
            enabled: canEdit && _savingThemeId == null,
            onTap: () => _selectTheme(QuiltThemeOption.options[i]),
          ),
          if (i != QuiltThemeOption.options.length - 1)
            const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.option,
    required this.selected,
    required this.saving,
    required this.enabled,
    required this.onTap,
  });

  final QuiltThemeOption option;
  final bool selected;
  final bool saving;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = option.palette;

    return Material(
      color: selected
          ? colorScheme.primary.withValues(alpha: 0.08)
          : colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: enabled && !selected ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outline.withValues(alpha: 0.55),
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                option.icon,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ThemeSwatches(
                      colors: [
                        palette.accent,
                        palette.gradientStart,
                        palette.gradientEnd,
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              if (saving)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (selected)
                Icon(Icons.check_circle, color: colorScheme.primary)
              else
                Icon(
                  Icons.radio_button_unchecked,
                  color: colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeSwatches extends StatelessWidget {
  const _ThemeSwatches({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final color in colors)
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.45),
              ),
            ),
          ),
      ],
    );
  }
}

class _CalendarIntegrationButtonsState
    extends State<_CalendarIntegrationButtons> {
  bool _connectingGoogle = false;
  bool _connectingApple = false;
  bool _appleConnected = false;

  @override
  void initState() {
    super.initState();
    _loadAppleCalendarState();
  }

  Future<void> _loadAppleCalendarState() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      final connected = await context
          .read<CalendarAccountService>()
          .hasAppleCalendar();
      if (!mounted) return;
      setState(() => _appleConnected = connected);
    } catch (_) {
      // If calendar permission has not been granted yet, the connect button
      // should stay available.
    }
  }

  Future<void> _connectGoogle() async {
    final profileNotifier = context.read<CurrentUserProfileNotifier>();
    final profile = profileNotifier.profile;
    if (profile == null || profileNotifier.isGuestSession) return;

    setState(() => _connectingGoogle = true);
    try {
      await context.read<CalendarAccountService>().connectGoogleCalendar(
        profile,
      );
      await profileNotifier.refresh();
      if (!mounted) return;
      QuiltConfirmation.success(
        context,
        'Google Calendar connected to Quilt Club Events.',
      );
    } catch (e) {
      if (!mounted) return;
      QuiltConfirmation.error(context, 'Could not connect Google Calendar: $e');
    } finally {
      if (mounted) {
        setState(() => _connectingGoogle = false);
      }
    }
  }

  Future<void> _connectApple() async {
    setState(() => _connectingApple = true);
    try {
      await context.read<CalendarAccountService>().connectAppleCalendar();
      if (!mounted) return;
      setState(() => _appleConnected = true);
      QuiltConfirmation.success(
        context,
        'Apple Calendar connected to Quilt Club Events.',
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      final message = switch (e.code) {
        'permissionDenied' =>
          'Calendar access was not granted. You can continue using Quilt without Apple Calendar sync.',
        'calendarUnavailable' => 'No writable Apple Calendar is available.',
        _ => 'Could not connect Apple Calendar.',
      };
      QuiltConfirmation.error(context, message);
    } finally {
      if (mounted) {
        setState(() => _connectingApple = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileNotifier = context.watch<CurrentUserProfileNotifier>();
    final profile = profileNotifier.profile;
    final canEdit = profile != null && !profileNotifier.isGuestSession;
    final googleConnected = (profile?.googleCalendarId ?? '').trim().isNotEmpty;
    final canConnectApple =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: canEdit && !_connectingGoogle ? _connectGoogle : null,
          icon: _connectingGoogle
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  googleConnected
                      ? Icons.check_circle_outline
                      : Icons.calendar_month_outlined,
                ),
          label: Text(
            googleConnected
                ? 'Google Calendar connected'
                : 'Connect Google Calendar',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: canConnectApple && !_connectingApple
              ? _connectApple
              : null,
          icon: _connectingApple
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  _appleConnected
                      ? Icons.check_circle_outline
                      : Icons.event_note_outlined,
                ),
          label: Text(
            canConnectApple
                ? _appleConnected
                      ? 'Apple Calendar connected'
                      : 'Connect Apple Calendar'
                : 'Apple Calendar available on iPhone',
          ),
        ),
      ],
    );
  }
}

class _CalendarAutoUpdatesSwitch extends StatefulWidget {
  const _CalendarAutoUpdatesSwitch();

  @override
  State<_CalendarAutoUpdatesSwitch> createState() =>
      _CalendarAutoUpdatesSwitchState();
}

class _CalendarAutoUpdatesSwitchState
    extends State<_CalendarAutoUpdatesSwitch> {
  bool _saving = false;

  Future<void> _setEnabled(bool enabled) async {
    final profileNotifier = context.read<CurrentUserProfileNotifier>();
    final profile = profileNotifier.profile;
    if (profile == null || profileNotifier.isGuestSession) return;

    setState(() => _saving = true);
    try {
      await context.read<FirebaseService>().saveUserProfile(
        profile.copyWith(autoCalendarUpdatesEnabled: enabled),
      );
      await profileNotifier.refresh();
      if (!mounted) return;
      QuiltConfirmation.success(
        context,
        enabled ? 'Calendar prompts enabled.' : 'Calendar prompts disabled.',
      );
    } catch (e) {
      if (!mounted) return;
      QuiltConfirmation.error(context, 'Could not save setting: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileNotifier = context.watch<CurrentUserProfileNotifier>();
    final profile = profileNotifier.profile;
    final enabled = profile?.autoCalendarUpdatesEnabled ?? false;
    final canEdit = profile != null && !profileNotifier.isGuestSession;

    return SwitchListTile.adaptive(
      value: enabled,
      onChanged: canEdit && !_saving ? _setEnabled : null,
      secondary: _saving
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.event_repeat_outlined),
      title: const Text('Calendar prompts'),
      subtitle: const Text(
        'Automatically open add-to-calendar options after event signups.',
      ),
      contentPadding: EdgeInsets.zero,
    );
  }
}

class _EventSignupNotificationsSwitch extends StatefulWidget {
  const _EventSignupNotificationsSwitch();

  @override
  State<_EventSignupNotificationsSwitch> createState() =>
      _EventSignupNotificationsSwitchState();
}

class _EventSignupNotificationsSwitchState
    extends State<_EventSignupNotificationsSwitch> {
  bool _saving = false;

  Future<void> _setEnabled(bool enabled) async {
    final profileNotifier = context.read<CurrentUserProfileNotifier>();
    final profile = profileNotifier.profile;
    if (profile == null || profileNotifier.isGuestSession) return;

    setState(() => _saving = true);
    try {
      await context.read<FirebaseService>().saveUserProfile(
        profile.copyWith(eventSignupNotificationsEnabled: enabled),
      );
      await profileNotifier.refresh();
      if (!mounted) return;
      QuiltConfirmation.success(
        context,
        enabled
            ? 'Child signup notifications enabled.'
            : 'Child signup notifications disabled.',
      );
    } catch (e) {
      if (!mounted) return;
      QuiltConfirmation.error(context, 'Could not save setting: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileNotifier = context.watch<CurrentUserProfileNotifier>();
    final profile = profileNotifier.profile;
    final enabled = profile?.eventSignupNotificationsEnabled ?? true;
    final canEdit = profile != null && !profileNotifier.isGuestSession;

    return SwitchListTile.adaptive(
      value: enabled,
      onChanged: canEdit && !_saving ? _setEnabled : null,
      secondary: _saving
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.notifications_active_outlined),
      title: const Text('Child event signups'),
      subtitle: const Text(
        'Notify me when a linked child signs up for an event.',
      ),
      contentPadding: EdgeInsets.zero,
    );
  }
}

class _SignOutButton extends StatefulWidget {
  const _SignOutButton();

  @override
  State<_SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends State<_SignOutButton> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    final profileNotifier = context.read<CurrentUserProfileNotifier>();
    final navigator = Navigator.of(context, rootNavigator: true);

    setState(() => _signingOut = true);
    try {
      await profileNotifier.signOut();
      if (!mounted) return;
      navigator.popUntil((route) => route.isFirst);
    } finally {
      if (mounted) {
        setState(() => _signingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _signingOut ? null : _signOut,
        icon: _signingOut
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.logout),
        label: const Text('Log out'),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: theme.colorScheme.surface,
        elevation: 4,
        shadowColor: AppDecorations.shadow(context).withValues(alpha: 0.12),
        surfaceTintColor: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSchoolInfoRow extends StatelessWidget {
  const _SettingsSchoolInfoRow({required this.schoolID});

  final String schoolID;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: context.read<FirebaseService>().getSchoolByID(schoolID),
      builder: (context, snapshot) {
        return _SettingsInfoRow(
          icon: Icons.school_outlined,
          label: 'School',
          value: displaySchoolName(
            schoolID: schoolID,
            schoolName: snapshot.data?.name,
          ),
        );
      },
    );
  }
}

class _SettingsInfoRow extends StatelessWidget {
  const _SettingsInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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

class _BlockedUsersControl extends StatefulWidget {
  const _BlockedUsersControl();

  @override
  State<_BlockedUsersControl> createState() => _BlockedUsersControlState();
}

class _BlockedUsersControlState extends State<_BlockedUsersControl> {
  bool _clearing = false;

  Future<void> _clear() async {
    final notifier = context.read<CurrentUserProfileNotifier>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unblock all authors?'),
        content: const Text(
          'Posts from previously blocked authors will appear again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Unblock all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _clearing = true);
    try {
      await notifier.clearBlockedUsers();
      if (mounted) QuiltConfirmation.success(context, 'Blocked users cleared.');
    } catch (_) {
      if (mounted) {
        QuiltConfirmation.error(context, 'Could not update blocked users.');
      }
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = context.select<CurrentUserProfileNotifier, int>(
      (notifier) => notifier.profile?.blockedUserIds.length ?? 0,
    );
    return OutlinedButton.icon(
      onPressed: count == 0 || _clearing ? null : _clear,
      icon: _clearing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.block_outlined),
      label: Text(count == 0 ? 'No blocked users' : 'Unblock all ($count)'),
    );
  }
}

class _DeleteAccountButton extends StatefulWidget {
  const _DeleteAccountButton();

  @override
  State<_DeleteAccountButton> createState() => _DeleteAccountButtonState();
}

class _DeleteAccountButtonState extends State<_DeleteAccountButton> {
  bool _deleting = false;

  Future<void> _deleteAccount() async {
    final profileNotifier = context.read<CurrentUserProfileNotifier>();
    if (profileNotifier.isUsingDebugProfile) {
      QuiltConfirmation.warning(
        context,
        'Switch to your signed-in account first.',
      );
      return;
    }
    final auth = context.read<AuthService>();
    final navigator = Navigator.of(context, rootNavigator: true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently removes your Quilt profile, sign-in account, authored posts, polls, events, and uploaded profile or post files. Safety reports and school records may be retained only when required for safety, school operations, disputes, or legal obligations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await auth.deleteCurrentAccount();
      if (navigator.mounted) {
        navigator.popUntil((route) => route.isFirst);
      }
      QuiltConfirmation.successMessage('Account deleted.');
    } catch (e) {
      if (!mounted) return;
      debugPrint('Account deletion failed: $e');
      QuiltConfirmation.error(context, auth.friendlyAuthError(e));
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _deleting ? null : _deleteAccount,
        icon: _deleting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.delete_outline),
        label: const Text('Delete account'),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.error,
          side: BorderSide(color: theme.colorScheme.error),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        ),
      ),
    );
  }
}

class _ProfileOverviewCardState extends State<_ProfileOverviewCard> {
  bool _uploading = false;

  Future<void> _changePhoto() async {
    final firebase = context.read<FirebaseService>();
    final picker = context.read<UploadPickerService>();
    final profileNotifier = context.read<CurrentUserProfileNotifier>();
    if (profileNotifier.isUsingDebugProfile) {
      QuiltConfirmation.warning(
        context,
        'Switch to your signed-in account first.',
      );
      return;
    }
    final uid = profileNotifier.profile?.UID;
    if (uid == null) return;

    final picked = await picker.pickSingleImage();
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      await firebase.uploadProfilePicture(uid: uid, image: picked);
      await profileNotifier.refresh();
      if (!mounted) return;
      QuiltConfirmation.success(context, 'Profile photo updated.');
    } catch (e) {
      if (!mounted) return;
      QuiltConfirmation.error(context, 'Could not upload profile photo: $e');
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileNotifier = context.watch<CurrentUserProfileNotifier>();
    final profile = profileNotifier.profile;
    final email = profile?.email ?? '';
    final showSchool = profile?.isCurrentStudent == true;
    final canEditProfilePhoto = !profileNotifier.isGuestSession;

    return Container(
      width: double.infinity,
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
          Stack(
            children: [
              UserPFP(
                uid: profile?.UID,
                displayName: profile?.displayName,
                photoUrl: profile?.pfpURL,
                radius: 34,
              ),
              if (canEditProfilePhoto)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Material(
                    color: theme.colorScheme.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _uploading ? null : _changePhoto,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: _uploading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_outlined,
                                size: 16,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (profile?.displayName ?? '').isNotEmpty
                      ? profile!.displayName
                      : 'Student',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if ((profile?.realName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    profile!.realName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if ((profile?.accountRole ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    profile!.accountRole,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                if ((profile?.accountStatus ?? '').isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: profile?.accountStatus == 'Verified'
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      profile!.accountStatus,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: profile.accountStatus == 'Verified'
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (showSchool)
                  FutureBuilder(
                    future: context.read<FirebaseService>().getSchoolByID(
                      profile!.schoolID,
                    ),
                    builder: (context, snapshot) {
                      final schoolName = displaySchoolName(
                        schoolID: profile.schoolID,
                        schoolName: snapshot.data?.name,
                      );
                      return Text(
                        'School: $schoolName',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
