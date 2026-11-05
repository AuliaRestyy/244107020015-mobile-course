import 'package:flutter_test/flutter_test.dart';
import 'package:week5_offline_notes/features/chat/domain/entities/chat_message.dart';
import 'package:week5_offline_notes/features/chat/domain/failures/ai_failure.dart';
import 'package:week5_offline_notes/features/chat/domain/usecases/send_chat_message.dart';

import 'support/fake_ai_repository.dart';

void main() {
  test('input kosong ditolak tanpa memanggil repository', () async {
    final repo = FakeAiRepository();
    final usecase = SendChatMessage(repo);

    await expectLater(
      usecase(message: '   '),
      emitsError(isA<AiInvalidInputFailure>()),
    );
    expect(repo.callCount, 0);
  });

  test('input lebih dari 500 karakter ditolak', () async {
    final repo = FakeAiRepository();
    final usecase = SendChatMessage(repo);

    await expectLater(
      usecase(message: 'a' * (SendChatMessage.maxLength + 1)),
      emitsError(isA<AiInvalidInputFailure>()),
    );
    expect(repo.callCount, 0);
  });

  test('input tepat 500 karakter diterima', () async {
    final repo = FakeAiRepository();
    final usecase = SendChatMessage(repo);

    await expectLater(
      usecase(message: 'a' * SendChatMessage.maxLength),
      emitsInOrder(<dynamic>['Halo', ' dunia', emitsDone]),
    );
    expect(repo.callCount, 1);
  });

  test('system prompt ditambahkan di awal riwayat', () async {
    final repo = FakeAiRepository();
    const history = [
      ChatMessage(role: ChatRole.user, text: 'halo'),
      ChatMessage(role: ChatRole.assistant, text: 'hai'),
    ];

    await SendChatMessage(repo)
        .call(message: ' apa kabar ', history: history)
        .toList();

    final payload = repo.lastHistory!;
    expect(payload.first.role, ChatRole.system);
    expect(payload.first.text, SendChatMessage.systemPrompt);
    expect(payload.first.text, contains('data pribadi'));
  });

  test('pesan pengguna di-trim dan ditaruh paling akhir', () async {
    final repo = FakeAiRepository();

    await SendChatMessage(repo).call(message: '  apa kabar  ').toList();

    final payload = repo.lastHistory!;
    expect(payload.length, 2);
    expect(payload.last.role, ChatRole.user);
    expect(payload.last.text, 'apa kabar');
  });

  test('stream dari repository diteruskan apa adanya', () async {
    final repo = FakeAiRepository(chunks: ['A', 'B', 'C']);

    await expectLater(
      SendChatMessage(repo).call(message: 'hai'),
      emitsInOrder(<dynamic>['A', 'B', 'C', emitsDone]),
    );
  });

  test('error dari repository diteruskan ke pemanggil', () async {
    final repo = FakeAiRepository(error: const AiRateLimitedFailure());

    await expectLater(
      SendChatMessage(repo).call(message: 'hai'),
      emitsError(isA<AiRateLimitedFailure>()),
    );
  });
}
