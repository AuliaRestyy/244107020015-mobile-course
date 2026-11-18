import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:week5_offline_notes/features/notes/presentation/widgets/note_tile.dart';
import 'package:week5_offline_notes/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tambah catatan lalu sinkronkan menghilangkan chip dirty', (
    tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle();

    // Judul unik agar tidak bertabrakan dengan catatan dari run sebelumnya.
    final title = 'Catatan ${DateTime.now().microsecondsSinceEpoch}';

    await tester.tap(find.byKey(const ValueKey('add-note-fab')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('note-title-field')),
      title,
    );
    await tester.tap(find.byKey(const ValueKey('note-save-button')));
    await tester.pumpAndSettle();

    expect(find.text(title), findsOneWidget);

    final chip = find.text('Belum tersinkron');
    expect(
      find.descendant(
        of: find.ancestor(of: find.text(title), matching: find.byType(NoteTile)),
        matching: chip,
      ),
      findsOneWidget,
      reason: 'catatan baru harus ditandai belum tersinkron',
    );

    await tester.tap(find.byKey(const ValueKey('sync-button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text(title), findsOneWidget);
    expect(chip, findsNothing, reason: 'chip hilang setelah sinkronisasi');
  });
}