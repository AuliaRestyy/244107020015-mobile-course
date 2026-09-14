// =============================================================================
// StatsPage — A Flutter page demonstrating async state management with Riverpod
// =============================================================================
//
// This file contains:
//   1. StatItem       — A simple data model representing one statistic.
//   2. StatsNotifier   — An AsyncNotifier that simulates fetching stats from
//                        a remote API (2-second delay, ~30 % failure rate).
//   3. StatsPage       — A ConsumerWidget that reactively listens to the
//                        notifier and renders loading / error / success UI.
//
// Key Riverpod concepts demonstrated:
//   • AsyncNotifierProvider   — owns and exposes an AsyncValue<List<StatItem>>
//   • ref.invalidate()       — triggers a manual re-fetch (retry)
//   • AsyncValue pattern-matching (.loading / .error / .value)
// =============================================================================

import 'dart:math'; // Used for the simulated random failure.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// =============================================================================
// 1. Data Model — StatItem
// =============================================================================

/// A lightweight model that holds a single statistic.
///
/// In a real app this might be deserialised from JSON returned by a REST API.
/// For this demo we hard-code three items after a simulated delay.
class StatItem {
  final String title; // e.g. "Total Users"
  final String value; // e.g. "12,345"
  final IconData icon; // Visual cue for the stat.

  const StatItem({
    required this.title,
    required this.value,
    required this.icon,
  });
}

// =============================================================================
// 2. State Management — StatsNotifier (AsyncNotifier)
// =============================================================================

/// The core piece of state management for this page.
///
/// `AsyncNotifier` is the modern Riverpod 2.x way to manage *asynchronous*
/// state. Under the hood it wraps the data in an `AsyncValue<T>` which can
/// be in one of three states:
///   • `AsyncLoading`  — the future is still running
///   • `AsyncError`    — the future threw / returned an error
///   • `AsyncData`     — the future completed successfully
///
/// We extend `AsyncNotifier<List<StatItem>>` so the managed state is a list
/// of stat items.
class StatsNotifier extends AsyncNotifier<List<StatItem>> {
  // ---------------------------------------------------------------------------
  // build() replaces the old `autoDispose` future-provider approach.
  // It is called once when the provider is first read and returns the initial
  // future that populates the `AsyncValue`.
  // ---------------------------------------------------------------------------
  @override
  Future<List<StatItem>> build() => _fetchStats();

  // ---------------------------------------------------------------------------
  // _fetchStats — Simulated network call
  // ---------------------------------------------------------------------------
  // • Awaits for 2 seconds to mimic real latency.
  // • Has a 30 % chance of throwing so we can exercise the error path.
  // • Returns three hard-coded StatItem objects on success.
  //
  // In production you would replace the body with a real HTTP call.
  // ---------------------------------------------------------------------------
  Future<List<StatItem>> _fetchStats() async {
    // Simulate network latency.
    await Future<void>.delayed(const Duration(seconds: 2));

    // 30 % failure rate — throw a descriptive error that the UI will display.
    if (Random().nextDouble() < 0.3) {
      throw Exception('Failed to load statistics. Please try again.');
    }

    // Successful response — return dummy data.
    return const [
      StatItem(title: 'Total Users', value: '12,345', icon: Icons.people),
      StatItem(title: 'Revenue', value: r'$89,432', icon: Icons.attach_money),
      StatItem(title: 'Orders', value: '1,023', icon: Icons.shopping_cart),
    ];
  }

  // ---------------------------------------------------------------------------
  // refresh() — Public method the UI can call to retry.
  // ---------------------------------------------------------------------------
  // `ref.invalidate(provider)` marks the provider as stale, causing Riverpod
  // to re-run `build()` and re-fetch the data. This is the idiomatic way to
  // implement a "retry" button.
  // ---------------------------------------------------------------------------
  void refresh() {
    // `this` here refers to the provider itself — invalidate triggers a
    // rebuild of the AsyncNotifier and re-runs `build()`.
    ref.invalidateSelf();
  }
}

// =============================================================================
// 3. Provider declaration
// =============================================================================

/// Exposes [StatsNotifier] to the widget tree.
///
/// Because this provider is *not* autoDispose, the cached state survives
/// hot-reloads and navigator pushes. For a truly ephemeral page you could
/// use `autoDispose` variant instead.
final statsProvider =
    AsyncNotifierProvider<StatsNotifier, List<StatItem>>(StatsNotifier.new);

// =============================================================================
// 4. UI — StatsPage (ConsumerWidget)
// =============================================================================

/// A ConsumerWidget is a Widget that has access to a [WidgetRef] so it can
/// *watch* (reactively listen to) providers.
///
/// Contrast this with a plain `StatefulWidget` — we don't need `initState` or
/// `setState` because Riverpod handles all state transitions for us.
class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ---------------------------------------------------------------------------
    // ref.watch(statsProvider) returns the current `AsyncValue<List<StatItem>>`.
    //
    // Because we're watching, this widget will automatically rebuild whenever
    // the provider's state changes (loading → error → data, or on retry).
    // ---------------------------------------------------------------------------
    final statsAsync = ref.watch(statsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        actions: [
          // Retry button — always visible so the user can re-trigger a fetch.
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // `ref.read` gives us access to the notifier *instance* so we
              // can call its `refresh()` method, which invalidates the provider
              // and causes a fresh fetch.
              ref.read(statsProvider.notifier).refresh();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),

      // ---------------------------------------------------------------------------
      // AsyncValue pattern-matching — the cleanest way to handle all three
      // states (loading, error, data) in a single expression.
      // ---------------------------------------------------------------------------
      body: statsAsync.when(
        // ---- LOADING STATE ---------------------------------------------------
        // Show a centered spinner while the future is in progress.
        loading: () => const Center(child: CircularProgressIndicator()),

        // ---- ERROR STATE -----------------------------------------------------
        // Display the error message along with a dedicated retry button.
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  error.toString(), // Show the exception message to the user.
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    // Retry — same invalidate logic as the AppBar button.
                    ref.read(statsProvider.notifier).refresh();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),

        // ---- SUCCESS / DATA STATE --------------------------------------------
        // Render the list of stat items inside a ListView.
        // `.value` unwraps the `AsyncData` and gives us `List<StatItem>`.
        data: (stats) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: stats.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (context, index) {
            final item = stats[index];
            return ListTile(
              leading: CircleAvatar(child: Icon(item.icon)),
              title: Text(item.title),
              trailing: Text(
                item.value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
