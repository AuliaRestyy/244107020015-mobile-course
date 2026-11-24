import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:week5_offline_notes/core/failures.dart';
import 'package:week5_offline_notes/core/providers.dart';
import 'package:week5_offline_notes/features/notes/domain/entities/note.dart';
import 'package:week5_offline_notes/features/notes/presentation/pages/notes_page.dart';
import 'package:week5_offline_notes/features/notes/presentation/providers/notes_providers.dart';

import 'fakes/fake_note_repository.dart';

Note _note(int id, String title, {bool dirty = false}) => Note(
  id: id,
  title: title,
  body: 'isi $title',
  updatedAt: DateTime(2026, 11, 4, 0, id),
  dirty: dirty,
);

Future<ProviderContainer> _pumpNotesPage(
  WidgetTester tester,
  FakeNoteRepository repository,
) async {
  final container = ProviderContainer(
    overrides: [noteRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: NotesPage()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('tampilan awal menampilkan catatan dari repository', (
    tester,
  ) async {
    final repository = FakeNoteRepository(
      items: [
        _note(1, 'Belanja mingguan'),
        _note(2, 'Rapat kampus', dirty: true),
      ],
    );

    await _pumpNotesPage(tester, repository);

    expect(find.text('Belanja mingguan'), findsOneWidget);
    expect(find.text('Rapat kampus'), findsOneWidget);
    expect(find.byIcon(Icons.note_alt_outlined), findsNothing);
    expect(find.byKey(const ValueKey('add-note-fab')), findsOneWidget);
    expect(find.byKey(const ValueKey('sync-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('notes-search-field')), findsOneWidget);
    expect(repository.fetchCount, greaterThanOrEqualTo(1));
  });

  testWidgets('search "zzz" menampilkan empty state pencarian', (tester) async {
    final repository = FakeNoteRepository(
      items: [_note(1, 'Belanja mingguan'), _note(2, 'Rapat kampus')],
    );

    await _pumpNotesPage(tester, repository);
    expect(find.text('Belanja mingguan'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('notes-search-field')),
      'zzz',
    );
    await tester.pumpAndSettle();

    expect(find.text('Belanja mingguan'), findsNothing);
    expect(find.byIcon(Icons.search_off), findsOneWidget);
    expect(find.textContaining('Tidak ada catatan yang cocok'), findsOneWidget);
  });

  testWidgets('sync saat forceOffline menampilkan snackbar ditunda', (
    tester,
  ) async {
    final repository = FakeNoteRepository(
      items: [_note(1, 'Belanja mingguan', dirty: true)],
    );

    final container = await _pumpNotesPage(tester, repository);
    container.read(forceOfflineProvider.notifier).toggle();
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Mode offline (simulasi) aktif'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('sync-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Mode offline aktif (simulasi) — sinkronisasi ditunda.'),
      findsOneWidget,
    );
    expect(repository.markAllSyncedCount, 0);
  });

  testWidgets('failure dari fake repository menampilkan ErrorView', (
    tester,
  ) async {
    final repository = FakeNoteRepository(
      failure: const LocalFailure('db locked (simulasi)'),
    );

    await _pumpNotesPage(tester, repository);

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.textContaining('Gagal memuat catatan'), findsOneWidget);
    expect(find.textContaining('db locked (simulasi)'), findsOneWidget);
    expect(find.byIcon(Icons.note_alt_outlined), findsNothing);
  });
}
