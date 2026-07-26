import 'dart:io';

import 'package:flutter/material.dart';
import 'package:my_app/models/workout_models.dart';
import 'package:my_app/services/settings_service.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key, required this.creatorId});

  final String creatorId;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final SettingsService _settingsService = SettingsService();
  CreatorCommunityStats _stats = const CreatorCommunityStats(
    creatorId: 'unknown',
    username: 'Creator',
    profileImagePath: '',
    bio: '',
    totalPublished: 0,
    followers: 0,
    totalDownloads: 0,
    totalShares: 0,
    likesReceived: 0,
    fiveStarRatings: 0,
    badges: [],
  );
  List<CommunityWorkout> _workouts = const [];
  bool _isFollowing = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final stats = await _settingsService.loadCreatorCommunityStats(widget.creatorId);
    final allWorkouts = await _settingsService.loadCommunityWorkouts();
    final creatorWorkouts = allWorkouts
        .where((entry) => entry.creatorId == widget.creatorId)
        .toList(growable: false);
    final isFollowing = creatorWorkouts.isNotEmpty
        ? creatorWorkouts.first.isFollowingCreator
        : false;
    if (!mounted) {
      return;
    }
    setState(() {
      _stats = stats;
      _workouts = creatorWorkouts;
      _isFollowing = isFollowing;
      _loading = false;
    });
  }

  Future<void> _toggleFollow() async {
    final next = await _settingsService.toggleFollowCreator(widget.creatorId);
    if (!mounted) {
      return;
    }
    setState(() {
      _workouts = next;
      _isFollowing = next.any((w) => w.creatorId == widget.creatorId && w.isFollowingCreator);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_stats.username),
        backgroundColor: const Color(0xFF101A2B),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF141B2D), Color(0xFF0A1020), Color(0xFF1A2439)],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
                  children: [
                    _ProfileHeader(stats: _stats, isFollowing: _isFollowing, onToggleFollow: _toggleFollow),
                    const SizedBox(height: 16),
                    if (_stats.bio.trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          _stats.bio,
                          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                        ),
                      ),
                    if (_stats.bio.trim().isNotEmpty) const SizedBox(height: 16),
                    if (_stats.badges.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _stats.badges
                            .map((badge) => _pill(badge, Icons.workspace_premium_rounded))
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const Text(
                      'Published Workouts',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (_workouts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(22),
                        child: Text(
                          'No published workouts yet.',
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ..._workouts.map(
                        (entry) => _WorkoutTile(workout: entry),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.stats,
    required this.isFollowing,
    required this.onToggleFollow,
  });

  final CreatorCommunityStats stats;
  final bool isFollowing;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF384A6A), Color(0xFF2E314A)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white70, width: 2),
              gradient: const LinearGradient(
                colors: [Color(0xFF8EA1BE), Color(0xFF5A6C86)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: stats.profileImagePath.trim().isEmpty
                ? const Icon(Icons.person_rounded, size: 36, color: Colors.white)
                : Image.file(
                    File(stats.profileImagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) {
                      return const Icon(Icons.person_rounded, size: 36, color: Colors.white);
                    },
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@${stats.username}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _pill('${stats.totalPublished} workouts', Icons.grid_view_rounded),
                    _pill('${stats.followers} followers', Icons.groups_rounded),
                    _pill('${stats.likesReceived} likes', Icons.favorite_rounded),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutTile extends StatelessWidget {
  const _WorkoutTile({required this.workout});

  final CommunityWorkout workout;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout.title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  '${workout.downloads} downloads \u2022 ${workout.likes} likes \u2022 ${workout.averageRating.toStringAsFixed(1)} \u2605',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _pill(String label, IconData icon) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.09),
      border: Border.all(color: Colors.white24),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.white),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
      ],
    ),
  );
}
