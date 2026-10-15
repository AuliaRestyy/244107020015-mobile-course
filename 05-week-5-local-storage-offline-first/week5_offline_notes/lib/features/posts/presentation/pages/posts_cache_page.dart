import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers.dart';
import '../../../../routes.dart';
import '../providers/posts_providers.dart';

class PostsCachePage extends ConsumerWidget {
  const PostsCachePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(postsProvider);
    final offline = ref.watch(forceOfflineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cache Posts'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.notes),
        ),
      ),
      body: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.cloud_download_outlined),
            title: Text('Cache-first (JSONPlaceholder)'),
            subtitle: Text('Tampil dari cache lokal tanpa internet'),
          ),
          if (offline)
            Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: const ListTile(
                leading: Icon(Icons.wifi_off),
                title: Text('Mode offline (simulasi) aktif'),
                subtitle: Text('Refresh cache dari jaringan ditunda.'),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: posts.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Cache kosong / gagal memuat:\n$error',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (items) => items.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Belum ada cache posts.'),
                      ),
                    )
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final post = items[index];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(child: Text('${post.id}')),
                          title: Text(
                            post.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            post.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
