import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../routes.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/failures/ai_failure.dart';
import '../../domain/usecases/send_chat_message.dart';
import '../providers/chat_providers.dart';
import '../widgets/api_key_dialog.dart';

String aiFailureHeadline(AiFailure failure) => switch (failure) {
  AiMissingApiKeyFailure() => 'API key Gemini belum diatur.',
  AiUnauthorizedFailure() => 'API key Gemini ditolak.',
  AiRateLimitedFailure() => 'Layanan AI sedang sibuk, coba lagi nanti.',
  AiServerErrorFailure() => 'Layanan AI sedang sibuk, coba lagi nanti.',
  AiNetworkFailure() => 'Layanan AI sedang sibuk, coba lagi nanti.',
  AiTimeoutFailure() => 'Layanan AI sedang sibuk, coba lagi nanti.',
  AiEmptyResponseFailure() => 'AI tidak mengirim jawaban.',
  AiInvalidInputFailure() => failure.message,
};

bool aiFailureNeedsKey(AiFailure failure) =>
    failure is AiMissingApiKeyFailure || failure is AiUnauthorizedFailure;

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || ref.read(chatProvider).isStreaming) return;
    _controller.clear();
    setState(() {});
    ref.read(chatProvider.notifier).send(text);
    _scrollToEnd();
  }

  void _retry() {
    ref.read(chatProvider.notifier).retry();
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);
    final failure = state.error;
    final canSend =
        _controller.text.trim().isNotEmpty &&
        !state.isStreaming &&
        _controller.text.trim().length <= SendChatMessage.maxLength;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat AI'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.notes),
        ),
        actions: [
          IconButton(
            key: const ValueKey('chat-open-api-key'),
            tooltip: 'API key Gemini',
            onPressed: () => showApiKeyDialog(context),
            icon: const Icon(Icons.key),
          ),
        ],
      ),
      body: Column(
        children: [
          if (state.isStreaming)
            const LinearProgressIndicator(
              key: ValueKey('chat-streaming'),
              minHeight: 2,
            ),
          Expanded(
            child: state.messages.isEmpty
                ? const _ChatEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final message = state.messages[index];
                      return _Bubble(
                        key: ValueKey('chat-message-$index'),
                        isUser: message.role != ChatRole.assistant,
                        text: message.text,
                      );
                    },
                  ),
          ),
          if (failure != null)
            _FailurePanel(
              failure: failure,
              onRetry: _retry,
              onOpenKey: () => showApiKeyDialog(context),
            ),
          _Composer(
            controller: _controller,
            canSend: canSend,
            isStreaming: state.isStreaming,
            onChanged: () => setState(() {}),
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          const Text(
            'Tanya apa saja ke asisten AI. '
            'Jangan kirim data pribadi atau isi catatanmu.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.isUser, required this.text});

  final bool isUser;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: isUser ? scheme.primaryContainer : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text.isEmpty ? '…' : text),
      ),
    );
  }
}

class _FailurePanel extends StatelessWidget {
  const _FailurePanel({
    required this.failure,
    required this.onRetry,
    required this.onOpenKey,
  });

  final AiFailure failure;
  final VoidCallback onRetry;
  final VoidCallback onOpenKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const ValueKey('chat-failure'),
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              aiFailureHeadline(failure),
              style: TextStyle(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Catatan offline tetap bisa dipakai seperti biasa.',
              style: TextStyle(color: scheme.onErrorContainer),
            ),
            Wrap(
              children: [
                if (aiFailureNeedsKey(failure))
                  TextButton(
                    key: const ValueKey('chat-open-key-from-error'),
                    onPressed: onOpenKey,
                    child: const Text('Atur API key'),
                  ),
                TextButton(
                  key: const ValueKey('chat-retry'),
                  onPressed: onRetry,
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.canSend,
    required this.isStreaming,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool canSend;
  final bool isStreaming;
  final VoidCallback onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              onSubmitted: (_) {
                if (canSend) onSend();
              },
              minLines: 1,
              maxLines: 4,
              maxLength: SendChatMessage.maxLength,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              decoration: const InputDecoration(
                hintText: 'Tulis pesan…',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            key: const ValueKey('chat-send'),
            tooltip: 'Kirim',
            onPressed: canSend ? onSend : null,
            icon: Icon(isStreaming ? Icons.hourglass_top : Icons.send),
          ),
        ],
      ),
    ),
  );
}
