import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';

export '../data/providers.dart'
    show prefsRepositoryProvider, darkModeProvider, DarkModeNotifier;

/// Halaman pengaturan: tema gelap/terang (SharedPreferences),
/// waktu terakhir dibuka, dan toggle offline deterministik.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  String _formatLastOpened(String? iso) {
    if (iso == null) return 'Belum pernah dibuka';
    final parsed = DateTime.tryParse(iso)?.toLocal();
    if (parsed == null) return iso;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${parsed.year}-${two(parsed.month)}-${two(parsed.day)} '
        '${two(parsed.hour)}:${two(parsed.minute)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkAsync = ref.watch(darkModeProvider);
    final lastOpened = ref.watch(lastOpenedProvider);
    final forceOffline = ref.watch(forceOfflineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Mode gelap'),
            subtitle: const Text('Disimpan di SharedPreferences'),
            value: darkAsync.value ?? false,
            onChanged: darkAsync.isLoading
                ? null
                : (_) => ref.read(darkModeProvider.notifier).toggle(),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Terakhir dibuka'),
            subtitle: Text(
              lastOpened.when(
                loading: () => '…',
                error: (_, _) => 'Tidak tersedia',
                data: _formatLastOpened,
              ),
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Mode offline (simulasi)'),
            subtitle: const Text(
              'Matikan jaringan aplikasi secara deterministik: '
              'refresh posts & sinkronisasi ditunda, '
              'baca/tulis catatan tetap berfungsi.',
            ),
            value: forceOffline,
            onChanged: (_) =>
                ref.read(forceOfflineProvider.notifier).toggle(),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Aplikasi ini offline-first: semua catatan tersimpan di SQLite '
              'lokal (sqflite) dan tetap dapat dibaca/ditulis tanpa internet.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
