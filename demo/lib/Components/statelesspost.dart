import 'package:flutter/material.dart';
import '../Utility/AppSpacing.dart';
import '../Utility/app_decorations.dart';
import '../Components/userPFP.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

class Post extends StatelessWidget {
  final String postTitle;
  final String postTime;
  final String postOwner;
  final String postDescription;

  const Post({
    this.postTitle = "Orz",
    this.postTime = "10:10 PM",
    this.postOwner = "John Doe",
    this.postDescription =
        "Lorem ipsum dolor sit amet consectetur adipiscing "
        "elit quisque convallis tempus leo eu aenean sed diam urna tempor pul"
        "vinar vivamus fringilla lacus nec metus bibendum egestas iaculis mass"
        "a nisl malesuada lacinia integer nunc posuere ut hendrerit semper vel"
        " class aptent taciti sociosqu ad litora torquent per conubia nostra i"
        "nceptos himenaeos orci varius natoque penatibus",
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppDecorations.shadow(context).withValues(alpha: 0.08),
            blurRadius: 36,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserPFP(),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      postTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      postTime,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Linkify(
            onOpen: (link) async {
              final uri = Uri.tryParse(link.url);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            text: postDescription,
            options: const LinkifyOptions(humanize: false),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            linkStyle: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }
}
