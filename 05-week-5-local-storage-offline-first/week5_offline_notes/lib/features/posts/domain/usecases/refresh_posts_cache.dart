import '../../../../core/failures.dart';
import '../repositories/post_repository.dart';

class RefreshPostsCache {
  const RefreshPostsCache(this._repository);

  final PostRepository _repository;

  Future<({bool changed, Failure? failure})> call({bool offline = false}) async {
    if (offline) return (changed: false, failure: null);
    try {
      return await _repository.refreshCache();
    } catch (e) {
      return (
        changed: false,
        failure: UnexpectedFailure('Refresh cache posts gagal: $e'),
      );
    }
  }
}
