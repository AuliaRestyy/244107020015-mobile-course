import 'package:flutter/material.dart';
import '../../../../core/format.dart';
import '../../domain/entities/note.dart';

class NoteTile extends StatelessWidget {
  const NoteTile({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: onTap,
        title: Text(
          note.title.isEmpty ? '(Tanpa judul)' : note.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              note.body.isEmpty ? '(Tanpa isi)' : note.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            _NoteMeta(updatedAt: note.updatedAt, dirty: note.dirty),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Hapus catatan',
          onPressed: onDelete,
        ),
      ),
    );
  }
}

class _NoteMeta extends StatelessWidget {
  const _NoteMeta({required this.updatedAt, required this.dirty});

  final DateTime updatedAt;
  final bool dirty;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    if (!dirty) {
      // Kasus mayoritas: satu Text saja, tanpa Row/Container.
      return Text(formatDateTime(updatedAt), style: style);
    }
    return Row(
      children: [
        Text(formatDateTime(updatedAt), style: style),
        const SizedBox(width: 8),
        const _SyncBadge(),
      ],
    );
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('Belum tersinkron', style: theme.textTheme.labelSmall),
    );
  }
}