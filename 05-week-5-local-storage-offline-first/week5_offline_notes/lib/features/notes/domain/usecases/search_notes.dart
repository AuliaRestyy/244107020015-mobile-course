import '../entities/note.dart';

class SearchNotes {
  const SearchNotes();

  List<Note> call(List<Note> notes, String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return notes;
    return notes
        .where((note) => note.title.toLowerCase().contains(needle))
        .toList(growable: false);
  }
}
