import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/failures.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/post_repository.dart';
import '../models/post_model.dart';

class PostRepositoryImpl implements PostRepository {
  PostRepositoryImpl({
    required Future<Database> Function() openDb,
    Dio Function()? createDio,
  }) : _createDio = createDio ?? _defaultDio {
    _openDb = openDb;
  }

  late final Future<Database> Function() _openDb;
  final Dio Function() _createDio;

  static Dio _defaultDio() =>
      Dio(BaseOptions(baseUrl: 'https://jsonplaceholder.typicode.com'));

  @override
  Future<({List<Post> posts, Failure? failure})> readCache() async {
    try {
      final db = await _openDb();
      final rows = await db.query('cached_posts', orderBy: 'id ASC');
      return (
        posts: rows.map(PostModel.fromCacheMap).map((m) => m.toEntity()).toList(),
        failure: null,
      );
    } catch (e) {
      return (
        posts: const <Post>[],
        failure: LocalFailure('Gagal membaca cache posts: $e'),
      );
    }
  }

  @override
  Future<({bool changed, Failure? failure})> refreshCache() async {
    try {
      final response = await _createDio().get<List<dynamic>>(
        '/posts',
        queryParameters: {'_limit': 20},
      );
      final raw = response.data;
      if (raw == null) return (changed: false, failure: null);

      final fresh = <PostModel>[
        for (final item in raw)
          if (item is Map)
            PostModel(
              id: (item['id'] as num?)?.toInt() ?? 0,
              title: item['title'] as String? ?? '',
              body: item['body'] as String? ?? '',
            ),
      ]..sort((a, b) => a.id.compareTo(b.id));

      final cached = await readCache();
      if (cached.failure != null) {
        return (changed: false, failure: cached.failure);
      }
      if (_samePosts(cached.posts, fresh)) {
        return (changed: false, failure: null);
      }

      final db = await _openDb();
      await db.transaction((txn) async {
        await txn.delete('cached_posts');
        for (final post in fresh) {
          await txn.insert('cached_posts', post.toCacheMap());
        }
      });
      return (changed: true, failure: null);
    } on DioException catch (e) {
      return (
        changed: false,
        failure: NetworkFailure('Gagal menyegarkan cache posts: ${e.message}'),
      );
    } catch (e) {
      return (
        changed: false,
        failure: LocalFailure('Gagal menyimpan cache posts: $e'),
      );
    }
  }

  bool _samePosts(List<Post> a, List<Post> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].title != b[i].title ||
          a[i].body != b[i].body) {
        return false;
      }
    }
    return true;
  }
}
