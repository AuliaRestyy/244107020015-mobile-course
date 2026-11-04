import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/notes_providers.dart';

class NotesSearchField extends ConsumerStatefulWidget {
  const NotesSearchField({super.key});

  @override
  ConsumerState<NotesSearchField> createState() => _NotesSearchFieldState();
}

class _NotesSearchFieldState extends ConsumerState<NotesSearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    ref.read(searchQueryProvider.notifier).setQuery(value);
    setState(() {});
  }

  void _clear() {
    _controller.clear();
    _onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: TextField(
        controller: _controller,
        onChanged: _onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Cari judul catatan',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Kosongkan pencarian',
                  onPressed: _clear,
                  icon: const Icon(Icons.clear),
                ),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
