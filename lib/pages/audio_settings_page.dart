import 'package:flutter/material.dart';
import 'package:my_app/models/cached_workout_info.dart';
import 'package:my_app/models/workout_fingerprint.dart';
import 'package:my_app/services/audio_engine.dart';
import 'package:my_app/services/settings_service.dart';

class AudioSettingsPage extends StatefulWidget {
  const AudioSettingsPage({
    super.key,
    required this.audioEngine,
    required this.settings,
    required this.onSettingsChanged,
    this.currentFingerprint,
    this.currentExerciseNames,
  });

  final AudioEngine audioEngine;
  final AppSettings settings;
  final VoidCallback onSettingsChanged;
  final String? currentFingerprint;
  final List<String>? currentExerciseNames;

  @override
  State<AudioSettingsPage> createState() => _AudioSettingsPageState();
}

class _AudioSettingsPageState extends State<AudioSettingsPage> {
  late bool _voiceEnabled;
  late double _speechRate;
  late bool _countdownBeeps;
  late bool _transitionSound;
  late bool _musicDucking;

  List<CachedWorkoutInfo> _cachedWorkouts = [];
  int _cacheSizeBytes = 0;

  @override
  void initState() {
    super.initState();
    _voiceEnabled = widget.settings.voiceCueEnabled;
    _speechRate = widget.settings.voiceCueRate;
    _countdownBeeps = widget.settings.countdownBeepsEnabled;
    _transitionSound = widget.settings.transitionSoundEnabled;
    _musicDucking = widget.settings.musicDuckingEnabled;
    _loadCacheInfo();
  }

  Future<void> _loadCacheInfo() async {
    final workouts = await widget.audioEngine.getCachedWorkouts();
    final size = await widget.audioEngine.getCacheSizeBytes();
    if (mounted) {
      setState(() {
        _cachedWorkouts = workouts;
        _cacheSizeBytes = size;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Audio Settings',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSection(
            'VOICE COACH',
            [
              _buildSwitch('Voice Guidance', _voiceEnabled, (v) {
                setState(() => _voiceEnabled = v);
                widget.onSettingsChanged();
              }),
              _buildSlider('Speech Speed', _speechRate, (v) {
                setState(() => _speechRate = v);
                widget.onSettingsChanged();
              }, min: 0.2, max: 0.8),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            'SOUND EFFECTS',
            [
              _buildSwitch('Countdown Beeps', _countdownBeeps, (v) {
                setState(() => _countdownBeeps = v);
                widget.audioEngine.updateSettings(countdownBeepsEnabled: v);
                widget.onSettingsChanged();
              }),
              _buildSwitch('Transition Sound', _transitionSound, (v) {
                setState(() => _transitionSound = v);
                widget.audioEngine.updateSettings(transitionSoundEnabled: v);
                widget.onSettingsChanged();
              }),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            'MUSIC',
            [
              _buildSwitch('Music Ducking', _musicDucking, (v) {
                setState(() => _musicDucking = v);
                widget.audioEngine.updateSettings(musicDuckingEnabled: v);
                widget.onSettingsChanged();
              }),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            'VOICE CACHE',
            [
              ListTile(
                title: const Text('Total Cache Size', style: TextStyle(color: Colors.white70)),
                trailing: Text(_formatBytes(_cacheSizeBytes), style: const TextStyle(color: Colors.white54)),
              ),
              if (_cachedWorkouts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No cached workouts', style: TextStyle(color: Colors.white38)),
                ),
              for (final workout in _cachedWorkouts)
                _buildWorkoutCacheCard(workout),
              const Divider(color: Colors.white12),
              ListTile(
                title: const Text('Clear All Cache', style: TextStyle(color: Color(0xFFEF4444))),
                onTap: () async {
                  await widget.audioEngine.clearCache();
                  await _loadCacheInfo();
                  if (!mounted || !context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cache cleared')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(color: Colors.white70)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: const Color(0xFF22C55E),
    );
  }

  Widget _buildSlider(String label, double value, ValueChanged<double> onChanged, {
    double min = 0.0,
    double max = 1.0,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70)),
              Text('${(value * 100).round()}%', style: const TextStyle(color: Colors.white54)),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: const Color(0xFF22C55E),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutCacheCard(CachedWorkoutInfo workout) {
    final isCurrent = workout.fingerprint == widget.currentFingerprint;
    final dateStr = '${workout.generatedAt.month}/${workout.generatedAt.day}/${workout.generatedAt.year}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isCurrent ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? const Color(0xFF22C55E).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  workout.name,
                  style: TextStyle(
                    color: isCurrent ? const Color(0xFF22C55E) : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('CURRENT', style: TextStyle(color: Color(0xFF22C55E), fontSize: 10, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${workout.clipCount} clips · ${_formatBytes(workout.sizeBytes)} · $dateStr',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildCacheAction(
                icon: Icons.play_arrow_rounded,
                label: 'Play',
                color: const Color(0xFF22C55E),
                onTap: () => _previewWorkout(workout),
              ),
              const SizedBox(width: 12),
              _buildCacheAction(
                icon: Icons.refresh_rounded,
                label: 'Rebuild',
                color: const Color(0xFFF59E0B),
                onTap: () => _rebuildWorkout(workout),
              ),
              const SizedBox(width: 12),
              _buildCacheAction(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                color: const Color(0xFFEF4444),
                onTap: () => _deleteWorkout(workout),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCacheAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Future<void> _previewWorkout(CachedWorkoutInfo workout) async {
    await widget.audioEngine.previewWorkoutClip(workout.fingerprint);
    if (!mounted || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Playing preview: ${workout.name}')),
    );
  }

  Future<void> _rebuildWorkout(CachedWorkoutInfo workout) async {
    if (widget.currentExerciseNames == null || widget.currentExerciseNames!.isEmpty) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No workout data available for rebuild')),
      );
      return;
    }
    if (!mounted || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Rebuilding: ${workout.name}...')),
    );
    await widget.audioEngine.rebuildCache(
      WorkoutFingerprint(
        workoutId: workout.fingerprint,
        exerciseNames: widget.currentExerciseNames!,
        exerciseDurations: [],
        restDurations: [],
        recoveryDurations: [],
      ),
      widget.currentExerciseNames!,
      workoutName: workout.name,
    );
    await _loadCacheInfo();
    if (!mounted || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Rebuilt: ${workout.name}')),
    );
  }

  Future<void> _deleteWorkout(CachedWorkoutInfo workout) async {
    await widget.audioEngine.deleteWorkoutCache(workout.fingerprint);
    await _loadCacheInfo();
    if (!mounted || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted: ${workout.name}')),
    );
  }
}
