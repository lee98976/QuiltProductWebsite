import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Models/club.dart';
import '../Providers/current_user_profile_notifier.dart';
import 'confirmation_hub.dart';

Future<void> blockPostAuthor(
  BuildContext context, {
  required ClubPostEntry post,
}) async {
  final notifier = context.read<CurrentUserProfileNotifier>();
  final profile = notifier.profile;
  if (profile == null ||
      post.authorId.isEmpty ||
      post.authorId == profile.UID) {
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Block this author?'),
      content: Text(
        'Posts from ${post.authorName.isEmpty ? 'this author' : post.authorName} will be hidden from you. You can clear blocked users in Settings.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Block author'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await notifier.blockUser(post.authorId);
    if (context.mounted) {
      QuiltConfirmation.success(context, 'Author blocked.');
    }
  } catch (_) {
    if (context.mounted) {
      QuiltConfirmation.error(context, 'Could not block this author.');
    }
  }
}
