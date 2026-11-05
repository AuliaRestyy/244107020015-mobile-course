import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class FakeHttpClientAdapter implements HttpClientAdapter {
  FakeHttpClientAdapter({
    this.statusCode = 200,
    this.chunks = const [],
    this.error,
  });

  final List<String> chunks;
  final int statusCode;
  final DioException? error;
  
  RequestOptions? lastRequest;
  int callCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    callCount++;
    lastRequest = options;
    final failure = error;
    if (failure != null) throw failure;
    return ResponseBody(
      Stream<Uint8List>.fromIterable([
        for (final chunk in chunks)
          Uint8List.fromList(utf8.encode(_sseEvent(chunk))),
      ]),
      statusCode,
    );
  }

  static String _sseEvent(String text) {
    final payload = jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': text},
            ],
          },
        },
      ],
    });
    return 'data: $payload\n\n';
  }

  @override
  void close({bool force = false}) {}
}
