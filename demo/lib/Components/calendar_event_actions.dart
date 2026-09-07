import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Models/platform_event.dart';
import '../Providers/current_user_profile_notifier.dart';
import '../Service/calendar_account_service.dart';
import '../Utility/AppSpacing.dart';
import '../Utility/calendar_links.dart';
import 'confirmation_hub.dart';

class CalendarEventActions extends StatelessWidget {
  const CalendarEventActions({required this.event, super.key});

  final PlatformEvent event;

  static void showCalendarOptions(BuildContext context, PlatformEvent event) {
    _showCalendarSheet(context, event);
  }

  static Future<void> promptAutomaticCalendarAdd(
    BuildContext context,
    PlatformEvent event,
  ) async {
    if (!context.mounted) return;
    final add = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add event to calendar?'),
          content: Text(
            'Open calendar options for ${event.title.trim().isNotEmpty ? event.title.trim() : 'this event'}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Not now'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.calendar_today_outlined),
              label: const Text('Open options'),
            ),
          ],
        );
      },
    );
    if (add == true && context.mounted) {
      showCalendarOptions(context, event);
    }
  }

  static Future<void> _addToGoogleCalendar(
    BuildContext context,
    PlatformEvent event,
  ) async {
    final profileNotifier = context.read<CurrentUserProfileNotifier>();
    final profile = profileNotifier.profile;
    if (profile == null || profileNotifier.isGuestSession) {
      QuiltConfirmation.show(context, 'Sign in before connecting a calendar.');
      return;
    }

    try {
      await context.read<CalendarAccountService>().addEventToGoogleCalendar(
        profile,
        event,
        promptIfNecessary: true,
      );
      if (!context.mounted) return;
      QuiltConfirmation.success(
        context,
        'Event added to Quilt Club Events in Google Calendar.',
      );
    } catch (e) {
      if (!context.mounted) return;
      QuiltConfirmation.error(context, 'Could not update Google Calendar: $e');
    }
  }

  static Future<void> _openUri(
    BuildContext context,
    Uri uri,
    String errorText,
  ) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      QuiltConfirmation.error(context, errorText);
    }
  }

  static Future<void> _addAppleOrExport(
    BuildContext context,
    PlatformEvent event,
  ) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await _addToAppleCalendar(context, event);
      return;
    }
    await _openUri(
      context,
      CalendarLinks.icsDataUri(event),
      'Could not open calendar export.',
    );
  }

  static Future<void> _addToAppleCalendar(
    BuildContext context,
    PlatformEvent event,
  ) async {
    try {
      await context.read<CalendarAccountService>().addEventToAppleCalendar(
        event,
      );
      if (!context.mounted) return;
      QuiltConfirmation.success(
        context,
        'Event added to Quilt Club Events in Apple Calendar.',
      );
    } on PlatformException catch (e) {
      if (!context.mounted) return;
      final message = switch (e.code) {
        'permissionDenied' =>
          'Calendar access was not granted. You can continue using Quilt without adding this event to Apple Calendar.',
        'calendarUnavailable' => 'Apple Calendar is not available.',
        _ => 'Could not add event to Apple Calendar.',
      };
      QuiltConfirmation.error(context, message);
    }
  }

  static void _showCalendarSheet(BuildContext context, PlatformEvent event) {
    final usesNativeAppleCalendar =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('Google Calendar'),
                  subtitle: const Text('Save to Quilt Club Events'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _addToGoogleCalendar(context, event);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.event_note_outlined),
                  title: Text(
                    usesNativeAppleCalendar
                        ? 'Apple Calendar'
                        : 'Apple or Outlook Calendar',
                  ),
                  subtitle: Text(
                    usesNativeAppleCalendar
                        ? 'Add directly to your calendar'
                        : 'Export as an .ics calendar event',
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _addAppleOrExport(context, event);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _showCalendarSheet(context, event),
      icon: const Icon(Icons.calendar_today_outlined),
      label: const Text('Add to calendar'),
    );
  }
}
