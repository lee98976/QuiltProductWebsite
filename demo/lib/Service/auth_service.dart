import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../Models/user.dart';
import 'firebase_service.dart';

class AuthService {
  AuthService(this._fb, {FirebaseAuth? auth, GoogleSignIn? googleSignIn})
    : _auth = auth ?? FirebaseAuth.instance,
      _googleSignIn = googleSignIn ?? GoogleSignIn.instance {
    _googleInit = kIsWeb ? Future<void>.value() : _initializeGoogleSignIn();
  }

  static const String _serverClientId =
      'demo-client-id.apps.googleusercontent.com';
  static const String _androidGoogleConfigMessage =
      'Google sign-in is not configured for this Android build. In Firebase, add the SHA-1/SHA-256 fingerprint for the signing key used by this APK under the Android app com.codingmind.quilt, download the updated google-services.json, and rebuild.';

  final FirebaseAuth _auth;
  final FirebaseService _fb;
  final GoogleSignIn _googleSignIn;
  late final Future<void> _googleInit;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  String friendlyAuthError(Object error) {
    if (error is AccountAlreadyExistsException) {
      return 'That account already has a Quilt profile. Use Log in instead.';
    }
    if (error is FirebaseAuthException) {
      if (error.code == 'invalid-cert-hash') {
        return _androidGoogleConfigMessage;
      }
      if (error.code == 'account-exists-with-different-credential') {
        return 'An account already exists for this email with a different sign-in method. Sign in with that method first.';
      }
      if (error.code == 'requires-recent-login') {
        return 'For your security, please sign in again to confirm before deleting your account, then try once more.';
      }
      if (error.code == 'web-context-cancelled' ||
          error.code == 'popup-closed-by-user' ||
          error.code == 'canceled') {
        return 'Sign-in was cancelled.';
      }
      if (error.code == 'invalid-credential' ||
          error.code == 'wrong-password' ||
          error.code == 'user-not-found' ||
          error.code == 'invalid-email') {
        return 'That email or password is incorrect.';
      }
      if (error.code == 'user-disabled') {
        return 'This account has been disabled.';
      }
      if (error.code == 'too-many-requests') {
        return 'Too many attempts. Wait a moment and try again.';
      }
      if (error.code == 'operation-not-allowed') {
        return 'Email/password sign-in is not enabled for this project.';
      }
      return error.message ?? 'Firebase Auth error: ${error.code}';
    }
    if (error is GoogleSignInException) {
      if (_isAndroidGoogleConfigError(error)) {
        return _androidGoogleConfigMessage;
      }
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        if (defaultTargetPlatform == TargetPlatform.android) {
          return 'Google sign-in did not finish. If this happened after choosing an account, this Android build is probably missing its Firebase SHA fingerprint.';
        }
        return 'Google sign-in was cancelled.';
      }
      return error.description ?? 'Google sign-in failed: ${error.code.name}';
    }
    return error.toString();
  }

  Future<void> _initializeGoogleSignIn() {
    return _googleSignIn.initialize(serverClientId: _serverClientId);
  }

  bool _isAndroidGoogleConfigError(GoogleSignInException error) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    if (error.code == GoogleSignInExceptionCode.clientConfigurationError ||
        error.code == GoogleSignInExceptionCode.providerConfigurationError) {
      return true;
    }

    final description = error.description?.toLowerCase() ?? '';
    return description.contains('account reauth failed') ||
        description.contains('developer_error') ||
        description.contains('configuration') ||
        description.contains('serverclientid') ||
        description.contains('certificate') ||
        description.contains('sha');
  }

  bool get isCurrentUserGoogleAccount {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((info) => info.providerId == 'google.com');
  }

  bool get isCurrentUserSupportedAccount => isCurrentUserGoogleAccount;

  Future<User?> signInWithGoogle({
    String accountRole = UserProfile.prospectiveStudentRole,
    String studentId = '',
  }) async {
    final result = await _runGoogleProviderFlow(_googleProvider());
    return result.user;
  }

  Future<User?> signUpWithGoogle({
    String accountRole = UserProfile.prospectiveStudentRole,
    String studentId = '',
  }) async {
    final result = await _runGoogleProviderFlow(_googleProvider());
    return _completeSocialSignUp(
      result,
      accountRole: accountRole,
      studentId: studentId,
    );
  }

  Future<User?> _completeSocialSignUp(
    UserCredential result, {
    required String accountRole,
    required String studentId,
  }) async {
    final user = result.user;
    if (user == null) return null;

    final existingProfile = await _fb.getUser(user.uid);
    if (existingProfile != null) {
      if (!existingProfile.isProspectiveStudent ||
          accountRole == UserProfile.prospectiveStudentRole) {
        await signOut();
        throw const AccountAlreadyExistsException();
      }

      await _upgradeProspectiveProfile(
        existingProfile: existingProfile,
        user: user,
        accountRole: accountRole,
        studentId: studentId,
      );
      return user;
    }

    await ensureProfileForCurrentUser(
      accountRole: accountRole,
      studentId: studentId,
    );
    return user;
  }

  Future<void> _upgradeProspectiveProfile({
    required UserProfile existingProfile,
    required User user,
    required String accountRole,
    required String studentId,
  }) async {
    final isCurrentStudent = accountRole == UserProfile.currentStudentRole;
    final isParent = accountRole == UserProfile.parentRole;
    if (!isCurrentStudent && !isParent) {
      throw StateError(
        'Prospective profiles can only become student or parent profiles.',
      );
    }

    final displayName = (user.displayName ?? '').trim();
    final email = user.email ?? existingProfile.email;
    final fallbackName = displayName.isNotEmpty ? displayName : email;
    final familyCode = isCurrentStudent
        ? existingProfile.familyCode.isNotEmpty
              ? existingProfile.familyCode
              : await _fb.createUniqueFamilyCode()
        : '';

    await _fb.saveUserProfile(
      existingProfile.copyWith(
        email: email,
        displayName: fallbackName.isNotEmpty
            ? fallbackName
            : existingProfile.displayName,
        realName: displayName.isNotEmpty
            ? displayName
            : existingProfile.realName,
        studentId: isCurrentStudent ? studentId : '',
        familyCode: familyCode,
        accountStatus: isCurrentStudent
            ? UserProfile.nonVerifiedStatus
            : UserProfile.viewOnlyStatus,
        accountRole: accountRole,
        pfpURL: user.photoURL ?? existingProfile.pfpURL,
        schoolID: isCurrentStudent ? 'troy_high_school' : '',
      ),
    );
  }

  GoogleAuthProvider _googleProvider() {
    return GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile');
  }

  Future<UserCredential> _runGoogleProviderFlow(
    GoogleAuthProvider provider,
  ) async {
    if (kIsWeb) {
      return _auth.signInWithPopup(provider);
    }

    await _googleInit;
    final googleUser = await _googleSignIn.authenticate();
    final googleAuth = googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<void> ensureProfileForCurrentUser({
    String accountRole = UserProfile.prospectiveStudentRole,
    String studentId = '',
  }) async {
    final user = _auth.currentUser;
    if (user == null || !isCurrentUserSupportedAccount) return;

    final existingProfile = await _fb.getUser(user.uid);
    if (existingProfile != null) return;

    final isCurrentStudent = accountRole == UserProfile.currentStudentRole;
    final isProspectiveStudent =
        accountRole == UserProfile.prospectiveStudentRole;
    final isParent = accountRole == UserProfile.parentRole;
    final displayName = (user.displayName ?? '').trim();
    final email = user.email ?? '';
    final familyCode = isCurrentStudent
        ? await _fb.createUniqueFamilyCode()
        : '';

    await _fb.createUserProfile(
      UserProfile(
        email: email,
        displayName: displayName.isNotEmpty ? displayName : email,
        realName: displayName,
        studentId: isCurrentStudent ? studentId : '',
        familyCode: familyCode,
        accountStatus: isCurrentStudent
            ? UserProfile.nonVerifiedStatus
            : UserProfile.viewOnlyStatus,
        accountRole: accountRole,
        pfpURL: user.photoURL,
        schoolID: isProspectiveStudent || isParent ? '' : 'troy_high_school',
        UID: user.uid,
      ),
    );
  }

  Future<UserProfile> createTemporaryAdminAccount({
    required String schoolID,
  }) async {
    final user = _auth.currentUser;
    if (user == null || !isCurrentUserGoogleAccount) {
      throw StateError('Sign in with Google before creating an admin account.');
    }

    final existingProfile = await _fb.getUser(user.uid);
    final displayName = (user.displayName ?? '').trim();
    final email = user.email ?? '';
    final fallbackName = displayName.isNotEmpty ? displayName : email;

    final adminProfile =
        existingProfile?.copyWith(
          email: email.isNotEmpty ? email : existingProfile.email,
          displayName: existingProfile.displayName.isNotEmpty
              ? existingProfile.displayName
              : fallbackName,
          realName: existingProfile.realName.isNotEmpty
              ? existingProfile.realName
              : fallbackName,
          pfpURL: user.photoURL ?? existingProfile.pfpURL,
          schoolID: schoolID,
          accountRole: UserProfile.schoolAdministratorRole,
          accountStatus: UserProfile.verifiedStatus,
          isAdmin: true,
        ) ??
        UserProfile(
          email: email,
          displayName: fallbackName,
          realName: fallbackName,
          accountStatus: UserProfile.verifiedStatus,
          accountRole: UserProfile.schoolAdministratorRole,
          pfpURL: user.photoURL,
          schoolID: schoolID,
          UID: user.uid,
          isAdmin: true,
        );

    await _fb.saveUserProfile(adminProfile);
    return adminProfile;
  }

  /// Email/password sign-in.
  ///
  /// Regular users authenticate with Google; this path exists for the App
  /// Review demo account, which is provisioned in the Firebase console
  /// (Authentication > Email/Password provider) with a seeded `Users` profile
  /// document so it loads real, permissioned data on sign-in.
  Future<User?> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential.user;
  }

  Future<User?> signUp({
    required String email,
    required String password,
    required String name,
    String studentId = '',
  }) async {
    throw UnsupportedError(
      'Email/password account creation is disabled. Use Google.',
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) {
      try {
        await _googleInit;
        await _googleSignIn.signOut().timeout(
          const Duration(seconds: 3),
          onTimeout: () {},
        );
      } catch (_) {
        // Firebase Auth owns the active session; GoogleSignIn cleanup is best-effort.
      }
    }
  }

  Future<void> deleteCurrentAccount() async {
    var user = _auth.currentUser;
    if (user == null) return;
    if (!isCurrentUserSupportedAccount) {
      throw StateError('This account cannot be deleted from Quilt.');
    }

    if (_needsFreshLogin(user)) {
      await _reauthenticateGoogleUser(user);
    }

    user = _auth.currentUser;
    if (user == null) return;
    await _fb.deleteUserAccountData(user.uid);
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login') {
        rethrow;
      }

      // Firestore data was already removed before user.delete() first ran;
      // only the auth record remains, so reauthenticate and retry that step.
      await _reauthenticateGoogleUser(user);
      user = _auth.currentUser;
      if (user == null) return;
      await user.delete();
    }
    if (!kIsWeb) {
      try {
        await _googleInit;
        await _googleSignIn.signOut();
      } catch (_) {
        // Firebase and the user's Quilt data are already deleted.
      }
    }
  }

  bool _needsFreshLogin(User user) {
    final lastSignIn = user.metadata.lastSignInTime;
    if (lastSignIn == null) return false;
    return DateTime.now().difference(lastSignIn) > const Duration(minutes: 4);
  }

  Future<void> _reauthenticateGoogleUser(User user) async {
    if (kIsWeb) {
      await user.reauthenticateWithPopup(_googleProvider());
      return;
    }

    final credential = await _googleCredential();
    await user.reauthenticateWithCredential(credential);
  }

  Future<AuthCredential> _googleCredential() async {
    await _googleInit;
    final googleUser = await _googleSignIn.authenticate();
    final googleAuth = googleUser.authentication;
    return GoogleAuthProvider.credential(idToken: googleAuth.idToken);
  }

  Future<Map<String, String>> googleAuthorizationHeaders(
    List<String> scopes, {
    bool promptIfNecessary = false,
  }) async {
    if (!isCurrentUserGoogleAccount) {
      throw StateError(
        'Sign in with Google before connecting Google Calendar.',
      );
    }

    await _googleInit;
    var account = await _tryLightweightGoogleAccount();
    if (account == null && promptIfNecessary) {
      account = await _googleSignIn.authenticate(scopeHint: scopes);
    }
    if (account == null) {
      throw StateError(
        'Reconnect Google Calendar in Settings to refresh permission.',
      );
    }

    final currentEmail = (_auth.currentUser?.email ?? '').trim().toLowerCase();
    if (currentEmail.isNotEmpty &&
        account.email.trim().toLowerCase() != currentEmail) {
      throw StateError('Choose the same Google account used for Quilt.');
    }

    final headers = await account.authorizationClient.authorizationHeaders(
      scopes,
      promptIfNecessary: promptIfNecessary,
    );
    if (headers == null) {
      throw StateError(
        promptIfNecessary
            ? 'Google Calendar permission was not granted.'
            : 'Reconnect Google Calendar in Settings to refresh permission.',
      );
    }
    return headers;
  }

  Future<GoogleSignInAccount?> _tryLightweightGoogleAccount() async {
    try {
      return await _googleSignIn.attemptLightweightAuthentication();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted ||
          e.code == GoogleSignInExceptionCode.uiUnavailable) {
        return null;
      }
      rethrow;
    }
  }
}

class AccountAlreadyExistsException implements Exception {
  const AccountAlreadyExistsException();
}
