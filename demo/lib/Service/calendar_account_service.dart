import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../Models/platform_event.dart';
import '../Models/user.dart';
import '../Utility/calendar_links.dart';
import 'auth_service.dart';
import 'firebase_service.dart';

class CalendarAccountService {
  CalendarAccountService(
    this._authService,
    this._firebaseService, {
    http.Client? client,
  }) : _client = client,
       _googleAuthorizationHeadersOverride = null,
       _saveUserProfileOverride = null;

  @visibleForTesting
  CalendarAccountService.testing({
    required GoogleAuthorizationHeadersProvider googleAuthorizationHeaders,
    required UserProfileSaver saveUserProfile,
    http.Client? client,
  }) : _authService = null,
       _firebaseService = null,
       _googleAuthorizationHeadersOverride = googleAuthorizationHeaders,
       _saveUserProfileOverride = saveUserProfile,
       _client = client;

  static const String calendarName = 'Quilt Club Events';
  static const String googleCalendarScope =
      'https://www.googleapis.com/auth/calendar.app.created';
  static const String googleCalendarListScope =
      'https://www.googleapis.com/auth/calendar.calendarlist.readonly';
  static const MethodChannel _appleCalendarChannel = MethodChannel(
    'quilt/calendar',
  );

  final AuthService? _authService;
  final FirebaseService? _firebaseService;
  final http.Client? _client;
  final GoogleAuthorizationHeadersProvider? _googleAuthorizationHeadersOverride;
  final UserProfileSaver? _saveUserProfileOverride;
  Future<String>? _googleCalendarSetup;

  Future<UserProfile> connectGoogleCalendar(UserProfile profile) async {
    final calendarId = await _googleCalendarIdForProfile(
      profile,
      promptIfNecessary: true,
    );

    if (calendarId == profile.googleCalendarId.trim()) {
      return profile;
    }

    final updated = profile.copyWith(googleCalendarId: calendarId);
    await _saveUserProfile(updated);
    return updated;
  }

  Future<void> addEventToGoogleCalendar(
    UserProfile profile,
    PlatformEvent event, {
    bool promptIfNecessary = false,
  }) async {
    if (profile.googleCalendarId.trim().isEmpty && !promptIfNecessary) {
      throw const CalendarIntegrationException(
        'Connect Google Calendar in Settings first.',
      );
    }

    var connectedProfile = profile.googleCalendarId.trim().isEmpty
        ? await connectGoogleCalendar(profile)
        : profile;
    var response = await _insertGoogleEvent(
      calendarId: connectedProfile.googleCalendarId,
      event: event,
      promptIfNecessary: promptIfNecessary,
    );

    if (response.statusCode == 404) {
      final newCalendarId = await _findOrCreateGoogleCalendar(
        promptIfNecessary: promptIfNecessary,
      );
      connectedProfile = connectedProfile.copyWith(
        googleCalendarId: newCalendarId,
      );
      await _saveUserProfile(connectedProfile);
      response = await _insertGoogleEvent(
        calendarId: connectedProfile.googleCalendarId,
        event: event,
        promptIfNecessary: promptIfNecessary,
      );
    }

    if (response.statusCode == 409) {
      response = await _updateGoogleEvent(
        calendarId: connectedProfile.googleCalendarId,
        event: event,
        promptIfNecessary: promptIfNecessary,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CalendarIntegrationException(_googleErrorMessage(response));
    }
  }

  Future<int> addEventToConnectedCalendars(
    UserProfile profile,
    PlatformEvent event,
  ) async {
    var updateCount = 0;
    final errors = <String>[];

    if (profile.googleCalendarId.trim().isNotEmpty) {
      try {
        await addEventToGoogleCalendar(profile, event);
        updateCount++;
      } catch (e) {
        errors.add('Google Calendar: $e');
      }
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await addEventToAppleCalendar(event);
        updateCount++;
      } catch (e) {
        errors.add('Apple Calendar: ${_appleErrorMessage(e)}');
      }
    }

    if (updateCount == 0) {
      if (errors.isNotEmpty) {
        throw CalendarIntegrationException(errors.join('\n'));
      }
      throw const CalendarIntegrationException(
        'Connect a calendar in Settings first.',
      );
    }

    if (errors.isNotEmpty) {
      throw CalendarIntegrationException(errors.join('\n'));
    }

    return updateCount;
  }

  Future<void> connectAppleCalendar() {
    return _appleCalendarChannel.invokeMethod<void>('ensureCalendar');
  }

  Future<bool> hasAppleCalendar() async {
    final hasCalendar = await _appleCalendarChannel.invokeMethod<bool>(
      'hasCalendar',
    );
    return hasCalendar ?? false;
  }

