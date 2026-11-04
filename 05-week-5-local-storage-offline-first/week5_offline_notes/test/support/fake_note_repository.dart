import 'package:week5_offline_notes/core/failures.dart';
import 'package:week5_offline_notes/features/notes/domain/entities/note.dart';
import 'package:week5_offline_notes/features/notes/domain/repositories/note_repository.dart';

class FakeNoteRepository implements NoteRepository {
  FakeNoteRepository({List<Note> items = const [], this.fail = false})
    : _items = List<Note>.of(items);

  final List<Note> _items;
  final bool fail;

  @override
  Future<({List<Note> notes, Failure? failure})> fetchNotes() async {
    if (fail) {
      return (
        notes: const <Note>[],
        failure: const LocalFailure('db locked (simulasi)'),
      );
    }
    return (notes: List<Note>.unmodifiable(_items), failure: null);
  }

  @override
  Future<({Note? note, Failure? failure})> getNote(int id) async {
    final match = _items.where((note) => note.id == id);
    return (note: match.isEmpty ? null : match.first, failure: null);
  }

  @override
  Future<({Note? note, Failure? failure})> addNote({
    required String title,
    String body = '',
  }) async {
    final note = Note(
      id: _items.length + 1,
      title: title,
      body: body,
      updatedAt: DateTime(2026, 11, 4),
      dirty: true,
    );
    _items.add(note);
    return (note: note, failure: null);
  }

  @override
  Future<({Note? note, Failure? failure})> updateNote({
    required int id,
    required String title,
    String body = '',
  }) async {
    throw UnimplementedError('updateNote belum dipakai di test ini');
  }

  @override
  Future<({bool ok, Failure? failure})> deleteNote(int id) async {
    throw UnimplementedError('deleteNote belum dipakai di test ini');
  }

  @override
  Future<({int count, Failure? failure})> countDirty() async {
    final dirty = _items.where((note) => note.dirty).length;
    return (count: dirty, failure: null);
  }

  @override
  Future<({bool ok, Failure? failure})> markAllSynced() async {
    throw UnimplementedError('markAllSynced belum dipakai di test ini');
  }
}
