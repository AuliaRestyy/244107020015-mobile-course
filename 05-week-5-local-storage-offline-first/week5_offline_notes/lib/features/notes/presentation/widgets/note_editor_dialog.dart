import 'package:flutter/material.dart';

class NoteEditorResult {
  const NoteEditorResult({required this.title, required this.body});

  final String title;
  final String body;
}

class NoteEditorDialog extends StatefulWidget {
  const NoteEditorDialog({
    super.key,
    this.initialTitle = '',
    this.initialBody = '',
    this.isEditing = false,
    this.bodyMaxLines = 4,
    this.autofocusTitle = true,
  });

  final String initialTitle;
  final String initialBody;
  final bool isEditing;
  final int bodyMaxLines;
  final bool autofocusTitle;

  @override
  State<NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<NoteEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _bodyController = TextEditingController(text: widget.initialBody);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      NoteEditorResult(
        title: _titleController.text.trim(),
        body: _bodyController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEditing ? 'Edit catatan' : 'Catatan baru'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const ValueKey('note-title-field'),
              controller: _titleController,
              autofocus: widget.autofocusTitle,
              decoration: const InputDecoration(labelText: 'Judul'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Judul wajib'
                  : null,
            ),
            TextFormField(
              controller: _bodyController,
              decoration: const InputDecoration(labelText: 'Isi'),
              maxLines: widget.bodyMaxLines,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          key: const ValueKey('note-save-button'),
          onPressed: _submit,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

Future<NoteEditorResult?> showNoteEditorDialog(
  BuildContext context, {
  String initialTitle = '',
  String initialBody = '',
  bool isEditing = false,
  int bodyMaxLines = 4,
  bool autofocusTitle = true,
}) {
  return showDialog<NoteEditorResult>(
    context: context,
    builder: (dialogContext) => NoteEditorDialog(
      initialTitle: initialTitle,
      initialBody: initialBody,
      isEditing: isEditing,
      bodyMaxLines: bodyMaxLines,
      autofocusTitle: autofocusTitle,
    ),
  );
}