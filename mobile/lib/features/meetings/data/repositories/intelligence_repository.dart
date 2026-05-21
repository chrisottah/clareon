import 'package:clareon/core/network/api_client.dart';

class MeetingIntelligence {
  final String meetingId;
  final String? summary;
  final List<String> actionPoints;
  final List<String> keyInsights;

  MeetingIntelligence({
    required this.meetingId,
    this.summary,
    this.actionPoints = const [],
    this.keyInsights = const [],
  });

  factory MeetingIntelligence.fromJson(Map<String, dynamic> json) {
    return MeetingIntelligence(
      meetingId: json['meeting_id'].toString(),
      summary: json['summary'],
      actionPoints: (json['action_points'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      keyInsights: (json['key_insights'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class IntelligenceRepository {
  final _dio = ApiClient.dio;

  Future<MeetingIntelligence> getIntelligence(String meetingId) async {
    final response = await _dio.get('/intelligence/$meetingId');
    return MeetingIntelligence.fromJson(response.data);
  }
}