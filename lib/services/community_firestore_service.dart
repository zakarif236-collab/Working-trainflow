import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_app/models/sync_action.dart';
import 'package:my_app/models/workout_models.dart';
import 'package:my_app/services/sync_queue.dart';

class CommunityFirestoreService {
  CommunityFirestoreService._();

  static final CommunityFirestoreService instance = CommunityFirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference get _workouts => _db.collection('community_workouts');
  CollectionReference get _users => _db.collection('users');

  // --- Publish ---

  Future<String?> publishWorkout(PublishCommunityWorkoutInput input) async {
    if (_uid == null) {
      print('[CommunityFirestore] BLOCKED: _uid is null — user not authenticated with Firebase Auth');
      return null;
    }

    final user = _auth.currentUser;
    final docRef = _workouts.doc();

    final workout = CommunityWorkout(
      id: docRef.id,
      creatorId: _uid!,
      creatorUsername: user?.displayName ?? 'Anonymous',
      creatorAvatarPath: user?.photoURL ?? '',
      title: input.title,
      description: input.description,
      category: input.category,
      difficulty: input.difficulty,
      tags: input.tags,
      coverImagePath: input.coverImagePath,
      exercises: input.routine.exercises,
      createdAt: DateTime.now(),
      downloads: 0,
      likes: 0,
      favorites: 0,
      shares: 0,
      ratingsCount: 0,
      ratingsTotal: 0,
      isLiked: false,
      isFavorited: false,
      isSaved: false,
      userRating: 0,
      comments: const [],
      isFollowingCreator: false,
      visibility: 'public',
      likedBy: const [],
      savedBy: const [],
    );

    try {
      final json = workout.toJson();
      print('[CommunityFirestore] Publishing workout: title="${input.title}", creatorId=$_uid, docId=${docRef.id}');
      await docRef.set(json);
      print('[CommunityFirestore] SUCCESS: Workout published to Firestore');
      return docRef.id;
    } catch (e) {
      print('[CommunityFirestore] FAILED: $e');
      return null;
    }
  }

  // --- Load ---

