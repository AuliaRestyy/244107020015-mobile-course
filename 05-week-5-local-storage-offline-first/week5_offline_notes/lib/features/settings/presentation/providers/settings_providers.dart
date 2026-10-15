import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/prefs_repository_impl.dart';
import '../../domain/repositories/prefs_repository.dart';
import '../../domain/usecases/toggle_dark_mode.dart';

final prefsRepositoryProvider =
    Provider<PrefsRepository>((ref) => PrefsRepositoryImpl());

final toggleDarkModeProvider = Provider<ToggleDarkMode>(
  (ref) => ToggleDarkMode(ref.watch(prefsRepositoryProvider)),
);

class DarkModeNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final result = await ref.watch(prefsRepositoryProvider).getDarkMode();
    if (result.failure != null) throw Exception(result.failure!.message);
    return result.value;
  }

  Future<void> toggle() async {
    final current = state.value ?? false;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result =
          await ref.read(toggleDarkModeProvider).call(current: current);
      if (result.failure != null) throw Exception(result.failure!.message);
      return result.value;
    });
  }
}

final darkModeProvider =
    AsyncNotifierProvider<DarkModeNotifier, bool>(DarkModeNotifier.new);

final lastOpenedProvider = FutureProvider<String?>((ref) async {
  final result = await ref.watch(prefsRepositoryProvider).getLastOpened();
  if (result.failure != null) throw Exception(result.failure!.message);
  return result.iso;
});
