import 'package:flutter_test/flutter_test.dart';
import 'package:week5_offline_notes/core/failures.dart';
import 'package:week5_offline_notes/features/notes/domain/entities/note.dart';
import 'package:week5_offline_notes/features/notes/domain/usecases/get_notes.dart';

import 'support/fake_note_repository.dart';

void main() {
  test('GetNotes meneruskan daftar dari repository', () async {
    final repo = FakeNoteRepository(
      items: [Note(title: 'A', updatedAt: DateTime(2026, 9, 27))],
    );
    final result = await GetNotes(repo).call();
    expect(result.failure, isNull);
    expect(result.notes.length, 1);
    expect(result.notes.first.title, 'A');
  });

  test('GetNotes meneruskan failure tanpa melempar', () async {
    final repo = FakeNoteRepository(fail: true);
    final result = await GetNotes(repo).call();
    expect(result.failure, isA<LocalFailure>());
    expect(result.notes, isEmpty);
  });
}
