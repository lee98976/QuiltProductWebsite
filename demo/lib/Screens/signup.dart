import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Models/user.dart';
import '../Components/confirmation_hub.dart';
import '../Providers/current_user_profile_notifier.dart';
import '../Service/auth_service.dart';
import '../Utility/AppColors.dart';
import '../Utility/AppSpacing.dart';
import '../Utility/app_decorations.dart';
import '../firebase_options_selector.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key, this.initialRole});

  final String? initialRole;

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController studentIdController = TextEditingController();
  late String _accountRole;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _accountRole = widget.initialRole ?? UserProfile.currentStudentRole;
  }

  @override
  void dispose() {
    studentIdController.dispose();
    super.dispose();
  }

  Widget _header(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Create profile", style: theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            "Choose how you will use Quilt, then continue with Google.",
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _roleField() {
    final selectedOption = _roleOptions.firstWhere(
      (option) => option.role == _accountRole,
      orElse: () => _roleOptions.first,
    );
    final menuWidth =
        MediaQuery.of(context).size.width -
        (AppSpacing.screenPaddingH * 2) -
        (AppSpacing.cardPadding * 2);

    return PopupMenuButton<String>(
      enabled: !_isSubmitting,
      initialValue: _accountRole,
      position: PopupMenuPosition.under,
      offset: const Offset(0, AppSpacing.xs),
      color: Theme.of(context).colorScheme.surface,
      elevation: 14,
      shadowColor: AppDecorations.shadow(context).withValues(alpha: 0.18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      constraints: BoxConstraints.tightFor(
        width: menuWidth.clamp(280.0, 420.0),
      ),
      onSelected: (value) => setState(() => _accountRole = value),
      itemBuilder: (context) {
        return _roleOptions.map((option) {
          return PopupMenuItem<String>(
            value: option.role,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: 4,
            ),
            child: _RoleMenuItem(
              option: option,
              isSelected: option.role == _accountRole,
            ),
          );
        }).toList();
      },
      child: _RoleSelectorField(
        option: selectedOption,
        isEnabled: !_isSubmitting,
      ),
    );
  }

  Widget _studentIdField() {
    if (_accountRole != UserProfile.currentStudentRole) {
      return const SizedBox.shrink();
    }

    return TextField(
      decoration: const InputDecoration(
        hintText: "Optional",
        labelText: "Student ID number",
        prefixIcon: Icon(Icons.badge_outlined, size: 22),
      ),
      controller: studentIdController,
      keyboardType: TextInputType.text,
    );
  }

  Widget _submitButton(AuthService auth) {
    final isDemoBuild = QuiltFirebaseOptions.isDemo;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: _isSubmitting
            ? null
            : () async {
                final nav = Navigator.of(context);
                final profileNotifier = context
                    .read<CurrentUserProfileNotifier>();
                final studentId = studentIdController.text.trim();

                setState(() => _isSubmitting = true);
                try {
                  if (isDemoBuild) {
                    await profileNotifier.startDemoSession();
                  } else {
                    await auth.signUpWithGoogle(
                      accountRole: _accountRole,
                      studentId: studentId,
                    );
                    await profileNotifier.refresh();
                  }

                  if (!context.mounted) return;
                  nav.pop();
                } catch (e) {
                  if (!mounted) return;
                  QuiltConfirmation.error(context, auth.friendlyAuthError(e));
                  debugPrint('Google signUp error: $e');
                } finally {
                  if (mounted) {
                    setState(() => _isSubmitting = false);
                  }
                }
              },
        child: _isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.account_circle_outlined),
                  const SizedBox(width: 8),
                  Text(
                    isDemoBuild ? 'Enter safe demo' : 'Continue with Google',
                  ),
                ],
              ),
      ),
    );
  }


  Widget _switchToLogin(ThemeData theme) {
    return TextButton(
      onPressed: () => Navigator.pop(context),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodySmall,
          children: [
            const TextSpan(text: "Already have an account? "),
            TextSpan(
              text: "Log in",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppDecorations.screenBackground(context),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingH,
              vertical: AppSpacing.screenPaddingV,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    _header(theme),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.cardPadding),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppDecorations.shadow(
                              context,
                            ).withValues(alpha: 0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _roleField(),
                          if (_accountRole ==
                              UserProfile.currentStudentRole) ...[
                            const SizedBox(height: AppSpacing.md),
                            _studentIdField(),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                          _submitButton(auth),
                          const SizedBox(height: AppSpacing.md),
                          _switchToLogin(theme),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const List<_RoleOption> _roleOptions = [
  _RoleOption(
    role: UserProfile.currentStudentRole,
    title: "Current student",
    subtitle: "Join your school with full student access",
    icon: Icons.school_outlined,
  ),
  _RoleOption(
    role: UserProfile.parentRole,
    title: "Parent",
    subtitle: "Follow school activity with view-only access",
    icon: Icons.family_restroom_outlined,
  ),
];

class _RoleOption {
  const _RoleOption({
    required this.role,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String role;
  final String title;
  final String subtitle;
  final IconData icon;
}

class _RoleSelectorField extends StatelessWidget {
  const _RoleSelectorField({required this.option, required this.isEnabled});

  final _RoleOption option;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = isEnabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withValues(alpha: 0.48);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: isEnabled ? 1 : 0.62,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(option.icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Account type",
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    option.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.keyboard_arrow_down_rounded, color: foreground),
          ],
        ),
      ),
    );
  }
}

class _RoleMenuItem extends StatelessWidget {
  const _RoleMenuItem({required this.option, required this.isSelected});

  final _RoleOption option;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary
                  : AppColors.inputFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              option.icon,
              size: 21,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  option.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: isSelected ? 1 : 0,
            child: Icon(
              Icons.check_circle_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
