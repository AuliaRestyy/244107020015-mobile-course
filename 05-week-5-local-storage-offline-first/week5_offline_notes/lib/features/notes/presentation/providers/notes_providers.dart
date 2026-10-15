import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/failures.dart';
import '../../../../database/app_database.dart';
import '../../data/repositories/note_repository_impl.dart';
import '../../domain/entities/note.dart';
import '../../domain/repositories/note_repository.dart';
import '../../domain/usecases/add_note.dart';
import '../../domain/usecases/get_notes.dart';
import '../../domain/usecases/sync_notes.dart';

final noteRepositoryProvider = Provider<NoteRepository>(
  (ref) => NoteRepositoryImpl(openDb: ref.watch(appDatabaseProvider)),
);

final getNotesProvider =
    Provider<GetNotes>((ref) => GetNotes(ref.watch(noteRepositoryProvider)));
final addNoteProvider =
    Provider<AddNote>((ref) => AddNote(ref.watch(noteRepositoryProvider)));
final syncNotesProvider =
    Provider<SyncNotes>((ref) => SyncNotes(ref.watch(noteRepositoryProvider)));

class NotesNotifier extends AsyncNotifier<List<Note>> {
  @override
  Future<List<Note>> build() async {
    final result = await ref.watch(getNotesProvider).call();
    if (result.failure != null) throw Exception(result.failure!.message);
    return result.notes;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await ref.read(getNotesProvider).call();
      if (result.failure != null) throw Exception(result.failure!.message);
      return result.notes;
    });
  }

  Future<void> addNote({required String title, String body = ''}) async {
    final result =
        await ref.read(addNoteProvider).call(title: title, body: body);
    if (result.failure != null) throw Exception(result.failure!.message);
    await refresh();
    await ref.read(dirtyCountProvider.notifier).refresh();
  }

  Future<void> updateNote({
    required int id,
    required String title,
    String body = '',
  }) async {
    final result = await ref
        .read(noteRepositoryProvider)
        .updateNote(id: id, title: title, body: body);
    if (result.failure != null) throw Exception(result.failure!.message);
    await refresh();
    await ref.read(dirtyCountProvider.notifier).refresh();
  }

  Future<void> deleteNote(int id) async {
    final result = await ref.read(noteRepositoryProvider).deleteNote(id);
    if (result.failure != null) throw Exception(result.failure!.message);
    await refresh();
    await ref.read(dirtyCountProvider.notifier).refresh();
  }

  Future<({int synced, Failure? failure})> syncNotes() async {
    final result = await ref.read(syncNotesProvider).call();
    await ref.read(dirtyCountProvider.notifier).refresh();
    return result;
  }
}

final notesProvider =
    AsyncNotifierProvider<NotesNotifier, List<Note>>(NotesNotifier.new);

class DirtyCountNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final result = await ref.watch(noteRepositoryProvider).countDirty();
    if (result.failure != null) throw Exception(result.failure!.message);
    return result.count;
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() async {
      final result = await ref.read(noteRepositoryProvider).countDirty();
      if (result.failure != null) throw Exception(result.failure!.message);
      return result.count;
    });
  }
}

final dirtyCountProvider =
    AsyncNotifierProvider<DirtyCountNotifier, int>(DirtyCountNotifier.new);

final noteProvider = FutureProvider.family<Note?, int>((ref, id) async {
  final result = await ref.watch(noteRepositoryProvider).getNote(id);
  if (result.failure != null) throw Exception(result.failure!.message);
  return result.note;
});
