import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:week5_offline_notes/features/notes/presentation/widgets/notes_empty_state.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('tanpa query menampilkan empty state "Belum ada catatan"', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const NotesEmptyState()));

    expect(find.textContaining('Belum ada catatan'), findsOneWidget);
    expect(find.byIcon(Icons.note_alt_outlined), findsOneWidget);
    expect(find.byIcon(Icons.search_off), findsNothing);
  });

  testWidgets('query tanpa hasil menampilkan pesan pencarian kosong', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const NotesEmptyState(query: 'zzz')));

    expect(find.textContaining('Tidak ada catatan yang cocok'), findsOneWidget);
    expect(find.textContaining('zzz'), findsWidgets);
    expect(find.byIcon(Icons.search_off), findsOneWidget);
    expect(find.textContaining('Belum ada catatan'), findsNothing);
  });

  testWidgets('query berisi spasi saja tetap dianggap tanpa pencarian', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const NotesEmptyState(query: '   ')));

    expect(find.textContaining('Belum ada catatan'), findsOneWidget);
    expect(find.byIcon(Icons.search_off), findsNothing);
  });
}
