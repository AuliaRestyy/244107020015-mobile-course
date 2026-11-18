import 'package:flutter_test/flutter_test.dart';
import 'package:week5_offline_notes/core/format.dart';

void main() {
  test('parseNoteId menolak input yang bukan bilangan bulat', () {
    expect(parseNoteId('abc'), isNull);
  });

  test('parseNoteId menolak 0 karena id AUTOINCREMENT mulai dari 1', () {
    expect(parseNoteId('0'), isNull);
  });

  test('parseNoteId menolak id negatif', () {
    expect(parseNoteId('-1'), isNull);
  });

  test('parseNoteId menerima id valid', () {
    expect(parseNoteId('1'), 1);
  });
}