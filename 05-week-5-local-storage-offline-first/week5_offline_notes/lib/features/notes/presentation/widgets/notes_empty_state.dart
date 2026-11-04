import 'package:flutter/material.dart';

class NotesEmptyState extends StatelessWidget {
  const NotesEmptyState({super.key, this.query = ''});

  final String query;

  bool get _isSearchMiss => query.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isSearchMiss) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                'Tidak ada catatan yang cocok dengan "${query.trim()}".',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Coba kata kunci lain atau kosongkan kolom pencarian.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.note_alt_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          const Text('Belum ada catatan.\nKetuk + untuk menulis.'),
          const SizedBox(height: 8),
          Text(
            'Semua fitur tetap berfungsi dalam mode pesawat.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
