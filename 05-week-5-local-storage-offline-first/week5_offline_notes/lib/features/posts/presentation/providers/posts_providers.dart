import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/debug.dart';
import '../../../../core/providers.dart';
import '../../../../database/app_database.dart';
import '../../data/repositories/post_repository_impl.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/post_repository.dart';
import '../../domain/usecases/refresh_posts_cache.dart';

final postRepositoryProvider = Provider<PostRepository>(
  (ref) => PostRepositoryImpl(openDb: ref.watch(appDatabaseProvider)),
);

final refreshPostsCacheProvider = Provider<RefreshPostsCache>(
  (ref) => RefreshPostsCache(ref.watch(postRepositoryProvider)),
);

class PostsRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state += 1;
}

final postsRevisionProvider =
    NotifierProvider<PostsRevisionNotifier, int>(PostsRevisionNotifier.new);

final postsProvider = FutureProvider<List<Post>>((ref) async {
  ref.watch(postsRevisionProvider); 
  final repository = ref.watch(postRepositoryProvider);
  final cached = await repository.readCache();
  if (cached.failure != null) throw Exception(cached.failure!.message);

  final offline = ref.watch(forceOfflineProvider);
  unawaited(() async {
    final refreshed =
        await ref.read(refreshPostsCacheProvider).call(offline: offline);
    if (refreshed.failure != null) {
      debugPrintIfDebug(refreshed.failure!.message);
      return;
    }
    if (refreshed.changed) {
      ref.read(postsRevisionProvider.notifier).bump();
    }
  }());
  return cached.posts;
});
