import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Models/user.dart';
import '../Providers/current_user_profile_notifier.dart';
import '../Service/auth_service.dart';
import '../Utility/AppSpacing.dart';
import '../Utility/app_decorations.dart';
import '../Components/confirmation_hub.dart';
import '../firebase_options_selector.dart';
import 'debug_account_switcher.dart';
import '../Utility/debug_flags.dart';
import 'signup.dart';
import 'legal_and_support_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isSigningIn = false;
  bool _showReviewerLogin = false;
  final TextEditingController _reviewerEmailController = TextEditingController();
  final TextEditingController _reviewerPasswordController =
      TextEditingController();

  @override
  void dispose() {
    _reviewerEmailController.dispose();
    _reviewerPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitReviewerLogin(
    BuildContext context,
    AuthService auth,
  ) async {
    final email = _reviewerEmailController.text.trim();
    final password = _reviewerPasswordController.text;
    if (email.isEmpty || password.isEmpty) {
      QuiltConfirmation.error(context, 'Enter the demo email and password.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isSigningIn = true);
    try {
      await auth.signIn(email, password);
    } catch (e) {
      if (context.mounted) {
        QuiltConfirmation.error(context, auth.friendlyAuthError(e));
      }
      debugPrint('Reviewer signIn error: $e');
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Widget _reviewerLogin(BuildContext context, AuthService auth) {
    // Google is the only account type real users need; this secondary
    // email/password path exists so App Review (and its automated demo-account
    // check) has a functional username/password to sign in with.
    if (QuiltFirebaseOptions.isDemo) return const SizedBox.shrink();

    final theme = Theme.of(context);

    if (!_showReviewerLogin) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _isSigningIn
              ? null
              : () => setState(() => _showReviewerLogin = true),
          icon: const Icon(Icons.badge_outlined),
          label: const Text('Reviewer & demo sign-in'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Reviewer & demo sign-in',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _reviewerEmailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _reviewerPasswordController,
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitReviewerLogin(context, auth),
          decoration: const InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _isSigningIn
                ? null
                : () => _submitReviewerLogin(context, auth),
            child: _isSigningIn
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sign in'),
          ),
        ),
      ],
    );
  }

  Widget _header(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Welcome to Quilt", style: theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            "Sign in or create the right profile for your visit.",
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _submitButton(BuildContext context, AuthService auth) {
    final isDemoBuild = QuiltFirebaseOptions.isDemo;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: _isSigningIn
            ? null
            : () async {
                setState(() => _isSigningIn = true);
                try {
                  if (isDemoBuild) {
                    await context
                        .read<CurrentUserProfileNotifier>()
                        .startDemoSession();
                  } else {
                    await auth.signInWithGoogle();
                  }
                } catch (e) {
                  if (context.mounted) {
                    QuiltConfirmation.error(context, auth.friendlyAuthError(e));
                  }
                  debugPrint('Google signIn error: $e');
                } finally {
                  if (mounted) setState(() => _isSigningIn = false);
                }
              },
        child: _isSigningIn
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


  Widget _missingProfileNotice(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Sign-in worked, but this account does not have a Quilt profile yet. Create one below or switch accounts.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _isSigningIn
                ? null
                : () async {
                    setState(() => _isSigningIn = true);
                    try {
                      await context
                          .read<CurrentUserProfileNotifier>()
                          .signOut();
                    } finally {
                      if (mounted) setState(() => _isSigningIn = false);
                    }
                  },
            icon: const Icon(Icons.logout),
            label: const Text('Switch account'),
          ),
        ],
      ),
    );
  }

  Widget _debugAccountsButton(BuildContext context, AuthService auth) {
    if (!kShowDebugTools) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: _isSigningIn
              ? null
              : () async {
                  setState(() => _isSigningIn = true);
                  try {
                    await showDebugAccountSwitcher(context, signInFirst: true);
                  } catch (e) {
                    if (context.mounted) {
                      QuiltConfirmation.error(
                        context,
                        auth.friendlyAuthError(e),
                      );
                    }
                    debugPrint('Debug fake account signIn error: $e');
                  } finally {
                    if (mounted) setState(() => _isSigningIn = false);
                  }
                },
          icon: const Icon(Icons.bug_report_outlined),
          label: const Text('Use fake debug account'),
        ),
      ],
    );
  }

  Widget _switchToSignUp(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "New users",
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _newProfileOption(
          context,
          icon: Icons.school_outlined,
          title: "Current student",
          subtitle: "Needs administrator approval",
          role: UserProfile.currentStudentRole,
        ),
        const SizedBox(height: AppSpacing.sm),
        _newProfileOption(
          context,
          icon: Icons.family_restroom_outlined,
          title: "Parent",
          subtitle: "View-only club access",
          role: UserProfile.parentRole,
        ),
        const SizedBox(height: AppSpacing.sm),
        _newProfileOption(
          context,
          icon: Icons.explore_outlined,
          title: "Prospective student",
          subtitle: "Browse schools without an account",
          role: UserProfile.prospectiveStudentRole,
          onPressed: () {
            context
                .read<CurrentUserProfileNotifier>()
                .startProspectiveGuestSession();
          },
        ),
      ],
    );
  }

  Widget _newProfileOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String role,
    VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);

    return OutlinedButton(
      onPressed:
          onPressed ??
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SignUpPage(initialRole: role),
              ),
            );
          },
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(AppSpacing.md),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final theme = Theme.of(context);
    final profileState = context
        .select<
          CurrentUserProfileNotifier,
          ({bool hasLoadError, bool hasProfile, bool loading})
        >(
          (notifier) => (
            hasLoadError: notifier.loadError != null,
            hasProfile: notifier.profile != null,
            loading: notifier.loading,
          ),
        );
    final signedInWithoutProfile =
        auth.currentUser != null &&
        !profileState.loading &&
        !profileState.hasProfile &&
        !profileState.hasLoadError;

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
                          if (signedInWithoutProfile)
                            _missingProfileNotice(context),
                          Text(
                            "Returning users",
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _submitButton(context, auth),
                          _debugAccountsButton(context, auth),
                          _reviewerLogin(context, auth),
                          const SizedBox(height: AppSpacing.xl),
                          _switchToSignUp(context, theme),
                          const SizedBox(height: AppSpacing.md),
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const LegalAndSupportPage(),
                              ),
                            ),
                            icon: const Icon(Icons.privacy_tip_outlined),
                            label: const Text('Privacy, safety & support'),
                          ),
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
