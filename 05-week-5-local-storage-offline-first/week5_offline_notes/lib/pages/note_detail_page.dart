import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';

/// Halaman detail `/note/:id` — membaca dari repository lokal
/// (via noteProvider), bukan dari state halaman list
/// (Refactoring Challenge #3 codelab).
class NoteDetailPage extends ConsumerWidget {
  const NoteDetailPage({super.key, required this.id});

  final int id;

  String _format(DateTime time) {
    final local = time.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, ({
    String title,
    String body,
  }) note) async {
    final titleController = TextEditingController(text: note.title);
    final bodyController = TextEditingController(text: note.body);
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit catatan'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Judul'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Judul wajib' : null,
              ),
              TextFormField(
                controller: bodyController,
                decoration: const InputDecoration(labelText: 'Isi'),
                maxLines: 8,
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
    await ref.read(notesProvider.notifier).updateNote(
          id: id,
          title: titleController.text.trim(),
          body: bodyController.text,
        );
    ref.invalidate(noteProvider(id)); // muat ulang dari repository
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus catatan?'),
        content: const Text('Catatan akan dihapus dari penyimpanan lokal.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(notesProvider.notifier).deleteNote(id);
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteAsync = ref.watch(noteProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: Text('Catatan #$id'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            onPressed: () {
              final note = noteAsync.value;
              if (note == null) return;
              _edit(
                context,
                ref,
                (title: note.title, body: note.body),
              );
            },
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Hapus',
            onPressed: () => _delete(context, ref),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: noteAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Gagal memuat: $error')),
        data: (note) {
          if (note == null) {
            return const Center(child: Text('Catatan tidak ditemukan.'));
          }
          final theme = Theme.of(context);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title.isEmpty ? '(Tanpa judul)' : note.title,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Diperbarui: ${_format(note.updatedAt)}',
                        style: theme.textTheme.bodySmall),
                    const SizedBox(width: 8),
                    if (note.dirty)
                      Chip(
                        label: const Text('Belum tersinkron'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor:
                            theme.colorScheme.tertiaryContainer,
                      ),
                  ],
                ),
                const Divider(height: 32),
                Text(
                  note.body.isEmpty ? '(Tanpa isi)' : note.body,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
