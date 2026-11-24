import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:week5_offline_notes/core/failures.dart';
import 'package:week5_offline_notes/core/providers.dart';
import 'package:week5_offline_notes/features/posts/domain/entities/post.dart';
import 'package:week5_offline_notes/features/posts/domain/repositories/post_repository.dart';
import 'package:week5_offline_notes/features/posts/presentation/providers/posts_providers.dart';

class _FakePostRepository implements PostRepository {
  _FakePostRepository({
    required List<Post> cache,
    this.refreshFailure,
    this.refreshResult,
  }) : _cache = List<Post>.of(cache);

  List<Post> _cache;
  final Failure? refreshFailure;
  final List<Post>? refreshResult;

  int readCount = 0;
  int refreshCount = 0;

  @override
  Future<({List<Post> posts, Failure? failure})> readCache() async {
    readCount++;
    return (posts: List<Post>.unmodifiable(_cache), failure: null);
  }

  @override
  Future<({bool changed, Failure? failure})> refreshCache() async {
    refreshCount++;
    final failure = refreshFailure;
    if (failure != null) return (changed: false, failure: failure);
    final fresh = refreshResult;
    if (fresh == null) return (changed: false, failure: null);
    if (_sameAsCache(fresh)) return (changed: false, failure: null);
    _cache = List<Post>.of(fresh);
    return (changed: true, failure: null);
  }

  bool _sameAsCache(List<Post> fresh) {
    if (fresh.length != _cache.length) return false;
    for (var i = 0; i < fresh.length; i++) {
      final a = _cache[i];
      final b = fresh[i];
      if (a.id != b.id || a.title != b.title || a.body != b.body) {
        return false;
      }
    }
    return true;
  }
}

void main() {
  Future<void> waitForRefresh(
    _FakePostRepository repository, {
    int expected = 1,
  }) async {
    for (var i = 0; i < 200 && repository.refreshCount < expected; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  Future<List<Post>> waitForPosts(
    ProviderContainer container,
    bool Function(List<Post> posts) predicate,
  ) async {
    for (var i = 0; i < 200; i++) {
      final data = container.read(postsProvider).asData?.value;
      if (data != null && predicate(data)) return data;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('postsProvider tidak pernah memenuhi kondisi yang ditunggu');
  }

  ProviderContainer makeContainer(_FakePostRepository repository) {
    final container = ProviderContainer(
      overrides: [postRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('refresh gagal: data cache tetap tampil dan tidak jadi error', () async {
    final repository = _FakePostRepository(
      cache: const [
        Post(id: 1, title: 'Dari cache', body: 'isi lama'),
        Post(id: 2, title: 'Juga cache', body: 'isi lama 2'),
      ],
      refreshFailure: const NetworkFailure('jaringan mati (simulasi)'),
    );
    final container = makeContainer(repository);
    final sub = container.listen(postsProvider, (_, _) {});
    addTearDown(sub.close);

    final first = await container.read(postsProvider.future);
    expect(first.map((post) => post.title), ['Dari cache', 'Juga cache']);

    await waitForRefresh(repository);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final state = container.read(postsProvider);
    expect(state.hasError, isFalse);
    expect(state.asData?.value.map((post) => post.title), [
      'Dari cache',
      'Juga cache',
    ]);
    expect(repository.refreshCount, 1);
  });

  test('mode offline: refresh latar tidak memanggil jaringan', () async {
    final repository = _FakePostRepository(
      cache: const [Post(id: 1, title: 'Cache offline', body: 'isi')],
    );
    final container = makeContainer(repository);
    final sub = container.listen(postsProvider, (_, _) {});
    addTearDown(sub.close);

    container.read(forceOfflineProvider.notifier).toggle();
    expect(container.read(forceOfflineProvider), isTrue);

    final posts = await container.read(postsProvider.future);
    expect(posts.single.title, 'Cache offline');

    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(
      repository.refreshCount,
      0,
      reason: 'refreshCache tidak boleh dipanggil saat offline',
    );
    expect(repository.readCount, 1);
    expect(container.read(postsProvider).hasError, isFalse);
  });

  test(
    'refresh sukses dengan data berbeda: cache diperbarui dan tampil',
    () async {
      final repository = _FakePostRepository(
        cache: const [Post(id: 1, title: 'Judul lama', body: 'isi lama')],
        refreshResult: const [
          Post(id: 1, title: 'Judul baru', body: 'isi baru'),
          Post(id: 2, title: 'Post tambahan', body: 'isi tambahan'),
        ],
      );
      final container = makeContainer(repository);
      final sub = container.listen(postsProvider, (_, _) {});
      addTearDown(sub.close);

      final first = await container.read(postsProvider.future);
      expect(first.single.title, 'Judul lama');

      await waitForRefresh(repository);
      final updated = await waitForPosts(
        container,
        (posts) => posts.any((post) => post.title == 'Judul baru'),
      );

      expect(updated.map((post) => post.title), [
        'Judul baru',
        'Post tambahan',
      ]);
      // Cache repositori ikut berubah, bukan hanya state provider.
      final cached = await repository.readCache();
      expect(cached.posts.map((post) => post.title), [
        'Judul baru',
        'Post tambahan',
      ]);
      expect(repository.refreshCount, greaterThanOrEqualTo(1));
      expect(container.read(postsProvider).hasError, isFalse);
    },
  );
}
