import 'dart:convert';

import '../../domain/entities/post.dart';

class PostModel extends Post {
  const PostModel({
    required super.id,
    required super.title,
    required super.body,
  });

  Map<String, Object?> toCacheMap() => {
        'id': id,
        'payload': jsonEncode({'title': title, 'body': body}),
        'cached_at': DateTime.now().toUtc().toIso8601String(),
      };

  factory PostModel.fromCacheMap(Map<String, Object?> map) {
    Object? decoded;
    try {
      decoded = jsonDecode(map['payload'] as String? ?? '{}');
    } catch (_) {
      decoded = null;
    }
    final payload = decoded is Map ? decoded : const <String, Object?>{};
    return PostModel(
      id: (map['id'] as num?)?.toInt() ?? 0,
      title: payload['title'] as String? ?? '',
      body: payload['body'] as String? ?? '',
    );
  }

  Post toEntity() => Post(id: id, title: title, body: body);
}
