# Week 5 — Local Storage & Offline-First (Flutter Notes)

Aplikasi **Offline Notes** untuk praktikum Minggu 5: CRUD catatan yang berfungsi
penuh tanpa internet, preferensi tema, pola offline-first (cache-first read,
dirty flag, antrean sinkronisasi), dan simulasi offline yang deterministik.

Codelab resmi: [flutter-codelab — Minggu 5](https://jti-polinema.github.io/flutter-codelab/05-minggu-5-local-storage-offline-first/index.html)

## Tujuan

Menunjukkan pilihan storage lokal yang tepat (SharedPreferences vs Hive vs
sqflite vs Drift) dan mengimplementasikan pola **offline-first** pada aplikasi
catatan Flutter dengan Riverpod.

## Fitur utama

- **CRUD catatan** persisten via **SQLite (sqflite)** melalui repository lokal;
  daftar diurutkan `updated_at` terbaru.
- **Preferensi tema** gelap/terang + waktu terakhir dibuka via **SharedPreferences**.
- **Offline-first**:
  - *Cache-first read* untuk data posts (JSONPlaceholder): tampilkan cache lokal
    seketika, refresh jaringan di background, simpan ke tabel `cached_posts`
    (`lib/data/sync.dart`).
  - *Dirty flag*: setiap catatan baru/ubah ditandai `dirty = 1`.
  - *Antrean sinkronisasi*: badge jumlah catatan belum tersinkron + `syncNotes()`
    (simulasi server dengan delay; mekanisme yang dinilai, bukan servernya).
- **State lengkap**: loading / error / empty / success via `AsyncValue` Riverpod.
- **Simulasi offline deterministik** (`forceOffline` toggle di Pengaturan) —
  demo tidak bergantung pada kondisi Wi-Fi.
- **Halaman detail** `/note/:id` (GoRouter) yang membaca dari repository lokal,
  bukan dari state halaman list.
- **NoteTile** dengan badge "Belum tersinkron" bila `dirty == true`.

## Stack teknologi

| Layer | Teknologi |
|---|---|
| UI | Flutter (Material 3), GoRouter |
| State | Riverpod (`AsyncNotifier`, `AsyncValue`, `FutureProvider`) |
| Local storage — catatan | **sqflite (SQLite)** + repository pattern |
| Local storage — preferensi | **shared_preferences** |
| Network (simulasi cache-first) | Dio → `https://jsonplaceholder.typicode.com/posts` |
| Testing | `flutter_test` + `ProviderContainer` + repository palsu |

Keputusan storage (bandingkan SharedPreferences / Hive / sqflite / Drift) dan
justifikasinya: [`docs/storage-comparison.md`](docs/storage-comparison.md) &
[`docs/ai-challenge.md`](docs/ai-challenge.md).

## Struktur proyek

```
05-week-5-local-storage-offline-first/
├── README.md
├── docs/                      # hasil AI Challenge & analisis storage
├── screenshots/               # bukti mode pesawat (offline)
└── week5_offline_notes/       # project Flutter
    ├── lib/
    │   ├── main.dart          # ProviderScope + GoRouter + tema
    │   ├── data/
    │   │   ├── local/
    │   │   │   ├── db.dart        # pembuka SQLite (notes, cached_posts)
    │   │   │   └── note.dart      # model Note (dirty flag)
    │   │   ├── prefs.dart         # PrefsRepository (SharedPreferences)
    │   │   ├── providers.dart     # semua provider Riverpod
    │   │   ├── sync.dart          # cache-first posts + syncNotes
    │   │   └── repositories/
    │   │       └── note_repository.dart   # CRUD saja (satu pintu data)
    │   └── pages/
    │       ├── notes_page.dart    # daftar + badge dirty + editor
    │       ├── note_detail_page.dart
    │       ├── settings_page.dart # tema, last opened, forceOffline
    │       └── widgets/note_tile.dart
    └── test/
        └── note_test.dart     # unit test model + provider dgn repo palsu
```

## Cara menjalankan

```bash
cd week5_offline_notes
flutter pub get
flutter run          # emulator / perangkat fisik
```

Catatan: setelah menambah plugin, **stop aplikasi dan `flutter run` ulang**
(bukan hot reload) untuk menghindari `MissingPluginException`.

### Uji

```bash
flutter analyze      # harus 0 issue
flutter test         # 5 test lulus (model + provider dengan repository palsu)
```

> **Catatan Riverpod 3:** secara default provider yang melempar `Exception`
> di-**retry otomatis** (exponential backoff, maks 10×) sebelum error sampai
> ke UI — bagus untuk error DB/transien di production, tapi di test matikan
> dengan `ProviderContainer(retry: (_, _) => null)` (lihat
> `test/note_test.dart`). Error berupa `Error`/`StateError` tidak di-retry.

## Hasil yang dicapai

- ✅ `flutter analyze` bersih (0 error, 0 warning).
- ✅ Semua test lulus (`test/note_test.dart`): mapping aman null, serialisasi
  `dirty`, provider sukses/error dengan repository palsu, dan `addNote` via
  provider menaikkan badge antrean sync.
- ✅ UI tidak memanggil SQLite/SharedPreferences langsung — semuanya lewat
  repository + provider.
- ✅ Aplikasi berfungsi penuh dalam mode pesawat: baca/tambah/hapus catatan,
  badge dirty akurat.
- ✅ Cache posts tampil tanpa internet (cache-first), refresh di background.
- ✅ `forceOffline` toggle memberi simulasi offline deterministik.
- ✅ Analisis & keputusan storage terdokumentasi di `docs/`.

## Verifikasi mode pesawat (manual)

1. Aktifkan mode pesawat / matikan Wi-Fi → buka aplikasi:
   daftar catatan tetap tampil, badge dirty tetap akurat, **cache posts**
   tetap tampil (bila sudah pernah online sekali).
2. Tambah/hapus catatan saat offline → badge dirty naik.
3. Nyalakan koneksi (atau matikan toggle **Mode offline (simulasi)** di
   Pengaturan) → ketuk ikon **sync**: badge kembali ke 0.
4. Simpan screenshot sebelum/sesudah ke folder `screenshots/`.

## Refleksi codelab (ringkas)

- Daftar catatan **tidak boleh** di SharedPreferences: rewrite penuh O(n) tiap
  simpan, tanpa query, tanpa tipe, tanpa relasi — rusak di >100 catatan.
- Cache-first cukup untuk data yang boleh usang (posts, daftar); data harga
  real-time butuh network-first.
- Dirty flag → antrean sync tanpa memblokir UI (kerja di background + badge);
  antrean terpisah (tabel outbox) diperlukan bila sync harus bertahan
  restart/di antre panjang.
