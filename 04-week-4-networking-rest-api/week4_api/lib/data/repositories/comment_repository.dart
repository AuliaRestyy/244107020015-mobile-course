import 'package:dio/dio.dart';

import '../models/comment.dart';

/// Menyediakan akses data komentar dari JSONPlaceholder.
class CommentRepository {
  /// Repository menerima Dio agar mudah dipakai ulang dan diuji dengan mock.
  CommentRepository(this._dio);

  final Dio _dio;

  /// Mengambil semua komentar untuk post tertentu dengan batas waktu 10 detik.
  Future<List<Comment>> fetchComments(int postId) async {
    final response = await _dio.get<List>(
      '/comments',
      queryParameters: {'postId': postId},
      options: Options(
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    // Hanya item map yang valid diubah menjadi model agar respons tidak sesuai
    // format tidak menyebabkan error saat parsing.
    final data = response.data ?? [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Comment.fromJson)
        .toList();
  }
}