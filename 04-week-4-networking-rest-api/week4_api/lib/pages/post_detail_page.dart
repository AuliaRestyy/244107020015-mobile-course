import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/paged_post.dart';
import '../data/providers.dart';

class PostDetailPage extends ConsumerWidget {
  const PostDetailPage({required this.postId, super.key});

  final int postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(postDetailProvider(postId));
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Post')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(friendlyErrorMessage(error)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(postDetailProvider(postId)),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
        data: (post) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(post.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            Text(post.body, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}