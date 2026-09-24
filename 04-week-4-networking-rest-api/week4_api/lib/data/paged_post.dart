import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/post.dart';
import 'providers.dart';

class PagedPostsState {
  const PagedPostsState({
    this.items = const [],
    this.page = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<Post> items;
  final int page;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;
}

class PagedPostsNotifier extends Notifier<PagedPostsState> {
  bool _requestInFlight = false;

  @override
  PagedPostsState build() {
    Future.microtask(loadFirstPage);
    return const PagedPostsState(isLoading: true);
  }

  Future<void> loadFirstPage() async {
    if (_requestInFlight) return;
    _requestInFlight = true;
    state = PagedPostsState(
      items: state.items,
      page: state.page,
      isLoading: true,
      hasMore: true,
    );
    final repository = ref.read(postRepositoryProvider);
    try {
      final items =
          await repository.fetchPostsPage(page: 1, limit: 10);
      state = PagedPostsState(
        items: items,
        page: 1,
        isLoading: false,
        hasMore: items.length == 10,
      );
    } catch (e) {
      state = PagedPostsState(
        items: state.items,
        page: state.page,
        isLoading: false,
        hasMore: false,
        error: e,
      );
    } finally {
      _requestInFlight = false;
    }
  }

  Future<void> loadNextPage() async {
    if (_requestInFlight || state.isLoading || !state.hasMore) return;
    _requestInFlight = true;
    final repo = ref.read(postRepositoryProvider);
    final currentItems = state.items;
    final currentPage = state.page;
    state = PagedPostsState(
      items: currentItems,
      page: currentPage,
      isLoadingMore: true,
      hasMore: state.hasMore,
    );
    try {
      final next = currentPage + 1;
      final items =
          await repo.fetchPostsPage(page: next, limit: 10);
      state = PagedPostsState(
        items: [...currentItems, ...items],
        page: next,
        isLoading: false,
        hasMore: items.length == 10,
      );
    } catch (e) {
      state = PagedPostsState(
        items: currentItems,
        page: currentPage,
        isLoading: false,
        error: e,
      );
    } finally {
      _requestInFlight = false;
    }
  }
}

final pagedPostsProvider =
    NotifierProvider<PagedPostsNotifier, PagedPostsState>(
        PagedPostsNotifier.new);

final postDetailProvider = FutureProvider.autoDispose
  .family<Post, int>((ref, id) async {
  final cachedPost = ref
    .read(pagedPostsProvider)
    .items
    .where((post) => post.id == id)
    .firstOrNull;
  return cachedPost ?? ref.read(postRepositoryProvider).fetchPost(id);
});