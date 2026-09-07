import 'package:flutter/material.dart';

import '../Components/deferred_content.dart';
import '../Utility/AppSpacing.dart';
import '../Utility/app_decorations.dart';
import 'userpage.dart';

class ParentConnectStudentPage extends StatelessWidget {
  const ParentConnectStudentPage({super.key, this.onOpenStudents});

  final VoidCallback? onOpenStudents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Connect with a Student',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: Container(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppDecorations.screenBackground(context),
        child: SafeArea(
          child: DeferredContent(
            active: true,
            delay: const Duration(milliseconds: 140),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPaddingH,
                vertical: AppSpacing.screenPaddingV,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ParentFamilyRequestCard(
                    onOpenStudents: onOpenStudents,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
