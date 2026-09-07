import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../Models/club.dart';
import '../Utility/AppSpacing.dart';
import 'userPFP.dart';

class PostAcknowledgementRow extends StatelessWidget {
  const PostAcknowledgementRow({
    super.key,
    required this.post,
    required this.currentUserID,
    required this.isLoading,
    required this.onConfirm,
    required this.onShowAll,
    this.canConfirm = true,
  });

  final ClubPostEntry post;
  final String currentUserID;
  final bool isLoading;
  final VoidCallback onConfirm;
  final VoidCallback onShowAll;
  final bool canConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final acknowledged = post.acknowledgedBy(currentUserID);
    final names = post.acknowledgements
        .map((acknowledgement) => acknowledgement.displayName)
        .where((name) => name.trim().isNotEmpty)
        .join(', ');

    return Row(
      children: [
        SizedBox.square(
          dimension: 34,
          child: IconButton(
            tooltip: acknowledged
                ? 'You acknowledged this post'
                : canConfirm
                ? 'Acknowledge post'
                : 'Only club members can acknowledge posts',
            onPressed: !canConfirm || acknowledged || isLoading
                ? null
                : onConfirm,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            icon: isLoading
                ? SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : Icon(
                    acknowledged
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                    size: 24,
                    color: acknowledged
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: InkWell(
            onTap: onShowAll,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                names.isEmpty ? 'No acknowledgements yet' : names,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: names.isEmpty
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurface,
                  fontWeight: names.isEmpty ? FontWeight.w500 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> showPostAcknowledgementsDialog(
  BuildContext context,
  ClubPostEntry post,
) {
  final acknowledgements = post.acknowledgements;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);

      return AlertDialog(
        title: const Text('Acknowledgements'),
        content: SizedBox(
          width: double.maxFinite,
          child: acknowledgements.isEmpty
              ? const Text('No one has acknowledged this post yet.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: acknowledgements.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final acknowledgement = acknowledgements[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: UserPFP(
                        uid: acknowledgement.uid,
                        displayName: acknowledgement.displayName,
                        photoUrl: acknowledgement.photoUrl,
                        radius: 18,
                      ),
                      title: Text(
                        acknowledgement.displayName.isNotEmpty
                            ? acknowledgement.displayName
                            : 'Member',
                      ),
                      subtitle: Text(
                        DateFormat.yMMMd().add_jm().format(
                          acknowledgement.acknowledgedAt,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
