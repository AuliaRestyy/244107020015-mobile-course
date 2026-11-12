import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers.dart';
import '../../../../routes.dart';
import '../providers/notes_providers.dart';
import '../widgets/note_editor_dialog.dart';
import '../widgets/note_tile.dart';
import '../widgets/notes_empty_state.dart';
import '../widgets/notes_search_field.dart';

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
    final result = await ref.read(notesProvider.notifier).syncNotes();
    if (!context.mounted) return;
    final failure = result.failure;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failure != null
              ? 'Sinkronisasi gagal: ${failure.message}'
              : result.synced == 0
              ? 'Tidak ada catatan untuk disinkronkan.'
              : '${result.synced} catatan tersinkron. Badge kembali ke 0.',
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
    final edited = await showNoteEditorDialog(
      context,
      initialTitle: initialTitle,
      initialBody: initialBody,
      isEditing: noteId != null,
    );
    if (edited == null) return;

    final notifier = ref.read(notesProvider.notifier);
    if (noteId == null) {
      await notifier.addNote(title: edited.title, body: edited.body);
    } else {
      await notifier.updateNote(
        id: noteId,
        title: edited.title,
        body: edited.body,
      );
      ref.invalidate(noteProvider(noteId));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan Offline'),
        actions: [
          _SyncBadgeButton(onPressed: () => _sync(context, ref)),
          IconButton(
            tooltip: 'Chat AI',
            onPressed: () => context.go(AppRoutes.chat),
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          IconButton(
            tooltip: 'Cache posts',
            onPressed: () => context.go(AppRoutes.postsCache),
            icon: const Icon(Icons.cloud_outlined),
          ),
          IconButton(
            tooltip: 'Pengaturan',
            onPressed: () => context.go(AppRoutes.settings),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          const _OfflineBanner(),
          const NotesSearchField(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () {
                return ref.read(notesProvider.notifier).refresh();
              },
              child: const _NotesListSection(),
            ),
          ),
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

class _SyncBadgeButton extends ConsumerWidget {
  const _SyncBadgeButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dirtyCount = ref.watch(
      dirtyCountProvider.select((value) => value.value ?? 0),
    );
    return IconButton(
      tooltip: 'Sinkronkan antrean dirty',
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: dirtyCount > 0,
        label: Text('$dirtyCount'),
        child: const Icon(Icons.sync),
      ),
    );
  }
}

class _OfflineBanner extends ConsumerWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(forceOfflineProvider);
    if (!offline) return const SizedBox.shrink();
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: const ListTile(
        leading: Icon(Icons.wifi_off),
        title: Text('Mode offline (simulasi) aktif'),
        subtitle: Text(
          'Baca/tulis catatan tetap berfungsi penuh; '
          'sinkronisasi & refresh posts ditunda.',
        ),
      ),
    );
  }
}

class _NotesListSection extends ConsumerWidget {
  const _NotesListSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(filteredNotesProvider);

    return notes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorView(error: error),
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyStateSection();
        }
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          addAutomaticKeepAlives: false,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final note = items[index];
            return NoteTile(
              key: ValueKey(note.id),
              note: note,
              onTap: () => context.go(AppRoutes.noteDetail(note.id!)),
              onDelete: () async {
                await ref.read(notesProvider.notifier).deleteNote(note.id!);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Catatan dihapus.')),
                  );
                }
              },
            );
          },
        );
      },
    );
  }
}

class _EmptyStateSection extends ConsumerWidget {
  const _EmptyStateSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider.select((q) => q.trim()));
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: NotesEmptyState(query: query),
        ),
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
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text('Gagal memuat catatan:\n$error', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}