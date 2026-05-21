import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/transcript_repository.dart';

final transcriptRepositoryProvider =
    Provider<TranscriptRepository>((_) => TranscriptRepository());

final transcriptProvider =
    FutureProvider.family<Transcript, String>((ref, meetingId) {
  final repo = ref.read(transcriptRepositoryProvider);
  return repo.getTranscript(meetingId);
});