import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'local/db.dart';
import 'repositories/note_repository.dart';

/// Model ringkas untuk data cache `GET /posts` (JSONPlaceholder, Minggu 4).
class Post {
  const Post({required this.id, required this.title, required this.body});

  final int id;
  final String title;
  final String body;

  Map<String, Object?> toCacheMap() => {
        'id': id,
        'payload': jsonEncode({'title': title, 'body': body}),
        'cached_at': DateTime.now().toUtc().toIso8601String(),
      };

  factory Post.fromCacheMap(Map<String, Object?> map) {
    Object? decoded;
    try {
      decoded = jsonDecode(map['payload'] as String? ?? '{}');
    } catch (_) {
      decoded = null;
    }
    final payload = decoded is Map ? decoded : const <String, Object?>{};
    return Post(
      id: (map['id'] as num?)?.toInt() ?? 0,
      title: payload['title'] as String? ?? '',
      body: payload['body'] as String? ?? '',
    );
  }
}

/// Cache-first read (codelab §Offline-first, mekanisme 1):
/// 1. Baca cache lebih dulu → UI tidak blank saat offline.
/// 2. Di background: refresh dari jaringan → simpan ke `cached_posts` →
///    panggil [onRefreshed] agar provider memuat ulang cache yang sudah segar.
///
/// [skipNetwork] dipakai toggle `forceOffline` untuk simulasi offline
/// yang deterministik (demo & testing, bukan tergantung Wi-Fi kelas).
Future<List<Post>> loadPostsCacheFirst({
  Dio? dio,
  bool skipNetwork = false,
  void Function()? onRefreshed,
}) async {
  final cached = await readCachedPosts();
  if (!skipNetwork) {
    unawaited(_safeRefreshPostsInBackground(dio: dio, onRefreshed: onRefreshed));
  }
  return cached;
}

Future<void> _safeRefreshPostsInBackground({
  Dio? dio,
  void Function()? onRefreshed,
}) async {
  try {
    await refreshPostsInBackground(dio: dio, onRefreshed: onRefreshed);
  } catch (error) {
    // Offline-first: kegagalan jaringan tidak boleh menggagalkan UI.
    // Cache yang ada tetap menjadi sumber data sampai jaringan kembali.
    debugPrintIfDebug(error);
  }
}

/// Baca seluruh isi tabel `cached_posts` (urut id agar stabil).
Future<List<Post>> readCachedPosts() async {
  final db = await openNotesDb();
  final rows = await db.query('cached_posts', orderBy: 'id ASC');
  return rows.map(Post.fromCacheMap).toList();
}

/// Ambil POST /posts dari JSONPlaceholder, tulis ke `cached_posts`.
/// [onRefreshed] hanya dipanggil bila payload BENAR-BENAR berubah —
/// ini mencegah invalidate loop (rebuild → refresh → sama → berhenti).
Future<void> refreshPostsInBackground({
  Dio? dio,
  void Function()? onRefreshed,
}) async {
  final client =
      dio ?? Dio(BaseOptions(baseUrl: 'https://jsonplaceholder.typicode.com'));
  final response = await client.get<List<dynamic>>(
    '/posts',
    queryParameters: {'_limit': 20},
  );
  final raw = response.data;
  if (raw == null) return;

  final fresh = <Post>[
    for (final item in raw)
      if (item is Map)
        Post(
          id: (item['id'] as num?)?.toInt() ?? 0,
          title: item['title'] as String? ?? '',
          body: item['body'] as String? ?? '',
        ),
  ]..sort((a, b) => a.id.compareTo(b.id));

  final cached = await readCachedPosts();
  if (_samePosts(cached, fresh)) return; // tidak ada perubahan → jangan invalidate

  final db = await openNotesDb();
  await db.transaction((txn) async {
    await txn.delete('cached_posts');
    for (final post in fresh) {
      await txn.insert('cached_posts', post.toCacheMap());
    }
  });
  onRefreshed?.call();
}

bool _samePosts(List<Post> a, List<Post> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id || a[i].title != b[i].title || a[i].body != b[i].body) {
      return false;
    }
  }
  return true;
}

/// Sinkronisasi catatan "kotor" (codelab §Offline-first, mekanisme 2+3):
/// karena codelab belum punya backend tulis, server disimulasikan dengan delay.
/// Yang dinilai mekanismenya: hitung dirty → "upload" → tandai bersih.
Future<int> syncNotes(NoteRepository repo) async {
  final dirtyCount = await repo.countDirty();
  if (dirtyCount == 0) return 0;
  // Simulasi upload: pada project nyata, kirim tiap catatan dirty
  // ke REST API di sini, lalu tandai bersih bila server menjawab 2xx.
  await Future.delayed(const Duration(seconds: 1));
  await repo.markAllSynced();
  return dirtyCount;
}

// Tanpa import flutter agar sync.dart tetap pure Dart (mudah diuji).
void debugPrintIfDebug(Object? error) {
  assert(() {
    // ignore: avoid_print
    print('[sync] background refresh gagal (offline?): $error');
    return true;
  }());
}
