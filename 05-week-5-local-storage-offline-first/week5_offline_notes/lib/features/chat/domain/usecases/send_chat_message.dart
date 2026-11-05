import '../entities/chat_message.dart';
import '../failures/ai_failure.dart';
import '../repositories/ai_repository.dart';

class SendChatMessage {
  const SendChatMessage(this._repository);

  final AiRepository _repository;
  static const int maxLength = 500;

  static const String systemPrompt =
      'Kamu adalah asisten AI yang ramah dan membantu, selalu menjawab dalam '
      'bahasa indonesia yang santai dan mudah dipahami. Jawablah secara '
      'singkat, langsung ke inti, maksimal beberapa kalimat. Jangan pernah '
      'meminta, menanyakan, menyebut, atau menyimpan data pribadi pengguna '
      'seperti nama lengkap, alamat, nomor telepon, email, NIM, lokasi, atau '
      'kata sandi. Jika pengguna sendiri mengirim data pribadi, ingatkan '
      'dengan sopan agar tidak membagikan data tersebut. Jangan membahas isi '
      'catatan pribadi pengguna.';

  Stream<String> call({
    required String message,
    List<ChatMessage> history = const [],
  }) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return Stream.error(
        const AiInvalidInputFailure('Pesan tidak boleh kosong.'),
      );
    }
    if (trimmed.length > maxLength) {
      return Stream.error(
        const AiInvalidInputFailure(
          'Pesan terlalu panjang (maksimal $maxLength karakter).',
        ),
      );
    }

    final payload = <ChatMessage>[
      const ChatMessage(role: ChatRole.system, text: systemPrompt),
      ...history,
      ChatMessage(role: ChatRole.user, text: trimmed),
    ];
    return _repository.sendMessage(payload);
  }
}
