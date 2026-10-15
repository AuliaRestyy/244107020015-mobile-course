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

  @override
  Future<({List<Note> notes, Failure? failure})> fetchNotes() async {
    try {
      final db = await _openDb();
      final rows = await db.query('notes', orderBy: 'updated_at DESC');
      return (
        notes: rows.map(NoteModel.fromMap).map((m) => m.toEntity()).toList(),
        failure: null,
      );
    } catch (e) {
      return (
        notes: const <Note>[],
        failure: LocalFailure('Gagal membaca catatan: $e'),
      );
    }
  }

  @override
  Future<({Note? note, Failure? failure})> getNote(int id) async {
    try {
      final db = await _openDb();
      final rows =
          await db.query('notes', where: 'id = ?', whereArgs: [id], limit: 1);
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
      return (
        note: NoteModel(
          id: id,
          title: model.title,
          body: model.body,
          updatedAt: model.updatedAt,
          dirty: true,
        ).toEntity(),
        failure: null,
      );
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
      return (
        note: NoteModel(
          id: id,
          title: title,
          body: body,
          updatedAt: updatedAt,
          dirty: true,
        ).toEntity(),
        failure: null,
      );
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
      return (ok: true, failure: null);
    } catch (e) {
      return (ok: false, failure: LocalFailure('Gagal menghapus catatan: $e'));
    }
  }

  @override
  Future<({int count, Failure? failure})> countDirty() async {
    try {
      final db = await _openDb();
      final rows =
          await db.rawQuery('SELECT COUNT(*) AS c FROM notes WHERE dirty = 1');
      return (
        count: ((rows.first['c'] as num?)?.toInt() ?? 0),
        failure: null,
      );
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
      return (ok: true, failure: null);
    } catch (e) {
      return (
        ok: false,
        failure: LocalFailure('Gagal menandai catatan tersinkron: $e'),
      );
    }
  }
}
