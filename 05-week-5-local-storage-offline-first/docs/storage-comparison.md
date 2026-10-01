# Week 5 — Offline Storage Comparison: SharedPreferences vs Hive vs sqflite vs Drift

> Scope: an offline-first Flutter **Notes** app with:
> - **CRUD notes** (title, body, timestamps, dirty/sync flag)
> - **Theme preferences** (dark/light mode, last-opened timestamp)
> - Scale target: **1,000+ notes**
>
> Project context: `week5_offline_notes` currently uses **sqflite** (notes) + **shared_preferences** (theme) + Riverpod.

---

## 1. TL;DR Comparison Table

| Criterion | SharedPreferences | Hive | sqflite (SQLite) | Drift (on SQLite) |
|---|---|---|---|---|
| **Data model** | Primitive key → value (bool/int/double/String/StringList) | Dart objects in typed boxes (key → value) | Relational tables, SQL | Relational tables, typed Dart DSL → SQL |
| **Best for** | Tiny flags, settings | Simple object collections, configs | Structured/queryable data | Structured/queryable data + compile-time safety + streams |
| **Query complexity** | ❌ None — only `get/set` by exact key | ⚠️ Weak — `get`, `values`, filter in Dart, `box.get(key)` | ✅ Full SQL: WHERE/JOIN/GROUP BY/LIMIT/FTS5 | ✅ Full SQL via type-safe query builder + raw SQL escape hatch |
| **Relationships (FK, JOIN)** | ❌ None | ❌ Manual (store ids, join in Dart) | ✅ Native FKs + JOINs | ✅ Native FKs + typed relational APIs (`withRefs`, `customSelect`) |
| **Stream reactivity** | ❌ None (manual `setState`) | ✅ `box.watch()` / `listenable()` | ❌ None natively (manual query + notify) | ✅ **`table.watch()` / `select().watch()`** — auto re-query on write |
| **Type safety** | ❌ Weak — `getBool('x') as bool?`, runtime casts | ⚠️ Medium — TypeAdapters, codegen `HiveObject` | ❌ Weak — `Map<String, Object?>` everywhere, manual casts | ✅ **Strong** — generated `Note` class, compile-time columns |
| **Boilerplate** | Very low | Low–medium (adapters, part files) | Medium (raw SQL strings, manual mappers) | High initial (schema + build_runner), near-zero at call sites |
| **Indexing / FTS search** | N/A | ❌ No (scan all values) | ✅ Indexes + FTS5 full-text | ✅ Indexes + FTS5 |
| **Transactions / integrity** | ❌ Atomic per-key set only | ⚠️ `box.put` atomic per write | ✅ ACID transactions, batch ops | ✅ ACID transactions, batch ops |
| **Testing** | Easy — `SharedPreferences.setMockInitialValues({})` | Easy — `Hive.init(tempDir)` in-memory | Medium — `sqflite_common_ffi` on desktop/CI | ✅ Easiest — `NativeDatabase.memory()` in pure Dart |
| **Web support** | ✅ | ✅ | ❌ (sqflite is mobile/desktop only) | ✅ (Drift wasm / IndexedDB via `drift_wasm` or `wasm`) |
| **Performance @ 1,000 notes** | N/A (doesn't scale to lists) | ✅ Very fast in-memory reads (all loaded) | ✅ Fast; loads only requested rows | ✅ Same SQLite engine; + change-stream overhead |
| **Typical APK size impact** | ~negligible | ~1–2 MB | ~negligible (SQLite often bundled) | ~small (Dart-side + SQLite) |
| **Where it lives in this app** | ✅ Theme prefs (`prefs.dart`) | Not used | ✅ Notes (`db.dart`, `note_repository.dart`) | Not used |

---

## 2. Deep Dive per Option

### 2.1 SharedPreferences — *the right tool for theme prefs*

```dart
final prefs = await SharedPreferences.getInstance();
await prefs.setBool('dark_mode', true);
final dark = prefs.getBool('dark_mode') ?? false;
```

**Strengths**
- Trivial API, near-zero boilerplate, tiny footprint.
- Perfect for **theme preference, default currency, last-opened timestamp** — exactly what `lib/data/prefs.dart` does today.

**Weaknesses for notes**
- No queries: you cannot "get notes updated since X" or "count dirty".
- Stores the *entire* value list under one key — adding a note means read-all → modify → write-all (O(n) rewrite per save).
- No type safety (`getBool` returns null if key missing or type mismatch), no relationships, no streams, no indexes.
- Android: XML-backed, ~1MB soft limit before `commit`/`apply` jank.

**Verdict:** ✅ Keep for **theme/settings only**. ❌ Never use for the notes list itself.

---

### 2.2 Hive — *fast object box, not a database*

```dart
@HiveType(typeId: 0)
class Note extends HiveObject {
  @HiveField(0) int? id;
  @HiveField(1) String title;
  @HiveField(2) String body;
  // ...
}
final box = await Hive.openBox<Note>('notes');
box.put(note);                       // CRUD
final stream = box.watch();          // ✅ reactivity
```

**Strengths**
- Very fast reads (entire box held in memory), binary format.
- `box.watch()` gives **change streams** — list UI updates automatically.
- Works on **web**, pure Dart, easy tests with `Hive.init(tempDir)`.

**Weaknesses for notes**
- Queries are "load everything, filter in Dart" — fine at 1k notes, painful at 100k.
- Relationships must be hand-rolled (store `noteIds` on tags, join manually).
- No SQL, no indexes, no FTS full-text search.
- TypeAdapters + codegen (`build_runner`) needed; schema changes need manual migration logic.

**Verdict:** ⚠️ Acceptable for a small notes app if you love streams and want simplicity — but you outgrow it the moment you need search, filters, or relationships.

---

### 2.3 sqflite — *what this project uses for notes*

```dart
// Write (lib/data/repositories/note_repository.dart)
final id = await db.insert('notes', note.toMap());

// Read
final rows = await db.query('notes', orderBy: 'updated_at DESC');
return rows.map(Note.fromMap).toList();

// Count dirty for sync
SELECT COUNT(*) AS c FROM notes WHERE dirty = 1
```

**Strengths**
- Real **relational database**: SQL WHERE/ORDER/GROUP/JOIN, **indexes**, **FTS5** full-text search.
- ACID transactions + `Batch` — critical for offline sync (write note + mark synced atomically).
- Scales trivially well beyond 1,000 notes (SQLite is used at billions of rows elsewhere).
- The `dirty` flag + `syncNotes()` pattern in this repo is exactly the offline-first "local first, sync later" approach.

**Weaknesses**
- ❌ **No stream reactivity** — after `insert/update/delete`, you must manually re-query and push into Riverpod (`ref.invalidate` / `ref.read(...).state = ...`).
- ❌ No type safety: everything is `Map<String, Object?>` with manual casts (`note.dart` `fromMap`).
- ❌ Boilerplate: raw SQL strings, hand-written `toMap`/`fromMap` mappers.
- ❌ **No web support** — a real gap for an offline-first app targeting Flutter Web.
- Manual migrations (`onUpgrade` + `ALTER TABLE`) with no compile-time checking.

**Verdict:** ✅ Solid engine choice for structured notes; ⚠️ keep a clean repository layer to hide the raw-map ugliness.

---

### 2.4 Drift — *sqflite's type-safe, reactive big brother*

```dart
// schema (drift)
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get body => text().withDefault(const Constant(''))();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();
}

// typed query + stream in one line
@DriftAccessor(tables: [Notes])
class NoteDao extends DatabaseAccessor<AppDatabase> {
  Stream<List<Note>> watchUpdatedDesc() =>
      (select(notes)..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();
}
```

**Strengths**
- **Full type safety**: generated `Note` data class, columns are typed, typos won't compile.
- **Built-in stream reactivity**: `select(notes).watch()` re-queries automatically after any write — perfect for Riverpod (`StreamProvider`).
- Full SQL power (joins, transactions, FTS5 via `@TableIndex` / custom statements).
- **Best testing story**: pure in-memory Dart tests (`NativeDatabase.memory()`), no device needed.
- Works on **web** (via wasm) — unlike raw sqflite.
- Migrations are declarative (`schemaVersion`, step-by-step migration steps).

**Weaknesses**
- Highest setup cost: `drift_dev` + `build_runner` codegen, `part` files, generated `.g.dart`.
- Learning curve (query builder API, `Value<T>` for nullable column updates).
- Overkill for a 20-line app; shines once schema grows.

**Verdict:** ✅ Best overall engine for a growing notes app — recommended if you can accept codegen.

---

## 3. Feature-by-Feature Analysis for This Notes App

### 3.1 Query complexity

| Need | SharedPreferences | Hive | sqflite | Drift |
|---|---|---|---|---|
| List all notes, newest first | ❌ rewrite whole list | ⚠️ sort in Dart | ✅ `ORDER BY updated_at DESC` | ✅ `orderBy(desc(updatedAt))` |
| Filter by title/body (search) | ❌ | ⚠️ full scan in Dart | ✅ `WHERE title LIKE ?` / FTS5 | ✅ typed `where()` / FTS5 |
| Count unsynced (dirty=1) | ❌ | ⚠️ scan all | ✅ `COUNT(*) WHERE dirty=1` | ✅ `count()` with filter |
| Pagination (50 at a time) | ❌ | ⚠️ skip/take in Dart | ✅ `LIMIT 50 OFFSET x` or keyset | ✅ same via query builder |
| "Notes updated since last sync" | ❌ | ⚠️ filter in Dart | ✅ `WHERE updated_at > ?` | ✅ typed comparison |

At **1,000+ notes** with search, sorting, and a dirty-sync counter, only sqflite/Drift are appropriate.

### 3.2 Relationships

Planned Phase-2 style features (notebook/category, tags, household) need relations:

- **SharedPreferences:** impossible.
- **Hive:** you store `List<String> tagIds` on a note and join in Dart — you reimplement a database badly.
- **sqflite / Drift:** `notes.notebook_id → notebooks.id` with `ON DELETE CASCADE`, real JOINs:

```sql
SELECT n.*, nb.name AS notebook_name
FROM notes n JOIN notebooks nb ON nb.id = n.notebook_id
WHERE n.notebook_id = ? ORDER BY n.updated_at DESC;
```

### 3.3 Stream reactivity (live UI updates)

| | Mechanism | Notes UI behavior |
|---|---|---|
| SharedPreferences | none | manual refresh |
| Hive | `box.watch()` | automatic ✅ |
| sqflite | none | **you** must `ref.invalidate(notesProvider)` after each write (what this repo's structure expects) |
| Drift | `select(notes).watch()` | automatic ✅ — zero invalidation code |

Riverpod wiring for each:
- sqflite: `FutureProvider` + manual invalidation on mutation.
- Drift: `StreamProvider((ref) => noteDao.watchAll())` — list rebuilds itself.
- Hive: `StreamProvider((ref) => box.watch().map(...))` with an initial read.

### 3.4 Type safety

- **SharedPreferences:** `prefs.getBool('dark_mode')` → null-checked primitive; typo in a key string fails silently at runtime.
- **sqflite:** `map['updated_at'] as String?` — column names are stringly-typed; rename a column and everything still "compiles".
- **Hive:** `@HiveField(n)` adapters catch some issues, but field indexes are magic numbers.
- **Drift:** generated types — `note.updatedAt` is a `DateTime`, `where((t) => t.dirty.equals(true))` is checked at compile time. **Winner.**

### 3.5 Boilerplate (CRUD note, end to end)

| | Files touched | Approx. code |
|---|---|---|
| SharedPreferences | N/A for lists | — |
| Hive | model + adapter + box open | ~40 lines (model+adapter), ~5 lines per op |
| sqflite | model + SQL strings + `toMap`/`fromMap` + repo + manual notify | **~120+ lines** (see current `note.dart` + `note_repository.dart`) |
| Drift | table class + dao + `build_runner` run | ~25 lines schema, **~3 lines per op**, streams free |

Drift has the biggest *upfront* cost (codegen) and the smallest *marginal* cost.

### 3.6 Testing

| | How | Device needed? |
|---|---|---|
| SharedPreferences | `SharedPreferences.setMockInitialValues({'dark_mode': true})` | No |
| Hive | `Hive.init(tempDir)` + register adapters | No |
| sqflite | `sqfliteFfiInit()` + `databaseFactoryFfi` (desktop/CI); or mock the `NoteRepository` interface | No (with ffi) |
| Drift | `AppDatabase(NativeDatabase.memory())` in a pure `test()` | **No — first-class, fastest** |

For this repo, the injectable `openDb` hook in `NoteRepository({Future<Database> Function()? openDb})` is already the right seam — a test can pass `databaseFactoryFfi.openDatabase(inMemoryDatabasePath)`.

> **Finding (Riverpod 3.4.3, verified in this repo):** `ProviderContainer`'s
> **default retry auto-retries any thrown `Exception`** up to 10× with
> exponential backoff (200ms → 6.4s) before the error surfaces as `AsyncError`.
> A plain `Error`/`StateError` is **not** retried. In tests, disable it with
> `ProviderContainer(retry: (_, _) => null)` so errors propagate immediately
> (this fixed the "provider error dengan repository palsu" test, which timed
> out waiting for the 10-retry backoff to finish). In the app this default is
> beneficial: transient DB failures self-heal before users see an error state.

### 3.7 Trade-off summary (what you gain/lose with each)

- **SharedPreferences:** gain simplicity; lose queries, scale, safety. Fine for theme.
- **Hive:** gain streams + speed + web; lose SQL, relationships, real search.
- **sqflite:** gain full relational power + sync-friendly transactions; lose streams, type safety, web.
- **Drift:** gain everything sqflite has **plus** streams, type safety, web, and testing ergonomics; pay with codegen ceremony.

---

## 4. Final Recommendations for This App

### Use case A — Theme & app preferences → **SharedPreferences** ✅

- Current `PrefsRepository` (`dark_mode`, `last_opened_at`) is exactly the right size for it.
- Swap-in alternative: a single Drift table only if you *already* have Drift and want one DB; otherwise not worth it.

### Use case B — Notes CRUD at 1,000+ notes → pick one:

| If your priority is… | Choose |
|---|---|
| You already built it with sqflite and it works | **Stay on sqflite** (current repo) — keep `NoteRepository` as the abstraction seam; add `ref.invalidate` after writes |
| Type safety + auto UI updates (streams) + web + easy tests | **Migrate to Drift** — the best long-term fit for this exact app |
| Maximum simplicity, small scale, pure-Dart (web OK) | Hive — but you'll hit walls on search/relations |
| Never | SharedPreferences for the notes list |

**My recommendation for `week5_offline_notes`:**
1. **Keep SharedPreferences** for theme (already correct).
2. **Keep sqflite for now** — the repository pattern in `lib/data/repositories/note_repository.dart` isolates it; migrating later to Drift is a contained change.
3. **If** you add search/tags/notebooks, migrate to **Drift** — it answers every weakness of the current sqflite layer (streams, type safety, web, tests) on the same SQLite engine.

---

## 5. Schema Design for 1,000+ Notes

### 5.1 Current schema (sqflite, `lib/data/local/db.dart`)

```sql
CREATE TABLE notes(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  body TEXT NOT NULL DEFAULT '',
  updated_at TEXT NOT NULL,
  dirty INTEGER NOT NULL DEFAULT 0
);
```

**Gaps at 1,000+ notes:** no index on `updated_at` (ORDER BY becomes a sort per query), no `created_at`, no tags/category, no FTS search table, `updated_at` stored as ISO-8601 TEXT (works for lexicographic compare, but epoch millis INTEGER is faster/smaller — this matches what `Note.toMap()` writes today).

### 5.2 Recommended schema (SQLite / sqflite / Drift-compatible)

```sql
-- 1) Main table
CREATE TABLE notes(
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  title         TEXT    NOT NULL,
  body          TEXT    NOT NULL DEFAULT '',
  color         INTEGER,                      -- optional: hex ARGB int
  notebook_id   INTEGER REFERENCES notebooks(id) ON DELETE SET NULL,
  created_at    INTEGER NOT NULL,             -- epoch millis UTC
  updated_at    INTEGER NOT NULL,             -- epoch millis UTC
  deleted_at    INTEGER,                      -- soft delete for offline sync
  dirty         INTEGER NOT NULL DEFAULT 1    -- needs upload
);

-- 2) Speed indexes (the actual 1,000+ notes fix)
CREATE INDEX idx_notes_updated_at  ON notes(updated_at DESC);
CREATE INDEX idx_notes_dirty       ON notes(dirty, updated_at DESC);  -- sync worker
CREATE INDEX idx_notes_notebook    ON notes(notebook_id, updated_at DESC);

-- 3) Tags (M:N relationship)
CREATE TABLE tags(
  id   INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE
);
CREATE TABLE note_tags(
  note_id INTEGER NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  tag_id  INTEGER NOT NULL REFERENCES tags(id)  ON DELETE CASCADE,
  PRIMARY KEY(note_id, tag_id)
);

-- 4) Full-text search (optional but recommended)
CREATE VIRTUAL TABLE notes_fts USING fts5(
  title, body, content='notes', content_rowid='id'
);
-- keep in sync via triggers on INSERT/UPDATE/DELETE of notes
```

**Drift equivalent (typed, codegen):**

```dart
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get body => text().withDefault(const Constant(''))();
  IntColumn get color => integer().nullable()();
  IntColumn get notebookId => integer().nullable().references(Notebooks, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();
}

@UseDriftSchema(tables: [Notes, Notebooks, Tags, NoteTags])
```

### 5.3 Size & performance notes at this scale

- 1,000 notes × ~1 KB text ≈ **1 MB** — SQLite handles 10–100k rows easily; the indexes above make list queries O(log n) instead of full sorts.
- **Pagination:** prefer keyset over OFFSET for long lists:
  ```sql
  SELECT * FROM notes WHERE deleted_at IS NULL AND updated_at < ?
  ORDER BY updated_at DESC LIMIT 50;
  ```
- **Sync:** the existing `dirty` flag + `syncNotes()` pattern scales as-is: `WHERE dirty = 1` uses `idx_notes_dirty`; wrap `markAllSynced()` + note updates in one transaction.
- Timestamps: switch `TEXT ISO-8601` → `INTEGER epoch millis` in a v2 migration (`onUpgrade`) for smaller storage and faster range queries.

---

## 6. Why `note_repository.dart` Had Errors (root cause)

`flutter analyze` reported 3 errors, all in the same dead function:

```
error - The name 'Post' isn't a type ...                note_repository.dart:53
error - The function 'readCachedPosts' isn't defined ... note_repository.dart:54
error - The function 'refreshPostsInBackground' isn't defined ... note_repository.dart:57
```

**Root cause:** the file contained `loadPostsCacheFirst()`, a **leftover tutorial snippet about a "posts" REST API cache** (Dio + provider invalidation). It referenced three symbols that were **never implemented anywhere in this project**:

| Symbol | Referenced at | Actually exists? |
|---|---|---|
| `Post` (type) | return type `Future<List<Post>>` | ❌ No `Post` model class in `lib/` |
| `readCachedPosts()` | reads from `cached_posts` table | ❌ Only the SQL table exists in `db.dart` — no Dart function |
| `refreshPostsInBackground()` | background re-fetch | ❌ Never defined |

Nothing in the app called `loadPostsCacheFirst` (grep: 0 callers), and the `cached_posts` table is only referenced by that dead code — so this was **copied-in demo code that was never completed**, in a notes app that doesn't have a "posts" concept at all.

**Resolution (final):** after checking the official codelab, the missing pieces were **implemented for real** rather than left deleted — the codelab's Refactoring Challenge #2 requires moving cache-post logic and `syncNotes` into `lib/data/sync.dart`:

- `Post` model + `readCachedPosts()` (reads `cached_posts` table) — implemented.
- `refreshPostsInBackground()` — implemented with Dio (`GET /posts?_limit=20`), transactional write to `cached_posts`, and **change-detection** so `onRefreshed` (provider reload) only fires when the payload actually changed (prevents invalidate loops).
- `loadPostsCacheFirst()` — implemented as true cache-first read (return cache immediately, refresh un-awaited in background; `skipNetwork` flag powers the deterministic `forceOffline` simulation).
- `syncNotes()` — moved out of `NoteRepository` so the repository stays CRUD-only.

`flutter analyze` now reports **zero issues** (the unused `material.dart` warning in `settings_page.dart` also went away once the settings UI was built).

> Lesson for offline-first repos: keep "cache-first loading" *patterns* as documented pseudo-code or implement them fully — half-written examples that reference undefined symbols fail the analyzer and mislead readers.
