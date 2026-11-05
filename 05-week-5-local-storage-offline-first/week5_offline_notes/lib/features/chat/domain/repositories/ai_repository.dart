import '../entities/chat_message.dart';

abstract class AiRepository {
  Stream<String> sendMessage(List<ChatMessage> history);
}
