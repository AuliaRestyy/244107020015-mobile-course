import 'package:sqflite/sqflite.dart';

import '../local/db.dart';
import '../local/note.dart';

/// Satu-satunya pintu data untuk catatan (CRUD + status sync).
/// Logika cache posts & sinkronisasi sengaja TIDAK di sini —
/// lihat `lib/data/sync.dart` (Refactoring Challenge codelab).
class NoteRepository {
  NoteRepository({Future<Database> Function()? openDb})
      : _openDb = openDb ?? openNotesDb;

  final Future<Database> Function() _openDb;

  /// Semua catatan, terbaru dulu (diurutkan `updated_at DESC`).
  Future<List<Note>> fetchNotes() async {
    final db = await _openDb();
    final rows = await db.query('notes', orderBy: 'updated_at DESC');
    return rows.map(Note.fromMap).toList();
  }

  /// Satu catatan berdasarkan id (untuk halaman detail `/note/:id`).
  Future<Note?> getNote(int id) async {
    final db = await _openDb();
    final rows = await db.query('notes', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Note.fromMap(rows.first);
  }

  /// Catatan baru selalu `dirty = 1` → masuk antrean sinkronisasi.
  Future<Note> addNote({required String title, String body = ''}) async {
    final db = await _openDb();
    final note = Note(
      title: title,
      body: body,
      updatedAt: DateTime.now(),
      dirty: true,
    );
    final id = await db.insert('notes', note.toMap());
    return Note(
      id: id,
      title: note.title,
      body: note.body,
      updatedAt: note.updatedAt,
      dirty: true,
    );
  }

  /// Edit catatan → `updated_at` baru + `dirty = 1` (ikut antrean sync).
  Future<void> updateNote({
    required int id,
    required String title,
    String body = '',
  }) async {
    final db = await _openDb();
    await db.update(
      'notes',
      {
        'title': title,
        'body': body,
        'updated_at': DateTime.now().toIso8601String(),
        'dirty': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteNote(int id) async {
    final db = await _openDb();
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  /// Jumlah catatan yang belum terkirim → badge antrean sync.
  Future<int> countDirty() async {
    final db = await _openDb();
    final rows =
        await db.rawQuery('SELECT COUNT(*) AS c FROM notes WHERE dirty = 1');
    return ((rows.first['c'] as num?)?.toInt() ?? 0);
  }

  /// Panggil HANYA setelah "server" menjawab sukses.
  Future<void> markAllSynced() async {
    final db = await _openDb();
    await db.update('notes', {'dirty': 0}, where: 'dirty = 1');
  }
}
