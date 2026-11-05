import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:week5_offline_notes/features/chat/domain/failures/ai_failure.dart';
import 'package:week5_offline_notes/features/chat/presentation/pages/chat_screen.dart';
import 'package:week5_offline_notes/features/chat/presentation/providers/chat_providers.dart';

import 'support/controllable_ai_repository.dart';
import 'support/fake_api_key_store.dart';

Widget _app(ControllableAiRepository repo, {FakeApiKeyStore? keyStore}) =>
    ProviderScope(
      overrides: [
        aiRepositoryProvider.overrideWithValue(repo),
        apiKeyStoreProvider.overrideWithValue(
          keyStore ?? FakeApiKeyStore(FakeApiKeyStore.fakeKey),
        ),
      ],
      child: const MaterialApp(home: ChatScreen()),
    );

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

Future<void> _tapSend(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('chat-send')));
  await tester.pump();
}

void main() {
  testWidgets('tombol kirim nonaktif saat input kosong', (tester) async {
    final repo = ControllableAiRepository();
    await tester.pumpWidget(_app(repo));

    final sendButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('chat-send')),
    );
    expect(sendButton.onPressed, isNull);

    await _type(tester, 'halo');
    final enabledButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('chat-send')),
    );
    expect(enabledButton.onPressed, isNotNull);

    await _type(tester, '   ');
    final blankButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('chat-send')),
    );
    expect(blankButton.onPressed, isNull);

    repo.dispose();
  });

  testWidgets('jawaban AI muncul bertahap selama streaming', (tester) async {
    final repo = ControllableAiRepository();
    await tester.pumpWidget(_app(repo));

    await _type(tester, 'apa kabar?');
    await _tapSend(tester);

    expect(find.text('apa kabar?'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-streaming')), findsOneWidget);
    expect(find.text('Halo dunia'), findsNothing);

    repo.emit('Halo');
    await tester.pump();
    expect(find.text('Halo'), findsOneWidget);
    expect(find.text('Halo dunia'), findsNothing);

    repo.emit(' dunia');
    await tester.pump();
    expect(find.text('Halo dunia'), findsOneWidget);

    repo.dispose();
    await tester.pump();
    expect(find.byKey(const ValueKey('chat-streaming')), findsNothing);
  });

  testWidgets('kiriman ganda diblokir selama streaming', (tester) async {
    final repo = ControllableAiRepository();
    await tester.pumpWidget(_app(repo));

    await _type(tester, 'satu');
    await _tapSend(tester);
    expect(repo.callCount, 1);

    await _type(tester, 'dua');
    await _tapSend(tester);
    expect(repo.callCount, 1);

    repo.dispose();
    await tester.pump();
  });

  testWidgets('error rate limit menampilkan fallback dan tombol coba lagi', (
    tester,
  ) async {
    final repo = ControllableAiRepository(
      failOnCall: 1,
      error: const AiRateLimitedFailure(),
    );
    await tester.pumpWidget(_app(repo));

    await _type(tester, 'halo');
    await _tapSend(tester);
    await tester.pump();

    expect(
      find.text('Layanan AI sedang sibuk, coba lagi nanti.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('chat-retry')), findsOneWidget);
    expect(
      find.textContaining('Catatan offline tetap bisa dipakai'),
      findsOneWidget,
    );

    repo.dispose();
  });

  testWidgets('coba lagi mengirim ulang pesan yang gagal', (tester) async {
    final repo = ControllableAiRepository(
      failOnCall: 1,
      error: const AiServerErrorFailure(),
    );
    await tester.pumpWidget(_app(repo));

    await _type(tester, 'halo');
    await _tapSend(tester);
    await tester.pump();
    expect(find.byKey(const ValueKey('chat-failure')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chat-retry')));
    await tester.pump();

    expect(repo.callCount, 2);
    expect(find.byKey(const ValueKey('chat-failure')), findsNothing);

    repo.emit('Jawaban kedua');
    await tester.pump();
    expect(find.text('Jawaban kedua'), findsOneWidget);

    repo.dispose();
    await tester.pump();
    expect(find.byKey(const ValueKey('chat-streaming')), findsNothing);
  });

  testWidgets('missingApiKey menunjuk ke pengaturan API key', (tester) async {
    final repo = ControllableAiRepository(
      failOnCall: 1,
      error: const AiMissingApiKeyFailure(),
    );
    final keyStore = FakeApiKeyStore();
    await tester.pumpWidget(_app(repo, keyStore: keyStore));

    await _type(tester, 'halo');
    await _tapSend(tester);
    await tester.pump();

    expect(find.text('API key Gemini belum diatur.'), findsOneWidget);
    final openKey = find.byKey(const ValueKey('chat-open-key-from-error'));
    expect(openKey, findsOneWidget);

    await tester.tap(openKey);
    await tester.pumpAndSettle();

    expect(find.text('API key'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'kunci-baru');
    await tester.pump();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(await keyStore.readKey(), 'kunci-baru');

    repo.dispose();
  });

  testWidgets('stream yang selesai tanpa teks dianggap jawaban kosong', (
    tester,
  ) async {
    final repo = ControllableAiRepository();
    await tester.pumpWidget(_app(repo));

    await _type(tester, 'halo');
    await _tapSend(tester);
    repo.dispose();
    await tester.pump();

    expect(find.text('AI tidak mengirim jawaban.'), findsOneWidget);
  });
}
