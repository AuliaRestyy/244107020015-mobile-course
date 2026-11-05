import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../domain/entities/chat_message.dart';
import '../domain/failures/ai_failure.dart';
import '../domain/repositories/ai_repository.dart';
import 'api_key_store.dart';

const String kGeminiModel = 'gemini-3.8-flash';

class GeminiAiRepository implements AiRepository {
  GeminiAiRepository({
    required ApiKeyStore apiKeyStore,
    Dio? dio,
    this.timeout = const Duration(seconds: 45),
  }) {
    _apiKeyStore = apiKeyStore;
    _dio = dio ?? Dio();
  }

  static const String baseUrl = 'https://generativelanguage.googleapis.com';

  final Duration timeout;

  late final ApiKeyStore _apiKeyStore;
  late final Dio _dio;

  @override
  Stream<String> sendMessage(List<ChatMessage> history) async* {
    final apiKey = await _readApiKey();
    final response = await _post(apiKey, history);
    _throwIfErrorStatus(response.statusCode);

    final body = response.data;
    if (body == null) throw const AiEmptyResponseFailure();

    var emittedText = false;
    try {
      await for (final data in _sseData(body.stream).timeout(timeout)) {
        final text = _extractText(data);
        if (text == null) continue;
        emittedText = true;
        yield text;
      }
    } on TimeoutException {
      throw const AiTimeoutFailure();
    } on DioException catch (error) {
      throw _mapDioException(error);
    }

    if (!emittedText) throw const AiEmptyResponseFailure();
  }

  Future<String> _readApiKey() async {
    final String? key;
    try {
      key = await _apiKeyStore.readKey();
    } catch (error) {
      throw AiMissingApiKeyFailure(
        'API key Gemini tidak dapat dibaca dari secure storage: $error',
      );
    }
    final trimmed = key?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      throw const AiMissingApiKeyFailure();
    }
    return trimmed;
  }

  Future<Response<ResponseBody>> _post(
    String apiKey,
    List<ChatMessage> history,
  ) async {
    final uri = Uri.parse(
      '$baseUrl/v1beta/models/$kGeminiModel:streamGenerateContent',
    ).replace(queryParameters: const {'alt': 'sse'});
    try {
      return await _dio.postUri<ResponseBody>(
        uri,
        data: _buildBody(history),
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            Headers.contentTypeHeader: Headers.jsonContentType,
            'x-goog-api-key': apiKey,
          },
          validateStatus: (_) => true,
        ),
      );
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Map<String, dynamic> _buildBody(List<ChatMessage> history) {
    final systemText = history
        .where((message) => message.role == ChatRole.system)
        .map((message) => message.text)
        .join('\n');
    final contents = history
        .where((message) => message.role != ChatRole.system)
        .map(
          (message) => {
            'role': message.role == ChatRole.user ? 'user' : 'model',
            'parts': [
              {'text': message.text},
            ],
          },
        )
        .toList(growable: false);

    return {
      if (systemText.isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': systemText},
          ],
        },
      'contents': contents,
    };
  }

  Stream<String> _sseData(Stream<Uint8List> bytes) async* {
    final payloads = StringBuffer();
    final lines = utf8.decoder.bind(bytes).transform(const LineSplitter());
    await for (final line in lines) {
      if (line.isEmpty) {
        if (payloads.isNotEmpty) {
          yield payloads.toString();
          payloads.clear();
        }
        continue;
      }
      if (line.startsWith('data:')) {
        payloads.write(line.substring(5).trimLeft());
      }
    }
    if (payloads.isNotEmpty) yield payloads.toString();
  }

  String? _extractText(String payload) {
    final Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return null;
      json = decoded;
    } on FormatException {
      return null;
    }

    final candidates = json['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;
    final candidate = candidates.first;
    if (candidate is! Map) return null;
    final content = candidate['content'];
    if (content is! Map) return null;
    final parts = content['parts'];
    if (parts is! List) return null;

    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is! Map) continue;
      if (part['thought'] == true) continue;
      final text = part['text'];
      if (text is String && text.isNotEmpty) buffer.write(text);
    }
    return buffer.isEmpty ? null : buffer.toString();
  }

  void _throwIfErrorStatus(int? statusCode) {
    if (statusCode == null || (statusCode >= 200 && statusCode < 300)) return;
    if (statusCode == 401 || statusCode == 403) {
      throw const AiUnauthorizedFailure();
    }
    if (statusCode == 429) throw const AiRateLimitedFailure();
    if (statusCode >= 500) throw const AiServerErrorFailure();
    throw AiServerErrorFailure('Permintaan ke AI ditolak (HTTP $statusCode).');
  }

  AiFailure _mapDioException(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode != null && (statusCode < 200 || statusCode >= 300)) {
      if (statusCode == 401 || statusCode == 403) {
        return const AiUnauthorizedFailure();
      }
      if (statusCode == 429) return const AiRateLimitedFailure();
      if (statusCode >= 500) return const AiServerErrorFailure();
      return AiServerErrorFailure(
        'Permintaan ke AI ditolak (HTTP $statusCode).',
      );
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const AiTimeoutFailure();
      case DioExceptionType.badCertificate:
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return const AiNetworkFailure();
      case DioExceptionType.cancel:
        return const AiNetworkFailure('Permintaan ke AI dibatalkan.');
      case DioExceptionType.badResponse:
        return const AiServerErrorFailure();
    }
  }
}