  Future<void> addEventToAppleCalendar(PlatformEvent event) {
    return _appleCalendarChannel.invokeMethod<void>('addEvent', {
      'title': event.title,
      'description': CalendarLinks.eventDetails(event),
      'location': event.location.trim(),
      'startMillis': event.startTime.millisecondsSinceEpoch,
      'endMillis': event.startTime
          .add(CalendarLinks.defaultEventDuration)
          .millisecondsSinceEpoch,
      'externalId': event.id,
    });
  }

  Future<String> _googleCalendarIdForProfile(
    UserProfile profile, {
    required bool promptIfNecessary,
  }) async {
    final savedCalendarId = profile.googleCalendarId.trim();
    if (savedCalendarId.isNotEmpty &&
        await _googleCalendarExists(
          savedCalendarId,
          promptIfNecessary: promptIfNecessary,
        )) {
      return savedCalendarId;
    }

    return _findOrCreateGoogleCalendar(promptIfNecessary: promptIfNecessary);
  }

  Future<String> _findOrCreateGoogleCalendar({
    required bool promptIfNecessary,
  }) {
    final setup = _googleCalendarSetup;
    if (setup != null) {
      return setup;
    }

    final nextSetup = _findOrCreateGoogleCalendarOnce(
      promptIfNecessary: promptIfNecessary,
    );
    _googleCalendarSetup = nextSetup;
    nextSetup.whenComplete(() {
      if (identical(_googleCalendarSetup, nextSetup)) {
        _googleCalendarSetup = null;
      }
    });
    return nextSetup;
  }

  Future<String> _findOrCreateGoogleCalendarOnce({
    required bool promptIfNecessary,
  }) async {
    final existingId = await _findExistingGoogleCalendar(
      promptIfNecessary: promptIfNecessary,
    );
    if (existingId != null) {
      return existingId;
    }

    return _createGoogleCalendar(promptIfNecessary: promptIfNecessary);
  }

  Future<bool> _googleCalendarExists(
    String calendarId, {
    required bool promptIfNecessary,
  }) async {
    final response = await _get(
      _googleCalendarUri('calendars', calendarId),
      headers: await _googleHeaders(const [
        googleCalendarScope,
      ], promptIfNecessary: promptIfNecessary),
    );

    if (response.statusCode == 404 || response.statusCode == 410) {
      return false;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CalendarIntegrationException(_googleErrorMessage(response));
    }
    return true;
  }

