import 'package:flutter_test/flutter_test.dart';
import 'package:week5_offline_notes/features/notes/domain/entities/note.dart';
import 'package:week5_offline_notes/features/notes/domain/usecases/search_notes.dart';

Note _note(String title) =>
    Note(title: title, updatedAt: DateTime(2026, 11, 4));

void main() {
  const search = SearchNotes();
  final notes = <Note>[
    _note('Belanja mingguan'),
    _note('belanja bulanan'),
    _note('Rapat kampus'),
    _note('Resep kue'),
  ];

  test('filter mengabaikan huruf besar/kecil', () {
    expect(search(notes, 'belanja'), hasLength(2));
    expect(search(notes, 'BELANJA'), hasLength(2));
    expect(search(notes, 'BeLaNjA'), hasLength(2));
  });

  test('query tidak cocok mengembalikan list kosong', () {
    expect(search(notes, 'zzz-tak-ada'), isEmpty);
  });

  test('query kosong mengembalikan semua catatan tanpa menyalin', () {
    expect(search(notes, ''), hasLength(4));
    expect(search(notes, '   '), hasLength(4));
  });

  test('query di-trim sebelum dicocokkan', () {
    expect(search(notes, '  rapat  '), hasLength(1));
    expect(search(notes, '  rapat  ').single.title, 'Rapat kampus');
  });

  test('hanya judul yang dicari, bukan isi catatan', () {
    final withBody = <Note>[
      Note(
        title: 'Catatan harian',
        body: 'belanja sayur',
        updatedAt: DateTime(2026, 11, 4),
      ),
    ];
    expect(search(withBody, 'belanja'), isEmpty);
  });

  test('hasil filter mempertahankan urutan asli', () {
    expect(search(notes, 'an').map((note) => note.title).toList(), [
      'Belanja mingguan',
      'belanja bulanan',
    ]);
  });
}
