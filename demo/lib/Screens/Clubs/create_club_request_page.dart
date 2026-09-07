import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Models/club_request.dart';
import '../../Components/confirmation_hub.dart';
import '../../Service/auth_service.dart';
import '../../Service/firebase_service.dart';
import '../../Utility/AppSpacing.dart';

class CreateClubRequestPage extends StatefulWidget {
  const CreateClubRequestPage({required this.schoolID, super.key});

  final String schoolID;

  @override
  State<CreateClubRequestPage> createState() => _CreateClubRequestPageState();
}

class _CreateClubRequestPageState extends State<CreateClubRequestPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _meetingTimeController = TextEditingController();
  final _locationController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _meetingTimeController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final desc = _descriptionController.text.trim();
    final time = _meetingTimeController.text.trim();
    final loc = _locationController.text.trim();

    if (title.isEmpty || desc.isEmpty) {
      QuiltConfirmation.warning(
        context,
        'Please fill in title and description.',
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final auth = context.read<AuthService>();
      final firebase = context.read<FirebaseService>();
      final user = auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      final profile = await firebase.getUser(user.uid);
      final applicantName =
          profile?.displayName ?? profile?.realName ?? 'Unknown';

      final request = ClubRequest(
        id: '',
        applicantId: user.uid,
        applicantName: applicantName,
        title: title,
        description: desc,
        meetingTime: time,
        location: loc,
        createdAt: DateTime.now(),
      );

      await firebase.submitClubRequest(widget.schoolID, request);

      if (mounted) {
        Navigator.of(context).pop();
        QuiltConfirmation.success(
          context,
          'Club request submitted! An admin will review it.',
        );
      }
    } catch (e) {
      if (mounted) {
        QuiltConfirmation.error(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request a Club'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Club Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _meetingTimeController,
              decoration: const InputDecoration(
                labelText: 'Meeting Time (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const CircularProgressIndicator()
                  : const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
  }
}
