import 'dart:convert';
import 'package:crypto/crypto.dart';

class WorkoutFingerprint {
  const WorkoutFingerprint({
    required this.workoutId,
    required this.exerciseNames,
    required this.exerciseDurations,
    required this.restDurations,
    required this.recoveryDurations,
    this.voiceSelection = 'default_male',
    this.language = 'en',
    this.voiceModelVersion = '1.0',
  });

  final String workoutId;
  final List<String> exerciseNames;
  final List<int> exerciseDurations;
  final List<int> restDurations;
  final List<int> recoveryDurations;
  final String voiceSelection;
  final String language;
  final String voiceModelVersion;

  String compute() {
    final buffer = StringBuffer()
      ..write(workoutId)
      ..write('|')
      ..write(exerciseNames.join(','))
      ..write('|')
      ..write(exerciseDurations.join(','))
      ..write('|')
      ..write(restDurations.join(','))
      ..write('|')
      ..write(recoveryDurations.join(','))
      ..write('|')
      ..write(voiceSelection)
      ..write('|')
      ..write(language)
      ..write('|')
      ..write(voiceModelVersion);

    final bytes = utf8.encode(buffer.toString());
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 8).toUpperCase();
  }
}
