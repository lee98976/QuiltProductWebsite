import 'package:cloud_firestore/cloud_firestore.dart';

enum PollType { single_choice, multiple_choice, ranked_choice }

class ClubPoll {
  static const String publicVisibility = 'public';
  static const String schoolMembersVisibility = 'schoolMembers';
  static const String clubMembersVisibility = 'clubMembers';

  final String id;
  final String creatorId;
  final String creatorName;
  final String title;
  final String description;
  final PollType pollType;
  final List<String> options;
  final Map<String, dynamic> votes;
  final String visibility;
  final DateTime createdAt;

  const ClubPoll({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.title,
    required this.description,
    required this.pollType,
    required this.options,
    this.votes = const {},
    this.visibility = schoolMembersVisibility,
    required this.createdAt,
  });

  factory ClubPoll.fromMap(Map<String, dynamic> map, String id) {
    final ts = map['createdAt'];
    return ClubPoll(
      id: id,
      creatorId: map['creatorId'] as String? ?? '',
      creatorName: map['creatorName'] as String? ?? 'Member',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      pollType: PollType.values.firstWhere(
        (e) => e.name == map['pollType'],
        orElse: () => PollType.single_choice,
      ),
      options: List<String>.from(map['options'] ?? []),
      votes: Map<String, dynamic>.from(map['votes'] ?? {}),
      visibility: _visibilityFromMap(map),
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'creatorId': creatorId,
      'creatorName': creatorName,
      'title': title,
      'description': description,
      'pollType': pollType.name,
      'options': options,
      'votes': votes,
      'visibility': visibility,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  bool get isPublic => visibility == publicVisibility;

  static String _visibilityFromMap(Map<String, dynamic> map) {
    final raw = map['visibility'] as String?;
    if (raw == publicVisibility ||
        raw == schoolMembersVisibility ||
        raw == clubMembersVisibility) {
      return raw!;
    }
    if (map['isPublic'] == true || map['public'] == true) {
      return publicVisibility;
    }
    return schoolMembersVisibility;
  }
}
