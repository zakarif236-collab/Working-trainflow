import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> initialize() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveFcmToken(token);
      }
      _messaging.onTokenRefresh.listen(_saveFcmToken);
    }

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    await _messaging.subscribeToTopic('global_feed');
  }

  Future<void> _saveFcmToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // Handle foreground notification if needed
  }

  Future<void> sendShareNotification({
    required String senderName,
    required String workoutTitle,
  }) async {
    try {
      await _db.collection('notifications').add({
        'type': 'workout_shared',
        'senderName': senderName,
        'workoutTitle': workoutTitle,
        'createdAt': FieldValue.serverTimestamp(),
        'topic': 'global_feed',
      });
    } catch (_) {}
  }
}
