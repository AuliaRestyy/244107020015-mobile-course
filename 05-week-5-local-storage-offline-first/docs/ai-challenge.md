# AI Challenge — Keputusan Storage (Week 5)

> Bagian ini mendokumentasikan prompt AI yang dipakai, hasil verifikasi checklist
> codelab, dan keputusan final beserta alasannya (wajib untuk Mini Project /
> Industry Challenge).

## Prompt yang dipakai

Prompt resmi codelab (AI Prompt Challenge), dijalankan pada AI coding assistant:

```
Aplikasi Flutter Offline Notes: CRUD catatan + preferensi tema.
Bandingkan SharedPreferences, Hive, sqflite (SQLite), dan Drift
untuk dua kebutuhan ini. Requirements:
- Kriteria: kompleksitas query, kebutuhan relasi, reaktivitas (stream),
  type-safety, ukuran boilerplate, dan kemudahan testing.
- Beri rekomendasi final: mana untuk preferensi, mana untuk catatan,
  beserta alasannya dalam 1 tabel.
- Tunjukkan skema tabel/kotak untuk 1000+ catatan.
Jelaskan trade-off setiap pilihan.
```

Hasil lengkap analisis AI: **[storage-comparison.md](storage-comparison.md)**
(tabel perbandingan 4 storage, trade-off, rekomendasi, skema 1000+ catatan).

## AI Verification Checklist — hasil verifikasi manual

| # | Pertanyaan checklist | Temuan | Status |
|---|---|---|---|
| 1 | Apakah AI menempatkan daftar catatan di SharedPreferences? | **Tidak.** AI menempatkan daftar catatan di **sqflite (SQLite)** via repository; SharedPreferences hanya untuk tema & last-opened. Sesuai aturan codelab (SharedPreferences rapuh untuk koleksi: rewrite penuh per simpan, tanpa query, tanpa tipe). | ✅ Diterima |
| 2 | Apakah skema AI mendukung antrean sync (dirty flag / updated_at) atau hanya CRUD polos? | **Ya.** Skema mempertahankan `dirty INTEGER` + `updated_at`, dan menambah index `(dirty, updated_at)` untuk query antrean sync, plus usulan `created_at`/`deleted_at` (soft delete) untuk versi produksi. Mekanisme `countDirty()` → `syncNotes()` → `markAllSynced()` sudah diuji lewat badge di UI. | ✅ Diterima |
| 3 | Apakah klaim "real-time" AI didukung stream (Drift/watch) atau hanya asumsi? | **Jujur: tidak real-time.** sqflite memang **tidak** punya stream — AI merekomendasikan Drift (`table.watch()`) bila reaktivitas stream dibutuhkan, dan untuk sqflite memakai pola Riverpod `AsyncNotifier` + `ref.invalidate` setelah mutasi. Klaim "real-time" tidak dipakai untuk justifikasi sqflite. | ✅ Diverifikasi |
| 4 | Apakah estimasi boilerplate AI masuk akal setelah dicoba (`flutter pub add` + migrasi)? | **Ya, diverifikasi implementasi.** sqflite memang menuntut `toMap`/`fromMap` manual + SQL string (≈120+ baris untuk CRUD penuh, sesuai estimasi dokumen); Drift lebih hemat di call site tapi butuh `build_runner`. Estimasi dokumen sesuai pengalaman implementasi nyata di repo ini. | ✅ Diverifikasi |
| 5 | Keputusan final Anda beserta alasannya | Lihat tabel di bawah — boleh berbeda dari AI selama berargumen. | ✅ Didokumentasikan |

## Keputusan final

| Kebutuhan | Pilihan final | Alasan teknis |
|---|---|---|
| Preferensi tema & app (dark mode, last opened) | **SharedPreferences** | Data kecil key-value, akses kilat, boilerplate minimal; tidak butuh query/relasi/stream. `PrefsRepository` di `lib/data/prefs.dart` memusatkan seluruh akses key-value. |
| Catatan CRUD (1.000+ catatan, offline-first) | **sqflite (SQLite)** | Butuh query nyata (ORDER BY `updated_at DESC`, `COUNT(*) WHERE dirty=1`), transaksi ACID untuk pola dirty-flag sync, dan skala >1.000 baris. Dipilih juga karena codelab memakai kombinasi ini. |

**Kapan mempertimbangkan alternatif (didokumentasikan, belum diadopsi):**

- **Drift** → bila butuh reaktivitas stream bawaan (`select(notes).watch()`),
  type safety compile-time, web support, atau testing in-memory termudah.
  Migrasi terkontain karena engine tetap SQLite.
- **Hive** → bila aplikasi murni pure-Dart/web dan relasi tidak diperlukan;
  kalah untuk pencarian & relasi (filter dilakukan di Dart, tanpa index).
- **SharedPreferences untuk daftar catatan** → **ditolak** (rapuh untuk koleksi:
  rewrite penuh O(n) tiap simpan, tanpa query, tanpa tipe).

## Catatan implementasi terkait keputusan

- Skema awal `db.dart` dipertahankan (v1) agar cocok dengan codelab; index &
  tabel relasi (notebooks/tags/FTS5) direncanakan di **v2 migration**
  (lihat [storage-comparison.md](storage-comparison.md) §5).
- `loadPostsCacheFirst` yang tadinya error (simbol `Post`, `readCachedPosts`,
  `refreshPostsInBackground` tidak terdefinisi) kini **diimplementasikan penuh**
  di `lib/data/sync.dart` sesuai Refactoring Challenge #2 codelab —
  lihat pembahasan error di [storage-comparison.md](storage-comparison.md) §6.
