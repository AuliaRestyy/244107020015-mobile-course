import 'package:dio/dio.dart';

String friendlyApiError(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return 'Koneksi ke server habis waktu. Coba lagi.';
      case DioExceptionType.connectionError:
        return 'Tidak dapat terhubung. Periksa koneksi internet Anda.';
      case DioExceptionType.badCertificate:
        return 'Sertifikat server tidak valid.';
      case DioExceptionType.cancel:
        return 'Permintaan dibatalkan.';
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        if (status == null) return 'Permintaan gagal tanpa kode status.';
        return switch (status) {
          401 => 'Sesi berakhir. Silakan masuk ulang.',
          403 => 'Anda tidak punya akses ke sumber ini.',
          404 => 'Data yang diminta tidak ditemukan.',
          >= 500 => 'Server sedang bermasalah. Coba beberapa saat lagi.',
          _ => 'Permintaan gagal (kode $status).',
        };
      case DioExceptionType.unknown:
        return 'Terjadi kesalahan jaringan.';
    }
  }

  final message = error.toString().replaceFirst(RegExp(r'^\w*Exception: '), '');
  return message.isEmpty ? 'Terjadi kesalahan tak terduga.' : message;
}
