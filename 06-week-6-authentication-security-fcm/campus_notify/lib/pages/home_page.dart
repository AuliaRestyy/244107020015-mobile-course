import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../messaging/push_service.dart';
import '../providers/auth_provider.dart';
import '../routes.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Notify'),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            onPressed: () => ref.read(authStateProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Debug',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<String?>(
                    valueListenable: fcmToken,
                    builder: (_, token, _) =>
                        SelectableText('FCM token: ${truncateToken(token)}'),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Token sengaja ditampilkan 12 karakter pertama saja.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => context.go(Routes.announcementPath('3')),
            child: const Text('Buka /pengumuman/3 (uji deep link)'),
          ),
        ],
      ),
    );
  }
}

String truncateToken(String? token) {
  if (token == null || token.isEmpty) return '(belum ada token)';
  return token.length <= 12 ? token : '${token.substring(0, 12)}...';
}
