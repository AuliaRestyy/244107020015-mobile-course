import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:week5_offline_notes/features/notes/data/repositories/note_repository_impl.dart';
import 'package:week5_offline_notes/features/notes/domain/entities/note.dart';

/// Membuka database in-memory dengan skema yang sama seperti aplikasi.
Future<Database> _openMemoryDb() async {
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            body TEXT NOT NULL DEFAULT '',
            updated_at TEXT NOT NULL,
            dirty INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    ),
  );
  return db;
}

/// Membungkus query agar bermutasi langsung ke DB, untuk memastikan cache
/// benar-benar mencerminkan isi tabel dan bukan sekadar menebak.
Future<List<Note>> _rowsFromDb(Database db) async {
  final rows = await db.query('notes', orderBy: 'updated_at DESC');
  return [
    for (final row in rows)
      Note(
        id: (row['id'] as num).toInt(),
        title: row['title']! as String,
        body: row['body']! as String,
        updatedAt: DateTime.parse(row['updated_at']! as String),
        dirty: (row['dirty'] as num).toInt() == 1,
      ),
  ];
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late NoteRepositoryImpl repository;

  setUp(() async {
    db = await _openMemoryDb();
    repository = NoteRepositoryImpl(openDb: () async => db);
  });

  tearDown(() async {
    await db.close();
  });

  test('fetchNotes pertama membaca tabel, kedua memakai cache', () async {
    await db.insert('notes', {
      'title': 'A',
      'body': '',
      'updated_at': DateTime(2026, 1, 2).toIso8601String(),
      'dirty': 0,
    });

    final first = await repository.fetchNotes();
    final second = await repository.fetchNotes();

    expect(first.failure, isNull);
    expect(first.notes, hasLength(1));
    // Identitas list harus sama agar Riverpod tidak menganggap berubah.
    expect(identical(first.notes, second.notes), isTrue);
  });

  test('cache mengikuti addNote tanpa membaca ulang tabel', () async {
    await repository.fetchNotes();
    final added = await repository.addNote(title: 'Baru', body: 'isi');
    expect(added.note, isNotNull);

    final afterAdd = await repository.fetchNotes();
    final fromDb = await _rowsFromDb(db);
    expect(
      afterAdd.notes.map((n) => n.id).toList(),
      fromDb.map((n) => n.id).toList(),
    );
    expect(afterAdd.notes.first.title, 'Baru');
  });

  test('cache mengikuti updateNote, urutan tetap updated_at DESC', () async {
    final a = await repository.addNote(title: 'A');
    final b = await repository.addNote(title: 'B');
    await repository.fetchNotes();

    await repository.updateNote(id: a.note!.id!, title: 'A diubah');
    final notes = (await repository.fetchNotes()).notes;
    final fromDb = await _rowsFromDb(db);

    expect(notes.map((n) => n.id).toList(), fromDb.map((n) => n.id).toList());
    expect(notes.first.id, a.note!.id);
    expect(notes.first.title, 'A diubah');
    expect(notes.last.id, b.note!.id);
  });

  test('cache mengikuti deleteNote', () async {
    final a = await repository.addNote(title: 'A');
    await repository.addNote(title: 'B');
    await repository.fetchNotes();

    await repository.deleteNote(a.note!.id!);
    final notes = (await repository.fetchNotes()).notes;
    final fromDb = await _rowsFromDb(db);

    expect(notes.map((n) => n.id).toList(), fromDb.map((n) => n.id).toList());
    expect(notes.any((n) => n.id == a.note!.id), isFalse);
  });

  test('cache mengikuti markAllSynced', () async {
    await repository.addNote(title: 'A');
    await repository.addNote(title: 'B');
    await repository.fetchNotes();

    final before = await repository.countDirty();
    expect(before.count, 2);

    await repository.markAllSynced();
    final notes = (await repository.fetchNotes()).notes;
    final fromDb = await _rowsFromDb(db);

    expect(notes.every((n) => !n.dirty), isTrue);
    expect(
      notes.map((n) => n.dirty).toList(),
      fromDb.map((n) => n.dirty).toList(),
    );
    expect((await repository.countDirty()).count, 0);
  });

  test('getNote memakai cache dan konsisten dengan tabel', () async {
    final added = await repository.addNote(title: 'A', body: 'isi A');
    await repository.fetchNotes();

    final note = (await repository.getNote(added.note!.id!)).note;
    final fromDb = (await _rowsFromDb(db)).single;

    expect(note, isNotNull);
    expect(note!.title, fromDb.title);
    expect(note.body, fromDb.body);
    expect(note.dirty, fromDb.dirty);
  });

  test('getNote mengembalikan null untuk id yang tidak ada', () async {
    await repository.fetchNotes();
    expect((await repository.getNote(999)).note, isNull);
  });

  test('cache tidak bisa dimutasi pemanggil', () async {
    await repository.addNote(title: 'A');
    final notes = (await repository.fetchNotes()).notes;
    expect(() => notes.add(notes.first), throwsUnsupportedError);
  });

  test(
    'failure tidak mengisi cache sehingga percobaan berikut membaca tabel',
    () async {
      var failNext = true;
      final flaky = NoteRepositoryImpl(
        openDb: () async {
          if (failNext) throw StateError('db locked');
          return db;
        },
      );

      final failed = await flaky.fetchNotes();
      expect(failed.failure, isNotNull);

      failNext = false;
      await db.insert('notes', {
        'title': 'Setelah pulih',
        'body': '',
        'updated_at': DateTime(2026, 1, 3).toIso8601String(),
        'dirty': 0,
      });
      final recovered = await flaky.fetchNotes();
      expect(recovered.failure, isNull);
      expect(recovered.notes.single.title, 'Setelah pulih');
    },
  );
}
