import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';

class RecordingRepository {
  final AudioRecorder _recorder = AudioRecorder();
  final _dio = ApiClient.dio;

  /// Start recording — saves to app documents directory
  Future<String> startRecording() async {
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${dir.path}/meeting_$timestamp.m4a';

    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        bitRate: 128000,
        noiseSuppress: false, // Keep all audio for meeting context
      ),
      path: filePath,
    );

    return filePath;
  }

  Future<void> pauseRecording() async {
    await _recorder.pause();
  }

  Future<void> resumeRecording() async {
    await _recorder.resume();
  }

  /// Stop recording and return the saved file path
  Future<String?> stopRecording() async {
    return await _recorder.stop();
  }

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<bool> isRecording() async {
    return await _recorder.isRecording();
  }

  Future<bool> isPaused() async {
    return await _recorder.isPaused();
  }

  void dispose() {
    _recorder.dispose();
  }

  /// Upload audio file to backend
  Future<String> uploadRecording({
    required String filePath,
    required String title,
    required int durationSeconds,
    required DateTime recordedAt,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Recording file not found');
    }

    final formData = FormData.fromMap({
      'audio': await MultipartFile.fromFile(
        filePath,
        filename: filePath.split('/').last,
      ),
      'title': title,
      'duration_seconds': durationSeconds.toString(),
      'recorded_at': recordedAt.toIso8601String(),
    });

    final response = await _dio.post('/meetings/upload', data: formData);
    return response.data['meeting_id'] as String;
  }

  /// Delete local recording file after successful upload
  Future<void> deleteLocalFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
