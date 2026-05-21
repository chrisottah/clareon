import 'package:clareon/core/network/api_client.dart';

class TranscriptSegment {
  final String id;
  final String meetingId;
  final double startTime;
  final double endTime;
  final String text;
  final String? speaker;
  final double? confidence;
  final int segmentIndex;

  TranscriptSegment({
    required this.id,
    required this.meetingId,
    required this.startTime,
    required this.endTime,
    required this.text,
    this.speaker,
    this.confidence,
    required this.segmentIndex,
  });

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) {
    return TranscriptSegment(
      id: json['id'].toString(),
      meetingId: json['meeting_id'].toString(),
      startTime: (json['start_time'] as num).toDouble(),
      endTime: (json['end_time'] as num).toDouble(),
      text: json['text'] ?? '',
      speaker: json['speaker'],
      confidence: json['confidence']?.toDouble(),
      segmentIndex: json['segment_index'] ?? 0,
    );
  }
}

class Transcript {
  final String meetingId;
  final List<TranscriptSegment> segments;
  final double totalDuration;
  final int segmentCount;

  Transcript({
    required this.meetingId,
    required this.segments,
    required this.totalDuration,
    required this.segmentCount,
  });

  factory Transcript.fromJson(Map<String, dynamic> json) {
    return Transcript(
      meetingId: json['meeting_id'].toString(),
      segments: (json['segments'] as List<dynamic>? ?? [])
          .map((s) => TranscriptSegment.fromJson(s))
          .toList(),
      totalDuration: (json['total_duration'] as num?)?.toDouble() ?? 0.0,
      segmentCount: json['segment_count'] ?? 0,
    );
  }
}

class TranscriptRepository {
  final _dio = ApiClient.dio;

  Future<Transcript> getTranscript(String meetingId) async {
    final response = await _dio.get('/transcripts/$meetingId');
    return Transcript.fromJson(response.data);
  }
}