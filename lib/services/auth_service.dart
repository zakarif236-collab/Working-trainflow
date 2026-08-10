import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _google = GoogleSignIn(
    serverClientId: '832592716654-mvrsbndvps6hvi65bj687ob697m6en9a.apps.googleusercontent.com',
  );

  static String? _cachedUid;
  static const _uidKey = '_firebaseUid';
  static bool _uidLoaded = false;

  static String? _localUid;
  static const _localUidKey = '_localDeviceUid';

  static const String adminEmail = 'kingslayer.et@gmail.com';

  Future<void> init() async {
    await _ensureUidLoaded();
  }

  static Future<void> _ensureUidLoaded() async {
    if (_uidLoaded) return;
    _uidLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedUid = prefs.getString(_uidKey);
      _localUid = prefs.getString(_localUidKey);
      if (_localUid == null) {
        _localUid = 'device_${_randomHex(16)}';
        await prefs.setString(_localUidKey, _localUid!);
      }
    } catch (_) {
      _localUid = 'ephemeral_${DateTime.now().microsecondsSinceEpoch}';
    }
  }

  Future<void> _saveCachedUid(String uid) async {
    _cachedUid = uid;
    _uidLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_uidKey, uid);
    } catch (_) {
      debugPrint('[AuthService] Failed to save UID to SharedPreferences');
    }
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  String get currentUserId {
    final resolved = AuthService.resolvedUserId;
    if (resolved.isNotEmpty) return resolved;
    debugPrint('[AuthService] No Firebase UID — using local device UID');
    return 'fallback_${DateTime.now().microsecondsSinceEpoch}';
  }

  /// Stable per-device identity (Firebase UID when signed in, otherwise the
  /// cached or local device UID). Used to namespace per-user local storage so
  /// stats and profile data don't leak across accounts on a shared device.
  /// Returns an empty string when identity is not resolved yet.
  static String get resolvedUserId {
    try {
      final live = FirebaseAuth.instance.currentUser?.uid;
      if (live != null) return live;
    } catch (_) {
      // Firebase is not initialized yet (unit tests, very early startup).
    }
    if (_cachedUid != null) return _cachedUid!;
    return _localUid ?? '';
  }

  bool get hasFirebaseSession => _auth.currentUser != null;

  /// Whether a Firebase session was cached on this device during a previous
  /// run. Unlike [hasFirebaseSession] this is meaningful at cold start, before
  /// FirebaseAuth has finished restoring the persisted session.
  bool get hasCachedSession => _cachedUid != null;

  /// Cold-start helper: waits for FirebaseAuth to finish restoring a cached
  /// session (if any) before callers decide to sign in anonymously. Without
  /// this, `currentUser` can be null at cold start while a real session is
  /// still being restored, causing a fresh anonymous user to clobber it.
  Future<bool> waitForRestoredSession({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (_auth.currentUser != null) return true;
    try {
      final restored = await _auth
          .authStateChanges()
          .firstWhere((user) => user != null)
          .timeout(timeout, onTimeout: () => null);
      if (restored != null) {
        await _saveCachedUid(restored.uid);
        return true;
      }
    } on TimeoutException {
      // No session was restored within the window — treat as signed out.
    } catch (_) {
      debugPrint('[AuthService] Failed waiting for session restore');
    }
    return false;
  }

  String? get currentEmail => _auth.currentUser?.email;

  bool get isAdmin {
    final email = currentEmail;
    return email != null && email.toLowerCase() == adminEmail.toLowerCase();
  }

  String? get currentDisplayName => _auth.currentUser?.displayName;

  Future<void> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (credential.user != null) {
      await _saveCachedUid(credential.user!.uid);
    }
  }

  Future<void> signUp(String email, String password, String displayName) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(displayName.trim());
    if (credential.user != null) {
      await _saveCachedUid(credential.user!.uid);
    }
  }

  Future<void> signInWithGoogle() async {
    final googleUser = await _google.signIn();
    if (googleUser == null) {
      throw const AuthServiceException('Google sign-in was cancelled.');
    }

    final googleAuth = await googleUser.authentication;

    if (googleAuth.idToken == null) {
      throw const AuthServiceException(
        'Failed to get Google ID token. Make sure the OAuth consent screen is Published (not in Testing mode) in Google Cloud Console > APIs & Services > OAuth consent screen.',
      );
    }
    if (googleAuth.accessToken == null) {
      throw const AuthServiceException('Failed to get Google access token.');
    }

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final result = await _auth.signInWithCredential(credential);
    if (result.user != null) {
      await _saveCachedUid(result.user!.uid);
    }
  }

  Future<void> signOut() async {
    _cachedUid = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_uidKey);
    await prefs.remove('_firstLoginSeen');
    await _google.signOut();
    await _auth.signOut();
  }

  Future<bool> get isFirstLogin async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('_firstLoginSeen')) {
      await prefs.setBool('_firstLoginSeen', true);
      return true;
    }
    return false;
  }

  Future<void> markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('_onboardingComplete', true);
  }

  Future<bool> get isOnboardingComplete async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('_onboardingComplete') ?? false;
  }

  Future<void> signInAnonymously() async {
    final result = await _auth.signInAnonymously();
    if (result.user != null) {
      await _saveCachedUid(result.user!.uid);
    }
  }

  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;

  static String _randomHex(int length) {
    final random = Random();
    const chars = '0123456789abcdef';
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> linkWithGoogle() async {
    final googleUser = await _google.signIn();
    if (googleUser == null) throw const AuthServiceException('Google sign-in was cancelled.');
    final googleAuth = await googleUser.authentication;
    if (googleAuth.idToken == null) {
      throw const AuthServiceException(
        'Failed to get Google ID token. Make sure the OAuth consent screen is Published.',
      );
    }
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.currentUser!.linkWithCredential(credential);
    if (result.user != null) {
      await _saveCachedUid(result.user!.uid);
    }
  }

  Future<void> linkWithEmail(String email, String password) async {
    final credential = EmailAuthProvider.credential(email: email.trim(), password: password);
    final result = await _auth.currentUser!.linkWithCredential(credential);
    if (result.user != null) {
      await _saveCachedUid(result.user!.uid);
    }
  }
}

String resolveDisplayName({String? displayName, String? email}) {
  final name = displayName?.trim();
  if (name != null && name.isNotEmpty) return name;
  final localPart = email?.split('@').first.trim();
  if (localPart != null && localPart.isNotEmpty) return localPart;
  return 'Athlete';
}

class AuthServiceException implements Exception {
  const AuthServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}
