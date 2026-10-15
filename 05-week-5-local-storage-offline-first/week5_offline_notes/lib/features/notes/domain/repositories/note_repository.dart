import '../../../../core/failures.dart';
import '../entities/note.dart';

abstract class NoteRepository {
  Future<({List<Note> notes, Failure? failure})> fetchNotes();
  Future<({Note? note, Failure? failure})> getNote(int id);
  Future<({Note? note, Failure? failure})> addNote({
    required String title,
    String body = '',
  });
  Future<({Note? note, Failure? failure})> updateNote({
    required int id,
    required String title,
    String body = '',
  });
  Future<({bool ok, Failure? failure})> deleteNote(int id);
  Future<({int count, Failure? failure})> countDirty();
  Future<({bool ok, Failure? failure})> markAllSynced();
}
