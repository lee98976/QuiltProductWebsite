import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Providers/current_user_profile_notifier.dart';

class UserPFP extends StatelessWidget {
  const UserPFP({
    super.key,
    this.uid,
    this.displayName,
    this.photoUrl,
    this.radius = 23,
  });

  final String? uid;
  final String? displayName;
  final String? photoUrl;
  final double radius;

  Color _avatarColor(String seed) {
    final hash = seed.hashCode;
    const colors = [
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
    ];

    return colors[hash.abs() % colors.length];
  }

  String _initials(String text) {
    final parts = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) return '?';
    return parts.map((part) => part[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<CurrentUserProfileNotifier>().profile;
    final resolvedUid = uid ?? profile?.UID ?? 'guest';
    final resolvedName =
        displayName ?? profile?.displayName ?? profile?.realName ?? 'User';
    final resolvedPhoto = photoUrl ?? profile?.pfpURL;

    return CircleAvatar(
      radius: radius,
      backgroundColor: _avatarColor(resolvedUid),
      backgroundImage: resolvedPhoto != null && resolvedPhoto.isNotEmpty
          ? NetworkImage(resolvedPhoto)
          : null,
      child: resolvedPhoto == null || resolvedPhoto.isEmpty
          ? Text(
              _initials(resolvedName),
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.75,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}
