import 'package:week5_offline_notes/features/chat/domain/entities/chat_message.dart';
import 'package:week5_offline_notes/features/chat/domain/failures/ai_failure.dart';
import 'package:week5_offline_notes/features/chat/domain/repositories/ai_repository.dart';

class FakeAiRepository implements AiRepository {
  FakeAiRepository({this.chunks = const ['Halo', ' dunia'], this.error});

  final List<String> chunks;
  final AiFailure? error;
  List<ChatMessage>? lastHistory;
  int callCount = 0;

  @override
  Stream<String> sendMessage(List<ChatMessage> history) async* {
    callCount++;
    lastHistory = List<ChatMessage>.unmodifiable(history);
    final failure = error;
    if (failure != null) throw failure;
    for (final chunk in chunks) {
      yield chunk;
    }
  }
}
