import '../../../../core/failures.dart';
import '../repositories/prefs_repository.dart';

class ToggleDarkMode {
  const ToggleDarkMode(this._repository);

  final PrefsRepository _repository;

  Future<({bool value, Failure? failure})> call({required bool current}) async {
    final next = !current;
    final saved = await _repository.setDarkMode(next);
    if (saved.failure != null) return (value: current, failure: saved.failure);
    return (value: next, failure: null);
  }
}
