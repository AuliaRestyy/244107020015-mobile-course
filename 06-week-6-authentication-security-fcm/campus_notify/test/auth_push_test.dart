import 'package:flutter_test/flutter_test.dart';

import 'package:campus_notify/data/auth_repository.dart';
import 'package:campus_notify/routes.dart';

void main() {
  group('routeFromMessage (parsing deep link, tanpa Firebase)', () {
    test('route kosong diarahkan ke beranda', () {
      expect(routeFromMessage({}), Routes.home);
    });

    test('route tanpa slash depan ditambahkan', () {
      expect(routeFromMessage({'route': 'pengumuman/3'}), '/pengumuman/3');
    });

    test('route absolut dipertahankan', () {
      expect(routeFromMessage({'route': '/pengumuman/3'}), '/pengumuman/3');
    });

    test('data payload membawa id pengumuman', () {
      const data = {'route': '/pengumuman/3', 'id': '3'};
      expect(data['id'], '3');
      expect(routeFromMessage(data), Routes.announcementPath('3'));
    });
  });

  group('AuthRepository (logika sesi, tanpa Firebase)', () {
    test('login valid mengembalikan access + refresh', () async {
      final session = await AuthRepository().login(
        email: 'mahasiswa@polinema.ac.id',
        password: 'rahasia123',
      );
      expect(session.access, isNotEmpty);
      expect(session.refresh, isNotEmpty);
    });

    test('login tidak valid ditolak', () async {
      final auth = AuthRepository();
      expect(
        () => auth.login(email: 'bukan-email', password: 'rahasia123'),
        throwsA(isA<Exception>()),
      );
      expect(
        () => auth.login(email: 'a@b.c', password: '123'),
        throwsA(isA<Exception>()),
      );
    });

    test('refresh token kosong ditolak (paksa login ulang)', () async {
      expect(
        () => AuthRepository().refresh(''),
        throwsA(isA<Exception>()),
      );
    });

    test('refresh valid menerbitkan access baru', () async {
      final renewed = await AuthRepository().refresh('mock-refresh');
      expect(renewed, isNotEmpty);
    });
  });
}
