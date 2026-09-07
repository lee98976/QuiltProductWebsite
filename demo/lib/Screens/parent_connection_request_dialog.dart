import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Models/user.dart';
import '../Providers/current_user_profile_notifier.dart';
import '../Service/firebase_service.dart';
import '../Utility/AppSpacing.dart';

class ParentConnectionRequestDialog extends StatefulWidget {
  const ParentConnectionRequestDialog({required this.familyCode, super.key});

  final String familyCode;

  @override
  State<ParentConnectionRequestDialog> createState() =>
      _ParentConnectionRequestDialogState();
}

class _ParentConnectionRequestDialogState
    extends State<ParentConnectionRequestDialog> {
  static const List<String> _studentRelationshipOptions = [
    'Child',
    'Son',
    'Daughter',
    'Stepchild',
    'Ward',
    'Student',
    'Other',
  ];

  String _relationship = _studentRelationshipOptions.first;
  late final Future<UserProfile?> _studentFuture;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _studentFuture = context.read<FirebaseService>().findStudentByFamilyCode(
      widget.familyCode,
    );
  }

  Future<void> _submit() async {
    final parent = context.read<CurrentUserProfileNotifier>().profile;
    if (parent == null || !parent.isParent) {
      setState(() => _error = 'Sign in with a parent account to continue.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<FirebaseService>().submitParentRequest(
        parent: parent,
        familyCode: widget.familyCode,
        relationship: _relationship,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Bad state: ', '');
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      icon: Icon(Icons.family_restroom, color: theme.colorScheme.primary),
      title: const Text('Connect to student'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FutureBuilder<UserProfile?>(
                future: _studentFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LinearProgressIndicator();
                  }
                  final student = snapshot.data;
                  if (snapshot.hasError || student == null) {
                    return Text(
                      'This connection QR code is no longer valid.',
                      style: TextStyle(color: theme.colorScheme.error),
                    );
                  }
                  final name = student.realName.trim().isNotEmpty
                      ? student.realName.trim()
                      : student.displayName.trim();
                  return Text(
                    'Choose who $name is to you. They will scan your pending request QR to finish the connection.',
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _relationship,
                borderRadius: BorderRadius.circular(18),
                items: _studentRelationshipOptions
                    .map(
                      (relationship) => DropdownMenuItem(
                        value: relationship,
                        child: Text(relationship),
                      ),
                    )
                    .toList(),
                onChanged: _submitting
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _relationship = value);
                        }
                      },
                decoration: const InputDecoration(
                  labelText: 'Relationship',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
          label: const Text('Send request'),
        ),
      ],
    );
  }
}
