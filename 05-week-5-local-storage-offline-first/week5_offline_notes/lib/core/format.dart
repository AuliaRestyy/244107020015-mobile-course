library;

String formatDateTime(DateTime time) {
  final local = time.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String formatIsoLabel(String? iso) {
  if (iso == null) return 'Belum pernah dibuka';
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  return formatDateTime(parsed);
}

int? parseNoteId(String? raw) {
  final id = int.tryParse(raw ?? '');
  if (id == null || id < 1) return null;
  return id;
}
