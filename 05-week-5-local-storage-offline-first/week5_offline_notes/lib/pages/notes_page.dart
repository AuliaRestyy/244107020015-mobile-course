import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';
import '../data/sync.dart' show syncNotes;
import 'widgets/note_tile.dart';

/// Halaman catatan offline: CRUD penuh tanpa internet, badge dirty,
/// simulasi offline, dan cache-first posts (JSONPlaceholder).
class NotesPage extends ConsumerWidget {
  const NotesPage({super.key});

  Future<void> _sync(BuildContext context, WidgetRef ref) async {
    final offline = ref.read(forceOfflineProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (offline) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Mode offline aktif (simulasi) — sinkronisasi ditunda.',
          ),
        ),
      );
      return;
    }
    final repo = ref.read(noteRepositoryProvider);
    final count = await syncNotes(repo);
    await ref.read(dirtyCountProvider.notifier).refresh();
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          count == 0
              ? 'Tidak ada catatan untuk disinkronkan.'
              : '$count catatan tersinkron. Badge kembali ke 0.',
        ),
      ),
    );
  }

  Future<void> _showEditor(
    BuildContext context,
    WidgetRef ref, {
    int? noteId,
    String initialTitle = '',
    String initialBody = '',
  }) async {
    final titleController = TextEditingController(text: initialTitle);
    final bodyController = TextEditingController(text: initialBody);
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(noteId == null ? 'Catatan baru' : 'Edit catatan'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Judul'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Judul wajib' : null,
              ),
              TextFormField(
                controller: bodyController,
                decoration: const InputDecoration(labelText: 'Isi'),
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (saved != true) return;
    final title = titleController.text.trim();
    final body = bodyController.text;
    final notifier = ref.read(notesProvider.notifier);
    if (noteId == null) {
      await notifier.addNote(title: title, body: body);
    } else {
      await notifier.updateNote(id: noteId, title: title, body: body);
      ref.invalidate(noteProvider(noteId));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider);
    final dirtyCount = ref.watch(dirtyCountProvider).value ?? 0;
    final offline = ref.watch(forceOfflineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan Offline'),
        actions: [
          IconButton(
            tooltip: 'Sinkronkan antrean dirty',
            onPressed: () => _sync(context, ref),
            icon: Badge(
              isLabelVisible: dirtyCount > 0,
              label: Text('$dirtyCount'),
              child: const Icon(Icons.sync),
            ),
          ),
          IconButton(
            tooltip: 'Pengaturan',
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          if (offline)
            Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.wifi_off),
                title: const Text('Mode offline (simulasi) aktif'),
                subtitle: const Text(
                  'Baca/tulis catatan tetap berfungsi penuh; '
                  'sinkronisasi & refresh posts ditunda.',
                ),
              ),
            ),
          Expanded(
            child: notes.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorView(error: error),
              data: (items) => items.isEmpty
                  ? const _EmptyView()
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final note = items[index];
                        return NoteTile(
                          note: note,
                          onTap: () => context.go('/note/${note.id}'),
                          onDelete: () async {
                            await ref
                                .read(notesProvider.notifier)
                                .deleteNote(note.id!);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Catatan dihapus.'),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
            ),
          ),
          const _PostsCacheSection(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditor(context, ref),
        tooltip: 'Catatan baru',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(
              'Gagal memuat catatan:\n$error',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.note_alt_outlined,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          const Text('Belum ada catatan.\nKetuk + untuk menulis.'),
          const SizedBox(height: 8),
          Text(
            'Semua fitur tetap berfungsi dalam mode pesawat.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PostsCacheSection extends ConsumerWidget {
  const _PostsCacheSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(postsProvider);
    return ExpansionTile(
      title: const Text('Cache posts (JSONPlaceholder)'),
      subtitle: const Text('cache-first: tampil tanpa internet'),
      children: [
        posts.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Cache kosong / gagal memuat: $error'),
          ),
          data: (items) => items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Belum ada cache posts.'),
                )
              : Column(
                  children: [
                    for (final post in items.take(5))
                      ListTile(
                        dense: true,
                        leading: CircleAvatar(child: Text('${post.id}')),
                        title: Text(
                          post.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          post.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (items.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text('+${items.length - 5} lainnya di cache'),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
