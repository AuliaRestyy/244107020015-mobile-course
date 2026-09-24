import 'package:dio/dio.dart';
import '../models/post.dart';

class PostRepository {
  PostRepository(this._dio);
  final Dio _dio;

  Future<List<Post>> fetchPosts() async {
    final response = await _dio.get<List>('/posts');
    final data = response.data ?? [];
    return data
        .whereType<Map>()
        .map((json) => Post.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<List<Post>> fetchPostsPage({
    required int page,
    int limit = 10,
  }) async {
    final response = await _dio.get<List>(
      '/posts',
      queryParameters: {'_page': page, '_limit': limit},
    );
    final data = response.data ?? [];
    return data
        .whereType<Map>()
        .map((json) => Post.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<Post> fetchPost(int id) async {
    final response = await _dio.get<Map<String, dynamic>>('/posts/$id');
    final data = response.data;
    if (data == null) throw StateError('Post $id tidak ditemukan');
    return Post.fromJson(data);
  }
}