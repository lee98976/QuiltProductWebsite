import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Components/confirmation_hub.dart';
import '../../Models/club.dart';
import '../../Models/poll.dart';
import '../../Providers/current_user_profile_notifier.dart';
import '../../Service/auth_service.dart';
import '../../Service/firebase_service.dart';
import '../../Utility/AppSpacing.dart';
import '../../Utility/app_decorations.dart';

Future<void> showCreatePollDialog(
  BuildContext context, {
  required ClubInfo club,
  required String schoolID,
  bool canChangeVisibility = false,
}) {
  return showDialog(
    context: context,
    builder: (_) => _CreatePollDialog(
      club: club,
      schoolID: schoolID,
      canChangeVisibility: canChangeVisibility,
    ),
  );
}

class PollsTab extends StatelessWidget {
  const PollsTab({
    required this.club,
    required this.schoolID,
    this.publicOnly = false,
    this.schoolVisibleOnly = false,
    this.canModerate = false,
    super.key,
  });

  final ClubInfo club;
  final String schoolID;
  final bool publicOnly;
  final bool schoolVisibleOnly;
  final bool canModerate;

  @override
  Widget build(BuildContext context) {
    final firebase = context.read<FirebaseService>();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: StreamBuilder<List<ClubPoll>>(
            stream: publicOnly
                ? firebase.getPublicPolls(schoolID, club.id)
                : schoolVisibleOnly
                ? firebase.getSchoolVisiblePolls(schoolID, club.id)
                : firebase.getPolls(schoolID, club.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final polls = snapshot.data ?? [];

              if (polls.isEmpty) {
                return Center(
                  child: Text(
                    'No active polls yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.only(
                  top: AppSpacing.sm,
                  bottom: AppSpacing.xl * 3,
                ),
                itemCount: polls.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) => PollCard(
                  poll: polls[i],
                  schoolID: schoolID,
                  clubID: club.id,
                  isSchoolPoll: false,
                  readOnly: publicOnly,
                  canModerate: canModerate,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class PollCard extends StatefulWidget {
  const PollCard({
    required this.poll,
    required this.schoolID,
    this.clubID,
    this.isSchoolPoll = false,
    this.readOnly = false,
    this.canModerate = false,
    super.key,
  });

  final ClubPoll poll;
  final String schoolID;
  final String? clubID;
  final bool isSchoolPoll;
  final bool readOnly;
  final bool canModerate;

  @override
  State<PollCard> createState() => PollCardState();
}

class PollCardState extends State<PollCard> {
  final List<String> _selectedOptions = [];
  final List<String> _unselectedRanked = [];
  final List<String> _ranked = [];

  @override
  void initState() {
    super.initState();
    if (widget.poll.pollType == PollType.ranked_choice) {
      _unselectedRanked.addAll(widget.poll.options);
    }
  }

  void _submitVote(String uid) async {
    final firebase = context.read<FirebaseService>();
    final profileNotifier = context.read<CurrentUserProfileNotifier>();
    dynamic voteData;
    if (widget.poll.pollType == PollType.single_choice) {
      if (_selectedOptions.isEmpty) return;
      voteData = _selectedOptions.first;
    } else if (widget.poll.pollType == PollType.multiple_choice) {
      if (_selectedOptions.isEmpty) return;
      voteData = _selectedOptions;
    } else {
      if (_ranked.isEmpty) return;
      voteData = _ranked;
    }

    try {
      if (widget.isSchoolPoll) {
        await firebase.castSchoolVote(
          widget.schoolID,
          widget.poll.id,
          uid,
          voteData,
        );
      } else {
        await firebase.castVote(
          widget.schoolID,
          widget.clubID!,
          widget.poll.id,
          uid,
          voteData,
        );
      }
      if (mounted) {
        await profileNotifier.refresh();
      }
      if (mounted) {
        QuiltConfirmation.success(context, 'Vote cast!');
      }
    } catch (e) {
      if (mounted) {
        QuiltConfirmation.error(context, 'Failed: $e');
      }
    }
  }

  Future<void> _deletePoll() async {
    final firebase = context.read<FirebaseService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete poll?'),
        content: Text('This removes "${widget.poll.title}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || widget.clubID == null) return;

    try {
      await firebase.deletePoll(
        widget.schoolID,
        widget.clubID!,
        widget.poll.id,
      );
      if (!mounted) return;
      QuiltConfirmation.success(context, 'Poll deleted.');
    } catch (e) {
      if (!mounted) return;
      QuiltConfirmation.error(context, 'Could not delete poll: $e');
    }
  }

  Widget _buildRankedChoiceEditor(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= 560;
        final candidates = _buildRankedCandidateList(theme);
        final ranking = _buildRankingList(theme);

        if (!useTwoColumns) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              candidates,
              const SizedBox(height: AppSpacing.md),
              ranking,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: candidates),
            const SizedBox(width: AppSpacing.md),
            Expanded(flex: 3, child: ranking),
          ],
        );
      },
    );
  }

  Widget _buildRankedCandidateList(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Candidates', style: theme.textTheme.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        if (_unselectedRanked.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              'All candidates ranked.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final opt in _unselectedRanked)
          Card(
            margin: const EdgeInsets.only(bottom: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() {
                _unselectedRanked.remove(opt);
                _ranked.add(opt);
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(opt, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRankingList(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Your Ranking', style: theme.textTheme.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        if (_ranked.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              'Rank candidates here.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ReorderableListView.builder(
          buildDefaultDragHandles: false,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _ranked.length,
          onReorderItem: (oldIdx, newIdx) {
            setState(() {
              final item = _ranked.removeAt(oldIdx);
              _ranked.insert(newIdx, item);
            });
          },
          itemBuilder: (context, idx) {
            final opt = _ranked[idx];
            return Card(
              key: ValueKey(opt),
              margin: const EdgeInsets.only(bottom: 4),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${idx + 1}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        opt,
                        style: theme.textTheme.bodyMedium,
                        softWrap: true,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove from ranking',
                      icon: const Icon(Icons.remove_circle_outline),
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 36,
                      ),
                      onPressed: () => setState(() {
                        _ranked.remove(opt);
                        _unselectedRanked.add(opt);
                      }),
                    ),
                    ReorderableDragStartListener(
                      index: idx,
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(
                          Icons.drag_handle,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthService>();
    final uid = auth.currentUser?.uid;
    final canParticipate =
        !widget.readOnly &&
        (context.watch<CurrentUserProfileNotifier>().profile?.canParticipate ??
            false);
    final hasVoted = uid != null && widget.poll.votes.containsKey(uid);
    final totalVotes = widget.poll.votes.length;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.poll.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (widget.canModerate && !widget.isSchoolPoll)
                PopupMenuButton<String>(
                  tooltip: 'Poll actions',
                  onSelected: (value) {
                    if (value == 'delete') _deletePoll();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Delete poll'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (widget.poll.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(widget.poll.description, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.md),
          if (hasVoted)
            if (widget.poll.pollType == PollType.ranked_choice)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.how_to_vote,
                      color: theme.colorScheme.primary,
                      size: 32,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Your vote has been recorded!',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...widget.poll.options.map((opt) {
                double count = 0.0;
                if (widget.poll.pollType == PollType.single_choice) {
                  count = widget.poll.votes.values
                      .where((v) => v == opt)
                      .length
                      .toDouble();
                } else if (widget.poll.pollType == PollType.multiple_choice) {
                  count = widget.poll.votes.values
                      .where((v) => v is List && v.contains(opt))
                      .length
                      .toDouble();
                } else {
                  // Borda count approximation
                  int maxPoints = widget.poll.options.length;
                  for (var v in widget.poll.votes.values) {
                    if (v is List) {
                      final idx = v.indexOf(opt);
                      if (idx != -1) count += (maxPoints - idx);
                    }
                  }
                  // Normalize pct against total possible points
                }
                final maxPossibleScore =
                    widget.poll.pollType == PollType.ranked_choice
                    ? totalVotes * widget.poll.options.length
                    : totalVotes;

                final pct = maxPossibleScore == 0
                    ? 0.0
                    : count / maxPossibleScore;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Stack(
                    children: [
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: pct,
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                opt,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${(pct * 100).toStringAsFixed(0)}%',
                                style: theme.textTheme.labelMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          if (!hasVoted && !canParticipate) ...[
            ...widget.poll.options.map(
              (opt) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(opt, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'View-only accounts can read polls but cannot vote.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (!hasVoted && canParticipate) ...[
            if (widget.poll.pollType == PollType.ranked_choice) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildRankedChoiceEditor(theme),
            ] else ...[
              ...widget.poll.options.map((opt) {
                final tileShape = RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                );

                return Material(
                  type: MaterialType.transparency,
                  shape: tileShape,
                  clipBehavior: Clip.antiAlias,
                  child: CheckboxListTile(
                    title: Text(opt),
                    value: _selectedOptions.contains(opt),
                    shape: tileShape,
                    dense: true,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          if (widget.poll.pollType == PollType.single_choice) {
                            _selectedOptions.clear();
                          }
                          _selectedOptions.add(opt);
                        } else {
                          _selectedOptions.remove(opt);
                        }
                      });
                    },
                  ),
                );
              }),
            ],
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed:
                  ((widget.poll.pollType != PollType.ranked_choice &&
                          _selectedOptions.isEmpty) ||
                      (widget.poll.pollType == PollType.ranked_choice &&
                          _ranked.isEmpty) ||
                      uid == null)
                  ? null
                  : () => _submitVote(uid),
              child: const Text('Vote'),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$totalVotes vote${totalVotes == 1 ? '' : 's'}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatePollDialog extends StatefulWidget {
  const _CreatePollDialog({
    required this.club,
    required this.schoolID,
    required this.canChangeVisibility,
  });
  final ClubInfo club;
  final String schoolID;
  final bool canChangeVisibility;
  @override
  State<_CreatePollDialog> createState() => _CreatePollDialogState();
}

class _CreatePollDialogState extends State<_CreatePollDialog> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final List<TextEditingController> _options = [
    TextEditingController(),
    TextEditingController(),
  ];
  PollType _pollType = PollType.single_choice;
  String _visibility = ClubPoll.clubMembersVisibility;
  bool _submitting = false;

  void _addOption() {
    setState(() => _options.add(TextEditingController()));
  }

  Future<void> _submit() async {
    final auth = context.read<AuthService>();
    final profileNotifier = context.read<CurrentUserProfileNotifier>();
    final firebase = context.read<FirebaseService>();
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    final opts = _options
        .map((e) => e.text.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (_title.text.isEmpty || opts.length < 2) {
      QuiltConfirmation.warning(context, 'Need title and at least 2 options.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final String authorName =
          profileNotifier.profile?.displayName ?? 'Member';
      final poll = ClubPoll(
        id: '',
        creatorId: uid,
        creatorName: authorName,
        title: _title.text.trim(),
        description: _desc.text.trim(),
        pollType: _pollType,
        options: opts,
        visibility: _visibility,
        createdAt: DateTime.now(),
      );
      await firebase.createPoll(widget.schoolID, widget.club.id, poll);
      if (mounted) {
        Navigator.pop(context);
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
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: theme.colorScheme.surface,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create Poll',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Question'),
            ),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<PollType>(
              segments: const [
                ButtonSegment(
                  value: PollType.single_choice,
                  label: Text('Single'),
                ),
                ButtonSegment(
                  value: PollType.multiple_choice,
                  label: Text('Multiple'),
                ),
                ButtonSegment(
                  value: PollType.ranked_choice,
                  label: Text('Ranked'),
                ),
              ],
              selected: {_pollType},
              onSelectionChanged: (val) =>
                  setState(() => _pollType = val.first),
            ),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: ClubPoll.clubMembersVisibility,
                  icon: Icon(Icons.groups_2_outlined),
                  label: Text('Club'),
                ),
                ButtonSegment(
                  value: ClubPoll.schoolMembersVisibility,
                  icon: Icon(Icons.school_outlined),
                  label: Text('School'),
                ),
                ButtonSegment(
                  value: ClubPoll.publicVisibility,
                  icon: Icon(Icons.public_outlined),
                  label: Text('Public'),
                ),
              ],
              selected: {_visibility},
              onSelectionChanged: _submitting || !widget.canChangeVisibility
                  ? null
                  : (val) => setState(() => _visibility = val.first),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (int i = 0; i < _options.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: TextField(
                          controller: _options[i],
                          decoration: InputDecoration(
                            labelText: 'Option ${i + 1}',
                            isDense: true,
                          ),
                        ),
                      ),
                    TextButton.icon(
                      onPressed: _addOption,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Option'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const CircularProgressIndicator()
                  : const Text('Publish Poll'),
            ),
          ],
        ),
      ),
    );
  }
}
