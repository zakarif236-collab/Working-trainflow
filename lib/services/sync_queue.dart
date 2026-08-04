import 'dart:convert';
import 'package:my_app/models/sync_action.dart';
import 'package:my_app/services/community_firestore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyncQueue {
  SyncQueue._();

  static final SyncQueue instance = SyncQueue._();

  static const String _queueKey = 'offline.syncQueue';

  Future<void> enqueue(SyncAction action) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = _decodeQueue(prefs.getString(_queueKey));
    queue.add(action.toJson());
    await prefs.setString(_queueKey, jsonEncode(queue));
  }

  Future<int> get pendingCount async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeQueue(prefs.getString(_queueKey)).length;
  }

  Future<List<SyncAction>> peek() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeQueue(prefs.getString(_queueKey))
        .map((raw) => SyncAction.fromJson(Map<String, dynamic>.from(raw)))
        .toList();
  }

  Future<void> processQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = _decodeQueue(prefs.getString(_queueKey));
    if (queue.isEmpty) return;

    final remaining = <Map<String, dynamic>>[];
    final firestore = CommunityFirestoreService.instance;

    for (final item in queue) {
      try {
        final action = SyncAction.fromJson(Map<String, dynamic>.from(item));
        await _execute(firestore, action);
      } catch (_) {
        remaining.add(item);
      }
    }

    await prefs.setString(_queueKey, remaining.isEmpty ? '' : jsonEncode(remaining));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
  }

  Future<void> _execute(CommunityFirestoreService firestore, SyncAction action) async {
    switch (action.type) {
      case 'like_workout':
        await firestore.toggleLike(
          action.params['workoutId'] as String,
          action.params['isLiked'] as bool,
        );
      case 'favorite_workout':
        await firestore.toggleFavorite(
          action.params['workoutId'] as String,
          action.params['currentlyFavorited'] as bool,
        );
      case 'share_workout':
        await firestore.incrementShare(action.params['workoutId'] as String);
      case 'save_workout':
        await firestore.toggleSave(
          action.params['workoutId'] as String,
          action.params['currentlySaved'] as bool? ?? false,
        );
      case 'follow_creator':
        await firestore.toggleFollow(
          action.params['creatorId'] as String,
          action.params['isFollowing'] as bool,
        );
      case 'rate_workout':
        await firestore.rateWorkout(
          action.params['workoutId'] as String,
          (action.params['stars'] as num).toInt(),
        );
      case 'add_comment':
        await firestore.addComment(
          action.params['workoutId'] as String,
          action.params['message'] as String,
        );
      default:
        throw StateError('Unknown sync action type: ${action.type}');
    }
  }

  List<Map<String, dynamic>> _decodeQueue(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<Map>().cast<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }
}
