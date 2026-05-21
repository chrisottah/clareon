import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/intelligence_repository.dart';

final intelligenceRepositoryProvider =
    Provider<IntelligenceRepository>((_) => IntelligenceRepository());

final intelligenceProvider =
    FutureProvider.family<MeetingIntelligence, String>((ref, meetingId) {
  final repo = ref.read(intelligenceRepositoryProvider);
  return repo.getIntelligence(meetingId);
});