import 'package:dio/dio.dart';
import 'package:clareon/core/network/api_client.dart';

class Meeting {
  final String id;
  final String title;
  final String status; // uploaded, processing, completed, failed
  final DateTime createdAt;
  final int durationSeconds;

  Meeting({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    this.durationSeconds = 0,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      id: json['id'].toString(),
      title: json['title'] ?? 'Untitled Meeting',
      status: json['status'] ?? 'processing',
      createdAt: DateTime.parse(json['created_at']),
      durationSeconds: json['duration_seconds'] ?? 0,
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isProcessing =>
      status == 'processing' || status == 'uploaded';
  bool get isFailed => status == 'failed';

  String get statusLabel {
    switch (status) {
      case 'uploaded':
        return 'Queued';
      case 'processing':
        return 'Processing...';
      case 'completed':
        return 'Ready';
      case 'failed':
        return 'Failed';
      default:
        return status;
    }
  }

  String get formattedDuration {
    if (durationSeconds == 0) return '';
    final m = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (durationSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class MeetingRepository {
  final _dio = ApiClient.dio;

  Future<List<Meeting>> getMeetings() async {
    final response = await _dio.get('/meetings');
    final List<dynamic> data =
        response.data is List ? response.data : (response.data['meetings'] ?? []);
    return data.map((json) => Meeting.fromJson(json)).toList();
  }

  Future<Meeting> getMeeting(String id) async {
    final response = await _dio.get('/meetings/$id');
    return Meeting.fromJson(response.data);
  }

  Future<void> updateMeetingTitle(String id, String newTitle) async {
    await _dio.patch('/meetings/$id', data: {'title': newTitle});
  }

  Future<void> deleteMeeting(String id) async {
    await _dio.delete('/meetings/$id');
  }
}