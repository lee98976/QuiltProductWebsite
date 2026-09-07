import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../Models/club.dart';
import '../../Models/platform_event.dart';
import '../../Utility/AppSpacing.dart';

class ClubQrGeneratorPage extends StatelessWidget {
  const ClubQrGeneratorPage({required this.club, super.key});

  final ClubInfo club;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final dateStr = '${today.year}-${today.month}-${today.day}';

    // Format: quilt_club_attendance:{clubId}:{date}
    final qrData = 'quilt_club_attendance:${club.id}:$dateStr';

    return Scaffold(
      appBar: AppBar(
        title: Text('${club.title} Attendance'),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Scan to check in!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 280.0,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(color: Colors.black),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Date: $dateStr',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EventQrGeneratorPage extends StatelessWidget {
  const EventQrGeneratorPage({
    required this.club,
    required this.event,
    super.key,
  });

  final ClubInfo club;
  final PlatformEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateText = MaterialLocalizations.of(
      context,
    ).formatFullDate(event.startTime);
    final timeText = TimeOfDay.fromDateTime(event.startTime).format(context);
    final qrData = 'EVENT:${club.id}:${event.id}';

    return Scaffold(
      appBar: AppBar(
        title: Text('${event.title} Check-in'),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                event.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${club.title} · $dateText at $timeText',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 280.0,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(color: Colors.black),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Students scan this from Events or Clubs to check in.',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
