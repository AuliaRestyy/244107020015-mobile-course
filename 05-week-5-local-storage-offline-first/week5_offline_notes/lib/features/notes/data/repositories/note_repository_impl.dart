import 'package:sqflite/sqflite.dart';

import '../../../../core/failures.dart';
import '../../domain/entities/note.dart';
import '../../domain/repositories/note_repository.dart';
import '../models/note_model.dart';

class NoteRepositoryImpl implements NoteRepository {
  NoteRepositoryImpl({required Future<Database> Function() openDb}) {
    _openDb = openDb;
  }

  late final Future<Database> Function() _openDb;
  List<Note>? _cache;

  void _upsertCache(Note note) {
    final current = _cache;
    if (current == null) return;
    final next = <Note>[
      for (final existing in current)
        if (existing.id != note.id) existing,
      note,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _cache = List<Note>.unmodifiable(next);
  }

  void _markCacheSynced() {
    final current = _cache;
    if (current == null) return;
    _cache = List<Note>.unmodifiable([
      for (final note in current)
        if (note.dirty)
          Note(
            id: note.id,
            title: note.title,
            body: note.body,
            updatedAt: note.updatedAt,
            dirty: false,
          )
        else
          note,
    ]);
  }

  @override
  Future<({List<Note> notes, Failure? failure})> fetchNotes() async {
    final cached = _cache;
    if (cached != null) {
      return (notes: cached, failure: null);
    }

    try {
      final db = await _openDb();
      final rows = await db.query('notes', orderBy: 'updated_at DESC');
      final notes = List<Note>.unmodifiable(
        rows.map((row) => NoteModel.fromMap(row).toEntity()),
      );
      _cache = notes;
      return (notes: notes, failure: null);
    } catch (e) {
      return (
        notes: const <Note>[],
        failure: LocalFailure('Gagal membaca catatan: $e'),
      );
    }
  }

  @override
  Future<({Note? note, Failure? failure})> getNote(int id) async {
    final cached = _cache;
    if (cached != null) {
      for (final note in cached) {
        if (note.id == id) return (note: note, failure: null);
      }
      return (note: null, failure: null);
    }

    try {
      final db = await _openDb();
      final rows = await db.query(
        'notes',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return (note: null, failure: null);
      return (note: NoteModel.fromMap(rows.first).toEntity(), failure: null);
    } catch (e) {
      return (note: null, failure: LocalFailure('Gagal membaca catatan: $e'));
    }
  }

  @override
  Future<({Note? note, Failure? failure})> addNote({
    required String title,
    String body = '',
  }) async {
    try {
      final db = await _openDb();
      final model = NoteModel(
        title: title,
        body: body,
        updatedAt: DateTime.now(),
        dirty: true,
      );
      final id = await db.insert('notes', model.toMap());
      final created = NoteModel(
        id: id,
        title: model.title,
        body: model.body,
        updatedAt: model.updatedAt,
        dirty: true,
      ).toEntity();
      _upsertCache(created);
      return (note: created, failure: null);
    } catch (e) {
      return (note: null, failure: LocalFailure('Gagal menyimpan catatan: $e'));
    }
  }

  @override
  Future<({Note? note, Failure? failure})> updateNote({
    required int id,
    required String title,
    String body = '',
  }) async {
    try {
      final db = await _openDb();
      final updatedAt = DateTime.now();
      await db.update(
        'notes',
        {
          'title': title,
          'body': body,
          'updated_at': updatedAt.toIso8601String(),
          'dirty': 1,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      final updated = NoteModel(
        id: id,
        title: title,
        body: body,
        updatedAt: updatedAt,
        dirty: true,
      ).toEntity();
      _upsertCache(updated);
      return (note: updated, failure: null);
    } catch (e) {
      return (
        note: null,
        failure: LocalFailure('Gagal memperbarui catatan: $e'),
      );
    }
  }

  @override
  Future<({bool ok, Failure? failure})> deleteNote(int id) async {
    try {
      final db = await _openDb();
      await db.delete('notes', where: 'id = ?', whereArgs: [id]);
      final cached = _cache;
      if (cached != null) {
        _cache = List<Note>.unmodifiable(cached.where((note) => note.id != id));
      }
      return (ok: true, failure: null);
    } catch (e) {
      return (ok: false, failure: LocalFailure('Gagal menghapus catatan: $e'));
    }
  }

  @override
  Future<({int count, Failure? failure})> countDirty() async {
    try {
      final db = await _openDb();
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM notes WHERE dirty = 1',
      );
      return (count: ((rows.first['c'] as num?)?.toInt() ?? 0), failure: null);
    } catch (e) {
      return (
        count: 0,
        failure: LocalFailure('Gagal menghitung antrean sinkronisasi: $e'),
      );
    }
  }

  @override
  Future<({bool ok, Failure? failure})> markAllSynced() async {
    try {
      final db = await _openDb();
      await db.update('notes', {'dirty': 0}, where: 'dirty = 1');
      _markCacheSynced();
      return (ok: true, failure: null);
    } catch (e) {
      return (
        ok: false,
        failure: LocalFailure('Gagal menandai catatan tersinkron: $e'),
      );
    }
  }
}
