import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'pages/note_detail_page.dart';
import 'pages/notes_page.dart';
import 'pages/settings_page.dart';

void main() {
  // Plugin sqflite asli tidak tersedia di web, sehingga `databaseFactory`
  // kosong (error "databaseFactory not initialized"). Pakai implementasi
  // SQLite via WebAssembly (IndexedDB) dari sqflite_common_ffi_web;
  // di Android/iOS tetap pakai plugin sqflite bawaan.
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }
  runApp(const ProviderScope(child: MyApp()));
}

/// Routing: `/` daftar, `/note/:id` detail (baca dari repository lokal),
/// `/settings` preferensi.
final _appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const NotesPage()),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/note/:id',
      builder: (context, state) =>
          NoteDetailPage(id: int.parse(state.pathParameters['id']!)),
    ),
  ],
);

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // Catat waktu terakhir dibuka (SharedPreferences) setelah frame pertama.
    Future.microtask(
      () => ref.read(prefsRepositoryProvider).markOpenedNow(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Selama load (atau error), pakai tema terang sebagai default aman.
    final darkMode = ref.watch(darkModeProvider).value ?? false;

    return MaterialApp.router(
      title: 'Offline Notes',
      routerConfig: _appRouter,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
    );
  }
}
