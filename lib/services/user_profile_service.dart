import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createProfile(String uid, String email, String displayName) async {
    await _db.collection('users').doc(uid).set({
      'displayName': displayName.trim(),
      'email': email.trim(),
      'bio': '',
      'profileImagePath': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'totalWorkouts': 0,
      'totalSeconds': 0,
      'currentStreakDays': 0,
      'bestStreakDays': 0,
    });
  }

  Future<Map<String, dynamic>?> getProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}