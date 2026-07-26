class CachedWorkoutInfo {
  const CachedWorkoutInfo({
    required this.fingerprint,
    required this.name,
    required this.sizeBytes,
    required this.generatedAt,
    required this.clipCount,
  });

  final String fingerprint;
  final String name;
  final int sizeBytes;
  final DateTime generatedAt;
  final int clipCount;
}
