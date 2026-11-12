import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:week5_offline_notes/features/notes/presentation/widgets/note_editor_dialog.dart';

/// Membungkus dialog agar bisa dibuka/ditutup berulang kali dalam satu test.
Future<NoteEditorResult?> _open(
  WidgetTester tester, {
  String initialTitle = '',
  String initialBody = '',
  bool isEditing = false,
  int bodyMaxLines = 4,
}) async {
  NoteEditorResult? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showNoteEditorDialog(
                context,
                initialTitle: initialTitle,
                initialBody: initialBody,
                isEditing: isEditing,
                bodyMaxLines: bodyMaxLines,
              );
            },
            child: const Text('buka'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('judul dialog mengikuti mode baru/edit', (tester) async {
    await _open(tester);
    expect(find.text('Catatan baru'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    await _open(tester, isEditing: true, initialTitle: 'Lama');
    expect(find.text('Edit catatan'), findsOneWidget);
    await tester.tap(find.text('Batal'));
  });

  testWidgets('nilai awal terisi saat edit', (tester) async {
    await _open(
      tester,
      isEditing: true,
      initialTitle: 'Judul lama',
      initialBody: 'Isi lama',
    );
    expect(find.text('Judul lama'), findsOneWidget);
    expect(find.text('Isi lama'), findsOneWidget);
    await tester.tap(find.text('Batal'));
  });

  testWidgets('Batal mengembalikan null', (tester) async {
    NoteEditorResult? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                captured = await showNoteEditorDialog(context);
              },
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(captured, isNull);
  });

  testWidgets('judul kosong ditolak dan dialog tetap terbuka', (tester) async {
    await _open(tester, initialTitle: '   ');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Judul wajib'), findsOneWidget);
    expect(find.byType(NoteEditorDialog), findsOneWidget);
    await tester.tap(find.text('Batal'));
  });

  testWidgets('Simpan mengembalikan judul ter-trim dan isi apa adanya',
      (tester) async {
    NoteEditorResult? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                captured = await showNoteEditorDialog(context);
              },
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '  Belanja  ');
    await tester.enterText(fields.at(1), ' isi dengan spasi ');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.title, 'Belanja');
    expect(captured!.body, ' isi dengan spasi ');
  });

  testWidgets('controller dibuang setiap dialog ditutup (tanpa kebocoran)',
      (tester) async {
    // Membuka/menutup dialog berkali-kali harus melepas State & controller.
    // Bila dispose tidak dipanggil, Flutter melempar error pada pumpAndSettle
    // berikutnya karena ChangeNotifier masih punya listener.
    for (var i = 0; i < 10; i++) {
      await _open(tester);
      expect(find.byType(NoteEditorDialog), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.byType(NoteEditorDialog), findsNothing);
    }
  });

  testWidgets('kolom isi mengikuti bodyMaxLines', (tester) async {
    await _open(tester, bodyMaxLines: 8);
    final bodyField = find.byType(TextField).at(1);
    expect(tester.widget<TextField>(bodyField).maxLines, 8);
    await tester.tap(find.text('Batal'));
  });
}