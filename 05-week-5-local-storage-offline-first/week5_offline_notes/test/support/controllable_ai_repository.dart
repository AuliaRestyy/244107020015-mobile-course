import 'dart:async';

import 'package:week5_offline_notes/features/chat/domain/entities/chat_message.dart';
import 'package:week5_offline_notes/features/chat/domain/failures/ai_failure.dart';
import 'package:week5_offline_notes/features/chat/domain/repositories/ai_repository.dart';

class ControllableAiRepository implements AiRepository {
  ControllableAiRepository({this.failOnCall = 0, this.error});
  int failOnCall;

  final AiFailure? error;

  final List<StreamController<String>> _controllers = [];
  final List<List<ChatMessage>> histories = [];

  int get callCount => _controllers.length;

  List<ChatMessage> get lastHistory => histories.last;

  @override
  Stream<String> sendMessage(List<ChatMessage> history) {
    final controller = StreamController<String>();
    _controllers.add(controller);
    histories.add(List<ChatMessage>.unmodifiable(history));
    final failure = error;
    if (failure != null && _controllers.length <= failOnCall) {
      scheduleMicrotask(() => controller.addError(failure));
    }
    return controller.stream;
  }

  void emit(String chunk) => _controllers.last.add(chunk);

  void dispose() {
    for (final controller in _controllers) {
      if (!controller.isClosed) unawaited(controller.close());
    }
  }
}
