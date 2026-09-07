import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Models/parent_connection_link.dart';
import '../Providers/current_user_profile_notifier.dart';
import '../Service/auth_service.dart';
import '../Screens/parent_connection_request_dialog.dart';
import 'confirmation_hub.dart';

class ParentConnectionLinkListener extends StatefulWidget {
  const ParentConnectionLinkListener({required this.child, super.key});

  final Widget child;

  @override
  State<ParentConnectionLinkListener> createState() =>
      _ParentConnectionLinkListenerState();
}

class _ParentConnectionLinkListenerState
    extends State<ParentConnectionLinkListener> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  CurrentUserProfileNotifier? _profileNotifier;
  String? _pendingFamilyCode;
  bool _isPresenting = false;
  bool _signInMessageShown = false;
  bool _presentationScheduled = false;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _receiveLink,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Could not receive app link: $error');
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = context.read<CurrentUserProfileNotifier>();
    if (!identical(notifier, _profileNotifier)) {
      _profileNotifier?.removeListener(_profileChanged);
      _profileNotifier = notifier..addListener(_profileChanged);
    }
    _schedulePresentation();
  }

  void _profileChanged() => _schedulePresentation();

  void _receiveLink(Uri uri) {
    final familyCode = ParentConnectionLink.familyCodeFrom(uri.toString());
    if (familyCode == null) {
      _showMessage('This Quilt connection link is invalid.');
      return;
    }

    _pendingFamilyCode = familyCode;
    _signInMessageShown = false;
    _schedulePresentation();
  }

  void _schedulePresentation() {
    if (_presentationScheduled || !mounted) return;
    _presentationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _presentationScheduled = false;
      _presentPendingLink();
    });
  }

  Future<void> _presentPendingLink() async {
    final familyCode = _pendingFamilyCode;
    if (!mounted || familyCode == null || _isPresenting) return;

    final auth = context.read<AuthService>();
    if (auth.currentUser == null) {
      if (!_signInMessageShown) {
        _signInMessageShown = true;
        _showMessage(
          'Sign in with a guardian account to connect to this student.',
        );
      }
      return;
    }

    final profileNotifier = _profileNotifier;
    if (profileNotifier == null || profileNotifier.loading) return;
    final profile = profileNotifier.profile;
    if (profile == null) return;

    _pendingFamilyCode = null;
    if (!profile.isParent) {
      _showMessage('Only guardian accounts can use a student connection link.');
      return;
    }

    _isPresenting = true;
    final requestSent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ParentConnectionRequestDialog(familyCode: familyCode),
    );
    _isPresenting = false;

    if (mounted && requestSent == true) {
      _showMessage('Request sent. Ask the student to scan your QR.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      QuiltConfirmation.warning(context, message);
    });
  }

  @override
  void dispose() {
    _profileNotifier?.removeListener(_profileChanged);
    unawaited(_linkSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
