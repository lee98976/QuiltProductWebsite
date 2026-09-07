import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart';

import '../Models/user.dart';
import '../Service/auth_service.dart';
import '../Service/firebase_service.dart';

/// Loads and keeps [UserProfile] in sync with Firebase Auth for the signed-in user.
class CurrentUserProfileNotifier extends ChangeNotifier {
  CurrentUserProfileNotifier(this._authService, this._firebaseService) {
    _subscription = _authService.authStateChanges.listen(_onAuthUser);
    _onAuthUser(_authService.currentUser);
  }

  final AuthService _authService;
  final FirebaseService _firebaseService;

  late final StreamSubscription<auth.User?> _subscription;
  StreamSubscription<UserProfile?>? _profileSubscription;

  UserProfile? _profile;
  UserProfile? get profile => _profile;

  bool _isGuestSession = false;
  bool get isGuestSession => _isGuestSession;

  int _profileRevision = 0;
  int get profileRevision => _profileRevision;

  String? _debugProfileUid;
  String? get debugProfileUid => _debugProfileUid;

  bool get isUsingDebugProfile => _debugProfileUid != null;

  bool _loading = false;
  bool get loading => _loading;

  /// Set when Firestore [getUser] throws (rules, network, etc.).
  String? _loadError;
  String? get loadError => _loadError;

  Future<void> _onAuthUser(auth.User? user) async {
    await _profileSubscription?.cancel();
    _profileSubscription = null;

    if (user == null) {
      if (!_isGuestSession) {
        _clearLocalSession();
      }
      return;
    }

    _isGuestSession = false;
    _loading = true;
    _loadError = null;
    notifyListeners();

    try {
      final loaded = await _firebaseService.getUser(
        _debugProfileUid ?? user.uid,
      );
      _profile = loaded;
      _profileRevision++;
      _watchProfile(_debugProfileUid ?? user.uid);
    } catch (e, st) {
      _profile = null;
      _profileRevision++;
      _loadError = e.toString();
      debugPrint('CurrentUserProfileNotifier getUser failed: $e\n$st');
    }

    _loading = false;
    notifyListeners();
  }

  void _clearLocalSession() {
    _debugProfileUid = null;
    _isGuestSession = false;
    _profile = null;
    _profileRevision++;
    _loadError = null;
    _loading = false;
    notifyListeners();
  }

  Future<void> startProspectiveGuestSession() async {
    await _profileSubscription?.cancel();
    _profileSubscription = null;
    _debugProfileUid = null;
    _isGuestSession = true;
    _loadError = null;
    _loading = false;
    _profile = UserProfile(
      email: '',
      displayName: 'Prospective student',
      realName: '',
      accountStatus: UserProfile.viewOnlyStatus,
      accountRole: UserProfile.prospectiveStudentRole,
      schoolID: '',
      UID: 'guest_prospective',
    );
    _profileRevision++;
    notifyListeners();
  }

  Future<void> startDemoSession() async {
    await _profileSubscription?.cancel();
    _profileSubscription = null;
    _debugProfileUid = null;
    _isGuestSession = true;
    _loadError = null;
    _loading = false;
    _profile = UserProfile(
      email: 'demo@quilt.example',
      displayName: 'Some Guy',
      realName: 'Some Guy',
      studentId: 'demo-student',
      familyCode: 'Q-4821',
      accountStatus: UserProfile.verifiedStatus,
      accountRole: UserProfile.schoolAdministratorRole,
      schoolID: 'troy_high_school',
      UID: 'demo_some_guy',
      isAdmin: true,
      isDebug: true,
    );
    _profileRevision++;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _authService.signOut();
    await _profileSubscription?.cancel();
    _profileSubscription = null;
    _clearLocalSession();
  }

  void _watchProfile(String uid) {
    _profileSubscription = _firebaseService
        .watchUser(uid)
        .listen(
          (profile) {
            _profile = profile;
            _profileRevision++;
            _loadError = null;
            _loading = false;
            notifyListeners();
          },
          onError: (Object e, StackTrace st) {
            _profile = null;
            _profileRevision++;
            _loadError = e.toString();
            _loading = false;
            debugPrint('CurrentUserProfileNotifier watchUser failed: $e\n$st');
            notifyListeners();
          },
        );
  }

  /// Call after local profile updates so listeners refresh without re-fetching auth.
  Future<void> refresh() async {
    if (_isGuestSession) return;
    final uid = _debugProfileUid ?? _authService.currentUser?.uid;
    if (uid == null) return;
    _loading = true;
    _loadError = null;
    notifyListeners();
    try {
      _profile = await _firebaseService.getUser(uid);
      _profileRevision++;
    } catch (e, st) {
      _profile = null;
      _profileRevision++;
      _loadError = e.toString();
      debugPrint('CurrentUserProfileNotifier refresh failed: $e\n$st');
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> updateThemePreference(String appThemeId) async {
    final current = _profile;
    if (current == null || current.appThemeId == appThemeId) return;

    final previous = current;
    final updated = current.copyWith(appThemeId: appThemeId);
    _profile = updated;
    _profileRevision++;
    notifyListeners();

    if (_isGuestSession) return;

    try {
      await _firebaseService.saveUserProfile(updated);
    } catch (e, st) {
      _profile = previous;
      _profileRevision++;
      debugPrint(
        'CurrentUserProfileNotifier updateThemePreference failed: $e\n$st',
      );
      notifyListeners();
      rethrow;
    }
  }

  Future<void> blockUser(String uid) async {
    final normalized = uid.trim();
    final current = _profile;
    if (current == null || normalized.isEmpty || normalized == current.UID) {
      return;
    }
    if (current.blockedUserIds.contains(normalized)) return;
    await _updateBlockedUsers([...current.blockedUserIds, normalized]);
  }

  Future<void> clearBlockedUsers() async {
    if ((_profile?.blockedUserIds ?? const []).isEmpty) return;
    await _updateBlockedUsers(const []);
  }

  Future<void> _updateBlockedUsers(List<String> blockedUserIds) async {
    final current = _profile;
    if (current == null || _isGuestSession) return;
    final previous = current;
    _profile = current.copyWith(blockedUserIds: blockedUserIds);
    _profileRevision++;
    notifyListeners();
    try {
      await _firebaseService.saveUserProfile(_profile!);
    } catch (_) {
      _profile = previous;
      _profileRevision++;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> useDebugProfile(String uid) async {
    if (_authService.currentUser == null) {
      throw StateError('Sign in before using a fake profile.');
    }
    await _profileSubscription?.cancel();
    _profileSubscription = null;
    _debugProfileUid = uid;
    await refresh();
    _watchProfile(uid);
  }

  Future<void> stopUsingDebugProfile() async {
    if (_debugProfileUid == null) return;
    await _profileSubscription?.cancel();
    _profileSubscription = null;
    _debugProfileUid = null;
    await refresh();
    final uid = _authService.currentUser?.uid;
    if (uid != null) _watchProfile(uid);
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(_profileSubscription?.cancel());
    super.dispose();
  }
}