  Future<List<CommunityWorkout>> loadWorkouts({int limit = 50}) async {
    try {
      final snapshot = await _workouts
          .where('visibility', isEqualTo: 'public')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => CommunityWorkout.fromJson(doc.data() as Map<String, dynamic>))
          .map(_applyUserState)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // --- Real-time stream ---

  Stream<List<CommunityWorkout>> streamWorkouts({int limit = 50}) {
    return _workouts
        .where('visibility', isEqualTo: 'public')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CommunityWorkout.fromJson(doc.data() as Map<String, dynamic>))
            .map(_applyUserState)
            .toList());
  }

  CommunityWorkout _applyUserState(CommunityWorkout workout) {
    if (_uid == null) return workout;
    final liked = workout.likedBy.contains(_uid);
    final saved = workout.savedBy.contains(_uid);
    if (liked == workout.isLiked && saved == workout.isSaved) return workout;
    return workout.copyWith(isLiked: liked, isSaved: saved);
  }

  // --- Interactions ---

  Future<void> toggleLike(String workoutId, bool currentlyLiked) async {
    if (_uid == null) return;
    try {
      await _workouts.doc(workoutId).update({
        'likes': FieldValue.increment(currentlyLiked ? -1 : 1),
        'likedBy': currentlyLiked
            ? FieldValue.arrayRemove([_uid])
            : FieldValue.arrayUnion([_uid]),
      });
      final userLikeDoc = _users.doc(_uid).collection('liked_workouts').doc(workoutId);
      if (currentlyLiked) {
        await userLikeDoc.delete();
      } else {
        await userLikeDoc.set({'likedAt': FieldValue.serverTimestamp()});
      }
    } catch (_) {
      await SyncQueue.instance.enqueue(SyncAction(
        type: 'like_workout',
        params: {'workoutId': workoutId, 'isLiked': !currentlyLiked},
      ));
    }
  }

  Future<void> toggleFavorite(String workoutId, bool currentlyFavorited) async {
    if (_uid == null) return;
    try {
      await _workouts.doc(workoutId).update({
        'favorites': FieldValue.increment(currentlyFavorited ? -1 : 1),
      });
      final userFavDoc = _users.doc(_uid).collection('favorite_workouts').doc(workoutId);
      if (currentlyFavorited) {
        await userFavDoc.delete();
      } else {
        await userFavDoc.set({'favoritedAt': FieldValue.serverTimestamp()});
      }
    } catch (_) {
      await SyncQueue.instance.enqueue(SyncAction(
        type: 'like_workout',
        params: {'workoutId': workoutId, 'isLiked': !currentlyFavorited},
      ));
    }
  }

  Future<void> toggleSave(String workoutId, bool currentlySaved) async {
    if (_uid == null) return;
    try {
      await _workouts.doc(workoutId).update({
        'savedBy': currentlySaved
            ? FieldValue.arrayRemove([_uid])
            : FieldValue.arrayUnion([_uid]),
      });
      final savedDoc = _users.doc(_uid).collection('savedWorkouts').doc(workoutId);
      if (currentlySaved) {
        await savedDoc.delete();
      } else {
        final workoutDoc = await _workouts.doc(workoutId).get();
        if (workoutDoc.exists) {
          await savedDoc.set(workoutDoc.data() as Map<String, dynamic>);
        }
      }
    } catch (_) {
      await SyncQueue.instance.enqueue(SyncAction(
        type: 'save_workout',
        params: {'workoutId': workoutId, 'currentlySaved': currentlySaved},
      ));
    }
  }

  Future<List<WorkoutBuilderRoutine>> loadSavedWorkouts() async {
    if (_uid == null) return const [];
    try {
      final snapshot = await _users.doc(_uid).collection('savedWorkouts').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final rawExercises = data['exercises'];
        final exercises = rawExercises is List
            ? rawExercises
                  .whereType<Map>()
                  .map((raw) => WorkoutBuilderExercise.fromJson(Map<String, dynamic>.from(raw)))
                  .toList(growable: false)
            : const <WorkoutBuilderExercise>[];
        return WorkoutBuilderRoutine(
          id: doc.id,
          name: (data['title'] as String?) ?? 'Workout',
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            (data['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
          ),
          exercises: exercises,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> incrementShare(String workoutId) async {
    try {
      await _workouts.doc(workoutId).update({
        'shares': FieldValue.increment(1),
      });
    } catch (_) {
      await SyncQueue.instance.enqueue(SyncAction(
        type: 'like_workout',
        params: {'workoutId': workoutId, 'isLiked': true},
      ));
    }
  }

  Future<bool> deleteWorkout(String workoutId) async {
    if (_uid == null) return false;
    try {
      final doc = await _workouts.doc(workoutId).get();
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return false;

      final isCreator = data['creatorId'] == _uid;
      final isAdmin = _auth.currentUser?.email?.toLowerCase() == 'kingslayer.et@gmail.com';
      if (!isCreator && !isAdmin) return false;

      await _workouts.doc(workoutId).delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> shareRoutine(WorkoutBuilderRoutine routine) async {
    if (_uid == null) return null;
    try {
      final input = PublishCommunityWorkoutInput.fromRoutine(routine);
      return await publishWorkout(input);
    } catch (_) {
      return null;
    }
  }

  Future<CommunityWorkout?> fetchWorkoutById(String workoutId) async {
    try {
      final doc = await _workouts.doc(workoutId).get();
      if (!doc.exists) return null;
      return CommunityWorkout.fromJson(doc.data() as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> rateWorkout(String workoutId, int rating) async {
    if (_uid == null) return;
    try {
      final ratingDoc = _users.doc(_uid).collection('rated_workouts').doc(workoutId);
      await ratingDoc.set({'rating': rating, 'ratedAt': FieldValue.serverTimestamp()});

      await _workouts.doc(workoutId).update({
        'ratingsCount': FieldValue.increment(1),
        'ratingsTotal': FieldValue.increment(rating),
      });
    } catch (_) {
      await SyncQueue.instance.enqueue(SyncAction(
        type: 'rate_workout',
        params: {'workoutId': workoutId, 'stars': rating},
      ));
    }
  }

  Future<void> addComment(String workoutId, String message) async {
    if (_uid == null) return;
    try {
      final user = _auth.currentUser;
      final commentRef = _workouts.doc(workoutId).collection('comments').doc();

      final comment = CommunityComment(
        id: commentRef.id,
        authorUsername: user?.displayName ?? 'Anonymous',
        message: message,
        createdAt: DateTime.now(),
      );

      await commentRef.set(comment.toJson());
    } catch (_) {
      await SyncQueue.instance.enqueue(SyncAction(
        type: 'add_comment',
        params: {'workoutId': workoutId, 'message': message},
      ));
    }
  }

  Future<void> toggleFollow(String creatorId, bool currentlyFollowing) async {
    if (_uid == null) return;
    try {
      final followDoc = _users.doc(_uid).collection('following').doc(creatorId);
      if (currentlyFollowing) {
        await followDoc.delete();
      } else {
        await followDoc.set({'followedAt': FieldValue.serverTimestamp()});
      }
    } catch (_) {
      await SyncQueue.instance.enqueue(SyncAction(
        type: 'follow_creator',
        params: {'creatorId': creatorId, 'isFollowing': !currentlyFollowing},
      ));
    }
  }

  // --- Stats ---

  Future<CreatorCommunityStats> loadCreatorStats(String creatorId) async {
    try {
      final snapshot = await _workouts
          .where('creatorId', isEqualTo: creatorId)
          .get();

      final workouts = snapshot.docs
          .map((doc) => CommunityWorkout.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      final totalDownloads = workouts.fold<int>(0, (sum, w) => sum + w.downloads);
      final totalLikes = workouts.fold<int>(0, (sum, w) => sum + w.likes);
      final totalShares = workouts.fold<int>(0, (sum, w) => sum + w.shares);

      final profileSnap = await _users.doc(creatorId).get();
      final profile = profileSnap.data() as Map<String, dynamic>?;

      return CreatorCommunityStats(
        creatorId: creatorId,
        username: profile?['displayName'] ?? 'Unknown',
        profileImagePath: profile?['profileImagePath'] ?? '',
        bio: profile?['bio'] ?? '',
        totalPublished: workouts.length,
        followers: 0,
        totalDownloads: totalDownloads,
        totalShares: totalShares,
        likesReceived: totalLikes,
        fiveStarRatings: 0,
        badges: const [],
      );
    } catch (_) {
      return CreatorCommunityStats(
        creatorId: creatorId,
        username: 'Unknown',
        profileImagePath: '',
        bio: '',
        totalPublished: 0,
        followers: 0,
        totalDownloads: 0,
        totalShares: 0,
        likesReceived: 0,
        fiveStarRatings: 0,
        badges: const [],
      );
    }
  }
}