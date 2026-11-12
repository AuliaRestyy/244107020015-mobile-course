# Temuan Performa - Week 11

## 1. Baseline

| Metrik | Run 1 | Run 2 | Run 3 | **Median** |
|---|---:|---:|---:|---:|
| UI build avg | 33,44 ms | 37,50 ms | 33,87 ms | **33,87 ms** |
| UI p90 | 50,95 ms | 72,70 ms | 54,21 ms | **54,21 ms** |
| UI max | 456,23 ms | 420,48 ms | 384,37 ms | **420,48 ms** |
| Raster avg | 6,27 ms | 7,40 ms | 6,70 ms | **6,70 ms** |
| Raster max | 16,05 ms | 24,31 ms | 15,61 ms | **16,05 ms** |
| Hijau | 47 | 32 | 37 | **37** |
| Kuning | 49 | 50 | 59 | **50** |
| Merah | 63 | 77 | 62 | **63** |

Total median mencapai 158 frame, dengan 63 frame (40%) berstatus merah. Hanya 23% frame yang memenuhi batas 16,67 ms. Raster rata-rata 6,70 ms menunjukkan bahwa bottleneck utama berada di UI thread, bukan GPU.

## 2. Temuan

### 1. Biaya build dan paint tile saat scroll

Saat scroll, UI membutuhkan rata-rata 28,2 ms per frame dan menghasilkan 48 frame merah dari total 63 frame merah. Penyebabnya adalah struktur tile yang cukup kompleks dan penggunaan beberapa provider yang dapat memicu rebuild halaman. Jumlah 128 build tile masih tergolong normal karena ListView.builder menggunakan lazy loading. Penambahan RepaintBoundary manual dan caching format tanggal juga tidak diperlukan karena keduanya bukan sumber masalah utama.

### 2. Seluruh halaman rebuild setiap kali mengetik

Saat mencari kata belanja, NotesPage.build berjalan 8 kali untuk 7 karakter yang diketik. Masalahnya bukan pada proses pencarian, karena filter hanya membutuhkan sekitar 96–99 µs untuk 1.200 catatan. Setiap ketikan justru memicu rebuild seluruh halaman, termasuk AppBar, tombol, kolom pencarian, dan ListView. Solusinya adalah mempersempit area rebuild, bukan hanya menambahkan debounce.

### 3. Stall saat kembali dari halaman detail

Saat kembali ke halaman daftar, UI membutuhkan rata-rata 212,1 ms dan mencapai 420,5 ms pada satu frame. Hal ini terjadi karena NotesPage dan daftar catatan dibangun ulang dari awal. Temuan ini belum dioptimasi karena membutuhkan perubahan arsitektur agar state daftar dapat digunakan kembali.

### 4. Parsing ulang tanggal setiap fetch

Setiap fetch membaca 1.200 baris dan membutuhkan sekitar 37 ms untuk proses parsing tanggal. Biaya terbesar berasal dari konversi string ISO-8601 menjadi DateTime. Proses ini dilakukan berulang kali meskipun sebagian besar data tidak berubah. Saat refresh, daftar juga diganti dengan AsyncLoading sehingga perlu dibangun ulang.

### 5. Controller tidak di-dispose setelah dialog ditutup

Jumlah TextEditingController terus bertambah dari 1 hingga 10 setelah dialog editor dibuka sebanyak 10 kali. Jumlah tersebut tidak berkurang meskipun garbage collection sudah dijalankan, sementara heap meningkat 1,67 MB. Penyebabnya adalah controller dibuat di dalam method dan tidak di-dispose setelah dialog ditutup.

### 6. Belum ada cache pembacaan data

Setiap fetchNotes selalu menjalankan query database secara penuh. Optimasi ini belum dilakukan karena perbaikan pada parsing tanggal sudah mengurangi biaya di jalur yang sama. Penambahan cache juga berisiko membuat data yang ditampilkan tidak sesuai dengan kondisi terbaru.

## 3. Peringkat Dampak

| # | Temuan | Bukti utama | Status |
|---|---|---|---|
| 1 | Biaya build dan paint tile saat scroll | 48 frame merah | Dioptimasi |
| 2 | Rebuild seluruh halaman saat mengetik | 8 rebuild untuk 7 ketikan | Dioptimasi |
| 3 | Stall saat kembali dari detail | Frame mencapai 420,5 ms | Belum |
| 4 | Parsing ulang tanggal | Sekitar 37 ms per fetch | Dioptimasi |
| 5 | Controller tidak di-dispose | Jumlah controller meningkat 1–10 | Dioptimasi |
| 6 | Belum ada cache pembacaan | Query database selalu dijalankan ulang | Belum |