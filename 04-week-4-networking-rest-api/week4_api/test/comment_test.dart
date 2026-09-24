import 'package:flutter_test/flutter_test.dart';

import 'package:week4_api/data/models/comment.dart';

void main() {
  test('Comment.fromJson memakai nilai default saat field hilang', () {
    // JSON tidak lengkap tetap harus menghasilkan model yang aman digunakan UI.
    final comment = Comment.fromJson(<String, dynamic>{
      'id': 7,
      'email': 'user@example.com',
    });

    expect(comment.postId, 0);
    expect(comment.id, 7);
    expect(comment.name, '');
    expect(comment.email, 'user@example.com');
    expect(comment.body, '');
  });
}