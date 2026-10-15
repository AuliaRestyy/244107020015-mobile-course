import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/failures.dart';
import '../../domain/repositories/prefs_repository.dart';

class PrefsRepositoryImpl implements PrefsRepository {
  static const _darkModeKey = 'dark_mode';
  static const _lastOpenedKey = 'last_opened_at';

  @override
  Future<({bool value, Failure? failure})> getDarkMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (value: prefs.getBool(_darkModeKey) ?? false, failure: null);
    } catch (e) {
      return (
        value: false,
        failure: LocalFailure('Gagal membaca preferensi tema: $e'),
      );
    }
  }

  @override
  Future<({bool ok, Failure? failure})> setDarkMode(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_darkModeKey, value);
      return (ok: true, failure: null);
    } catch (e) {
      return (
        ok: false,
        failure: LocalFailure('Gagal menyimpan preferensi tema: $e'),
      );
    }
  }

  @override
  Future<({bool ok, Failure? failure})> markOpenedNow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastOpenedKey, DateTime.now().toIso8601String());
      return (ok: true, failure: null);
    } catch (e) {
      return (
        ok: false,
        failure: LocalFailure('Gagal mencatat waktu dibuka: $e'),
      );
    }
  }

  @override
  Future<({String? iso, Failure? failure})> getLastOpened() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (iso: prefs.getString(_lastOpenedKey), failure: null);
    } catch (e) {
      return (
        iso: null,
        failure: LocalFailure('Gagal membaca waktu terakhir dibuka: $e'),
      );
    }
  }
}
