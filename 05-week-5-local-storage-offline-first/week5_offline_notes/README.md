## Week 12: Testing & QA

### 1. Skenario yang diuji

| Skenario | Cakupan | File tes |
|---|---|---|
| Jalur sukses | CRUD catatan lewat cache repository, `addNote` → `syncNotes` membersihkan antrean dirty, cache posts tampil lebih dulu lalu diperbarui, streaming jawaban AI bertahap | `test/note_repository_cache_test.dart`, `test/sync_regression_test.dart`, `test/posts_cache_test.dart`, `test/chat_screen_test.dart` |
| Kasus tepi | Batas 500 vs 501 karakter pesan, `parseNoteId` untuk `abc`/`0`/`-1`/`1`, pencarian case-insensitive dan query spasi saja, SSE terpotong antar chunk, emoji multibyte terbelah, `part.thought` diabaikan, `getNote` id tidak ada | `test/chat_send_message_test.dart`, `test/parse_note_id_test.dart`, `test/search_filter_test.dart`, `test/notes_empty_state_test.dart`, `test/gemini_ai_repository_test.dart`, `test/note_repository_cache_test.dart` |
| Kegagalan | DB gagal dibaca (`LocalFailure`) → `ErrorView`, refresh posts gagal → cache tetap tampil tanpa error, HTTP 401/429/500 dan timeout/koneksi dipetakan ke `AiFailure`, API key kosong, input kosong/terlalu panjang, mode offline menunda sinkronisasi | `test/notes_page_test.dart`, `test/posts_cache_test.dart`, `test/gemini_ai_repository_test.dart`, `test/chat_send_message_test.dart` |
| Regresi | Chip "Belum tersinkron" tidak hilang setelah sinkronisasi; UI notes dengan repository palsu (FAB, tombol sync, field cari) | `test/sync_regression_test.dart`, `test/notes_page_test.dart` |
| End-to-end | `app.main()` → tambah catatan → chip dirty muncul → `sync-button` → chip hilang | `integration_test/app_test.dart` |

Total: 66 tes unit/widget + 1 integration test.

### 2. Hasil

- `flutter test`: **66 lulus** (sebelum penambahan Week 12: 54 lulus).
- `flutter analyze`: **1 info lama** — `avoid_print` di `lib/core/debug.dart:3` (`print` di dalam `assert`, sudah ada sebelum pekerjaan ini). Tidak ada error/warning baru.
- Coverage: **48,1% (486/1011)** menjadi **67,4% (683/1014)**.
- Integration test: **lulus di HP fisik**, perintah
  `flutter test integration_test/app_test.dart -d <device_id>`
  (log: `docs/week12-integration.txt`).

### 3. Bug regresi sync

`NotesNotifier.syncNotes` hanya me-refresh `dirtyCountProvider`; DB sudah bersih tetapi `notesProvider` masih memegang list lama dengan `dirty: true`, sehingga chip "Belum tersinkron" tetap tampil dan badge tidak sinkron dengan daftar.

- Tes regresi `test/sync_regression_test.dart` **gagal sebelum perbaikan** (assert DB lolos, assert `notesProvider` gagal: `Expected: empty, Actual: ['Catatan B', 'Catatan A']`) — log `docs/week12-sync-sebelum-fix.txt`.
- Perbaikan: tambah `await refresh();` dan `ref.invalidate(noteProvider);` sebelum me-refresh `dirtyCountProvider`. Tes **lulus sesudah perbaikan** — log `docs/week12-sync-sesudah-fix.txt`; seluruh suite 66/66 hijau.

### 4. Kendala integration test

- Cache paket Flutter berada di `C:` (`C:\Users\...\AppData\Local\Pub\Cache`) sementara proyek di drive `D:` → build gagal karena lintasan path beda drive; diatasi dengan mematikan build incremental Kotlin (`kotlin.incremental=false`, sudah ada di `android/gradle.properties`).
- Gradle daemon crash karena kehabisan memori. `android/gradle.properties` memakai `org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G -XX:ReservedCodeCacheSize=512m -XX:+HeapDumpOnOutOfMemoryError`.
- Instalasi APK gagal: `INSTALL_FAILED_INSUFFICIENT_STORAGE` di HP — perlu bersihkan penyimpanan perangkat, lalu pasang ulang.

### 5. Temuan belum diperbaiki

1. `postsProvider` memicu refresh jaringan dua kali per siklus perubahan (build pertama + rebuild setelah `postsRevisionProvider.bump()`); dibuktikan `test/posts_cache_test.dart`.
2. `ref.watch(forceOfflineProvider)` dibaca setelah `await repository.readCache()` di `posts_providers.dart`, sehingga dependensi terdaftar terlambat — rawan bila urutan build berubah.
3. Flag mode offline tidak memengaruhi fitur chat dan tidak persisten (hilang saat aplikasi ditutup).
4. Catatan dengan `updated_at` identik tidak punya tiebreaker (`id`), sehingga urutan hasil cache vs tabel bisa tidak stabil.

### 6. Refleksi

1. **Bug apa yang paling mungkin terlewat tanpa pengujian yang Anda tulis?**
   Bug regresi sync. Setelah `syncNotes`, database sudah bersih dan badge dirty sudah 0, tapi `notesProvider` masih memegang list lama yang berisi `dirty: true`, jadi chip "Belum tersinkron" tetap muncul. Tes yang hanya mengecek tabel dan `countDirty()` akan tetap lulus, padahal tampilannya salah. Hanya `test/sync_regression_test.dart` yang mengecek state provider, sehingga bug ini ketahuan. Hal serupa terjadi pada refresh posts yang ternyata dipanggil dua kali, dan itu baru terlihat setelah fake dipasang untuk menghitung jumlah panggilan.

2. **Bagian mana yang perlu fake, dan bagaimana fake itu membuat pengujian lebih konsisten?**
   Fake dipakai untuk `NoteRepository`, `PostRepository`, `AiRepository`, `ApiKeyStore`, dan `HttpClientAdapter`, supaya tes tidak bergantung pada SQLite, jaringan, secure storage, atau waktu sungguhan.

3. **Apa perbedaan nilai yang diberikan pengujian widget dan pengujian integrasi pada fitur Anda?**
   Pengujian widget dengan override provider cocok untuk memeriksa logika UI, interaksi, dan state Riverpod secara cepat dan spesifik. Kekurangannya, tes ini tidak menyentuh sqflite asli, go_router, maupun urutan startup aplikasi. Pengujian integrasi menjalankan `app.main()` dengan database dan navigasi sungguhan, sehingga alur tambah catatan, chip dirty muncul, tekan `sync-button`, lalu chip hilang terbukti berjalan utuh, termasuk dialog editor dan `uploadDelay` yang asli. Itu tidak bisa dibuktikan oleh tes widget karena repository-nya diganti fake. Harganya lebih mahal: butuh build Gradle, instalasi ke perangkat, dan waktu jalan lebih lama.