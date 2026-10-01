import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local/note.dart';
import 'prefs.dart';
import 'repositories/note_repository.dart';
import 'sync.dart';

// ---------------------------------------------------------------------------
// Repositories (UI tidak boleh menyentuh SQLite/SharedPreferences langsung)
// ---------------------------------------------------------------------------
final prefsRepositoryProvider = Provider((ref) => PrefsRepository());
final noteRepositoryProvider = Provider((ref) => NoteRepository());

// ---------------------------------------------------------------------------
// Preferensi tema (SharedPreferences)
// ---------------------------------------------------------------------------
class DarkModeNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.watch(prefsRepositoryProvider).getDarkMode();

  Future<void> toggle() async {
    final next = !(state.value ?? false);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(prefsRepositoryProvider).setDarkMode(next);
      return next;
    });
  }
}

final darkModeProvider =
    AsyncNotifierProvider<DarkModeNotifier, bool>(DarkModeNotifier.new);

final lastOpenedProvider = FutureProvider<String?>(
  (ref) => ref.watch(prefsRepositoryProvider).getLastOpened(),
);

// ---------------------------------------------------------------------------
// Toggle offline deterministik (demo & testing — codelab §Simulasi offline)
// ---------------------------------------------------------------------------
class ForceOfflineNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final forceOfflineProvider =
    NotifierProvider<ForceOfflineNotifier, bool>(ForceOfflineNotifier.new);

// ---------------------------------------------------------------------------
// Catatan (SQLite via repository) — AsyncValue loading/error/data
// ---------------------------------------------------------------------------
class NotesNotifier extends AsyncNotifier<List<Note>> {
  @override
  Future<List<Note>> build() => ref.watch(noteRepositoryProvider).fetchNotes();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(noteRepositoryProvider).fetchNotes(),
    );
  }

  Future<void> addNote({required String title, String body = ''}) async {
    await ref.read(noteRepositoryProvider).addNote(title: title, body: body);
    await refresh();
    await ref.read(dirtyCountProvider.notifier).refresh();
  }

  Future<void> updateNote({
    required int id,
    required String title,
    String body = '',
  }) async {
    await ref
        .read(noteRepositoryProvider)
        .updateNote(id: id, title: title, body: body);
    await refresh();
    await ref.read(dirtyCountProvider.notifier).refresh();
  }

  Future<void> deleteNote(int id) async {
    await ref.read(noteRepositoryProvider).deleteNote(id);
    await refresh();
    await ref.read(dirtyCountProvider.notifier).refresh();
  }
}

final notesProvider =
    AsyncNotifierProvider<NotesNotifier, List<Note>>(NotesNotifier.new);

/// Badge antrean sinkronisasi (jumlah catatan `dirty = 1`).
class DirtyCountNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() => ref.watch(noteRepositoryProvider).countDirty();

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(noteRepositoryProvider).countDirty(),
    );
  }
}

final dirtyCountProvider =
    AsyncNotifierProvider<DirtyCountNotifier, int>(DirtyCountNotifier.new);

/// Halaman detail membaca langsung dari repository — bukan dari state list.
final noteProvider = FutureProvider.family<Note?, int>(
  (ref, id) => ref.watch(noteRepositoryProvider).getNote(id),
);

// ---------------------------------------------------------------------------
// Cache-first posts (JSONPlaceholder) — codelab §Cache-first read
// ---------------------------------------------------------------------------
/// Revisi cache: di-bump hanya saat payload posts berubah.
/// Dipakai alih-alih `ref.invalidate(postsProvider)` dari dalam provider itu
/// sendiri (hindari invalidate loop & ref-after-dispose).
class PostsRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state += 1;
}

final postsRevisionProvider =
    NotifierProvider<PostsRevisionNotifier, int>(PostsRevisionNotifier.new);

final postsProvider = FutureProvider<List<Post>>((ref) {
  ref.watch(postsRevisionProvider); // rebuild saat cache posts berubah
  final skipNetwork = ref.watch(forceOfflineProvider);
  return loadPostsCacheFirst(
    skipNetwork: skipNetwork,
    onRefreshed: () => ref.read(postsRevisionProvider.notifier).bump(),
  );
});
