import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Models/club.dart';
import '../Providers/current_user_profile_notifier.dart';
import '../Service/firebase_service.dart';
import '../Utility/AppSpacing.dart';
import 'confirmation_hub.dart';

const List<String> _reportReasons = [
  'Bullying or harassment',
  'Hate speech',
  'Threats or violence',
  'Spam or misleading content',
  'Inappropriate content',
  'Other',
];

Future<void> showReportPostSheet(
  BuildContext context, {
  required ClubPostEntry post,
  required String schoolID,
  required String clubID,
  String clubTitle = '',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReportPostSheet(
      post: post,
      schoolID: schoolID,
      clubID: clubID,
      clubTitle: clubTitle,
    ),
  );
}

class _ReportPostSheet extends StatefulWidget {
  const _ReportPostSheet({
    required this.post,
    required this.schoolID,
    required this.clubID,
    required this.clubTitle,
  });

  final ClubPostEntry post;
  final String schoolID;
  final String clubID;
  final String clubTitle;

  @override
  State<_ReportPostSheet> createState() => _ReportPostSheetState();
}

class _ReportPostSheetState extends State<_ReportPostSheet> {
  final TextEditingController _detailsController = TextEditingController();
  String _reason = _reportReasons.first;
  bool _submitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final profile = context.read<CurrentUserProfileNotifier>().profile;
    if (profile == null) {
      QuiltConfirmation.warning(context, 'Sign in before reporting a post.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await context.read<FirebaseService>().reportPost(
        schoolID: widget.schoolID,
        clubID: widget.clubID,
        clubTitle: widget.clubTitle,
        post: widget.post,
        reporter: profile,
        reason: _reason,
        details: _detailsController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      QuiltConfirmation.success(
        context,
        'Report sent to school administrators.',
      );
    } catch (e) {
      if (!mounted) return;
      QuiltConfirmation.error(context, 'Could not send report: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenPaddingH,
          AppSpacing.sm,
          AppSpacing.screenPaddingH,
          bottomInset + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report post',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.post.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _reason,
              borderRadius: BorderRadius.circular(18),
              decoration: const InputDecoration(labelText: 'Reason'),
              items: _reportReasons
                  .map(
                    (reason) =>
                        DropdownMenuItem(value: reason, child: Text(reason)),
                  )
                  .toList(),
              onChanged: _submitting
                  ? null
                  : (value) => setState(() => _reason = value ?? _reason),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _detailsController,
              enabled: !_submitting,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Details',
                hintText: 'Add context for administrators.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.flag_outlined),
                label: const Text('Submit report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
