import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:my_app/models/workout_models.dart';
import 'package:my_app/services/community_firestore_service.dart';

class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  GlobalKey<NavigatorState>? _navigatorKey;

  void dispose() {
    _sub?.cancel();
    _navigatorKey = null;
  }

  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    } catch (_) {}

    _sub = _appLinks.uriLinkStream.listen((uri) {
      _handleUri(uri);
    });
  }

  void _handleUri(Uri uri) {
    if (uri.scheme != 'fitpulse') return;
    if (uri.host != 'workout') return;

    final workoutId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    if (workoutId == null || workoutId.isEmpty) return;

    _loadAndNavigate(workoutId);
  }

  Future<void> _loadAndNavigate(String workoutId) async {
    final navigatorKey = _navigatorKey;
    if (navigatorKey == null) return;

    try {
      final doc = await CommunityFirestoreService.instance.fetchWorkoutById(workoutId);
      if (doc == null) return;

      final context = navigatorKey.currentContext;
      if (context == null) return;
      if (!context.mounted) return;

      final routine = WorkoutBuilderRoutine(
        id: doc.id,
        name: doc.title,
        createdAt: doc.createdAt,
        exercises: doc.exercises,
      );

      Navigator.of(context).pushNamed(
        '/workout-builder-player',
        arguments: routine,
      );
    } catch (_) {
      final context = navigatorKey.currentContext;
      if (context == null) return;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load shared workout.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
