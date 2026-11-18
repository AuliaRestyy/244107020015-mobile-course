import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:week5_offline_notes/database/app_database.dart';
import 'package:week5_offline_notes/features/notes/domain/usecases/sync_notes.dart';
import 'package:week5_offline_notes/features/notes/presentation/providers/notes_providers.dart';

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

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late ProviderContainer container;

  setUp(() async {
    db = await _openMemoryDb();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(() async => db),
        // Lewati simulasi unggah 1 detik agar tes tetap cepat.
        syncNotesProvider.overrideWith(
          (ref) => SyncNotes(
            ref.watch(noteRepositoryProvider),
            uploadDelay: Duration.zero,
          ),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('addNote lalu syncNotes tidak menyisakan catatan dirty di notesProvider',
      () async {
    await container.read(notesProvider.future);

    final notifier = container.read(notesProvider.notifier);
    await notifier.addNote(title: 'Catatan A', body: 'isi A');
    await notifier.addNote(title: 'Catatan B', body: 'isi B');

    expect(container.read(notesProvider).requireValue.where((n) => n.dirty),
        hasLength(2));
    expect(await container.read(dirtyCountProvider.future), 2);

    await notifier.syncNotes();

    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM notes WHERE dirty = 1',
    );
    expect(rows.first['c'], 0, reason: 'DB masih punya baris dirty');

    final notes = container.read(notesProvider).requireValue;
    expect(notes, hasLength(2));
    expect(
      notes.where((note) => note.dirty).map((note) => note.title).toList(),
      isEmpty,
      reason: 'notesProvider masih memegang catatan dirty setelah sync',
    );
  });
}