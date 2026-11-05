import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:week5_offline_notes/features/chat/data/gemini_ai_repository.dart';
import 'package:week5_offline_notes/features/chat/domain/entities/chat_message.dart';
import 'package:week5_offline_notes/features/chat/domain/failures/ai_failure.dart';

import 'support/fake_api_key_store.dart';
import 'support/fake_http_client_adapter.dart';

class _RawAdapter implements HttpClientAdapter {
  _RawAdapter(this.payload);

  final String payload;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(payload, 200);

  @override
  void close({bool force = false}) {}
}

const _history = [
  ChatMessage(role: ChatRole.system, text: 'system prompt'),
  ChatMessage(role: ChatRole.user, text: 'halo'),
];

class _ChunkedRawAdapter implements HttpClientAdapter {
  _ChunkedRawAdapter(this.chunks);
  final List<List<int>> chunks;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody(
    Stream<Uint8List>.fromIterable(
      chunks.map((chunk) => Uint8List.fromList(chunk)),
    ),
    200,
  );

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(HttpClientAdapter adapter) => Dio()..httpClientAdapter = adapter;

void main() {
  test('streaming 2 chunk menghasilkan 2 potongan teks', () async {
    final adapter = FakeHttpClientAdapter(chunks: ['Halo', ' dunia']);
    final repo = GeminiAiRepository(
      apiKeyStore: FakeApiKeyStore(FakeApiKeyStore.fakeKey),
      dio: _dioWith(adapter),
    );

    final chunks = await repo.sendMessage(_history).toList();

    expect(chunks, ['Halo', ' dunia']);
    expect(adapter.callCount, 1);
  });

  test('API key dikirim di header, bukan di query string', () async {
    final adapter = FakeHttpClientAdapter(chunks: ['ok']);
    final repo = GeminiAiRepository(
      apiKeyStore: FakeApiKeyStore(FakeApiKeyStore.fakeKey),
      dio: _dioWith(adapter),
    );

    await repo.sendMessage(_history).toList();

    final request = adapter.lastRequest!;
    expect(request.headers['x-goog-api-key'], FakeApiKeyStore.fakeKey);
    expect(request.uri.queryParameters.containsKey('key'), isFalse);
    expect(request.uri.toString(), isNot(contains(FakeApiKeyStore.fakeKey)));
    expect(request.uri.toString(), contains('streamGenerateContent'));
    expect(request.uri.queryParameters['alt'], 'sse');
    expect(request.uri.toString(), contains(kGeminiModel));
  });

  test(
    'system prompt dikirim sebagai systemInstruction, bukan contents',
    () async {
      final adapter = FakeHttpClientAdapter(chunks: ['ok']);
      final repo = GeminiAiRepository(
        apiKeyStore: FakeApiKeyStore(FakeApiKeyStore.fakeKey),
        dio: _dioWith(adapter),
      );

      await repo.sendMessage(_history).toList();

      final body = adapter.lastRequest!.data as Map<String, dynamic>;
      expect(body['systemInstruction']['parts'].first['text'], 'system prompt');
      final contents = body['contents'] as List;
      expect(contents.length, 1);
      expect(contents.first['role'], 'user');
      expect(contents.first['parts'].first['text'], 'halo');
    },
  );

  test('HTTP 429 dipetakan ke AiRateLimitedFailure', () async {
    final repo = GeminiAiRepository(
      apiKeyStore: FakeApiKeyStore(FakeApiKeyStore.fakeKey),
      dio: _dioWith(FakeHttpClientAdapter(statusCode: 429)),
    );

    await expectLater(
      repo.sendMessage(_history),
      emitsError(isA<AiRateLimitedFailure>()),
    );
  });

  test('HTTP 401 dipetakan ke AiUnauthorizedFailure', () async {
    final repo = GeminiAiRepository(
      apiKeyStore: FakeApiKeyStore(FakeApiKeyStore.fakeKey),
      dio: _dioWith(FakeHttpClientAdapter(statusCode: 401)),
    );

    await expectLater(
      repo.sendMessage(_history),
      emitsError(isA<AiUnauthorizedFailure>()),
    );
  });

  test('HTTP 500 dipetakan ke AiServerErrorFailure', () async {
    final repo = GeminiAiRepository(
      apiKeyStore: FakeApiKeyStore(FakeApiKeyStore.fakeKey),
      dio: _dioWith(FakeHttpClientAdapter(statusCode: 500)),
    );

    await expectLater(
      repo.sendMessage(_history),
      emitsError(isA<AiServerErrorFailure>()),
    );
  });

  test('API key kosong tidak mengirim request sama sekali', () async {
    final adapter = FakeHttpClientAdapter(chunks: ['ok']);
    final repo = GeminiAiRepository(
      apiKeyStore: FakeApiKeyStore(),
      dio: _dioWith(adapter),
    );

    await expectLater(
      repo.sendMessage(_history),
      emitsError(isA<AiMissingApiKeyFailure>()),
    );
    expect(adapter.callCount, 0);
  });

  test('koneksi gagal dipetakan ke AiNetworkFailure', () async {
    final repo = GeminiAiRepository(
      apiKeyStore: FakeApiKeyStore(FakeApiKeyStore.fakeKey),
      dio: _dioWith(
        FakeHttpClientAdapter(
          error: DioException(
            requestOptions: RequestOptions(path: '/'),
            type: DioExceptionType.connectionError,
          ),
        ),
      ),
    );

    await expectLater(
      repo.sendMessage(_history),
      emitsError(isA<AiNetworkFailure>()),
    );
  });

  test('respon kosong dipetakan ke AiEmptyResponseFailure', () async {
    final repo = GeminiAiRepository(
      apiKeyStore: FakeApiKeyStore(FakeApiKeyStore.fakeKey),
      dio: _dioWith(_RawAdapter('')),
    );

    await expectLater(
      repo.sendMessage(_history),
      emitsError(isA<AiEmptyResponseFailure>()),
    );
  });

  test('chunk tanpa teks dianggap empty response', () async {
    final repo = GeminiAiRepository(
      apiKeyStore: FakeApiKeyStore(FakeApiKeyStore.fakeKey),
      dio: _dioWith(
        _RawAdapter(
          'data: ${jsonEncode({
            'usageMetadata': {'totalTokenCount': 5},
          })}\n\n',
        ),
      ),
    );

