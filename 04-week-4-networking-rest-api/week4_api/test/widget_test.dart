import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:week4_api/data/models/post.dart';
import 'package:week4_api/data/providers.dart';
import 'package:week4_api/data/repositories/post_repository.dart';
import 'package:week4_api/pages/paged_post_page.dart';

void main() {
  testWidgets('menampilkan post dari repository', (tester) async {
    final repository = _FakePostRepository(const [
      Post(userId: 1, id: 1, title: 'Post test', body: 'Isi'),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [postRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: PagedPostPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Post test'), findsOneWidget);
  });
}

class _FakePostRepository extends PostRepository {
  _FakePostRepository(this.posts) : super(Dio());
  final List<Post> posts;

  @override
  Future<List<Post>> fetchPostsPage({required int page, int limit = 10}) async {
    return posts;
  }
}