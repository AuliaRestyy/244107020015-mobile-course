import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api_key_store.dart';
import '../../data/gemini_ai_repository.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/failures/ai_failure.dart';
import '../../domain/repositories/ai_repository.dart';
import '../../domain/usecases/send_chat_message.dart';

final apiKeyStoreProvider = Provider<ApiKeyStore>(
  (ref) => SecureStorageApiKeyStore(),
);

final aiRepositoryProvider = Provider<AiRepository>(
  (ref) => GeminiAiRepository(apiKeyStore: ref.watch(apiKeyStoreProvider)),
);

final sendChatMessageProvider = Provider<SendChatMessage>(
  (ref) => SendChatMessage(ref.watch(aiRepositoryProvider)),
);

class ChatState {
  const ChatState({
    this.messages = const [],
    this.isStreaming = false,
    this.error,
  });

  final List<ChatMessage> messages;
  final bool isStreaming;
  final AiFailure? error;
}

class ChatNotifier extends Notifier<ChatState> {
  StreamSubscription<String>? _subscription;
  String? _lastPrompt;
  List<ChatMessage> _lastHistory = const [];

  @override
  ChatState build() {
    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });
    return const ChatState();
  }

  void send(String raw) {
    final text = raw.trim();
    if (text.isEmpty || state.isStreaming) return;
    _start(text: text, history: state.messages);
  }

  void retry() {
    final text = _lastPrompt;
    if (text == null || state.isStreaming) return;
    _start(text: text, history: _lastHistory);
  }

  void _start({required String text, required List<ChatMessage> history}) {
    _lastPrompt = text;
    _lastHistory = history;

    state = ChatState(
      messages: [
        ...history,
        ChatMessage(role: ChatRole.user, text: text),
        const ChatMessage(role: ChatRole.assistant, text: ''),
      ],
      isStreaming: true,
    );

    _subscription?.cancel();
    _subscription = ref
        .read(sendChatMessageProvider)
        .call(message: text, history: history)
        .listen(
          _onChunk,
          onError: _onError,
          onDone: _onDone,
          cancelOnError: true,
        );
  }

  void _onChunk(String chunk) {
    if (!ref.mounted || !state.isStreaming) return;
    final messages = List<ChatMessage>.of(state.messages);
    if (messages.isEmpty) return;
    final last = messages.removeLast();
    messages.add(ChatMessage(role: last.role, text: '${last.text}$chunk'));
    state = ChatState(messages: messages, isStreaming: true);
  }

  void _onError(Object error) {
    if (!ref.mounted) return;
    final failure = error is AiFailure
        ? error
        : AiServerErrorFailure('Terjadi kesalahan tak terduga: $error');
    state = ChatState(
      messages: _withoutEmptyReply(state.messages),
      error: failure,
    );
  }

  void _onDone() {
    if (!ref.mounted) return;
    final messages = state.messages;
    final reply = messages.isEmpty ? '' : messages.last.text;
    if (reply.trim().isEmpty) {
      state = ChatState(
        messages: _withoutEmptyReply(messages),
        error: const AiEmptyResponseFailure(),
      );
      return;
    }
    state = ChatState(messages: messages);
  }

  List<ChatMessage> _withoutEmptyReply(List<ChatMessage> messages) {
    if (messages.isEmpty) return messages;
    final last = messages.last;
    if (last.role != ChatRole.assistant || last.text.isNotEmpty) {
      return messages;
    }
    return messages.sublist(0, messages.length - 1);
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(
  ChatNotifier.new,
);
