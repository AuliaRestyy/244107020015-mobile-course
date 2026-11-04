# AI Log — Week 9 (AI-Assisted Development)

Feature added with AI: **search by note title + dedicated empty state**, on top of the `week5_offline_notes` project (feature-first Clean Architecture, Riverpod 3.4.3, sqflite + Dio). No new project, no architecture change.

---

## 1. Prompt (5 slots)

```
Peran: senior Flutter dev
Konteks:
  feature-first: presentation -> domain <- data (Riverpod 3.4.3, sqflite 2.4.4, Dio 5.11.1)
  domain/ sudah berisi: entities/note.dart (Note: id,title,body,updatedAt,dirty),
    repositories/note_repository.dart (kontrak, Future<({T value, Failure? failure})>),
    usecases/{get_notes,add_note,sync_notes}.dart (semua berbentuk class dengan method call())
  presentation/pages/notes_page.dart saat ini: notes.when(...) -> items.isEmpty ? _EmptyView() : ListView.builder(...)
  test/ yang ada: test/get_notes_test.dart
Tugas:
  Tambah pencarian judul catatan (case-insensitive) + empty state terpisah untuk "hasil pencarian kosong".
  Filter harus jadi aturan domain murni, bukan logika di widget.
Batas:
  Jangan ubah arsitektur / nama file lama / perilaku sync & offline banner.
  domain/ tidak boleh import flutter, sqflite, atau dio.
  Maksimal ~80 baris kode baru non-test. Sertakan test.
Output:
  kode + test + cara menjalankan verifikasi (analyze/test).
```

Context pasted was the folder tree, the `Note` entity, the `NoteRepository` contract, the relevant slice of `notes_page.dart`, and package versions from `pubspec.yaml` / `pubspec.lock`. No tokens, keys, or whole-repo dump.

---

## 2. Raw AI output

Recorded as produced, before verification. Abridged to the parts that mattered:

```dart
// lib/features/notes/domain/usecases/search_notes.dart
List<Note> filterNotes(List<Note> notes, String query) =>
    notes.where((n) => n.title.contains(query)).toList();

// lib/features/notes/presentation/pages/notes_page.dart
data: (items) {
  final filtered = items.where((n) => n.title.contains(query)).toList();
  ...
}
```

and the test the AI proposed:

```dart
test('filter abaikan huruf besar/kecil', () {
  expect(filterNotes(list, 'belanja'), hasLength(2));
});
```

---

## 3. Verification

| Step | Check | Result |
|---|---|---|
| 1 | `domain/` free of Flutter/sqflite/Dio | `grep -rn "package:flutter\|sqflite\|dio" lib/features/notes/domain/` → one hit only, a comment in `search_notes.dart`, zero imports |
| 2 | Every API really exists | `Notifier`, `NotifierProvider`, `Provider`, `AsyncValue.whenData` all resolve against flutter_riverpod 3.4.3 |
| 3 | `flutter analyze` clean | 1 issue left, pre-existing: `lib/core/debug.dart:3 avoid_print` |
| 4 | ≥1 success test and ≥1 failure test | `test/search_filter_test.dart`  6 tests, including no-match |
| 5 | Manual: empty query / match / no match | run on the real app (`flutter build web` + Chrome): empty -> all 2 notes, `BELANJA` -> both mixed-case notes, `zzz-tak-ada` -> search empty state |


## 4. Findings: accepted, accepted+refactored, rejected

| # | AI finding | Decision | Technical reason | Evidence |
|---|---|---|---|---|
| 1 | Put `filterNotes` as a free function in `domain/usecases/` | **Rejected → Wrote a `SearchNotes` class** | All the other use cases in this project are classes with `call()` (`GetNotes`, `AddNote`, `SyncNotes`). A free function would add a second style in the same layer | `grep -n "class .*{" lib/features/notes/domain/usecases/*.dart` shows all four are classes |
| 2 | Filter inside the widget: `items.where((n) => n.title.contains(query))` | **Finding is correct → refactored to domain** | The widget should not hold business rules. Also, `contains` is case-sensitive, so "belanja" does not find "Belanja". In `SearchNotes` I can test it without a widget. | The test "filter mengabaikan huruf besar/kecil" fails with the raw `contains` version and passes after the refactor |
| 3 | No handling for a blank query or extra spaces | **Accepted → fixed** | A query like `"   "` would match nothing and show "no results" even though the search box looks empty. | Tests "query kosong mengembalikan semua catatan" and "query di-trim sebelum dicocokkan" |
| 4 | Reuse the old `_EmptyView` when search finds nothing | **Rejected** | "Belum ada catatan. Ketuk + untuk menulis." is wrong when notes exist but the search missed. These are two different situations, so they need two messages. | `test/notes_empty_state_test.dart` checks both cases, and that `Icons.search_off` shows only when search finds nothing |

### Hallucination check

- **Made-up method:** None got through. The only APIs I wasn't fully sure about were `AsyncValue.whenData`, `Notifier`, and `NotifierProvider`. They all compile, and `flutter analyze` has no complaints about them.
- **Outdated package API:** I checked `pubspec.lock`. The version is `flutter_riverpod 3.4.3`. I did not use Riverpod 2 style like `StateProvider`. I used `Notifier` + `NotifierProvider`, the same as `lib/core/providers.dart`, so the project doesn't mix two state styles.
- **Wrong logic that looks right:** This is the case-sensitive `contains` in finding #2. The code looks fine and runs, but it quietly misses results ("belanja" doesn't find "Belanja").

## 6. Accepted refactor, in the module's layer order

Files changed

| File | Change |
|---|---|
| `lib/features/notes/domain/usecases/search_notes.dart` | **new** = pure `SearchNotes.call(List<Note>, String)` |
| `lib/features/notes/presentation/providers/notes_providers.dart` | `searchQueryProvider`, `searchNotesProvider`, `filteredNotesProvider` |
| `lib/features/notes/presentation/widgets/notes_search_field.dart` | **new** = search box + clear button |
| `lib/features/notes/presentation/widgets/notes_empty_state.dart` | **new** = two branches, replaces private `_EmptyView` |
| `lib/features/notes/presentation/pages/notes_page.dart` | watches `filteredNotesProvider`, inserts `NotesSearchField`, drops `_EmptyView` |
| `test/get_notes_test.dart` | added missing imports; fake moved to `test/support/` |
| `test/search_filter_test.dart` | **new** = 6 domain tests |
| `test/notes_empty_state_test.dart` | **new** = 3 widget tests |