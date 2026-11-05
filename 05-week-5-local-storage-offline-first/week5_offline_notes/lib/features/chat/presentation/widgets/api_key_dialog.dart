import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';

Future<void> showApiKeyDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const ApiKeyDialog());

class ApiKeyDialog extends ConsumerStatefulWidget {
  const ApiKeyDialog({super.key});

  @override
  ConsumerState<ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends ConsumerState<ApiKeyDialog> {
  final _controller = TextEditingController();
  bool _hasStoredKey = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final key = await ref.read(apiKeyStoreProvider).readKey();
    if (!mounted) return;
    setState(() => _hasStoredKey = key != null && key.isNotEmpty);
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty || _saving) return;
    setState(() => _saving = true);
    await ref.read(apiKeyStoreProvider).saveKey(value);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _clear() async {
    await ref.read(apiKeyStoreProvider).clearKey();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _controller.text.trim().isNotEmpty && !_saving;

    return AlertDialog(
      title: const Text('API key Gemini'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _hasStoredKey
                ? 'Sudah ada API key tersimpan. Masukkan kunci baru untuk '
                      'menggantinya.'
                : 'Belum ada API key tersimpan. Kunci dari Google AI Studio '
                      'disimpan di secure storage perangkat.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'API key',
              hintText: 'Tempel kunci di sini',
            ),
          ),
        ],
      ),
      actions: [
        if (_hasStoredKey)
          TextButton(
            onPressed: _saving ? null : _clear,
            child: const Text('Hapus kunci'),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: canSave ? _save : null,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
