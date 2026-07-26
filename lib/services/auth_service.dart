import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _google = GoogleSignIn(
    serverClientId: '832592716654-mvrsbndvps6hvi65bj687ob697m6en9a.apps.googleusercontent.com',
  );

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  String? get currentUserId => _auth.currentUser?.uid;

  String? get currentEmail => _auth.currentUser?.email;

  String? get currentDisplayName => _auth.currentUser?.displayName;

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signUp(String email, String password, String displayName) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(displayName.trim());
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

    await _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
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
}

class AuthServiceException implements Exception {
  const AuthServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}
