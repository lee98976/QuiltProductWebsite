import 'dart:async';
import 'dart:math';
import 'preview_database.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../Models/bell_schedule.dart';
import '../Models/app_notification.dart';
import '../Models/club.dart';
import '../Models/club_request.dart';
import '../Models/hall_pass.dart';
import '../Models/moderation_report.dart';
import '../Models/parent_request.dart';
import '../Models/period.dart';
import '../Models/platform_event.dart';
import '../Models/poll.dart';
import '../Models/post_attachment.dart';
import '../Models/school.dart';
import '../Models/upload_file_data.dart';
import '../Models/user.dart';
import '../Utility/content_safety.dart';
import '../firebase_options_selector.dart';

class FirebaseService {
  FirebaseService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    Duration bellScheduleCacheDuration = const Duration(minutes: 30),
    Duration dashboardCacheDuration = const Duration(minutes: 2),
    DateTime Function()? clock,
  }) : _db = firestore ?? PreviewDatabase(),
       _storage = storage ?? FirebaseStorage.instance,
       _bellScheduleCacheDuration = bellScheduleCacheDuration,
       _dashboardCacheDuration = dashboardCacheDuration,
       _clock = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final Duration _bellScheduleCacheDuration;
  final Duration _dashboardCacheDuration;
  final DateTime Function() _clock;
  final Map<String, _BellScheduleCacheEntry> _bellScheduleCache = {};
  final Map<String, Future<BellSchedule?>> _bellScheduleRequests = {};
  final Map<String, _FutureCacheEntry<dynamic>> _requestCache = {};

  static const String _familyCodeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const List<String> _schoolVisibleContent = [
    ClubPostEntry.publicVisibility,
    ClubPostEntry.schoolMembersVisibility,
  ];
  static final Filter _schoolVisibleContentFilter = Filter.or(
    Filter('visibility', whereIn: _schoolVisibleContent),
    Filter('visibility', isNull: true),
  );

  static const String _demoSchoolID = 'troy_high_school';

  static List<School> _demoSchools() {
    return const [
      School(
        id: _demoSchoolID,
        name: 'Troy High School',
        city: 'Troy',
        state: 'MI',
        description:
            'A sample Quilt campus with clubs, events, hall passes, and family views.',
        address: '4777 Northfield Parkway',
        websiteUrl: 'https://example.com/troy-high',
      ),
      School(
        id: 'sunset_ridge_high',
        name: 'Sunset Ridge High School',
        city: 'Irvine',
        state: 'CA',
        description:
            'A sample public preview school for prospective students and families.',
      ),
      School(
        id: 'northview_prep',
        name: 'Northview Preparatory',
        city: 'Austin',
        state: 'TX',
        description: 'A sample independent school with public club listings.',
      ),
    ];
  }

  static List<ClubInfo> _demoClubs(String schoolID) {
    final normalizedSchoolID = schoolID.trim();
    if (normalizedSchoolID.isEmpty) return const [];

    return [
      ClubInfo.fromMap(const {
        'title': 'Robotics Team',
        'tagline':
            'Designing competition robots and teaching engineering skills.',
        'description':
            'Students design, build, program, and test robots for regional competitions.',
        'meetingTime': 'Wednesdays after school',
        'location': 'Engineering Lab',
        'accentColor': 0xFF2563EB,
        'supervisorName': 'Priya Shah',
        'supervisorEmail': 'pshah@example.com',
        'presidentName': 'Max Rivera',
        'presidentEmail': 'max.rivera@example.com',
        'highlights': ['Robot design', 'Programming', 'Drive team'],
        'quickLinks': [
          {
            'label': 'Build checklist',
            'url': 'https://example.com/build-checklist',
            'description': 'Materials and deadlines for the next meeting.',
            'visibility': ClubQuickLink.schoolMembersVisibility,
          },
        ],
      }, 'robotics_team'),
      ClubInfo.fromMap(const {
        'title': 'Art Collective',
        'tagline': 'Studio practice, public art, critique, and exhibitions.',
        'description':
            'A creative home for campus artists to plan showcases and collaborative installations.',
        'meetingTime': 'Tuesdays at lunch',
        'location': 'Room 204',
        'accentColor': 0xFF7C3AED,
        'supervisorName': 'Avery Brooks',
        'presidentName': 'Sofia Martinez',
        'highlights': ['Showcases', 'Murals', 'Portfolio nights'],
      }, 'art_collective'),
      ClubInfo.fromMap(const {
        'title': 'Health Sciences HOSA',
        'tagline': 'Healthcare career prep, service, and competitions.',
        'description':
            'Explore medical careers through guest speakers, service projects, and HOSA events.',
        'meetingTime': 'Fridays after school',
        'location': 'Health Sciences Room 310',
        'accentColor': 0xFFDC2626,
        'supervisorName': 'Dr. Nia Okafor',
        'presidentName': 'Jordan Patel',
        'highlights': ['Career panels', 'Competitions', 'Service'],
      }, 'hosa'),
      ClubInfo.fromMap(const {
        'title': 'Debate Society',
        'tagline': 'Public speaking, research, and tournament preparation.',
        'description':
            'Practice argumentation, research current issues, and prepare for debate tournaments.',
        'meetingTime': 'Mondays after school',
        'location': 'Library',
        'accentColor': 0xFF0F172A,
        'supervisorName': 'Mina Chen',
        'presidentName': 'Ethan Brooks',
        'highlights': ['Research', 'Tournaments', 'Public speaking'],
      }, 'debate_society'),
      ClubInfo.fromMap(const {
        'title': 'Environmental Action Club',
        'tagline': 'Hands-on sustainability projects for campus and community.',
        'description':
            'Plan cleanups, native planting days, and practical climate projects around school.',
        'meetingTime': 'Thursdays before school',
        'location': 'Greenhouse',
        'accentColor': 0xFF16A34A,
        'supervisorName': 'Jonah Silva',
        'presidentName': 'Ava Nguyen',
        'highlights': ['Cleanups', 'Gardening', 'Service hours'],
      }, 'environmental_action'),
    ];
  }

  static Set<String> _demoJoinedClubIDs(Iterable<String> clubIDs) {
    const joined = {'robotics_team', 'hosa'};
    return clubIDs.where(joined.contains).toSet();
  }

  static List<ClubPostEntry> _demoPosts(String schoolID, String clubID) {
    final club = _demoClubs(schoolID).where((club) => club.id == clubID);
    final clubTitle = club.isEmpty ? 'Club' : club.first.title;
    final now = DateTime.now().subtract(const Duration(hours: 1));

    return [
      ClubPostEntry(
        id: '${clubID}_tryouts',
        schoolID: schoolID,
        clubID: clubID,
        clubTitle: clubTitle,
        title: clubID == 'robotics_team'
            ? 'Drive team tryouts'
            : '$clubTitle meeting update',
        authorId: 'max_rivera',
        authorName: 'Max Rivera',
        body:
            '$clubTitle update: please check the agenda, bring required materials, and reply to the leadership team if you need help before the next meeting.',
        visibility: ClubPostEntry.schoolMembersVisibility,
        timestamp: now,
      ),
      ClubPostEntry(
        id: '${clubID}_checklist',
        schoolID: schoolID,
        clubID: clubID,
        clubTitle: clubTitle,
        title: clubID == 'robotics_team'
            ? 'Build season checklist'
            : '$clubTitle prep list',
        authorId: 'kai_kim',
        authorName: 'Kai Kim',
        body:
            'New checklist posted for $clubTitle. Officers added reminders, dates, and materials so everyone can prepare.',
        visibility: ClubPostEntry.publicVisibility,
        timestamp: now.subtract(const Duration(hours: 2)),
      ),
    ];
  }

  static List<ClubPoll> _demoPolls(String clubID) {
    return [
      ClubPoll(
        id: '${clubID}_meeting_poll',
        creatorId: 'sofia_martinez',
        creatorName: 'Sofia Martinez',
        title: 'Best meeting time next week?',
        description: 'Choose the time that works best for the group.',
        pollType: PollType.single_choice,
        options: const ['Lunch', 'After school', 'Before school'],
        votes: const {
          'demo_some_guy': 'After school',
          'maya_chen': 'Lunch',
          'noah_kim': 'After school',
        },
        visibility: ClubPoll.schoolMembersVisibility,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  }

  static List<PlatformEvent> _demoEvents(String schoolID, {String? clubID}) {
    final events = [
      PlatformEvent(
        id: 'hosa_panel',
        schoolID: schoolID,
        clubID: 'hosa',
        clubTitle: 'Health Sciences HOSA',
        title: 'HOSA Future Health Professionals career panel',
        description:
            'Meet local healthcare professionals and learn about clinical career paths.',
        location: 'Health Sciences Room 310',
        startTime: DateTime.now().add(const Duration(days: 1)),
        creatorId: 'jordan_patel',
        creatorName: 'Jordan Patel',
        attendeeNames: const ['Maya Chen', 'Noah Kim'],
        goingCount: 12,
      ),
      PlatformEvent(
        id: 'robotics_scrimmage',
        schoolID: schoolID,
        clubID: 'robotics_team',
        clubTitle: 'Robotics Team',
        title: 'Robotics drive practice',
        description: 'Practice match strategy before the Saturday scrimmage.',
        location: 'Engineering Lab',
        startTime: DateTime.now().add(const Duration(days: 3)),
        creatorId: 'max_rivera',
        creatorName: 'Max Rivera',
        attendeeNames: const ['Ethan Brooks', 'Ava Nguyen'],
        goingCount: 18,
      ),
      PlatformEvent(
        id: 'school_club_fair',
        schoolID: schoolID,
        clubID: '',
        clubTitle: '',
        title: 'Fall club fair',
        description: 'Explore clubs, meet leaders, and find activities.',
        location: 'Main Gym',
        startTime: DateTime.now().add(const Duration(days: 5)),
        creatorId: 'demo_some_guy',
        creatorName: 'School Office',
        goingCount: 80,
      ),
    ];

    final normalizedClubID = clubID?.trim();
    if (normalizedClubID == null || normalizedClubID.isEmpty) return events;
    return events.where((event) => event.clubID == normalizedClubID).toList();
  }

  Future<T> _cachedRequest<T>(
    String key,
    Future<T> Function() loader, {
    Duration? ttl,
    bool forceRefresh = false,
  }) {
    final now = _clock();
    final cacheTtl = ttl ?? _dashboardCacheDuration;
    if (!forceRefresh && cacheTtl > Duration.zero) {
      final cached = _requestCache[key];
      if (cached != null && cached.expiresAt.isAfter(now)) {
        return cached.future as Future<T>;
      }
    }

    late final Future<T> request;
    request = loader().catchError((Object error, StackTrace stackTrace) {
      _requestCache.remove(key);
      Error.throwWithStackTrace(error, stackTrace);
    });
    if (cacheTtl > Duration.zero) {
      _requestCache[key] = _FutureCacheEntry<T>(
        future: request,
        expiresAt: now.add(cacheTtl),
      );
    }
    return request;
  }

  CollectionReference<Map<String, dynamic>> _bellSchedulesRef(String schoolID) {
    return _db.collection('Schools').doc(schoolID).collection('BellSchedules');
  }

  String _bellScheduleCacheKey(String schoolID, DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${schoolID.trim()}:${date.year}-$month-$day';
  }

  Future<BellSchedule?> getBellScheduleForDate({
    required String schoolID,
    required DateTime date,
  }) {
    if (_bellScheduleCacheDuration <= Duration.zero) {
      return _fetchBellScheduleForDate(schoolID: schoolID, date: date);
    }

    final cacheKey = _bellScheduleCacheKey(schoolID, date);
    final now = _clock();
    final cached = _bellScheduleCache[cacheKey];
    if (cached != null) {
      if (cached.expiresAt.isAfter(now)) return Future.value(cached.schedule);
      _bellScheduleCache.remove(cacheKey);
    }

    final pending = _bellScheduleRequests[cacheKey];
    if (pending != null) return pending;

    final request = _fetchBellScheduleForDate(schoolID: schoolID, date: date)
        .then((schedule) {
          _bellScheduleCache[cacheKey] = _BellScheduleCacheEntry(
            schedule: schedule,
            expiresAt: _clock().add(_bellScheduleCacheDuration),
          );
          return schedule;
        })
        .whenComplete(() {
          _bellScheduleRequests.remove(cacheKey);
        });
    _bellScheduleRequests[cacheKey] = request;
    return request;
  }

  Future<BellSchedule?> _fetchBellScheduleForDate({
    required String schoolID,
    required DateTime date,
  }) async {
    final schoolRef = _db.collection('Schools').doc(schoolID);
    final schoolDoc = await schoolRef.get();
    final schoolData = schoolDoc.data() ?? const <String, dynamic>{};
    final assignedSchedule =
        _scheduleKeyFromSchoolData(schoolData, date) ??
        await _scheduleKeyFromDayDocuments(schoolRef, date);
    if (assignedSchedule != null && _isNoSchoolScheduleKey(assignedSchedule)) {
      return null;
    }

    final schedule =
        await _getBellScheduleByKey(schoolID, assignedSchedule) ??
        await _getBellScheduleByKey(schoolID, 'regular_schedule');
    return schedule;
  }

  Future<List<CalEvent>> getScheduleForDay(String dayType) async {
    final scheduleDoc = await _db
        .collection('Schools')
        .doc('Troy')
        .collection('BellSchedules')
        .doc(dayType)
        .get();

    if (!scheduleDoc.exists || scheduleDoc.data() == null) {
      return [];
    }

    final rawPeriods = List<Map<String, dynamic>>.from(
      scheduleDoc.data()!['periods'] ?? [],
    );

    return rawPeriods.map(CalEvent.fromMap).toList();
  }

  Future<BellSchedule?> _getBellScheduleByKey(
    String schoolID,
    String? scheduleKey,
  ) async {
    final key = scheduleKey?.trim();
    if (key == null || key.isEmpty || _isNoSchoolScheduleKey(key)) return null;

    final candidateIds = _scheduleIdCandidates(key);
    for (final id in candidateIds) {
      final doc = await _bellSchedulesRef(schoolID).doc(id).get();
      final data = doc.data();
      if (doc.exists && data != null) {
        return _bellScheduleFromMap(data, doc.id);
      }
    }

    final titleMatches = await _bellSchedulesRef(
      schoolID,
    ).where('title', isEqualTo: key).limit(1).get();
    if (titleMatches.docs.isNotEmpty) {
      final doc = titleMatches.docs.first;
      return _bellScheduleFromMap(doc.data(), doc.id);
    }
    return null;
  }

  Future<String?> _scheduleKeyFromDayDocuments(
    DocumentReference<Map<String, dynamic>> schoolRef,
    DateTime date,
  ) async {
    for (final collection in const [
      'ScheduleDays',
      'BellScheduleDays',
      'DayTypes',
      'Calendar',
    ]) {
      for (final docId in _dateDocumentIds(date)) {
        try {
          final doc = await schoolRef.collection(collection).doc(docId).get();
          final data = doc.data();
          if (doc.exists && data != null) {
            return _scheduleKeyFromValue(data) ?? doc.id;
          }
        } on FirebaseException catch (error) {
          if (error.code != 'permission-denied' &&
              error.code != 'not-found' &&
              error.code != 'unavailable') {
            rethrow;
          }
        }
      }
    }
    return null;
  }

  List<String> _dateDocumentIds(DateTime date) {
    return _dateKeys(
      date,
    ).where((key) => !key.contains('/')).toSet().toList(growable: false);
  }

  BellSchedule _bellScheduleFromMap(Map<String, dynamic> map, String id) {
    final periods = (map['periods'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (period) =>
              _bellSchedulePeriodFromMap(Map<String, dynamic>.from(period)),
        )
        .whereType<BellSchedulePeriod>()
        .toList(growable: false);

    return BellSchedule(
      id: id,
      title: map['title'] as String? ?? _scheduleTitleFromId(id),
      dateNotes: map['dateNotes'] as String? ?? '',
      periods: periods,
    );
  }

  BellSchedulePeriod? _bellSchedulePeriodFromMap(Map<String, dynamic> map) {
    final title =
        map['title'] as String? ??
        map['label'] as String? ??
        map['name'] as String?;
    final start = _periodTimeParts(
      map,
      hourKey: 'startHour',
      minuteKey: 'startMinute',
      timeKeys: const ['startTime', 'start'],
    );
    final end = _periodTimeParts(
      map,
      hourKey: 'endHour',
      minuteKey: 'endMinute',
      timeKeys: const ['endTime', 'end'],
    );
    if (title == null || title.trim().isEmpty || start == null || end == null) {
      return null;
    }

    return BellSchedulePeriod(
      title: title.trim(),
      startHour: start.hour,
      startMinute: start.minute,
      endHour: end.hour,
      endMinute: end.minute,
      minutes:
          _intFromValue(map['minutes']) ??
          _intFromValue(map['min']) ??
          _durationMinutes(start, end),
    );
  }

  _TimeParts? _periodTimeParts(
    Map<String, dynamic> map, {
    required String hourKey,
    required String minuteKey,
    required List<String> timeKeys,
  }) {
    final hour = _intFromValue(map[hourKey]);
    final minute = _intFromValue(map[minuteKey]);
    if (hour != null && minute != null) return _TimeParts(hour, minute);

    for (final key in timeKeys) {
      final parsed = _timePartsFromValue(map[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  String? _scheduleKeyFromSchoolData(Map<String, dynamic> data, DateTime date) {
    for (final key in const [
      'scheduleByDate',
      'schedulesByDate',
      'bellScheduleByDate',
      'bellSchedulesByDate',
      'dayTypes',
      'scheduleCalendar',
      'calendar',
    ]) {
      final scheduleKey = _scheduleKeyFromDateMap(data[key], date);
      if (scheduleKey != null) return scheduleKey;
    }

    for (final key in const [
      'scheduleDates',
      'bellScheduleDates',
      'dayTypeDates',
    ]) {
      final scheduleKey = _scheduleKeyFromDateEntries(data[key], date);
      if (scheduleKey != null) return scheduleKey;
    }
    return _scheduleKeyFromValue(data['defaultSchedule']);
  }

  String? _scheduleKeyFromDateMap(Object? value, DateTime date) {
    if (value is! Map) return null;
    final map = Map<Object?, Object?>.from(value);
    for (final key in _dateKeys(date)) {
      if (map.containsKey(key)) return _scheduleKeyFromValue(map[key]);
    }
    return null;
  }

  String? _scheduleKeyFromDateEntries(Object? value, DateTime date) {
    if (value is! List) return null;
    for (final entry in value.whereType<Map>()) {
      final data = Map<String, dynamic>.from(entry);
      if (!_sameScheduleDate(data['date'], date)) continue;
      return _scheduleKeyFromValue(data);
    }
    return null;
  }

  String? _scheduleKeyFromValue(Object? value) {
    if (value == null) return null;
    if (value is String) return value.trim().isEmpty ? null : value.trim();
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      for (final key in const [
        'scheduleId',
        'scheduleID',
        'bellScheduleId',
        'bellScheduleID',
        'dayType',
        'type',
        'schedule',
        'title',
        'name',
      ]) {
        final scheduleKey = _scheduleKeyFromValue(map[key]);
        if (scheduleKey != null) return scheduleKey;
      }
    }
    return null;
  }

  bool _sameScheduleDate(Object? value, DateTime date) {
    final parsed = _dateFromValue(value);
    if (parsed == null) return false;
    return parsed.year == date.year &&
        parsed.month == date.month &&
        parsed.day == date.day;
  }

  DateTime? _dateFromValue(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;

      final slash = RegExp(
        r'^(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?$',
      ).firstMatch(value.trim());
      if (slash != null) {
        final month = int.parse(slash.group(1)!);
        final day = int.parse(slash.group(2)!);
        final yearText = slash.group(3);
        final year = yearText == null
            ? DateTime.now().year
            : _fullYear(int.parse(yearText));
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  List<String> _dateKeys(DateTime date) {
    final shortYear = (date.year % 100).toString().padLeft(2, '0');
    return [
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      '${date.month}/${date.day}/${date.year}',
      '${date.month}/${date.day}/$shortYear',
      '${date.month}/${date.day}',
      '${date.month}-${date.day}-${date.year}',
      '${date.month}-${date.day}-$shortYear',
    ];
  }

  Set<String> _scheduleIdCandidates(String key) {
    final normalized = _scheduleIdFromTitle(key);
    return {
      key,
      normalized,
      if (normalized.endsWith('_day'))
        '${normalized.substring(0, normalized.length - 4)}_schedule',
      if (!normalized.endsWith('_schedule')) '${normalized}_schedule',
    }.where((id) => id.trim().isNotEmpty).toSet();
  }

  String _scheduleIdFromTitle(String title) {
    final id = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return id.isEmpty ? 'schedule' : id;
  }

  String _scheduleTitleFromId(String id) {
    return id
        .split(RegExp(r'[_\s-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  _TimeParts? _timePartsFromValue(Object? value) {
    if (value is Timestamp) {
      final date = value.toDate();
      return _TimeParts(date.hour, date.minute);
    }
    if (value is DateTime) return _TimeParts(value.hour, value.minute);
    if (value is String) {
      final parsedDate = DateTime.tryParse(value);
      if (parsedDate != null) {
        return _TimeParts(parsedDate.hour, parsedDate.minute);
      }

      final match = RegExp(
        r'^(\d{1,2})\s*:\s*(\d{2})(?:\s*([AP]M))?$',
        caseSensitive: false,
      ).firstMatch(value.trim());
      if (match == null) return null;
      var hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final period = match.group(3)?.toUpperCase();
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return _TimeParts(hour, minute);
    }
    return null;
  }

  int? _intFromValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  int _durationMinutes(_TimeParts start, _TimeParts end) {
    final startMinutes = start.hour * 60 + start.minute;
    var endMinutes = end.hour * 60 + end.minute;
    if (endMinutes < startMinutes) endMinutes += 24 * 60;
    return endMinutes - startMinutes;
  }

  int _fullYear(int year) => year < 100 ? 2000 + year : year;

  bool _isNoSchoolScheduleKey(String key) {
    final normalized = _scheduleIdFromTitle(key);
    return normalized == 'no_school' ||
        normalized == 'holiday' ||
        normalized == 'break';
  }

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _db.collection('Users').doc(uid);
  }

  Future<void> createUserProfile(UserProfile user) async {
    await _userDoc(user.UID).set(user.toMap());
  }

  Future<void> saveUserProfile(UserProfile user, {bool merge = true}) async {
    await _userDoc(
      user.UID,
    ).set(user.toMap(), merge ? SetOptions(merge: true) : null);
  }

  Future<void> deleteUserAccountData(String uid) async {
    final authoredPosts = await _db
        .collectionGroup('Posts')
        .where('authorId', isEqualTo: uid)
        .get();
    final authoredPolls = await _db
        .collectionGroup('Polls')
        .where('creatorId', isEqualTo: uid)
        .get();
    final authoredEvents = await _db
        .collectionGroup('Events')
        .where('creatorId', isEqualTo: uid)
        .get();

    final attachmentPaths = <String>{};
    for (final post in authoredPosts.docs) {
      final attachments = post.data()['attachments'];
      if (attachments is! Iterable) continue;
      for (final attachment in attachments) {
        if (attachment is! Map) continue;
        final storagePath = attachment['storagePath'];
        if (storagePath is String && storagePath.trim().isNotEmpty) {
          attachmentPaths.add(storagePath.trim());
        }
      }
    }

    // Storage cleanup must not prevent the user from deleting their account.
    // A bucket can reject cleanup when its deployed rules or billing state do
    // not permit access, even though Auth and Firestore deletion are allowed.
    await Future.wait([
      for (final path in attachmentPaths) _deleteStorageObject(path),
      _deleteStoragePrefix('users/$uid/profile'),
    ]);

    for (final event in authoredEvents.docs) {
      await _deleteCollection(event.reference.collection('Attendees'));
      await _deleteCollection(event.reference.collection('Volunteers'));
    }

    await _deleteDocuments([
      ...authoredPosts.docs.map((doc) => doc.reference),
      ...authoredPolls.docs.map((doc) => doc.reference),
      ...authoredEvents.docs.map((doc) => doc.reference),
    ]);
    await _deleteCollection(_userDoc(uid).collection('Notifications'));

    final parentRequests = await Future.wait([
      _parentRequestsRef().where('parentId', isEqualTo: uid).get(),
      _parentRequestsRef().where('studentUid', isEqualTo: uid).get(),
    ]);
    await _deleteDocuments(
      parentRequests
          .expand((snapshot) => snapshot.docs)
          .map((doc) => doc.reference)
          .toSet(),
    );

    await _db.collection('RateLimits').doc(uid).delete();
    await _userDoc(uid).delete();
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final snapshot = await collection.limit(400).get();
      if (snapshot.docs.isEmpty) return;
      await _deleteDocuments(snapshot.docs.map((doc) => doc.reference));
      if (snapshot.docs.length < 400) return;
    }
  }

  Future<void> _deleteDocuments(
    Iterable<DocumentReference<Map<String, dynamic>>> references,
  ) async {
    final unique = {
      for (final reference in references) reference.path: reference,
    };
    final docs = unique.values.toList();
    for (var start = 0; start < docs.length; start += 400) {
      final batch = _db.batch();
      final end = min(start + 400, docs.length);
      for (final reference in docs.sublist(start, end)) {
        batch.delete(reference);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteStoragePrefix(String path) async {
    late final ListResult listing;
    try {
      listing = await _storage.ref(path).listAll();
    } on FirebaseException catch (error) {
      if (!_canSkipStorageCleanup(error)) rethrow;
      debugPrint('Skipped account Storage cleanup for $path: ${error.code}');
      return;
    }
    await Future.wait([
      for (final item in listing.items) _deleteStorageObject(item.fullPath),
      for (final prefix in listing.prefixes)
        _deleteStoragePrefix(prefix.fullPath),
    ]);
  }

  Future<void> _deleteStorageObject(String path) async {
    try {
      await _storage.ref(path).delete();
    } on FirebaseException catch (error) {
      if (!_canSkipStorageCleanup(error)) rethrow;
      if (error.code != 'object-not-found') {
        debugPrint('Skipped account Storage cleanup for $path: ${error.code}');
      }
    }
  }

  bool _canSkipStorageCleanup(FirebaseException error) {
    return error.code == 'object-not-found' || error.code == 'unauthorized';
  }

  Future<UserProfile?> getUser(String uid) async {
    final doc = await _userDoc(uid).get();

    if (!doc.exists || doc.data() == null) return null;

    final data = Map<String, dynamic>.from(doc.data()!);
    data['UID'] = data['UID'] ?? uid;
    return UserProfile.fromMap(data);
  }

  Stream<UserProfile?> watchUser(String uid) {
    return _userDoc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;

      final data = Map<String, dynamic>.from(doc.data()!);
      data['UID'] = data['UID'] ?? uid;
      return UserProfile.fromMap(data);
    });
  }

  Future<List<UserProfile>> getDebugUsers(String schoolID) async {
    const serverOnly = GetOptions(source: Source.server);
    final schoolSnapshot = await _db
        .collection('Users')
        .where('schoolID', isEqualTo: schoolID)
        .where('isDebug', isEqualTo: true)
        .get(serverOnly);
    final scopedSnapshot = await _db
        .collection('Users')
        .where('debugSchoolID', isEqualTo: schoolID)
        .where('isDebug', isEqualTo: true)
        .get(serverOnly);

    final usersById = <String, UserProfile>{};
    for (final doc in [...schoolSnapshot.docs, ...scopedSnapshot.docs]) {
      final data = Map<String, dynamic>.from(doc.data());
      data['UID'] = data['UID'] ?? doc.id;
      final user = UserProfile.fromMap(data);
      if (user.isDebug) usersById[user.UID] = user;
    }

    final users = usersById.values.toList();
    users.sort((a, b) {
      final roleCompare = a.accountRole.compareTo(b.accountRole);
      if (roleCompare != 0) return roleCompare;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return users;
  }

  Future<List<UserProfile>> createDebugFamilyAccounts({
    String schoolID = 'troy_high_school',
  }) async {
    final suffix = Random.secure().nextInt(9000) + 1000;
    final parentUid = 'debug_parent_$suffix';
    final linkedStudentUid = 'debug_student_linked_$suffix';
    final requestStudentUid = 'debug_student_request_$suffix';
    final linkedFamilyCode = await createUniqueFamilyCode();
    var requestFamilyCode = await createUniqueFamilyCode();
    while (requestFamilyCode == linkedFamilyCode) {
      requestFamilyCode = await createUniqueFamilyCode();
    }
    final parentName = 'Debug Parent $suffix';
    final linkedStudentName = 'Linked Student $suffix';
    final requestStudentName = 'Request Student $suffix';

    final parent = UserProfile(
      email: 'debug.parent.$suffix@debug.quilt',
      displayName: parentName,
      realName: parentName,
      accountStatus: UserProfile.viewOnlyStatus,
      accountRole: UserProfile.parentRole,
      schoolID: '',
      UID: parentUid,
      parentStudentIds: [linkedStudentUid],
      studentUids: [linkedStudentUid],
      isDebug: true,
    );
    final linkedStudent = UserProfile(
      email: 'linked.student.$suffix@debug.quilt',
      displayName: linkedStudentName,
      realName: linkedStudentName,
      studentId: 'DBG-$suffix-A',
      familyCode: linkedFamilyCode,
      accountStatus: UserProfile.verifiedStatus,
      accountRole: UserProfile.currentStudentRole,
      schoolID: schoolID,
      UID: linkedStudentUid,
      parentIds: [parentUid],
      isDebug: true,
    );
    final requestStudent = UserProfile(
      email: 'request.student.$suffix@debug.quilt',
      displayName: requestStudentName,
      realName: requestStudentName,
      studentId: 'DBG-$suffix-B',
      familyCode: requestFamilyCode,
      accountStatus: UserProfile.verifiedStatus,
      accountRole: UserProfile.currentStudentRole,
      schoolID: schoolID,
      UID: requestStudentUid,
      isDebug: true,
    );

    final batch = _db.batch();
    batch.set(_userDoc(parentUid), {
      ...parent.toMap(),
      'debugSchoolID': schoolID,
      'childUIDs': [linkedStudentUid],
      'childSchoolIDs': [schoolID],
      'linkedAccounts': [
        {
          'uid': linkedStudentUid,
          'name': linkedStudent.displayName,
          'role': linkedStudent.accountRole,
        },
      ],
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_userDoc(linkedStudentUid), {
      ...linkedStudent.toMap(),
      'debugSchoolID': schoolID,
      'parentUIDs': [parentUid],
      'linkedAccounts': [
        {
          'uid': parentUid,
          'name': parent.displayName,
          'role': parent.accountRole,
        },
      ],
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_userDoc(requestStudentUid), {
      ...requestStudent.toMap(),
      'debugSchoolID': schoolID,
      'parentUIDs': <String>[],
      'childUIDs': <String>[],
      'linkedAccounts': <Map<String, String>>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    return [parent, linkedStudent, requestStudent];
  }

  Future<List<UserProfile>> getStudentsForParent(UserProfile parent) {
    final explicitStudentIds = _linkedStudentIdsFor(parent)..sort();
    final cacheKey = [
      'parent_students',
      parent.UID,
      explicitStudentIds.join(','),
    ].join(':');
    return _cachedRequest(cacheKey, () => _fetchStudentsForParent(parent));
  }

  Future<List<UserProfile>> _fetchStudentsForParent(UserProfile parent) async {
    final studentsById = <String, UserProfile>{};

    for (final studentId in _linkedStudentIdsFor(parent)) {
      try {
        final student = await getUser(studentId);
        if (student != null) {
          studentsById[student.UID] = student;
        }
      } catch (_) {
        // Keep loading any students the parent is allowed to read.
      }
    }

    const parentReferenceFields = [
      'parentUIDs',
      'parentUids',
      'guardianUIDs',
      'guardianUids',
      'parentIds',
      'guardianIds',
      'parents',
    ];

    for (final field in parentReferenceFields) {
      try {
        final snapshot = await _db
            .collection('Users')
            .where(field, arrayContains: parent.UID)
            .get();

        for (final doc in snapshot.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          data['UID'] = data['UID'] ?? doc.id;
          final student = UserProfile.fromMap(data);
          if (student.isCurrentStudent) {
            studentsById[student.UID] = student;
          }
        }
      } catch (_) {
        // Some deployments may not use this field or may restrict it.
      }
    }

    final students = studentsById.values.toList()
      ..sort((a, b) {
        final aName = a.realName.isNotEmpty ? a.realName : a.displayName;
        final bName = b.realName.isNotEmpty ? b.realName : b.displayName;
        return aName.toLowerCase().compareTo(bName.toLowerCase());
      });
    return students;
  }

  List<String> _linkedStudentIdsFor(UserProfile parent) {
    final ids = <String>{
      ...parent.parentStudentIds,
      ...parent.studentUids,
      for (final account in parent.linkedAccounts)
        if (account.role.trim() != UserProfile.parentRole) account.uid,
    };
    return ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && id != parent.UID)
        .toList(growable: false);
  }

  Future<void> _updateUser(String uid, Map<String, dynamic> data) async {
    await _userDoc(uid).update(data);
  }

  Future<void> changeDisplayName(String uid, String displayName) {
    return _updateUser(uid, {'displayName': displayName});
  }

  Future<void> changeRealName(String uid, String realName) {
    return _updateUser(uid, {'realName': realName});
  }

  Future<void> changePFP(String uid, String url) {
    return _updateUser(uid, {'pfpURL': url});
  }

  Future<void> dismissClubVisibilityWarning(String uid) {
    return _updateUser(uid, {'clubVisibilityWarningDismissed': true});
  }

  String _displayNameForUser(UserProfile user) {
    final realName = user.realName.trim();
    if (realName.isNotEmpty) return realName;
    final displayName = user.displayName.trim();
    if (displayName.isNotEmpty) return displayName;
    final email = user.email.trim();
    if (email.isNotEmpty) return email;
    return user.UID;
  }

  Future<String> uploadProfilePicture({
    required String uid,
    required UploadFileData image,
  }) async {
    final uploaded = await _uploadBinary(
      storagePath:
          'users/$uid/profile/${DateTime.now().millisecondsSinceEpoch}_${_safeFileName(image.fileName)}',
      file: image,
    );
    await _updateUser(uid, {'pfpURL': uploaded.url});
    return uploaded.url;
  }

  Future<String> uploadClubPicture({
    required String schoolID,
    required String clubID,
    required UploadFileData image,
  }) async {
    final uploaded = await _uploadBinary(
      storagePath:
          'schools/$schoolID/clubs/$clubID/profile/${DateTime.now().millisecondsSinceEpoch}_${_safeFileName(image.fileName)}',
      file: image,
    );
    await _clubsRef(schoolID).doc(clubID).update({'imageUrl': uploaded.url});
    return uploaded.url;
  }

  Future<void> requestClubJoin({
    required String schoolID,
    required String clubID,
    required UserProfile user,
  }) async {
    final doc = _joinRequestsRef(schoolID, clubID).doc(user.UID);
    final existing = await doc.get();
    if (existing.exists) {
      final request = ClubJoinRequest.fromMap(existing.data() ?? {}, doc.id);
      if (request.status == ClubJoinRequestStatus.pending) {
        throw StateError('You already have a pending request for this club.');
      }
      if (request.status == ClubJoinRequestStatus.approved) {
        throw StateError('You are already approved for this club.');
      }
    }

    await doc.set(
      ClubJoinRequest(
        id: user.UID,
        userId: user.UID,
        name: _displayNameForUser(user),
        email: user.email.trim(),
        studentId: user.studentId.trim(),
        photoUrl: user.pfpURL,
        createdAt: DateTime.now(),
      ).toMap(),
    );
  }

  Future<Set<String>> getPendingClubJoinRequestIds({
    required String schoolID,
    required String userID,
    required Iterable<String> clubIDs,
  }) async {
    return <String>{};
  }

  CollectionReference<Map<String, dynamic>> _parentRequestsRef() {
    return _db.collection('ParentRequests');
  }

  Future<String> createUniqueFamilyCode() async {
    final random = Random.secure();

    for (var attempt = 0; attempt < 8; attempt++) {
      final code = List.generate(
        6,
        (_) => _familyCodeChars[random.nextInt(_familyCodeChars.length)],
      ).join();

      final existing = await _db
          .collection('Users')
          .where('familyCode', isEqualTo: code)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) return code;
    }

    throw StateError('Could not create a unique family code. Try again.');
  }

  Future<String> ensureStudentFamilyCode(UserProfile student) async {
    if (!student.isCurrentStudent) {
      throw StateError('Only current students can have a family code.');
    }
    if (student.familyCode.isNotEmpty) return student.familyCode;

    final code = await createUniqueFamilyCode();
    await _updateUser(student.UID, {'familyCode': code});
    return code;
  }

  Future<UserProfile?> findStudentByFamilyCode(String familyCode) async {
    final code = familyCode.trim();
    if (code.isEmpty) return null;

    final snapshot = await _db
        .collection('Users')
        .where('familyCode', isEqualTo: code)
        .where('accountRole', isEqualTo: UserProfile.currentStudentRole)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    final data = Map<String, dynamic>.from(doc.data());
    data['UID'] = data['UID'] ?? doc.id;
    final profile = UserProfile.fromMap(data);
    return profile.isCurrentStudent ? profile : null;
  }

  Future<void> submitParentRequest({
    required UserProfile parent,
    required String familyCode,
    required String relationship,
    String note = '',
  }) async {
    if (!parent.isParent) {
      throw StateError('Only parent accounts can request a student link.');
    }

    final student = await findStudentByFamilyCode(familyCode);
    if (student == null) {
      throw StateError('No student was found for that family code.');
    }
    if (student.UID == parent.UID) {
      throw StateError('You cannot request yourself as a parent.');
    }
    if (student.parentIds.contains(parent.UID) ||
        parent.studentUids.contains(student.UID)) {
      throw StateError('You are already connected to this student.');
    }

    final requestId = '${parent.UID}_${student.UID}';
    final requestRef = _parentRequestsRef().doc(requestId);
    final existing = await requestRef.get();
    if (existing.exists) {
      final request = ParentRequest.fromMap(existing.data() ?? {}, existing.id);
      if (request.status == ParentRequestStatus.accepted) {
        throw StateError('You are already connected to this student.');
      }
    }

    await requestRef.set(
      ParentRequest(
        id: requestId,
        parentId: parent.UID,
        parentName: parent.realName.isNotEmpty
            ? parent.realName
            : parent.displayName,
        parentEmail: parent.email,
        parentPhotoUrl: parent.pfpURL,
        relationship: relationship.trim(),
        note: note.trim(),
        studentUid: student.UID,
        studentName: student.realName.isNotEmpty
            ? student.realName
            : student.displayName,
        studentFamilyCode: student.familyCode,
        createdAt: DateTime.now(),
        isDebug: parent.isDebug || student.isDebug,
      ).toMap(),
      SetOptions(merge: true),
    );
  }

  Stream<List<ParentRequest>> watchIncomingParentRequests(String studentUid) {
    return Stream.value(<ParentRequest>[]);
  }

  Stream<List<ParentRequest>> watchParentRequestsForParent(String parentId) {
    return Stream.value(<ParentRequest>[]);
  }

  Future<void> acceptParentRequest({
    required String requestId,
    required String studentUid,
    required String parentRelationship,
  }) async {
    final normalizedParentRelationship = parentRelationship.trim();
    if (normalizedParentRelationship.isEmpty) {
      throw StateError('Choose who this guardian is to you.');
    }

    await _db.runTransaction((transaction) async {
      final requestRef = _parentRequestsRef().doc(requestId);
      final requestDoc = await transaction.get(requestRef);
      if (!requestDoc.exists || requestDoc.data() == null) {
        throw StateError('Parent request not found.');
      }

      final request = ParentRequest.fromMap(requestDoc.data()!, requestDoc.id);
      if (request.studentUid != studentUid) {
        throw StateError('This request belongs to another student.');
      }
      if (request.status != ParentRequestStatus.pending) {
        throw StateError('This request has already been handled.');
      }
      final studentDoc = await transaction.get(_userDoc(studentUid));
      final studentSchoolID = studentDoc.data()?['schoolID'] as String? ?? '';

      transaction.update(requestRef, {
        'status': ParentRequestStatus.accepted.name,
        'parentRelationship': normalizedParentRelationship,
        'respondedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(_userDoc(studentUid), {
        'parentIds': FieldValue.arrayUnion([request.parentId]),
        'parentUIDs': FieldValue.arrayUnion([request.parentId]),
        'linkedAccounts': FieldValue.arrayUnion([
          {
            'uid': request.parentId,
            'name': request.parentName,
            'role': UserProfile.parentRole,
            'relationship': normalizedParentRelationship,
            if ((request.parentPhotoUrl ?? '').isNotEmpty)
              'photoUrl': request.parentPhotoUrl,
          },
        ]),
      });
      transaction.update(_userDoc(request.parentId), {
        'studentUids': FieldValue.arrayUnion([studentUid]),
        'parentStudentIds': FieldValue.arrayUnion([studentUid]),
        'childUIDs': FieldValue.arrayUnion([studentUid]),
        if (studentSchoolID.isNotEmpty)
          'childSchoolIDs': FieldValue.arrayUnion([studentSchoolID]),
        'linkedAccounts': FieldValue.arrayUnion([
          {
            'uid': studentUid,
            'name': request.studentName,
            'role': UserProfile.currentStudentRole,
            'relationship': request.relationship,
          },
        ]),
      });
    });
  }

  Future<void> declineParentRequest({
    required String requestId,
    required String studentUid,
  }) async {
    await _db.runTransaction((transaction) async {
      final requestRef = _parentRequestsRef().doc(requestId);
      final requestDoc = await transaction.get(requestRef);
      if (!requestDoc.exists || requestDoc.data() == null) {
        throw StateError('Parent request not found.');
      }

      final request = ParentRequest.fromMap(requestDoc.data()!, requestDoc.id);
      if (request.studentUid != studentUid) {
        throw StateError('This request belongs to another student.');
      }

      transaction.update(requestRef, {
        'status': ParentRequestStatus.declined.name,
        'respondedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> deleteParentRequest({
    required String requestId,
    required String parentId,
  }) async {
    await _db.runTransaction((transaction) async {
      final requestRef = _parentRequestsRef().doc(requestId);
      final requestDoc = await transaction.get(requestRef);
      if (!requestDoc.exists || requestDoc.data() == null) {
        return;
      }

      final request = ParentRequest.fromMap(requestDoc.data()!, requestDoc.id);
      if (request.parentId != parentId) {
        throw StateError('This request belongs to another parent account.');
      }

      transaction.delete(requestRef);
    });
  }

  Stream<List<School>> getSchools() {
    if (QuiltFirebaseOptions.isDemo) {
      return Stream.value(_demoSchools());
    }

    return _db.collection('Schools').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => School.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<List<School>> getSchoolsFromServer() async {
    if (QuiltFirebaseOptions.isDemo) {
      return _demoSchools();
    }

    final snapshot = await _db
        .collection('Schools')
        .get(const GetOptions(source: Source.server));
    return snapshot.docs
        .map((doc) => School.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<School?> getSchoolByID(String schoolID) async {
    final id = schoolID.trim();
    if (id.isEmpty) return null;
    if (QuiltFirebaseOptions.isDemo) {
      for (final school in _demoSchools()) {
        if (school.id == id) return school;
      }
      return null;
    }

    final schoolDoc = await _db.collection('Schools').doc(id).get();
    final data = schoolDoc.data();
    if (!schoolDoc.exists || data == null) return null;

    return School.fromMap(data, schoolDoc.id);
  }

  Future<School?> getUserSchool(String uid) async {
    final user = await getUser(uid);
    if (user == null) return null;

    return getSchoolByID(user.schoolID);
  }

  CollectionReference<Map<String, dynamic>> _clubsRef(String schoolID) {
    return _db.collection('Schools').doc(schoolID).collection('Clubs');
  }

  Stream<List<ClubInfo>> getClubs(String schoolID) {
    if (QuiltFirebaseOptions.isDemo) {
      return Stream.value(_demoClubs(schoolID));
    }

    return _clubsRef(schoolID).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return ClubInfo.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  Future<List<ClubInfo>> getClubsOnce(String schoolID) async {
    if (QuiltFirebaseOptions.isDemo) {
      return _demoClubs(schoolID);
    }

    final snapshot = await _clubsRef(schoolID).get();
    return snapshot.docs.map((doc) {
      return ClubInfo.fromMap(doc.data(), doc.id);
    }).toList();
  }

  Future<void> createClub(String schoolID, ClubInfo club) async {
    await _clubsRef(schoolID).add(club.toMap());
  }

  Future<void> updateClubSettings({
    required String schoolID,
    required ClubInfo club,
  }) async {
    await _clubsRef(schoolID).doc(club.id).update({
      'title': club.title.trim(),
      'tagline': club.tagline.trim(),
      'description': club.description.trim(),
      'meetingTime': club.meetingTime.trim(),
      'location': club.location.trim(),
      'imageUrl': club.imageUrl,
      'groupChatUrl': club.groupChatUrl.trim(),
      'highlights': club.highlights
          .map((highlight) => highlight.trim())
          .where((highlight) => highlight.isNotEmpty)
          .toList(),
    });
  }

  Future<void> updateClubQuickLinks({
    required String schoolID,
    required String clubID,
    required List<ClubQuickLink> quickLinks,
  }) async {
    await _clubsRef(schoolID).doc(clubID).update({
      'quickLinks': quickLinks
          .where((link) => link.hasContent)
          .take(20)
          .map((link) => link.toMap())
          .toList(),
    });
  }

  CollectionReference<Map<String, dynamic>> _membersRef(
    String schoolID,
    String clubID,
  ) {
    return _clubsRef(schoolID).doc(clubID).collection('Members');
  }

  CollectionReference<Map<String, dynamic>> _joinRequestsRef(
    String schoolID,
    String clubID,
  ) {
    return _clubsRef(schoolID).doc(clubID).collection('JoinRequests');
  }

  Stream<List<ClubJoinRequest>> getPendingClubJoinRequests(
    String schoolID,
    String clubID,
  ) {
    return Stream.value(<ClubJoinRequest>[]);
  }

  Stream<List<ClubMember>> getMembers(String schoolID, String clubID) {
    return Stream.value([
      const ClubMember(
        userId: 'max_rivera',
        name: 'Max Rivera',
        role: ClubMember.presidentRole,
        subtitle: 'Club president',
        email: 'max.rivera@example.com',
      ),
      const ClubMember(
        userId: 'priya_shah',
        name: 'Priya Shah',
        role: ClubMember.supervisorRole,
        subtitle: 'Faculty adviser',
        email: 'pshah@example.com',
      ),
    ]);
  }

  Stream<List<ClubMember>> getLeaderMembers(String schoolID, String clubID) {
    return Stream.value([
      const ClubMember(
        userId: 'max_rivera',
        name: 'Max Rivera',
        role: ClubMember.presidentRole,
        subtitle: 'Club president',
        email: 'max.rivera@example.com',
      ),
      const ClubMember(
        userId: 'priya_shah',
        name: 'Priya Shah',
        role: ClubMember.supervisorRole,
        subtitle: 'Faculty adviser',
        email: 'pshah@example.com',
      ),
    ]);
  }

  Future<Set<String>> getMembershipClubIds(
    String schoolID,
    String uid,
    Iterable<String> clubIDs, {
    Duration ttl = const Duration(minutes: 5),
    bool forceRefresh = false,
  }) {
    final ids =
        clubIDs
            .map((clubID) => clubID.trim())
            .where((clubID) => clubID.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    if (QuiltFirebaseOptions.isDemo) {
      return Future.value(_demoJoinedClubIDs(ids));
    }

    final cacheKey = [
      'membership_club_ids',
      schoolID.trim(),
      uid,
      ids.join(','),
    ].join(':');
    return _cachedRequest(
      cacheKey,
      () => _fetchMembershipClubIds(schoolID, uid, ids),
      ttl: ttl,
      forceRefresh: forceRefresh,
    );
  }

  Future<Set<String>> _fetchMembershipClubIds(
    String schoolID,
    String uid,
    List<String> ids,
  ) async {
    final checks = await Future.wait(
      ids.map((clubID) async {
        final memberDoc = await _membersRef(schoolID, clubID).doc(uid).get();
        return memberDoc.exists ? clubID : null;
      }),
    );
    return checks.whereType<String>().toSet();
  }

  Future<List<ClubMember>> _clubMembersFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return Future.wait(
      snapshot.docs.map((doc) {
        return _clubMemberWithUserContact(
          ClubMember.fromMap(doc.data(), doc.id),
        );
      }),
    );
  }

  Future<ClubMember> _clubMemberWithUserContact(ClubMember member) async {
    final needsEmail = member.email.trim().isEmpty;
    final needsPhone = member.phoneNumber.trim().isEmpty;
    final needsPhoto = (member.photoUrl ?? '').trim().isEmpty;
    if (!needsEmail && !needsPhone && !needsPhoto) return member;

    try {
      final userDoc = await _userDoc(member.userId).get();
      final data = userDoc.data();
      if (data == null) return member;

      return member.copyWith(
        email: needsEmail ? (data['email'] as String? ?? '') : member.email,
        phoneNumber: needsPhone
            ? (data['phoneNumber'] as String? ??
                  data['phone'] as String? ??
                  data['mobilePhone'] as String? ??
                  '')
            : member.phoneNumber,
        photoUrl: needsPhoto
            ? (data['pfpURL'] as String? ?? data['photoUrl'] as String?)
            : member.photoUrl,
      );
    } catch (_) {
      return member;
    }
  }

  Future<void> addMember(
    String schoolID,
    String clubID,
    ClubMember member,
  ) async {
    await _membersRef(schoolID, clubID).doc(member.userId).set(member.toMap());
  }

  Future<void> approveClubJoinRequest({
    required String schoolID,
    required String clubID,
    required ClubJoinRequest request,
    required String approverId,
  }) async {
    final batch = _db.batch();
    batch.set(
      _membersRef(schoolID, clubID).doc(request.userId),
      ClubMember(
        userId: request.userId,
        name: request.name.trim().isNotEmpty
            ? request.name.trim()
            : request.email.trim().isNotEmpty
            ? request.email.trim()
            : request.userId,
        role: ClubMember.memberRole,
        subtitle: request.studentId.trim().isNotEmpty
            ? request.studentId.trim()
            : 'Student member',
        email: request.email.trim(),
        photoUrl: request.photoUrl,
      ).toMap(),
    );
    batch.update(_joinRequestsRef(schoolID, clubID).doc(request.id), {
      'status': ClubJoinRequestStatus.approved.name,
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': approverId,
    });
    await batch.commit();
  }

  Future<void> rejectClubJoinRequest({
    required String schoolID,
    required String clubID,
    required ClubJoinRequest request,
    required String approverId,
  }) async {
    await _joinRequestsRef(schoolID, clubID).doc(request.id).update({
      'status': ClubJoinRequestStatus.rejected.name,
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': approverId,
    });
  }

  Future<void> updateMemberRole({
    required String schoolID,
    required String clubID,
    required String userID,
    required String role,
  }) async {
    final normalizedRole = ClubRole.editableRoles.contains(role)
        ? role
        : ClubMember.memberRole;
    await _membersRef(schoolID, clubID).doc(userID).update({
      'role': normalizedRole,
      'permissions': ClubRole.permissionsFor(normalizedRole).toList()..sort(),
      'isImportant': normalizedRole != ClubMember.memberRole,
    });
  }

  Future<void> removeMember(
    String schoolID,
    String clubID,
    String userID,
  ) async {
    await _membersRef(schoolID, clubID).doc(userID).delete();
  }

  CollectionReference<Map<String, dynamic>> _postsRef(
    String schoolID,
    String clubID,
  ) {
    return _clubsRef(schoolID).doc(clubID).collection('Posts');
  }

  Stream<List<ClubPostEntry>> getPosts(String schoolID, String clubID) {
    if (QuiltFirebaseOptions.isDemo) {
      return Stream.value(_demoPosts(schoolID, clubID));
    }

    return _postsRef(
      schoolID,
      clubID,
    ).orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs
          .map(
            (doc) => ClubPostEntry.fromMap(
              doc.data(),
              doc.id,
              schoolID: schoolID,
              clubID: clubID,
            ),
          )
          .toList();
    });
  }

  Stream<List<ClubPostEntry>> getPublicPosts(String schoolID, String clubID) {
    if (QuiltFirebaseOptions.isDemo) {
      return Stream.value(
        _demoPosts(schoolID, clubID)
            .where((post) => post.visibility == ClubPostEntry.publicVisibility)
            .toList(),
      );
    }

    return _postsRef(schoolID, clubID)
        .where('visibility', isEqualTo: ClubPostEntry.publicVisibility)
        .snapshots()
        .map((snapshot) {
          final posts = snapshot.docs
              .map(
                (doc) => ClubPostEntry.fromMap(
                  doc.data(),
                  doc.id,
                  schoolID: schoolID,
                  clubID: clubID,
                ),
              )
              .toList();
          posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return posts;
        });
  }

  Stream<List<ClubPostEntry>> getSchoolVisiblePosts(
    String schoolID,
    String clubID,
  ) {
    if (QuiltFirebaseOptions.isDemo) {
      return Stream.value(
        _demoPosts(schoolID, clubID)
            .where(
              (post) =>
                  post.visibility == ClubPostEntry.publicVisibility ||
                  post.visibility == ClubPostEntry.schoolMembersVisibility,
            )
            .toList(),
      );
    }

    return _postsRef(
      schoolID,
      clubID,
    ).where(_schoolVisibleContentFilter).snapshots().map((snapshot) {
      final posts = snapshot.docs
          .map(
            (doc) => ClubPostEntry.fromMap(
              doc.data(),
              doc.id,
              schoolID: schoolID,
              clubID: clubID,
            ),
          )
          .toList();
      posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return posts;
    });
  }

  Future<List<ClubPostEntry>> getPostsForClubs(
    String schoolID,
    List<String> clubIDs, {
    int perClubLimit = 5,
  }) {
    final scopedClubIDs =
        clubIDs
            .map((clubID) => clubID.trim())
            .where((clubID) => clubID.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    if (scopedClubIDs.isEmpty) return Future.value([]);
    if (QuiltFirebaseOptions.isDemo) {
      final posts = [
        for (final clubID in scopedClubIDs)
          ..._demoPosts(schoolID, clubID).take(perClubLimit),
      ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return Future.value(posts);
    }

    final cacheKey = [
      'club_posts_preview',
      schoolID.trim(),
      perClubLimit,
      scopedClubIDs.join(','),
    ].join(':');
    return _cachedRequest(cacheKey, () async {
      final postGroups = await Future.wait(
        scopedClubIDs.map((clubID) async {
          final clubFuture = _clubsRef(schoolID).doc(clubID).get();
          final postsFuture = _postsRef(
            schoolID,
            clubID,
          ).orderBy('createdAt', descending: true).limit(perClubLimit).get();
          final clubSnapshot = await clubFuture;
          final snapshot = await postsFuture;
          final clubTitle = clubSnapshot.data()?['title'] as String? ?? '';
          return snapshot.docs.map(
            (doc) => ClubPostEntry.fromMap(
              doc.data(),
              doc.id,
              schoolID: schoolID,
              clubID: clubID,
              clubTitle: clubTitle,
            ),
          );
        }),
      );

      final allPosts = [for (final group in postGroups) ...group];

      allPosts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return allPosts;
    });
  }

  Future<List<ClubPostEntry>> getPostsForJoinedClubs(
    UserProfile profile, {
    int perClubLimit = 5,
  }) async {
    final schoolID = profile.schoolID.trim();
    final uid = profile.UID.trim();
    if (schoolID.isEmpty || uid.isEmpty) return const [];

    final clubs = await getClubsOnce(schoolID);
    final joinedClubIDs = await getMembershipClubIds(
      schoolID,
      uid,
      clubs.map((club) => club.id),
      ttl: Duration.zero,
      forceRefresh: true,
    );
    final posts = await getPostsForClubs(
      schoolID,
      joinedClubIDs.toList(),
      perClubLimit: perClubLimit,
    );
    return posts
        .where((post) => !profile.blockedUserIds.contains(post.authorId))
        .toList();
  }

  Future<void> createPost(
    String schoolID,
    String clubID,
    ClubPostEntry post,
  ) async {
    ContentSafety.validatePost(title: post.title, body: post.body);
    final batch = _db.batch();

    final postRef = _postsRef(schoolID, clubID).doc();
    batch.set(postRef, post.toMap());

    final rateLimitRef = _db.collection('RateLimits').doc(post.authorId);
    batch.set(rateLimitRef, {
      'lastPostTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> createPostWithAttachments({
    required String schoolID,
    required String clubID,
    required String title,
    required String body,
    required String authorId,
    required String authorName,
    String? authorPhotoUrl,
    String clubTitle = '',
    String visibility = ClubPostEntry.schoolMembersVisibility,
    List<UploadFileData> files = const [],
  }) async {
    ContentSafety.validatePost(title: title, body: body);
    final attachments = <PostAttachment>[];

    for (final file in files) {
      attachments.add(
        await _uploadPostAttachment(
          schoolID: schoolID,
          clubID: clubID,
          authorId: authorId,
          file: file,
        ),
      );
    }

    await createPost(
      schoolID,
      clubID,
      ClubPostEntry(
        id: '',
        schoolID: schoolID,
        clubID: clubID,
        clubTitle: clubTitle,
        title: title,
        authorId: authorId,
        authorName: authorName,
        authorPhotoUrl: authorPhotoUrl,
        body: body,
        visibility: visibility,
        timestamp: DateTime.now(),
        attachments: attachments,
      ),
    );
  }

  Future<void> deletePost(String schoolID, String clubID, String postID) async {
    await _postsRef(schoolID, clubID).doc(postID).delete();
  }

  Future<ClubPostEntry> acknowledgePost({
    required String schoolID,
    required String clubID,
    required ClubPostEntry post,
    required UserProfile user,
  }) async {
    final resolvedSchoolID = schoolID.trim().isNotEmpty
        ? schoolID.trim()
        : post.schoolID.trim();
    final resolvedClubID = clubID.trim().isNotEmpty
        ? clubID.trim()
        : post.clubID.trim();
    if (resolvedSchoolID.isEmpty || resolvedClubID.isEmpty || post.id.isEmpty) {
      throw ArgumentError('Post is missing school, club, or post information.');
    }

    final postRef = _postsRef(resolvedSchoolID, resolvedClubID).doc(post.id);
    final updatedPost = await _db.runTransaction<ClubPostEntry>((
      transaction,
    ) async {
      final snapshot = await transaction.get(postRef);
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw StateError('Post no longer exists.');
      }

      final currentPost = ClubPostEntry.fromMap(
        data,
        snapshot.id,
        schoolID: resolvedSchoolID,
        clubID: resolvedClubID,
        clubTitle: post.clubTitle,
      );
      final acknowledgements = [...currentPost.acknowledgements];
      if (!currentPost.acknowledgedBy(user.UID)) {
        final displayName = user.displayName.trim().isNotEmpty
            ? user.displayName.trim()
            : user.realName.trim().isNotEmpty
            ? user.realName.trim()
            : 'Member';
        acknowledgements.add(
          PostAcknowledgement(
            uid: user.UID,
            displayName: displayName,
            photoUrl: user.pfpURL,
            acknowledgedAt: _clock(),
          ),
        );
        transaction.update(postRef, {
          'acknowledgements': acknowledgements
              .map((acknowledgement) => acknowledgement.toMap())
              .toList(),
        });
      }

      return currentPost.copyWith(acknowledgements: acknowledgements);
    });

    _requestCache.removeWhere(
      (key, _) => key.startsWith('club_posts_preview:$resolvedSchoolID:'),
    );
    return updatedPost;
  }

  CollectionReference<Map<String, dynamic>> _moderationReportsRef(
    String schoolID,
  ) {
    return _db
        .collection('Schools')
        .doc(schoolID)
        .collection('ModerationReports');
  }

  Future<void> reportPost({
    required String schoolID,
    required String clubID,
    required ClubPostEntry post,
    required UserProfile reporter,
    required String reason,
    String details = '',
    String clubTitle = '',
  }) async {
    await _moderationReportsRef(schoolID).add(
      ModerationReport(
        id: '',
        schoolID: schoolID,
        clubID: clubID,
        clubTitle: clubTitle,
        postID: post.id,
        postTitle: post.title,
        postBody: post.body,
        postAuthorId: post.authorId,
        postAuthorName: post.authorName,
        reporterId: reporter.UID,
        reporterName: reporter.displayName.isNotEmpty
            ? reporter.displayName
            : reporter.realName,
        reporterEmail: reporter.email,
        reason: reason,
        details: details,
        createdAt: DateTime.now(),
      ).toMap(),
    );
  }

  Future<PostAttachment> _uploadPostAttachment({
    required String schoolID,
    required String clubID,
    required String authorId,
    required UploadFileData file,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = _safeFileName(file.fileName);
    final storagePath =
        'schools/$schoolID/clubs/$clubID/posts/$authorId/${timestamp}_$fileName';
    final uploaded = await _uploadBinary(storagePath: storagePath, file: file);

    return PostAttachment(
      type: _attachmentTypeForMime(file.mimeType, file.fileName),
      label: file.fileName,
      url: uploaded.url,
      mimeType: file.mimeType,
      sizeBytes: file.sizeBytes,
      storagePath: uploaded.storagePath,
    );
  }

  Future<_UploadedBinary> _uploadBinary({
    required String storagePath,
    required UploadFileData file,
  }) async {
    final ref = _storage.ref(storagePath);
    final metadata = SettableMetadata(
      contentType: file.mimeType,
      customMetadata: {'originalFileName': file.fileName},
    );
    await ref.putData(file.bytes, metadata);
    final url = await ref.getDownloadURL();
    return _UploadedBinary(url: url, storagePath: ref.fullPath);
  }

  PostAttachmentType _attachmentTypeForMime(String mimeType, String fileName) {
    if (mimeType.startsWith('image/')) {
      return PostAttachmentType.image;
    }
    if (mimeType == 'application/pdf' ||
        fileName.toLowerCase().endsWith('.pdf')) {
      return PostAttachmentType.pdf;
    }
    return PostAttachmentType.link;
  }

  String _safeFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  // -------------------------------------------------------------
  // POLLS
  // -------------------------------------------------------------
  CollectionReference<Map<String, dynamic>> _pollsRef(
    String schoolID,
    String clubID,
  ) {
    return _clubsRef(schoolID).doc(clubID).collection('Polls');
  }

  Stream<List<ClubPoll>> getPolls(String schoolID, String clubID) {
    if (QuiltFirebaseOptions.isDemo) {
      return Stream.value(_demoPolls(clubID));
    }

    return _pollsRef(
      schoolID,
      clubID,
    ).orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ClubPoll.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Stream<List<ClubPoll>> getPublicPolls(String schoolID, String clubID) {
    if (QuiltFirebaseOptions.isDemo) {
      return Stream.value(
        _demoPolls(clubID)
            .where((poll) => poll.visibility == ClubPoll.publicVisibility)
            .toList(),
      );
    }

    return _pollsRef(schoolID, clubID)
        .where('visibility', isEqualTo: ClubPoll.publicVisibility)
        .snapshots()
        .map((snapshot) {
          final polls = snapshot.docs
              .map((doc) => ClubPoll.fromMap(doc.data(), doc.id))
              .toList();
          polls.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return polls;
        });
  }

  Stream<List<ClubPoll>> getSchoolVisiblePolls(String schoolID, String clubID) {
    if (QuiltFirebaseOptions.isDemo) {
      return Stream.value(
        _demoPolls(clubID)
            .where(
              (poll) =>
                  poll.visibility == ClubPoll.publicVisibility ||
                  poll.visibility == ClubPoll.schoolMembersVisibility,
            )
            .toList(),
      );
    }

    return _pollsRef(
      schoolID,
      clubID,
    ).where(_schoolVisibleContentFilter).snapshots().map((snapshot) {
      final polls = snapshot.docs
          .map((doc) => ClubPoll.fromMap(doc.data(), doc.id))
          .toList();
      polls.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return polls;
    });
  }

  Future<void> createPoll(String schoolID, String clubID, ClubPoll poll) async {
    ContentSafety.validatePost(
      title: poll.title,
      body: '${poll.description}\n${poll.options.join('\n')}',
    );
    await _pollsRef(schoolID, clubID).add(poll.toMap());
  }

  Future<void> deletePoll(String schoolID, String clubID, String pollID) async {
    await _pollsRef(schoolID, clubID).doc(pollID).delete();
  }

  Future<void> castVote(
    String schoolID,
    String clubID,
    String pollId,
    String uid,
    dynamic voteData,
  ) async {
    await _db.runTransaction((transaction) async {
      final pollDocRef = _pollsRef(schoolID, clubID).doc(pollId);
      final snapshot = await transaction.get(pollDocRef);
      if (!snapshot.exists) throw Exception('Poll not found');

      final currentVotes = Map<String, dynamic>.from(
        snapshot.data()?['votes'] ?? {},
      );

      currentVotes[uid] = voteData;
      transaction.update(pollDocRef, {'votes': currentVotes});
    });
  }

  CollectionReference<Map<String, dynamic>> _schoolPollsRef(String schoolID) {
    return _db.collection('Schools').doc(schoolID).collection('Polls');
  }

  Stream<List<ClubPoll>> getSchoolPolls(String schoolID) {
    if (QuiltFirebaseOptions.isDemo) {
      return Stream.value([
        ClubPoll(
          id: 'school_lunch_poll',
          creatorId: 'demo_some_guy',
          creatorName: 'School Office',
          title: 'Which lunch pop-up should visit next?',
          description: 'Vote for the next student activity day option.',
          pollType: PollType.single_choice,
          options: const ['Tacos', 'Dumplings', 'Smoothies'],
          votes: const {
            'demo_some_guy': 'Tacos',
            'maya_chen': 'Smoothies',
            'ethan_brooks': 'Tacos',
          },
          visibility: ClubPoll.schoolMembersVisibility,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ]);
    }

    return _schoolPollsRef(
      schoolID,
    ).orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ClubPoll.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> createSchoolPoll(String schoolID, ClubPoll poll) async {
    await _schoolPollsRef(schoolID).add(poll.toMap());
  }

  Future<void> castSchoolVote(
    String schoolID,
    String pollId,
    String uid,
    dynamic voteData,
  ) async {
    await _db.runTransaction((transaction) async {
      final pollDocRef = _schoolPollsRef(schoolID).doc(pollId);
      final snapshot = await transaction.get(pollDocRef);
      if (!snapshot.exists) throw Exception('Poll not found');

      final currentVotes = Map<String, dynamic>.from(
        snapshot.data()?['votes'] ?? {},
      );
      currentVotes[uid] = voteData;
      transaction.update(pollDocRef, {'votes': currentVotes});
    });
  }

  // -------------------------------------------------------------
  // EVENTS
  // -------------------------------------------------------------
  CollectionReference<Map<String, dynamic>> _clubEventsRef(
    String schoolID,
    String clubID,
  ) {
    return _clubsRef(schoolID).doc(clubID).collection('Events');
  }

  Query<Map<String, dynamic>> _schoolVisibleEventsQuery(String schoolID) {
    return _db
        .collectionGroup('Events')
        .where('schoolID', isEqualTo: schoolID)
        .where('status', isEqualTo: PlatformEvent.approvedStatus)
        .where(_schoolVisibleContentFilter);
  }

  Future<void> createClubEvent(
    String schoolID,
    String clubID,
    PlatformEvent event,
  ) async {
    ContentSafety.validatePost(
      title: event.title,
      body: '${event.description}\n${event.location}',
    );
    await _clubEventsRef(schoolID, clubID).add(event.toMap());
  }

  Stream<List<PlatformEvent>> getEvents(String schoolID) {
    if (QuiltFirebaseOptions.isDemo) {
      final events = _demoEvents(schoolID)
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      return Stream.value(events);
    }

    return _schoolVisibleEventsQuery(schoolID).snapshots().map((snapshot) {
      final events = snapshot.docs
          .map((doc) => PlatformEvent.fromMap(doc.data(), doc.id))
          .toList();
      events.sort((a, b) => a.startTime.compareTo(b.startTime));
      return events;
    });
  }

  Future<int> getTodayEventCount(String schoolID, {DateTime? date}) {
    final target = date ?? _clock();
    final start = DateTime(target.year, target.month, target.day);
    final end = start.add(const Duration(days: 1));
    if (QuiltFirebaseOptions.isDemo) {
      return Future.value(
        _demoEvents(schoolID)
            .where(
              (event) =>
                  !event.startTime.isBefore(start) &&
                  event.startTime.isBefore(end),
            )
            .length,
      );
    }

    final cacheKey = [
      'today_event_count',
      schoolID.trim(),
      start.toIso8601String(),
    ].join(':');

    return _cachedRequest(cacheKey, () async {
      final dayQuery = _schoolVisibleEventsQuery(schoolID)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('startTime', isLessThan: Timestamp.fromDate(end));

      try {
        final snapshot = await dayQuery.count().get();
        return snapshot.count ?? 0;
      } catch (_) {
        final snapshot = await _schoolVisibleEventsQuery(schoolID).get();
        return snapshot.docs.where((doc) {
          final event = PlatformEvent.fromMap(doc.data(), doc.id);
          return !event.startTime.isBefore(start) &&
              event.startTime.isBefore(end);
        }).length;
      }
    }, ttl: const Duration(minutes: 5));
  }

  Stream<List<PlatformEvent>> getCalendarEvents(
    String schoolID,
    Iterable<String> memberClubIDs,
  ) {
    return Stream.fromFuture(getCalendarEventsOnce(schoolID, memberClubIDs));
  }

  Future<List<PlatformEvent>> getCalendarEventsOnce(
    String schoolID,
    Iterable<String> memberClubIDs, {
    DateTime? startAt,
    int? perSourceLimit,
  }) {
    final clubIDs =
        memberClubIDs
            .map((clubID) => clubID.trim())
            .where((clubID) => clubID.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    if (QuiltFirebaseOptions.isDemo) {
      final allowedClubIDs = clubIDs.toSet();
      final events =
          _demoEvents(schoolID)
              .where(
                (event) =>
                    event.clubID.isEmpty ||
                    allowedClubIDs.contains(event.clubID),
              )
              .where(
                (event) =>
                    startAt == null || !event.startTime.isBefore(startAt),
              )
              .toList()
            ..sort((a, b) => a.startTime.compareTo(b.startTime));
      return Future.value(
        perSourceLimit == null ? events : events.take(perSourceLimit).toList(),
      );
    }

    final cacheKey = [
      'calendar_events_once',
      schoolID.trim(),
      startAt?.toIso8601String() ?? 'all',
      perSourceLimit ?? 'all',
      clubIDs.join(','),
    ].join(':');
    return _cachedRequest(
      cacheKey,
      () => _fetchCalendarEventsOnce(
        schoolID,
        clubIDs,
        startAt: startAt,
        perSourceLimit: perSourceLimit,
      ),
      ttl: const Duration(minutes: 2),
    );
  }

  Future<List<PlatformEvent>> _fetchCalendarEventsOnce(
    String schoolID,
    List<String> clubIDs, {
    DateTime? startAt,
    int? perSourceLimit,
  }) async {
    final byKey = <String, PlatformEvent>{};

    var schoolQuery = _schoolVisibleEventsQuery(schoolID);
    if (startAt != null) {
      schoolQuery = schoolQuery
          .where(
            'startTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startAt),
          )
          .orderBy('startTime');
    }
    if (perSourceLimit != null) {
      schoolQuery = schoolQuery.limit(perSourceLimit);
    }

    QuerySnapshot<Map<String, dynamic>> schoolSnapshot;
    try {
      schoolSnapshot = await schoolQuery.get();
    } catch (_) {
      if (startAt == null) rethrow;
      schoolSnapshot = await _schoolVisibleEventsQuery(schoolID).get();
    }
    for (final doc in schoolSnapshot.docs) {
      final event = PlatformEvent.fromMap(doc.data(), doc.id);
      if (startAt != null && event.startTime.isBefore(startAt)) continue;
      byKey['${event.schoolID}/${event.clubID.trim()}/${event.id}'] = event;
    }

    for (final clubID in clubIDs) {
      try {
        var clubQuery = _clubEventsRef(
          schoolID,
          clubID,
        ).where('status', isEqualTo: PlatformEvent.approvedStatus);
        if (startAt != null) {
          clubQuery = clubQuery
              .where(
                'startTime',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startAt),
              )
              .orderBy('startTime');
        }
        if (perSourceLimit != null) {
          clubQuery = clubQuery.limit(perSourceLimit);
        }
        QuerySnapshot<Map<String, dynamic>> clubSnapshot;
        try {
          clubSnapshot = await clubQuery.get();
        } catch (_) {
          if (startAt == null) rethrow;
          clubSnapshot = await _clubEventsRef(
            schoolID,
            clubID,
          ).where('status', isEqualTo: PlatformEvent.approvedStatus).get();
        }
        for (final doc in clubSnapshot.docs) {
          final event = PlatformEvent.fromMap(doc.data(), doc.id);
          if (startAt != null && event.startTime.isBefore(startAt)) continue;
          byKey['${event.schoolID}/${event.clubID.trim()}/${event.id}'] = event;
        }
      } catch (_) {
        // Keep loading events from other clubs the user can read.
      }
    }

    final events = byKey.values.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return events;
  }

  Stream<List<PlatformEvent>> getClubEvents(String schoolID, String clubID) {
    if (QuiltFirebaseOptions.isDemo) {
      final events = _demoEvents(schoolID, clubID: clubID)
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      return Stream.value(events);
    }

    return _clubEventsRef(schoolID, clubID)
        .where('status', isEqualTo: PlatformEvent.approvedStatus)
        .snapshots()
        .map((snapshot) {
          final events = snapshot.docs
              .map((doc) => PlatformEvent.fromMap(doc.data(), doc.id))
              .toList();
          events.sort((a, b) => a.startTime.compareTo(b.startTime));
          return events;
        });
  }

  Stream<List<PlatformEvent>> getSchoolVisibleClubEvents(
    String schoolID,
    String clubID,
  ) {
    if (QuiltFirebaseOptions.isDemo) {
      final events = _demoEvents(schoolID, clubID: clubID)
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      return Stream.value(events);
    }

    return _clubEventsRef(schoolID, clubID)
        .where('status', isEqualTo: PlatformEvent.approvedStatus)
        .where(_schoolVisibleContentFilter)
        .snapshots()
        .map((snapshot) {
          final events = snapshot.docs
              .map((doc) => PlatformEvent.fromMap(doc.data(), doc.id))
              .toList();
          events.sort((a, b) => a.startTime.compareTo(b.startTime));
          return events;
        });
  }

  Stream<List<PlatformEvent>> getEventSubmissions(
    String schoolID,
    String creatorId,
  ) {
    return Stream.value(
      _demoEvents(
        schoolID,
      ).where((event) => event.creatorId == creatorId).toList(),
    );
  }

  Future<PlatformEvent> attendEvent(
    String schoolID,
    String clubID,
    String eventId,
    String uid,
  ) async {
    final eventRef = _clubEventsRef(schoolID, clubID).doc(eventId);
    final attendeesRef = eventRef.collection('Attendees').doc(uid);
    final student = await getUser(uid);
    if (student == null) {
      throw StateError('Student profile not found.');
    }
    if (!_hasConnectedParent(student)) {
      throw StateError(
        'Connect a parent or guardian before checking in to club events.',
      );
    }

    late final PlatformEvent event;
    await _db.runTransaction((transaction) async {
      final docCount = await transaction.get(attendeesRef);
      if (docCount.exists) throw Exception('Already checked into this event.');

      final eventDoc = await transaction.get(eventRef);
      if (!eventDoc.exists) throw Exception('Event not found.');
      event = PlatformEvent.fromMap(eventDoc.data() ?? {}, eventDoc.id);

      transaction.set(attendeesRef, {
        'uid': uid,
        'name': student.realName.trim().isNotEmpty
            ? student.realName.trim()
            : student.displayName.trim(),
        if (student.email.trim().isNotEmpty) 'email': student.email.trim(),
        if ((student.pfpURL ?? '').trim().isNotEmpty)
          'photoUrl': student.pfpURL,
        'status': 'going',
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
    await _createParentEventSignupNotifications(event: event, student: student);
    return event;
  }

  CollectionReference<Map<String, dynamic>> _notificationsRef(String uid) {
    return _userDoc(uid).collection('Notifications');
  }

  Stream<List<AppNotification>> watchNotifications(
    String uid, {
    int limit = 50,
  }) {
    return Stream.value(<AppNotification>[]);
  }

  Future<void> markNotificationRead({
    required String uid,
    required String notificationId,
  }) {
    return _notificationsRef(
      uid,
    ).doc(notificationId).update({'readAt': FieldValue.serverTimestamp()});
  }

  Future<List<ParentSignedUpEvent>> getSignedUpEventsForParent(
    UserProfile parent, {
    UserProfile? student,
    bool upcomingOnly = false,
    int? eventScanLimit,
  }) {
    final explicitStudentIds = _linkedStudentIdsFor(parent)..sort();
    final cacheKey = [
      'parent_signed_events',
      parent.UID,
      student?.UID ?? 'all',
      explicitStudentIds.join(','),
      upcomingOnly,
      eventScanLimit ?? 'all',
    ].join(':');
    return _cachedRequest(
      cacheKey,
      () => _fetchSignedUpEventsForParent(
        parent,
        student: student,
        upcomingOnly: upcomingOnly,
        eventScanLimit: eventScanLimit,
      ),
    );
  }

  Future<List<ParentSignedUpEvent>> _fetchSignedUpEventsForParent(
    UserProfile parent, {
    UserProfile? student,
    required bool upcomingOnly,
    int? eventScanLimit,
  }) async {
    final students = await getStudentsForParent(parent);
    final visibleStudents = student == null
        ? students
        : students.where((linkedStudent) => linkedStudent.UID == student.UID);
    if (visibleStudents.isEmpty) return const [];

    final studentsBySchool = <String, List<UserProfile>>{};
    for (final visibleStudent in visibleStudents) {
      final schoolID = visibleStudent.schoolID.trim();
      if (schoolID.isEmpty) continue;
      studentsBySchool.putIfAbsent(schoolID, () => []).add(visibleStudent);
    }
    final signedUpEvents = <String, ParentSignedUpEvent>{};
    final startAt = upcomingOnly ? _clock() : null;
    for (final entry in studentsBySchool.entries) {
      try {
        var eventQuery = _db
            .collectionGroup('Events')
            .where('schoolID', isEqualTo: entry.key)
            .where('status', isEqualTo: PlatformEvent.approvedStatus);
        if (startAt != null) {
          eventQuery = eventQuery
              .where(
                'startTime',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startAt),
              )
              .orderBy('startTime');
        }
        if (eventScanLimit != null) {
          eventQuery = eventQuery.limit(eventScanLimit);
        }

        QuerySnapshot<Map<String, dynamic>> eventSnapshot;
        try {
          eventSnapshot = await eventQuery.get();
        } catch (_) {
          if (startAt == null) rethrow;
          eventSnapshot = await _db
              .collectionGroup('Events')
              .where('schoolID', isEqualTo: entry.key)
              .where('status', isEqualTo: PlatformEvent.approvedStatus)
              .get();
        }
        for (final eventDoc in eventSnapshot.docs) {
          final event = PlatformEvent.fromMap(eventDoc.data(), eventDoc.id);
          if (startAt != null && event.startTime.isBefore(startAt)) continue;
          if (event.clubID.trim().isEmpty) continue;
          for (final student in entry.value) {
            final attendeeDoc = await _eventAttendeesRef(
              event.schoolID,
              event.clubID,
              event.id,
            ).doc(student.UID).get();
            final attendeeData = attendeeDoc.data();
            if (!attendeeDoc.exists || attendeeData == null) continue;
            final attendee = EventParticipant.fromMap(
              attendeeData,
              attendeeDoc.id,
            );
            final studentName = student.realName.trim().isNotEmpty
                ? student.realName.trim()
                : student.displayName.trim();
            signedUpEvents['${student.UID}:${event.schoolID}:${event.clubID}:${event.id}'] =
                ParentSignedUpEvent(
                  event: event,
                  studentUid: student.UID,
                  student: studentName.isNotEmpty ? studentName : attendee.name,
                  signupTime: attendee.timestamp,
                );
          }
        }
      } catch (_) {
        // Keep aggregating events the parent is allowed to read.
      }
    }

    final events = signedUpEvents.values.toList()
      ..sort((a, b) => a.event.startTime.compareTo(b.event.startTime));
    return events;
  }

  Future<List<PlatformEvent>> getSignedUpEventsForStudent(
    UserProfile student, {
    bool upcomingOnly = false,
    int? eventScanLimit,
  }) {
    return Future.value(
      _demoEvents(student.schoolID)
          .where(
            (event) =>
                event.clubID == 'robotics_team' &&
                (!upcomingOnly || event.startTime.isAfter(_clock())),
          )
          .toList(),
    );
  }

  Future<List<PlatformEvent>> _fetchSignedUpEventsForStudent(
    UserProfile student, {
    required bool upcomingOnly,
    int? eventScanLimit,
  }) async {
    final schoolID = student.schoolID.trim();
    if (schoolID.isEmpty) return const [];

    final clubs = await getClubsOnce(schoolID);
    final memberClubIDs = await getMembershipClubIds(
      schoolID,
      student.UID,
      clubs.map((club) => club.id),
    );
    final events = await getCalendarEventsOnce(
      schoolID,
      memberClubIDs,
      startAt: upcomingOnly ? _clock() : null,
      perSourceLimit: eventScanLimit,
    );
    final signedUpEvents = <String, PlatformEvent>{};

    for (final event in events) {
      if (event.clubID.trim().isEmpty) continue;
      try {
        final attendeeDoc = await _eventAttendeesRef(
          event.schoolID,
          event.clubID,
          event.id,
        ).doc(student.UID).get();
        if (attendeeDoc.exists) {
          signedUpEvents['${event.schoolID}:${event.clubID}:${event.id}'] =
              event;
        }
      } catch (_) {
        // Keep checking any events the student can read.
      }
    }

    final signedUp = signedUpEvents.values.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return signedUp;
  }

  Future<List<ParentVolunteeredEvent>> getVolunteeredEventsForParent(
    UserProfile parent, {
    bool upcomingOnly = false,
    int? eventScanLimit,
  }) {
    final cacheKey = [
      'parent_volunteered_events',
      parent.UID,
      upcomingOnly,
      eventScanLimit ?? 'all',
    ].join(':');
    return _cachedRequest(
      cacheKey,
      () => _fetchVolunteeredEventsForParent(
        parent,
        upcomingOnly: upcomingOnly,
        eventScanLimit: eventScanLimit,
      ),
    );
  }

  Future<List<ParentVolunteeredEvent>> _fetchVolunteeredEventsForParent(
    UserProfile parent, {
    required bool upcomingOnly,
    int? eventScanLimit,
  }) async {
    if (!parent.isParent) return const [];

    final students = await getStudentsForParent(parent);
    final schoolIDs = students
        .map((student) => student.schoolID.trim())
        .where((schoolID) => schoolID.isNotEmpty)
        .toSet();
    final volunteeredEvents = <String, ParentVolunteeredEvent>{};
    final startAt = upcomingOnly ? _clock() : null;

    for (final schoolID in schoolIDs) {
      try {
        var eventQuery = _db
            .collectionGroup('Events')
            .where('schoolID', isEqualTo: schoolID)
            .where('status', isEqualTo: PlatformEvent.approvedStatus);
        if (startAt != null) {
          eventQuery = eventQuery
              .where(
                'startTime',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startAt),
              )
              .orderBy('startTime');
        }
        if (eventScanLimit != null) {
          eventQuery = eventQuery.limit(eventScanLimit);
        }

        QuerySnapshot<Map<String, dynamic>> eventSnapshot;
        try {
          eventSnapshot = await eventQuery.get();
        } catch (_) {
          if (startAt == null) rethrow;
          eventSnapshot = await _db
              .collectionGroup('Events')
              .where('schoolID', isEqualTo: schoolID)
              .where('status', isEqualTo: PlatformEvent.approvedStatus)
              .get();
        }
        for (final eventDoc in eventSnapshot.docs) {
          final event = PlatformEvent.fromMap(eventDoc.data(), eventDoc.id);
          if (startAt != null && event.startTime.isBefore(startAt)) continue;
          if (event.clubID.trim().isEmpty) continue;
          final volunteerDoc = await _eventVolunteersRef(
            event.schoolID,
            event.clubID,
            event.id,
          ).doc(parent.UID).get();
          final volunteerData = volunteerDoc.data();
          if (!volunteerDoc.exists || volunteerData == null) continue;
          final volunteer = EventParticipant.fromMap(
            volunteerData,
            volunteerDoc.id,
          );
          volunteeredEvents['${event.schoolID}:${event.clubID}:${event.id}'] =
              ParentVolunteeredEvent(
                event: event,
                volunteerTime: volunteer.timestamp,
              );
        }
      } catch (_) {
        // Keep aggregating events from other schools the parent can read.
      }
    }

    final events = volunteeredEvents.values.toList()
      ..sort((a, b) => a.event.startTime.compareTo(b.event.startTime));
    return events;
  }

  Future<void> _createParentEventSignupNotifications({
    required PlatformEvent event,
    required UserProfile student,
  }) async {
    final parentIds = {
      ...student.parentIds,
      for (final account in student.linkedAccounts)
        if (account.role == UserProfile.parentRole) account.uid,
    }.where((id) => id.trim().isNotEmpty && id != student.UID).toList();
    if (parentIds.isEmpty) return;

    final studentName = student.realName.trim().isNotEmpty
        ? student.realName.trim()
        : student.displayName.trim();
    final batch = _db.batch();
    var writes = 0;

    for (final parentId in parentIds) {
      try {
        final parent = await getUser(parentId);
        if (parent == null || !parent.eventSignupNotificationsEnabled) {
          continue;
        }
        final notification = AppNotification(
          id: '',
          recipientUid: parentId,
          title: 'Event signup',
          body:
              '${studentName.isNotEmpty ? studentName : 'Your student'} signed up for ${event.title.trim().isNotEmpty ? event.title.trim() : 'an event'}.',
          type: AppNotification.eventSignupType,
          schoolID: event.schoolID,
          clubID: event.clubID,
          eventID: event.id,
          childUid: student.UID,
          childName: studentName,
        );
        batch.set(
          _notificationsRef(parentId).doc(),
          notification.toCreateMap(),
        );
        writes++;
      } catch (_) {
        // One inaccessible parent profile should not block the signup itself.
      }
    }

    if (writes > 0) {
      try {
        await batch.commit();
      } catch (_) {
        // The signup already succeeded; notification delivery is best-effort.
      }
    }
  }

  CollectionReference<Map<String, dynamic>> _eventAttendeesRef(
    String schoolID,
    String clubID,
    String eventID,
  ) {
    return _clubEventsRef(
      schoolID,
      clubID,
    ).doc(eventID).collection('Attendees');
  }

  CollectionReference<Map<String, dynamic>> _eventVolunteersRef(
    String schoolID,
    String clubID,
    String eventID,
  ) {
    return _clubEventsRef(
      schoolID,
      clubID,
    ).doc(eventID).collection('Volunteers');
  }

  Stream<List<EventParticipant>> getEventAttendees({
    required String schoolID,
    required String clubID,
    required String eventID,
  }) {
    return Stream.value(<EventParticipant>[]);
  }

  Stream<List<EventParticipant>> getEventVolunteers({
    required String schoolID,
    required String clubID,
    required String eventID,
  }) {
    return Stream.value(<EventParticipant>[]);
  }

  Future<void> volunteerForEvent({
    required String schoolID,
    required String clubID,
    required String eventID,
    required UserProfile parent,
  }) async {
    if (!parent.isParent) {
      throw StateError('Only parent accounts can volunteer for events.');
    }
    if (parent.studentUids.isEmpty && parent.parentStudentIds.isEmpty) {
      throw StateError('Connect a student before volunteering.');
    }

    final volunteerRef = _eventVolunteersRef(
      schoolID,
      clubID,
      eventID,
    ).doc(parent.UID);
    await volunteerRef.set({
      'uid': parent.UID,
      'name': parent.realName.trim().isNotEmpty
          ? parent.realName.trim()
          : parent.displayName.trim(),
      if (parent.email.trim().isNotEmpty) 'email': parent.email.trim(),
      if ((parent.pfpURL ?? '').trim().isNotEmpty) 'photoUrl': parent.pfpURL,
      'status': 'chaperone',
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  bool _hasConnectedParent(UserProfile student) {
    if (student.parentIds.isNotEmpty) return true;
    return student.linkedAccounts.any(
      (account) => account.role == UserProfile.parentRole,
    );
  }

  // -------------------------------------------------------------
  // HALL PASSES
  // -------------------------------------------------------------
  CollectionReference<Map<String, dynamic>> _hallPassesRef(String schoolID) {
    return _db.collection('Schools').doc(schoolID).collection('HallPasses');
  }

  Stream<HallPass?> getActiveHallPass(String schoolID, String uid) {
    if (QuiltFirebaseOptions.isDemo) {
      return Stream.value(null);
    }

    return _hallPassesRef(schoolID)
        .where('studentId', isEqualTo: uid)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return HallPass.fromMap(
            snapshot.docs.first.data(),
            snapshot.docs.first.id,
          );
        });
  }

  Future<HallPassScanResult> toggleHallPass(
    String schoolID,
    String uid,
    String roomId,
  ) async {
    final normalizedRoomId = roomId.trim();
    if (normalizedRoomId.isEmpty) {
      throw ArgumentError('Room QR code is missing a room.');
    }

    final activePassesQuery = await _hallPassesRef(schoolID)
        .where('studentId', isEqualTo: uid)
        .where('isActive', isEqualTo: true)
        .get();

    final batch = _db.batch();
    late final HallPassScanResult result;

    if (activePassesQuery.docs.isNotEmpty) {
      final activePass = HallPass.fromMap(
        activePassesQuery.docs.first.data(),
        activePassesQuery.docs.first.id,
      );
      if (activePass.roomId.trim() != normalizedRoomId) {
        throw StateError(
          'You have an active hall pass for Room ${activePass.roomId}. '
          'Scan that room QR to return it first.',
        );
      }
      // Close active pass
      final activePassId = activePassesQuery.docs.first.id;
      final ref = _hallPassesRef(schoolID).doc(activePassId);
      batch.update(ref, {
        'isActive': false,
        'returnTime': FieldValue.serverTimestamp(),
      });
      result = HallPassScanResult(
        action: HallPassScanAction.returned,
        roomId: normalizedRoomId,
      );
    } else {
      // Create new pass
      final ref = _hallPassesRef(schoolID).doc();
      batch.set(ref, {
        'studentId': uid,
        'roomId': normalizedRoomId,
        'departTime': FieldValue.serverTimestamp(),
        'returnTime': null,
        'isActive': true,
      });
      result = HallPassScanResult(
        action: HallPassScanAction.started,
        roomId: normalizedRoomId,
      );
    }

    await batch.commit();
    return result;
  }

  // -------------------------------------------------------------
  // CLUB REQUESTS
  // -------------------------------------------------------------
  CollectionReference<Map<String, dynamic>> _clubRequestsRef(String schoolID) {
    return _db.collection('Schools').doc(schoolID).collection('ClubRequests');
  }

  Future<void> submitClubRequest(String schoolID, ClubRequest request) async {
    await _clubRequestsRef(schoolID).add(request.toMap());
  }

  // -------------------------------------------------------------
  // ATTENDANCE
  // -------------------------------------------------------------
  Future<void> attendClubEvent(
    String schoolID,
    String clubID,
    String uid,
  ) async {
    final attendanceRef = _clubsRef(
      schoolID,
    ).doc(clubID).collection('Attendance').doc(uid);

    await _db.runTransaction((transaction) async {
      final doc = await transaction.get(attendanceRef);
      if (doc.exists) {
        transaction.update(attendanceRef, {
          'lastAttended': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.set(attendanceRef, {
          'firstAttended': FieldValue.serverTimestamp(),
          'lastAttended': FieldValue.serverTimestamp(),
        });
      }
    });
  }
}

class _TimeParts {
  const _TimeParts(this.hour, this.minute);

  final int hour;
  final int minute;
}

class _BellScheduleCacheEntry {
  const _BellScheduleCacheEntry({
    required this.schedule,
    required this.expiresAt,
  });

  final BellSchedule? schedule;
  final DateTime expiresAt;
}

class _FutureCacheEntry<T> {
  const _FutureCacheEntry({required this.future, required this.expiresAt});

  final Future<T> future;
  final DateTime expiresAt;
}

class _UploadedBinary {
  const _UploadedBinary({required this.url, required this.storagePath});

  final String url;
  final String storagePath;
}
