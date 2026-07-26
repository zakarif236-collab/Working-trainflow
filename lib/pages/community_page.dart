import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/models/workout_models.dart';
import 'package:my_app/pages/auth_page.dart';
import 'package:my_app/pages/user_profile_page.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/settings_service.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage>
    with SingleTickerProviderStateMixin {
  final SettingsService _settingsService = SettingsService();
  final ImagePicker _imagePicker = ImagePicker();
  final List<String> _allTags = const [
    'HIIT',
    'Cardio',
    'Fat Loss',
    'Strength',
    'Core',
    'Legs',
    'Full Body',
    'Home',
    'Gym',
    'No Equipment',
  ];
  late final TabController _tabController;

  List<CommunityWorkout> _workouts = const [];
  List<WorkoutBuilderRoutine> _myRoutines = const [];
  final Set<String> _selectedTags = <String>{};
  WorkoutBuilderRoutine? _prefillRoutine;
  bool _didReadArgs = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: CommunityTabKind.values.length, vsync: this);
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didReadArgs) {
      return;
    }
    _didReadArgs = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is WorkoutBuilderRoutine) {
      _prefillRoutine = args;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openPublishSheet(prefillRoutine: args);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final workouts = await _settingsService.loadCommunityWorkouts();
    final routines = await _settingsService.loadWorkoutBuilderRoutines();
    if (!mounted) {
      return;
    }
    setState(() {
      _workouts = workouts;
      _myRoutines = routines;
      _loading = false;
    });
  }

  final AuthService _authService = AuthService();

  Future<bool> _requireAuth() async {
    if (_authService.currentUserId != null) return true;
    final signedIn = await AuthPage.showAsSheet(context);
    return signedIn;
  }

  Future<void> _toggleLike(CommunityWorkout workout) async {
    if (!await _requireAuth()) return;
    final next = await _settingsService.toggleCommunityLike(workout.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _workouts = next;
    });
  }

  Future<void> _toggleFavorite(CommunityWorkout workout) async {
    if (!await _requireAuth()) return;
    final next = await _settingsService.toggleCommunityFavorite(workout.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _workouts = next;
    });
  }

  Future<void> _saveToMyWorkouts(CommunityWorkout workout) async {
    if (!await _requireAuth()) return;
    final next = await _settingsService.saveCommunityWorkoutToMyWorkouts(workout.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _workouts = next;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved "${workout.title}" to My Workouts.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _shareWorkout(CommunityWorkout workout) async {
    if (!await _requireAuth()) return;
    final shareText =
        'Check out ${workout.title} by @${workout.creatorUsername}: fitpulse://community/${workout.id}';
    await Clipboard.setData(ClipboardData(text: shareText));
    final next = await _settingsService.incrementCommunityShare(workout.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _workouts = next;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share link copied to clipboard.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _rateWorkout(CommunityWorkout workout) async {
    if (!await _requireAuth() || !mounted) return;
    final selected = await showDialog<int>(
      context: context,
      builder: (context) {
        var current = workout.userRating ?? 5;
        return AlertDialog(
          backgroundColor: const Color(0xFF1A2235),
          title: Text('Rate "${workout.title}"'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Your rating: $current star${current == 1 ? '' : 's'}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    children: List<Widget>.generate(5, (index) {
                      final star = index + 1;
                      return IconButton.filled(
                        onPressed: () => setDialogState(() => current = star),
                        style: IconButton.styleFrom(
                          backgroundColor: star <= current
                              ? const Color(0xFFFFC857)
                              : Colors.white.withValues(alpha: 0.12),
                        ),
                        icon: Icon(
                          Icons.star_rounded,
                          color: star <= current
                              ? const Color(0xFF2A1A02)
                              : Colors.white60,
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(current),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (selected == null) {
      return;
    }

    final next = await _settingsService.rateCommunityWorkout(workout.id, selected);
    if (!mounted) {
      return;
    }
    setState(() {
      _workouts = next;
    });
  }

  Future<void> _commentWorkout(CommunityWorkout workout) async {
    if (!await _requireAuth() || !mounted) return;
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A2235),
          title: Text('Comment on "${workout.title}"'),
          content: TextField(
            controller: controller,
            maxLength: 140,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Great flow and pacing.',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Post'),
            ),
          ],
        );
      },
    );

    if (text == null || text.trim().isEmpty) {
      return;
    }

    final next = await _settingsService.addCommunityComment(workout.id, text);
    if (!mounted) {
      return;
    }
    setState(() {
      _workouts = next;
    });
  }

  Future<void> _toggleFollowCreator(CommunityWorkout workout) async {
    if (!await _requireAuth()) return;
    final next = await _settingsService.toggleFollowCreator(workout.creatorId);
    if (!mounted) {
      return;
    }
    setState(() {
      _workouts = next;
    });
  }

  Future<void> _openCreatorProfile(CommunityWorkout workout) async {
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfilePage(creatorId: workout.creatorId),
      ),
    );
    await _loadData();
  }

  Future<void> _openPublishSheet({WorkoutBuilderRoutine? prefillRoutine}) async {
    if (!await _requireAuth() || !mounted) return;
    if (_myRoutines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a workout first, then publish it to community.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await showModalBottomSheet<PublishCommunityWorkoutInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101A2B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _PublishWorkoutSheet(
          imagePicker: _imagePicker,
          routines: _myRoutines,
          allTags: _allTags,
          prefillRoutine: prefillRoutine ?? _prefillRoutine,
        );
      },
    );

    _prefillRoutine = null;
    if (result == null) {
      return;
    }

    final published = await _settingsService.publishCommunityWorkout(result);
    if (published == null) {
      return;
    }
    await _loadData();

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Published "${published.title}" to Community.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<CommunityWorkout> _filteredForTab(CommunityTabKind tab) {
    var filtered = _workouts;

    if (_selectedTags.isNotEmpty) {
      filtered = filtered
          .where((entry) => entry.tags.any((tag) => _selectedTags.contains(tag)))
          .toList(growable: false);
    }

    switch (tab) {
      case CommunityTabKind.trending:
        filtered.sort((a, b) {
          final scoreA = (a.likes * 2) + (a.downloads * 3) + a.comments.length;
          final scoreB = (b.likes * 2) + (b.downloads * 3) + b.comments.length;
          return scoreB.compareTo(scoreA);
        });
        break;
      case CommunityTabKind.popular:
        filtered.sort((a, b) {
          final scoreA = a.likes + a.favorites + a.downloads;
          final scoreB = b.likes + b.favorites + b.downloads;
          return scoreB.compareTo(scoreA);
        });
        break;
      case CommunityTabKind.newest:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case CommunityTabKind.following:
        filtered = filtered
            .where((entry) => entry.isFollowingCreator)
            .toList(growable: false)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case CommunityTabKind.favorites:
        filtered = filtered
            .where((entry) => entry.isFavorited)
            .toList(growable: false)
          ..sort((a, b) => b.likes.compareTo(a.likes));
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Workouts'),
        backgroundColor: const Color(0xFF101A2B),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Trending'),
            Tab(text: 'Most Popular'),
            Tab(text: 'Newest'),
            Tab(text: 'Following'),
            Tab(text: 'Favorites'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openPublishSheet,
        icon: const Icon(Icons.publish_rounded),
        label: const Text('Publish'),
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
            : Column(
                children: [
                  SizedBox(
                    height: 56,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      scrollDirection: Axis.horizontal,
                      children: [
                        FilterChip(
                          selected: _selectedTags.isEmpty,
                          onSelected: (_) {
                            setState(() {
                              _selectedTags.clear();
                            });
                          },
                          label: const Text('All Tags'),
                        ),
                        const SizedBox(width: 6),
                        ..._allTags.map((tag) {
                          final active = _selectedTags.contains(tag);
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              selected: active,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedTags.add(tag);
                                  } else {
                                    _selectedTags.remove(tag);
                                  }
                                });
                              },
                              label: Text(tag),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: CommunityTabKind.values.map((tab) {
                        final entries = _filteredForTab(tab);
                        if (entries.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(22),
                              child: Text(
                                'No workouts match this tab and filter combination yet.',
                                style: TextStyle(color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final workout = entries[index];
                            return _CommunityWorkoutCard(
                              workout: workout,
                              onLike: () => _toggleLike(workout),
                              onFavorite: () => _toggleFavorite(workout),
                              onSave: () => _saveToMyWorkouts(workout),
                              onShare: () => _shareWorkout(workout),
                              onComment: () => _commentWorkout(workout),
                              onRate: () => _rateWorkout(workout),
                              onCreatorTap: () => _openCreatorProfile(workout),
                              onFollowCreator: () => _toggleFollowCreator(workout),
                            );
                          },
                        );
                      }).toList(growable: false),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CommunityWorkoutCard extends StatefulWidget {
  const _CommunityWorkoutCard({
    required this.workout,
    required this.onLike,
    required this.onFavorite,
    required this.onSave,
    required this.onShare,
    required this.onComment,
    required this.onRate,
    required this.onCreatorTap,
    required this.onFollowCreator,
  });

  final CommunityWorkout workout;
  final VoidCallback onLike;
  final VoidCallback onFavorite;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onComment;
  final VoidCallback onRate;
  final VoidCallback onCreatorTap;
  final VoidCallback onFollowCreator;

  @override
  State<_CommunityWorkoutCard> createState() => _CommunityWorkoutCardState();
}

class _CommunityWorkoutCardState extends State<_CommunityWorkoutCard> {
  bool _expanded = false;

  String _difficultyLabel(WorkoutDifficulty difficulty) {
    switch (difficulty) {
      case WorkoutDifficulty.beginner:
        return 'Beginner';
      case WorkoutDifficulty.intermediate:
        return 'Intermediate';
      case WorkoutDifficulty.advanced:
        return 'Advanced';
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    if (minutes <= 0) {
      return '${remainder}s';
    }
    return '${minutes}m ${remainder.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    final workout = widget.workout;
    final allPills = [
      _PillData(workout.category, Icons.category_rounded),
      _PillData(_difficultyLabel(workout.difficulty), Icons.timeline_rounded),
      _PillData(_formatDuration(workout.estimatedDurationSeconds), Icons.timer_rounded),
      _PillData('${workout.exercises.length} exercises', Icons.fitness_center_rounded),
      ...workout.tags.map((tag) => _PillData(tag, Icons.sell_rounded)),
    ];
    final visiblePills = _expanded ? allPills : allPills.take(3).toList();
    final hasMore = allPills.length > 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      color: const Color(0xFF0D1421),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onCreatorTap,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF2A3A5C),
                    child: Text(
                      workout.creatorUsername.isNotEmpty
                          ? workout.creatorUsername[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Color(0xFF9BC4FF),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: widget.onCreatorTap,
                    child: Text(
                      workout.creatorUsername,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: widget.onFollowCreator,
                  child: Text(
                    workout.isFollowingCreator ? 'Following' : 'Follow',
                    style: TextStyle(
                      color: workout.isFollowingCreator
                          ? Colors.white54
                          : const Color(0xFF9BC4FF),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (workout.coverImagePath.trim().isNotEmpty)
            GestureDetector(
              onDoubleTap: widget.onLike,
              child: Image.file(
                File(workout.coverImagePath),
                width: double.infinity,
                height: 320,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) {
                  return Container(
                    height: 180,
                    alignment: Alignment.center,
                    color: const Color(0xFF141E30),
                    child: const Text('Cover unavailable', style: TextStyle(color: Colors.white38)),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onLike,
                  onLongPress: widget.onRate,
                  child: Icon(
                    workout.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: workout.isLiked ? const Color(0xFFFF4D6A) : Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: widget.onComment,
                  child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: widget.onShare,
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onSave,
                  child: Icon(
                    workout.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: workout.isSaved ? Colors.white : Colors.white,
                    size: 26,
                  ),
                ),
              ],
            ),
          ),
          if (workout.likes > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '${workout.likes} like${workout.likes == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: RichText(
              maxLines: _expanded ? null : 2,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${workout.title}  ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  TextSpan(
                    text: workout.description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (workout.comments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                'View all ${workout.comments.length} comment${workout.comments.length == 1 ? '' : 's'}',
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
          if (workout.comments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '${workout.comments.first.authorUsername}  ${workout.comments.first.message}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...visiblePills.map((p) => _pillSmall(p.label)),
                if (hasMore)
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _expanded
                            ? 'Less'
                            : '+${allPills.length - 3} more',
                        style: const TextStyle(
                          color: Color(0xFF9BC4FF),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              _timeAgo(workout.createdAt),
              style: const TextStyle(color: Colors.white30, fontSize: 11),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _PillData {
  final String label;
  final IconData icon;
  const _PillData(this.label, this.icon);
}

Widget _pillSmall(String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white70,
        fontWeight: FontWeight.w600,
        fontSize: 11,
      ),
    ),
  );
}

class _PublishWorkoutSheet extends StatefulWidget {
  const _PublishWorkoutSheet({
    required this.imagePicker,
    required this.routines,
    required this.allTags,
    this.prefillRoutine,
  });

  final ImagePicker imagePicker;
  final List<WorkoutBuilderRoutine> routines;
  final List<String> allTags;
  final WorkoutBuilderRoutine? prefillRoutine;

  @override
  State<_PublishWorkoutSheet> createState() => _PublishWorkoutSheetState();
}

class _PublishWorkoutSheetState extends State<_PublishWorkoutSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  WorkoutBuilderRoutine? _selectedRoutine;
  WorkoutDifficulty _difficulty = WorkoutDifficulty.beginner;
  String _category = 'HIIT';
  String _coverImagePath = '';
  Set<String> _tags = <String>{};

  @override
  void initState() {
    super.initState();
    _selectedRoutine = widget.prefillRoutine ?? widget.routines.first;
    _titleController.text = _selectedRoutine?.name ?? '';
    _tags = {'Full Body'};
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final picked = await widget.imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 88,
    );
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _coverImagePath = picked.path;
    });
  }

  void _submit() {
    final routine = _selectedRoutine;
    if (routine == null || routine.exercises.isEmpty) {
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      PublishCommunityWorkoutInput(
        title: title,
        description: _descriptionController.text,
        category: _category,
        difficulty: _difficulty,
        tags: _tags.toList(growable: false),
        coverImagePath: _coverImagePath,
        routine: routine,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Publish to Community',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<WorkoutBuilderRoutine>(
                initialValue: _selectedRoutine,
                decoration: const InputDecoration(
                  labelText: 'Workout',
                  border: OutlineInputBorder(),
                ),
                items: widget.routines
                    .map(
                      (routine) => DropdownMenuItem(
                        value: routine,
                        child: Text(routine.name),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  setState(() {
                    _selectedRoutine = value;
                    if (_titleController.text.trim().isEmpty && value != null) {
                      _titleController.text = value.name;
                    }
                  });
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _titleController,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: 'Workout Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLength: 200,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'HIIT', child: Text('HIIT')),
                        DropdownMenuItem(value: 'Cardio', child: Text('Cardio')),
                        DropdownMenuItem(value: 'Strength', child: Text('Strength')),
                        DropdownMenuItem(value: 'Mobility', child: Text('Mobility')),
                        DropdownMenuItem(value: 'Recovery', child: Text('Recovery')),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _category = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<WorkoutDifficulty>(
                      initialValue: _difficulty,
                      decoration: const InputDecoration(
                        labelText: 'Difficulty',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: WorkoutDifficulty.beginner,
                          child: Text('Beginner'),
                        ),
                        DropdownMenuItem(
                          value: WorkoutDifficulty.intermediate,
                          child: Text('Intermediate'),
                        ),
                        DropdownMenuItem(
                          value: WorkoutDifficulty.advanced,
                          child: Text('Advanced'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _difficulty = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Tags', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.allTags.map((tag) {
                  final selected = _tags.contains(tag);
                  return FilterChip(
                    selected: selected,
                    label: Text(tag),
                    onSelected: (active) {
                      setState(() {
                        if (active) {
                          _tags.add(tag);
                        } else {
                          _tags.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(growable: false),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickCover,
                      icon: const Icon(Icons.image_rounded),
                      label: Text(
                        _coverImagePath.trim().isEmpty ? 'Add Cover Image' : 'Change Cover',
                      ),
                    ),
                  ),
                  if (_coverImagePath.trim().isNotEmpty)
                    IconButton(
                      onPressed: () => setState(() => _coverImagePath = ''),
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
              if (_coverImagePath.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_coverImagePath),
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.public_rounded),
                  label: const Text('Publish to Community'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${(diff.inDays / 7).floor()}w ago';
}
