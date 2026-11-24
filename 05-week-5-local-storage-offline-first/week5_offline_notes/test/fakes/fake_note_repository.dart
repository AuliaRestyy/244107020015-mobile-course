import 'package:week5_offline_notes/core/failures.dart';
import 'package:week5_offline_notes/features/notes/domain/entities/note.dart';
import 'package:week5_offline_notes/features/notes/domain/repositories/note_repository.dart';

class FakeNoteRepository implements NoteRepository {
  FakeNoteRepository({List<Note> items = const [], this.failure})
    : _items = List<Note>.of(items);

  final List<Note> _items;
  final Failure? failure;

  int fetchCount = 0;
  int countDirtyCount = 0;
  int markAllSyncedCount = 0;

  @override
  Future<({List<Note> notes, Failure? failure})> fetchNotes() async {
    fetchCount++;
    final fail = failure;
    if (fail != null) return (notes: const <Note>[], failure: fail);
    final sorted = List<Note>.of(_items)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return (notes: List<Note>.unmodifiable(sorted), failure: null);
  }

  @override
  Future<({Note? note, Failure? failure})> getNote(int id) async {
    final fail = failure;
    if (fail != null) return (note: null, failure: fail);
    for (final note in _items) {
      if (note.id == id) return (note: note, failure: null);
    }
    return (note: null, failure: null);
  }

  @override
  Future<({Note? note, Failure? failure})> addNote({
    required String title,
    String body = '',
  }) async {
    final fail = failure;
    if (fail != null) return (note: null, failure: fail);
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
    final fail = failure;
    if (fail != null) return (note: null, failure: fail);
    final updated = Note(
      id: id,
      title: title,
      body: body,
      updatedAt: DateTime(2026, 11, 4, 1),
      dirty: true,
    );
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].id == id) {
        _items[i] = updated;
        return (note: updated, failure: null);
      }
    }
    return (note: null, failure: null);
  }

  @override
  Future<({bool ok, Failure? failure})> deleteNote(int id) async {
    final fail = failure;
    if (fail != null) return (ok: false, failure: fail);
    _items.removeWhere((note) => note.id == id);
    return (ok: true, failure: null);
  }

  @override
  Future<({int count, Failure? failure})> countDirty() async {
    countDirtyCount++;
    final fail = failure;
    if (fail != null) return (count: 0, failure: fail);
    return (count: _items.where((note) => note.dirty).length, failure: null);
  }

  @override
  Future<({bool ok, Failure? failure})> markAllSynced() async {
    markAllSyncedCount++;
    final fail = failure;
    if (fail != null) return (ok: false, failure: fail);
    for (var i = 0; i < _items.length; i++) {
      final note = _items[i];
      if (note.dirty) {
        _items[i] = Note(
          id: note.id,
          title: note.title,
          body: note.body,
          updatedAt: note.updatedAt,
          dirty: false,
        );
      }
    }
    return (ok: true, failure: null);
  }
}
