import '../../../../core/failures.dart';

abstract class PrefsRepository {
  Future<({bool value, Failure? failure})> getDarkMode();
  Future<({bool ok, Failure? failure})> setDarkMode(bool value);
  Future<({bool ok, Failure? failure})> markOpenedNow();
  Future<({String? iso, Failure? failure})> getLastOpened();
}
