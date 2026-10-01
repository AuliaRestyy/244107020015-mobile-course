import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:week5_offline_notes/data/local/note.dart';
import 'package:week5_offline_notes/data/providers.dart';
import 'package:week5_offline_notes/data/repositories/note_repository.dart';

/// Repository palsu: menguji provider TANPA SQLite sungguhan.
class FakeNoteRepository extends NoteRepository {
  FakeNoteRepository({List<Note>? initial, this.throwError = false})
      : items = List<Note>.of(initial ?? const []),
        super(openDb: () => throw UnimplementedError());

  final List<Note> items;
  final bool throwError;

  @override
  Future<List<Note>> fetchNotes() async {
    if (throwError) throw Exception('db locked (simulasi)');
    return items;
  }

  @override
  Future<int> countDirty() async => items.where((n) => n.dirty).length;

  @override
  Future<Note> addNote({required String title, String body = ''}) async {
    final note = Note(
      id: items.length + 1,
      title: title,
      body: body,
      updatedAt: DateTime.now(),
      dirty: true,
    );
    items.add(note);
    return note;
  }
}

void main() {
  // --- Unit test model: mapping aman null + serialisasi dirty ---
  test('fromMap aman terhadap field yang hilang', () {
    final note = Note.fromMap({'title': 'Belanja'});
    expect(note.title, 'Belanja');
    expect(note.body, '');
    expect(note.dirty, isFalse);
    expect(note.id, isNull);
  });

  test('flag dirty bertahan pada serialisasi', () {
    final note = Note(
      title: 'a',
      updatedAt: DateTime(2026, 9, 18),
      dirty: true,
    );
    final restored = Note.fromMap(note.toMap());
    expect(restored.dirty, isTrue);
    expect(restored.title, 'a');
    expect(restored.updatedAt, note.updatedAt);
  });

  // --- Provider dengan repository palsu ---
  test('provider sukses dengan repository palsu', () async {
    final container = ProviderContainer(
      overrides: [
        noteRepositoryProvider.overrideWithValue(
          FakeNoteRepository(initial: [
            Note(title: 'Tes', updatedAt: DateTime.now()),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notes = await container.read(notesProvider.future);
    expect(notes.length, 1);
    expect(notes.first.title, 'Tes');
  });

  test('provider error dengan repository palsu', () async {
    // Catatan Riverpod 3: secara default provider yang melempar Exception
    // akan di-retry otomatis (exponential backoff, maks 10×) — error tidak
    // langsung sampai ke UI. Nonaktifkan retry agar error tampil seketika
    // (pola codelab: AsyncError → pesan error di UI).
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        noteRepositoryProvider.overrideWithValue(
          FakeNoteRepository(throwError: true),
        ),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(notesProvider.future),
      throwsA(isA<Exception>()),
    );
  });

  test('addNote via provider menambah item dan menandai dirty', () async {
    final container = ProviderContainer(
      overrides: [
        noteRepositoryProvider.overrideWithValue(FakeNoteRepository()),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(dirtyCountProvider.future), 0);

    await container
        .read(notesProvider.notifier)
        .addNote(title: 'Catatan baru', body: 'isi');

    final notes = await container.read(notesProvider.future);
    expect(notes.length, 1);
    expect(notes.first.dirty, isTrue);
    // Badge antrean sync harus naik mengikuti catatan dirty.
    expect(await container.read(dirtyCountProvider.future), 1);
  });
}
