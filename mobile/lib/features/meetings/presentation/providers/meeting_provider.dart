import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../data/repositories/meeting_repository.dart';

final meetingRepositoryProvider = Provider<MeetingRepository>(
  (_) => MeetingRepository(),
);

enum MeetingsStatus { initial, loading, success, error }

class MeetingsState {
  final MeetingsStatus status;
  final List<Meeting> meetings;
  final String? errorMessage;
  final String? completedMeetingId;

  const MeetingsState({
    this.status = MeetingsStatus.initial,
    this.meetings = const [],
    this.errorMessage,
    this.completedMeetingId,
  });

  MeetingsState copyWith({
    MeetingsStatus? status,
    List<Meeting>? meetings,
    String? errorMessage,
    String? completedMeetingId,
    bool clearCompletedNotification = false,
  }) =>
      MeetingsState(
        status: status ?? this.status,
        meetings: meetings ?? this.meetings,
        errorMessage: errorMessage,
        completedMeetingId: clearCompletedNotification
            ? null
            : (completedMeetingId ?? this.completedMeetingId),
      );
}

class MeetingsNotifier extends StateNotifier<MeetingsState> {
  final MeetingRepository _repo;
  Timer? _pollTimer;

  MeetingsNotifier(this._repo) : super(const MeetingsState());

  Future<void> loadMeetings() async {
    state = state.copyWith(status: MeetingsStatus.loading);
    try {
      final meetings = await _repo.getMeetings();

      // Detect newly completed meetings
      String? justCompleted;
      for (final m in meetings) {
        final old = state.meetings.where((om) => om.id == m.id).firstOrNull;
        if (old != null && !old.isCompleted && m.isCompleted) {
          justCompleted = m.id;
        }
      }

      state = state.copyWith(
        status: MeetingsStatus.success,
        meetings: meetings,
        errorMessage: null,
        completedMeetingId: justCompleted,
      );
    } catch (e) {
      state = state.copyWith(
        status: MeetingsStatus.error,
        errorMessage: _parseError(e),
      );
    }
  }

  void clearCompletedNotification() {
    state = state.copyWith(clearCompletedNotification: true);
  }

  Future<bool> deleteMeeting(String id) async {
    try {
      await _repo.deleteMeeting(id);
      state = state.copyWith(
        meetings: state.meetings.where((m) => m.id != id).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: _parseError(e));
      return false;
    }
  }

  Future<bool> updateTitle(String id, String newTitle) async {
    try {
      await _repo.updateMeetingTitle(id, newTitle);
      state = state.copyWith(
        meetings: state.meetings
            .map((m) => m.id == id
                ? Meeting(
                    id: m.id,
                    title: newTitle,
                    status: m.status,
                    createdAt: m.createdAt,
                    durationSeconds: m.durationSeconds,
                  )
                : m)
            .toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: _parseError(e));
      return false;
    }
  }

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      loadMeetings();
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  String _parseError(Object e) {
    if (e is DioException && e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map && data['detail'] != null) return data['detail'].toString();
    }
    return 'Something went wrong.';
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}

final meetingsProvider =
    StateNotifierProvider<MeetingsNotifier, MeetingsState>(
  (ref) => MeetingsNotifier(ref.read(meetingRepositoryProvider)),
);