    await expectLater(
      repo.sendMessage(_history),
      emitsError(isA<AiEmptyResponseFailure>()),
    );
  });

  test('event SSE yang terpotong antar chunk tetap tersusun', () async {
    final sse =
        'data: ${jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Halo'},
                ],
              },
            },
          ],
        })}\n\n'
        'data: ${jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': ' dunia'},
                ],
              },
            },
          ],
        })}\n\n';


    final split = sse.indexOf('dunia') + 4;
    final repo = GeminiAiRepository(
      apiKeyStore: FakeApiKeyStore(FakeApiKeyStore.fakeKey),
      dio: _dioWith(
        _ChunkedRawAdapter([
          utf8.encode(sse).sublist(0, split),
          utf8.encode(sse).sublist(split),
        ]),
      ),
    );

    expect(await repo.sendMessage(_history).toList(), ['Halo', ' dunia']);
  });

  test('karakter multibyte yang terpotong antar chunk tidak rusak', () async {
    final sse =
        'data: ${jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Halo dunia 👋'},
                ],
              },
            },
          ],
        })}\n\n';
    final bytes = utf8.encode(sse);
    // Pecah tepat di tengah 4 byte emoji.
    final emojiStart = bytes.indexOf(0xF0);

    final repo = GeminiAiRepository(
      apiKeyStore: FakeApiKeyStore(FakeApiKeyStore.fakeKey),
      dio: _dioWith(
        _ChunkedRawAdapter([
          bytes.sublist(0, emojiStart + 2),
          bytes.sublist(emojiStart + 2),
        ]),
      ),
    );

    expect(await repo.sendMessage(_history).toList(), ['Halo dunia 👋']);
  });

  test('part thought diabaikan', () async {
    final repo = GeminiAiRepository(
      apiKeyStore: FakeApiKeyStore(FakeApiKeyStore.fakeKey),
      dio: _dioWith(
        _RawAdapter(
          'data: ${jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'berpikir...', 'thought': true},
                    {'text': 'Jawaban.'},
                  ],
                },
              },
            ],
          })}\n\n',
        ),
      ),
    );

    expect(await repo.sendMessage(_history).toList(), ['Jawaban.']);
  });
}
