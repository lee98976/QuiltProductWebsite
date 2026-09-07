import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../Models/app_notification.dart';
import '../Providers/current_user_profile_notifier.dart';
import '../Service/firebase_service.dart';
import '../Utility/AppSpacing.dart';
import '../Utility/app_decorations.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = context.watch<CurrentUserProfileNotifier>().profile;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: theme.colorScheme.surface,
        ),
        flexibleSpace: Container(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppDecorations.screenBackground(context),
        child: SafeArea(
          child: profile == null
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<List<AppNotification>>(
                  stream: context.read<FirebaseService>().watchNotifications(
                    profile.UID,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final notifications = snapshot.data ?? const [];
                    if (notifications.isEmpty) {
                      return _NotificationEmptyState(theme: theme);
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenPaddingH,
                        AppSpacing.md,
                        AppSpacing.screenPaddingH,
                        AppSpacing.xl * 3,
                      ),
                      itemCount: notifications.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        return _NotificationTile(
                          notification: notifications[index],
                          uid: profile.UID,
                          theme: theme,
                        );
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.uid,
    required this.theme,
  });

  final AppNotification notification;
  final String uid;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final createdAt = notification.createdAt;
    final dateLabel = createdAt == null
        ? ''
        : MaterialLocalizations.of(context).formatShortDate(createdAt);

    return Material(
      color: notification.isUnread
          ? theme.colorScheme.primary.withValues(alpha: 0.08)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: notification.isUnread
            ? () => context.read<FirebaseService>().markNotificationRead(
                uid: uid,
                notificationId: notification.id,
              )
            : null,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: notification.isUnread
                  ? theme.colorScheme.primary.withValues(alpha: 0.28)
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.event_available_outlined,
                color: notification.isUnread
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (dateLabel.isNotEmpty)
                          Text(
                            dateLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('No notifications yet.', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
