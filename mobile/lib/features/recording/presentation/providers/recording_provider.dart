import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/recording_session.dart';
import '../data/repositories/recording_repository.dart';

enum RecordingStatus {
  idle,
  requestingPermission,
  recording,
  paused,
  stopping,
  uploading,
  uploaded,
  error,
}

class RecordingState {
  final RecordingStatus status;
  final RecordingSession? session;
  final String? errorMessage;
  final String? uploadedMeetingId;
  final double uploadProgress;

  const RecordingState({
    this.status = RecordingStatus.idle,
    this.session,
    this.errorMessage,
    this.uploadedMeetingId,
    this.uploadProgress = 0,
  });

  RecordingState copyWith({
    RecordingStatus? status,
    RecordingSession? session,
    String? errorMessage,
    String? uploadedMeetingId,
    double? uploadProgress,
  }) =>
      RecordingState(
        status: status ?? this.status,
        session: session ?? this.session,
        errorMessage: errorMessage,
        uploadedMeetingId: uploadedMeetingId ?? this.uploadedMeetingId,
        uploadProgress: uploadProgress ?? this.uploadProgress,
      );

  bool get isActive =>
      status == RecordingStatus.recording || status == RecordingStatus.paused;
}

class RecordingNotifier extends StateNotifier<RecordingState> {
  final RecordingRepository _repo;
  Timer? _timer;

  RecordingNotifier(this._repo) : super(const RecordingState());

  Future<void> startRecording() async {
    // Check permission first
    state = state.copyWith(status: RecordingStatus.requestingPermission);
    final hasPermission = await _repo.hasPermission();
    if (!hasPermission) {
      state = state.copyWith(
        status: RecordingStatus.error,
        errorMessage: 'Microphone permission denied. Please enable it in Settings.',
      );
      return;
    }

    try {
      final filePath = await _repo.startRecording();
      final session = RecordingSession(
        filePath: filePath,
        startedAt: DateTime.now(),
        duration: Duration.zero,
      );
      state = state.copyWith(status: RecordingStatus.recording, session: session);
      _startTimer();
    } catch (e) {
      state = state.copyWith(
        status: RecordingStatus.error,
        errorMessage: 'Failed to start recording: $e',
      );
    }
  }

  Future<void> pauseRecording() async {
    if (state.status != RecordingStatus.recording) return;
    await _repo.pauseRecording();
    _timer?.cancel();
    state = state.copyWith(
      status: RecordingStatus.paused,
      session: state.session?.copyWith(isPaused: true),
    );
  }

  Future<void> resumeRecording() async {
    if (state.status != RecordingStatus.paused) return;
    await _repo.resumeRecording();
    state = state.copyWith(
      status: RecordingStatus.recording,
      session: state.session?.copyWith(isPaused: false),
    );
    _startTimer();
  }

  Future<String?> stopAndUpload(String title) async {
    if (!state.isActive) return null;
    _timer?.cancel();

    state = state.copyWith(status: RecordingStatus.stopping);

    try {
      final filePath = await _repo.stopRecording();
      if (filePath == null) throw Exception('No recording file produced');

      final session = state.session!;
      state = state.copyWith(
        status: RecordingStatus.uploading,
        uploadProgress: 0,
      );

      final meetingId = await _repo.uploadRecording(
        filePath: filePath,
        title: title.isEmpty ? 'Meeting ${_formattedDate()}' : title,
        durationSeconds: session.duration.inSeconds,
        recordedAt: session.startedAt,
      );

      // Clean up local file after successful upload
      await _repo.deleteLocalFile(filePath);

      state = state.copyWith(
        status: RecordingStatus.uploaded,
        uploadedMeetingId: meetingId,
        uploadProgress: 1.0,
      );

      return meetingId;
    } catch (e) {
      state = state.copyWith(
        status: RecordingStatus.error,
        errorMessage: 'Upload failed: $e',
      );
      return null;
    }
  }

  void reset() {
    _timer?.cancel();
    state = const RecordingState();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.session == null) return;
      state = state.copyWith(
        session: state.session!.copyWith(
          duration: state.session!.duration + const Duration(seconds: 1),
        ),
      );
    });
  }

  String _formattedDate() {
    final now = DateTime.now();
    return '${now.day}/${now.month}/${now.year}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _repo.dispose();
    super.dispose();
  }
}

final recordingRepositoryProvider =
    Provider<RecordingRepository>((_) => RecordingRepository());

final recordingProvider =
    StateNotifierProvider<RecordingNotifier, RecordingState>(
  (ref) => RecordingNotifier(ref.read(recordingRepositoryProvider)),
);