  Future<String?> _findExistingGoogleCalendar({
    required bool promptIfNecessary,
  }) async {
    Map<String, String> headers;
    try {
      headers = await _googleHeaders(const [
        googleCalendarListScope,
      ], promptIfNecessary: promptIfNecessary);
    } on Object {
      if (promptIfNecessary) {
        rethrow;
      }
      return null;
    }

    String? pageToken;
    do {
      final response = await _get(
        _googleCalendarListUri(pageToken: pageToken),
        headers: headers,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (!promptIfNecessary &&
            (response.statusCode == 401 || response.statusCode == 403)) {
          return null;
        }
        throw CalendarIntegrationException(_googleErrorMessage(response));
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>? ?? const [];
      for (final item in items.whereType<Map<String, dynamic>>()) {
        final summary = (item['summary'] as String? ?? '').trim();
        final id = (item['id'] as String? ?? '').trim();
        final accessRole = item['accessRole'] as String?;
        final deleted = item['deleted'] == true;
        if (!deleted &&
            summary == calendarName &&
            id.isNotEmpty &&
            (accessRole == 'owner' || accessRole == 'writer')) {
          return id;
        }
      }
      pageToken = data['nextPageToken'] as String?;
    } while (pageToken != null && pageToken.trim().isNotEmpty);

    return null;
  }

  Future<String> _createGoogleCalendar({
    required bool promptIfNecessary,
  }) async {
    final response = await _post(
      _googleCalendarUri('calendars'),
      headers: await _googleHeaders(const [
        googleCalendarScope,
      ], promptIfNecessary: promptIfNecessary),
      body: jsonEncode({
        'summary': calendarName,
        'description': 'Club events saved from Quilt.',
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CalendarIntegrationException(_googleErrorMessage(response));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final id = data['id'] as String?;
    if (id == null || id.trim().isEmpty) {
      throw const CalendarIntegrationException(
        'Google did not return a calendar ID.',
      );
    }
    return id;
  }

  Future<http.Response> _insertGoogleEvent({
    required String calendarId,
    required PlatformEvent event,
    required bool promptIfNecessary,
  }) async {
    return _post(
      _googleCalendarUri('calendars', calendarId, 'events'),
      headers: await _googleHeaders(const [
        googleCalendarScope,
      ], promptIfNecessary: promptIfNecessary),
      body: jsonEncode(_googleEventBody(event, includeId: true)),
    );
  }

  Future<http.Response> _updateGoogleEvent({
    required String calendarId,
    required PlatformEvent event,
    required bool promptIfNecessary,
  }) async {
    return _put(
      _googleCalendarUri(
        'calendars',
        calendarId,
        'events',
        CalendarLinks.stableEventId(event),
      ),
      headers: await _googleHeaders(const [
        googleCalendarScope,
      ], promptIfNecessary: promptIfNecessary),
      body: jsonEncode(_googleEventBody(event)),
    );
  }

  Map<String, dynamic> _googleEventBody(
    PlatformEvent event, {
    bool includeId = false,
  }) {
    final details = CalendarLinks.eventDetails(event);
    return {
      if (includeId) 'id': CalendarLinks.stableEventId(event),
      'summary': event.title,
      if (details.isNotEmpty) 'description': details,
      if (event.location.trim().isNotEmpty) 'location': event.location.trim(),
      'start': {'dateTime': event.startTime.toUtc().toIso8601String()},
      'end': {
        'dateTime': event.startTime
            .add(CalendarLinks.defaultEventDuration)
            .toUtc()
            .toIso8601String(),
      },
      'extendedProperties': {
        'private': {
          'quiltEventId': event.id,
          'quiltClubId': event.clubID,
          'quiltSchoolId': event.schoolID,
        },
      },
      'reminders': {
        'useDefault': false,
        'overrides': [
          for (final minutes in CalendarLinks.defaultAlertMinutesBefore)
            {'method': 'popup', 'minutes': minutes},
        ],
      },
    };
  }

  Future<Map<String, String>> _googleHeaders(
    List<String> scopes, {
    required bool promptIfNecessary,
  }) async {
    final override = _googleAuthorizationHeadersOverride;
    final headers = override != null
        ? await override(scopes, promptIfNecessary: promptIfNecessary)
        : await _authService!.googleAuthorizationHeaders(
            scopes,
            promptIfNecessary: promptIfNecessary,
          );
    return {...headers, 'Content-Type': 'application/json; charset=utf-8'};
  }

  Uri _googleCalendarUri(
    String first, [
    String? second,
    String? third,
    String? fourth,
  ]) {
    return Uri(
      scheme: 'https',
      host: 'www.googleapis.com',
      pathSegments: [
        'calendar',
        'v3',
        first,
        if (second != null) second,
        if (third != null) third,
        if (fourth != null) fourth,
      ],
    );
  }

  Uri _googleCalendarListUri({String? pageToken}) {
    return Uri(
      scheme: 'https',
      host: 'www.googleapis.com',
      pathSegments: const ['calendar', 'v3', 'users', 'me', 'calendarList'],
      queryParameters: {
        'minAccessRole': 'writer',
        'showHidden': 'true',
        'maxResults': '250',
        if (pageToken != null) 'pageToken': pageToken,
      },
    );
  }

  Future<http.Response> _get(Uri uri, {required Map<String, String> headers}) {
    final client = _client;
    return client == null
        ? http.get(uri, headers: headers)
        : client.get(uri, headers: headers);
  }

  Future<http.Response> _post(
    Uri uri, {
    required Map<String, String> headers,
    required Object body,
  }) {
    final client = _client;
    return client == null
        ? http.post(uri, headers: headers, body: body)
        : client.post(uri, headers: headers, body: body);
  }

  Future<http.Response> _put(
    Uri uri, {
    required Map<String, String> headers,
    required Object body,
  }) {
    final client = _client;
    return client == null
        ? http.put(uri, headers: headers, body: body)
        : client.put(uri, headers: headers, body: body);
  }

  Future<void> _saveUserProfile(UserProfile profile) {
    final override = _saveUserProfileOverride;
    if (override != null) {
      return override(profile);
    }
    return _firebaseService!.saveUserProfile(profile);
  }

  String _googleErrorMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final error = data['error'] as Map<String, dynamic>?;
      final message = error?['message'] as String?;
      if (message != null && message.trim().isNotEmpty) {
        return message.trim();
      }
    } catch (_) {
      // Fall through to a status-based message.
    }
    return 'Google Calendar request failed (${response.statusCode}).';
  }

  String _appleErrorMessage(Object error) {
    if (error is PlatformException) {
      return switch (error.code) {
        'permissionDenied' =>
          'Calendar access was not granted. Calendar sync remains optional.',
        'calendarUnavailable' => 'No writable calendar is available.',
        _ => error.message ?? 'Could not update Apple Calendar.',
      };
    }
    return error.toString();
  }
}

typedef GoogleAuthorizationHeadersProvider =
    Future<Map<String, String>> Function(
      List<String> scopes, {
      required bool promptIfNecessary,
    });

typedef UserProfileSaver = Future<void> Function(UserProfile profile);

class CalendarIntegrationException implements Exception {
  const CalendarIntegrationException(this.message);

  final String message;

  @override
  String toString() => message;
}
