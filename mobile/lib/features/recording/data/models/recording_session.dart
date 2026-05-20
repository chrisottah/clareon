class RecordingSession {
  final String filePath;
  final DateTime startedAt;
  final Duration duration;
  final bool isPaused;

  const RecordingSession({
    required this.filePath,
    required this.startedAt,
    required this.duration,
    this.isPaused = false,
  });

  RecordingSession copyWith({
    String? filePath,
    DateTime? startedAt,
    Duration? duration,
    bool? isPaused,
  }) =>
      RecordingSession(
        filePath: filePath ?? this.filePath,
        startedAt: startedAt ?? this.startedAt,
        duration: duration ?? this.duration,
        isPaused: isPaused ?? this.isPaused,
      );

  String get formattedDuration {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
