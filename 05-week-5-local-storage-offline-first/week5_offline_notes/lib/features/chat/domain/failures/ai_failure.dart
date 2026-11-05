sealed class AiFailure implements Exception {
  const AiFailure(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// API key belum kosong
final class AiMissingApiKeyFailure extends AiFailure {
  const AiMissingApiKeyFailure([
    super.message = 'API key Gemini belum disimpan.',
  ]);
}

/// API key ditolak
final class AiUnauthorizedFailure extends AiFailure {
  const AiUnauthorizedFailure([
    super.message = 'API key Gemini ditolak atau tidak punya akses.',
  ]);
}

/// Kuota / rate limit terlampaui
final class AiRateLimitedFailure extends AiFailure {
  const AiRateLimitedFailure([
    super.message = 'Kuota AI sedang penuh (rate limit).',
  ]);
}

/// Kegagalan di sisi server Gemini
final class AiServerErrorFailure extends AiFailure {
  const AiServerErrorFailure([super.message = 'Server AI sedang bermasalah.']);
}

/// Koneksi terputus
final class AiNetworkFailure extends AiFailure {
  const AiNetworkFailure([
    super.message = 'Tidak dapat menghubungi layanan AI.',
  ]);
}

/// Permintaan melebihi batas waktu
final class AiTimeoutFailure extends AiFailure {
  const AiTimeoutFailure([
    super.message = 'Permintaan ke AI melebihi batas waktu.',
  ]);
}

/// Server membalas tanpa teks jawaban
final class AiEmptyResponseFailure extends AiFailure {
  const AiEmptyResponseFailure([
    super.message = 'AI tidak mengirim jawaban (kosong).',
  ]);
}

/// Input dari pengguna tidak valid
final class AiInvalidInputFailure extends AiFailure {
  const AiInvalidInputFailure(super.message);
}
