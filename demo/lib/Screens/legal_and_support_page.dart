import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Components/confirmation_hub.dart';
import '../Utility/AppSpacing.dart';
import '../Utility/app_decorations.dart';

class LegalAndSupportPage extends StatelessWidget {
  const LegalAndSupportPage({super.key});

  static const supportEmail = 'support@quilt.example';

  Future<void> _contactSupport(BuildContext context) async {
    final opened = await launchUrl(
      Uri(
        scheme: 'mailto',
        path: supportEmail,
        queryParameters: const {'subject': 'Quilt app support'},
      ),
    );
    if (!opened && context.mounted) {
      QuiltConfirmation.warning(context, 'Email support at $supportEmail.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy, safety & support')),
      body: DecoratedBox(
        decoration: AppDecorations.screenBackground(context),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
                children: [
                  Text(
                    'Quilt Privacy Notice',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Effective August 27, 2026',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _LegalSection(
                    title: 'Information Quilt uses',
                    body:
                        'Quilt stores account identifiers, name, email address, optional profile photo, role, school membership, optional student ID, family connections, club activity, event responses, hall-pass activity, posts, attachments, polls, acknowledgements, reports, and notification preferences when you use those features.',
                  ),
                  const _LegalSection(
                    title: 'Why it is used',
                    body:
                        'This information is used only to provide school and club features, authenticate accounts, connect families, show schedules and events, operate safety and moderation tools, and provide support. Quilt does not use this information for advertising or cross-app tracking.',
                  ),
                  const _LegalSection(
                    title: 'Service providers and schools',
                    body:
                        'Quilt uses Google Firebase for authentication, database, and file storage. Google sign-in and optional Google Calendar access are handled by Google. Sign in with Apple is handled by Apple. Authorized school administrators can access school records and moderation reports needed to operate their Quilt community.',
                  ),
                  const _LegalSection(
                    title: 'Camera, photos, and calendars',
                    body:
                        'Camera access is requested only after you open a QR scanner. Photo access occurs only when you choose a photo or attachment. Calendar access is optional and requested only when you choose to connect or save an event. Declining any of these permissions does not prevent use of unrelated features.',
                  ),
                  const _LegalSection(
                    title: 'Retention and deletion',
                    body:
                        'You can delete your Quilt profile, sign-in account, authored posts, polls, events, and uploaded profile or post files in Settings. Safety reports and school records may be retained only when needed for safety, school operations, dispute resolution, or legal obligations. Contact support to request access, correction, or deletion of any remaining personal data.',
                  ),
                  const _LegalSection(
                    title: 'Students and families',
                    body:
                        'Quilt is intended for school communities. Student accounts may require school approval, and parent access requires a connection flow. A parent, guardian, student, or school can contact support with privacy questions or data requests.',
                  ),
                  const Divider(height: AppSpacing.xl * 2),
                  Text(
                    'Community safety rules',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Do not post harassment, threats, hate speech, sexual content, graphic violence, illegal material, spam, impersonation, or someone else’s private information. Only share content you have the right to use. Posts can be reported to school administrators, removed, and used to restrict an account when these rules are violated.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Use Report post for content concerns. Use Block author to hide content from a person. For an urgent safety issue, contact your school or local emergency services; Quilt support is not an emergency service.',
                  ),
                  const Divider(height: AppSpacing.xl * 2),
                  Text(
                    'Support',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SelectableText(supportEmail),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: () => _contactSupport(context),
                    icon: const Icon(Icons.email_outlined),
                    label: const Text('Email Quilt support'),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalSection extends StatelessWidget {
  const _LegalSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(body),
        ],
      ),
    );
  }
}
