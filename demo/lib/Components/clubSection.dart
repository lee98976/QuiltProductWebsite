import 'package:flutter/material.dart';

import 'deferred_content.dart';
import '../Models/club.dart';
import '../Screens/clubpage.dart';
import '../Utility/AppSpacing.dart';
import '../Utility/app_decorations.dart';

class ClubSection extends StatelessWidget {
  final ClubInfo club;
  final String schoolID;

  const ClubSection({required this.club, required this.schoolID, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DeferredContent(
                active: true,
                placeholder: const _ClubDetailRoutePlaceholder(),
                child: ClubDetailPage(club: club, schoolID: schoolID),
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
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
              _ClubAvatar(club: club),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      club.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      club.tagline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
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

class _ClubDetailRoutePlaceholder extends StatelessWidget {
  const _ClubDetailRoutePlaceholder();

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

class _ClubAvatar extends StatelessWidget {
  final ClubInfo club;

  const _ClubAvatar({required this.club});

  String getInitials(String text) {
    List<String> cut = text.split(" ");
    String initials = "";
    for (String s in cut) {
      initials += s.substring(0, 1);
    }
    return initials;
  }

  @override
  Widget build(BuildContext context) {
    final textColor =
        ThemeData.estimateBrightnessForColor(club.accentColor) ==
            Brightness.dark
        ? Colors.white
        : Colors.black87;

    return CircleAvatar(
      radius: 30,
      backgroundColor: club.accentColor,
      backgroundImage: club.imageUrl != null
          ? NetworkImage(club.imageUrl!)
          : null,
      child: club.imageUrl == null
          ? Text(
              getInitials(club.title),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}
