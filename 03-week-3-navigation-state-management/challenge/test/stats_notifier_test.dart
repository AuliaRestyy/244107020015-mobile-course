// =============================================================================
// stats_notifier_test.dart — Unit tests for StatsNotifier
// =============================================================================
//
// We test three scenarios:
//   1. Initial loading state
//   2. Successful fetch returns the expected StatItem list
//   3. Refresh (retry) triggers a new fetch
//
// Because StatsNotifier uses `Random()` internally with a 30 % failure rate,
// the success/error outcome is non-deterministic. To make the tests reliable
// we override the provider with a **deterministic** notifier subclass that
// lets us control whether the next fetch succeeds or fails.
//
// Key Riverpod testing concepts demonstrated:
//   • ProviderContainer — an isolated container for testing providers without
//     needing a full Flutter widget tree.
//   • provider.overrideWithProvider / overrideWithValue — replace the real
//     implementation with a test double.
//   • container.read(provider.future) — await the underlying future.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Import the notifier and model we want to test.
import 'package:challenge/stats_page.dart';

// =============================================================================
// Test helpers — Deterministic notifier overrides
// =============================================================================

/// A fake StatsNotifier that always returns successful data.
///
/// By extending the real StatsNotifier we keep the same type signature, but
/// we override `_fetchStats` to skip the random failure logic entirely.
class _FakeSuccessNotifier extends StatsNotifier {
  @override
  Future<List<StatItem>> build() async {
    // Directly return the expected data — no delay, no randomness.
    return const [
      StatItem(title: 'Total Users', value: '12,345', icon: Icons.people),
      StatItem(title: 'Revenue', value: r'$89,432', icon: Icons.attach_money),
      StatItem(title: 'Orders', value: '1,023', icon: Icons.shopping_cart),
    ];
  }
}

/// A fake StatsNotifier that always throws an error.
class _FakeErrorNotifier extends StatsNotifier {
  @override
  Future<List<StatItem>> build() async {
    throw Exception('Simulated network error');
  }
}

// =============================================================================
// Test suite
// =============================================================================

void main() {
  // ---------------------------------------------------------------------------
  // Test 1 — Initial state is loading
  // ---------------------------------------------------------------------------
  // When a provider is first read, its AsyncValue starts as AsyncLoading.
  // We verify this by reading the provider immediately after creating the
  // container, before the future has had a chance to complete.
  // ---------------------------------------------------------------------------
  test('initial state is loading', () {
    // ProviderContainer is Riverpod's test harness. It creates an isolated
    // scope so tests don't leak state into each other.
    final container = ProviderContainer();

    // Reading the provider for the first time returns AsyncLoading because
    // the future is still in flight (we haven't called `await` yet).
    final state = container.read(statsProvider);

    // AsyncLoading is a subtype of AsyncValue — it represents "in progress".
    expect(state, isA<AsyncLoading<List<StatItem>>>());
  });

  // ---------------------------------------------------------------------------
  // Test 2 — Successful fetch returns expected data
  // ---------------------------------------------------------------------------
  // We override the real provider with our _FakeSuccessNotifier so the test
  // is deterministic and fast (no real 2-second delay).
  // ---------------------------------------------------------------------------
  test('successful fetch returns list of 3 stat items', () async {
    final container = ProviderContainer(
      overrides: [
        // Replace the real StatsNotifier with our fake that always succeeds.
        statsProvider.overrideWith(() => _FakeSuccessNotifier()),
      ],
    );

    // container.read(statsProvider.future) returns the underlying Future.
    // Awaiting it lets the notifier complete its `build()` method.
    final stats = await container.read(statsProvider.future);

    // We should receive exactly 3 StatItem objects.
    expect(stats, hasLength(3));

    // Spot-check the first item's properties.
    expect(stats[0].title, equals('Total Users'));
    expect(stats[0].value, equals('12,345'));
    expect(stats[0].icon, equals(Icons.people));

    // Verify the other two items exist with correct titles.
    expect(stats[1].title, equals('Revenue'));
    expect(stats[2].title, equals('Orders'));
  });

  // ---------------------------------------------------------------------------
  // Test 3 — Error state surfaces the exception message
  // ---------------------------------------------------------------------------
  // When the notifier throws, the provider should be in an AsyncError state
  // and the error message should be accessible.
  // ---------------------------------------------------------------------------
  test('error state contains exception message', () async {
    final container = ProviderContainer(
      overrides: [
        statsProvider.overrideWith(() => _FakeErrorNotifier()),
      ],
    );

    // `.future` re-throws the exception so we can assert on it.
    expect(
      () => container.read(statsProvider.future),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Simulated network error'),
        ),
      ),
    );

    // After the error propagates, the provider should be in AsyncError.
    // We need to use `await Future.value()` to let microtasks settle.
    await Future<void>.value();
    final state = container.read(statsProvider);
    expect(state, isA<AsyncError<List<StatItem>>>());
  });

  // ---------------------------------------------------------------------------
  // Test 4 — refresh() invalidates and re-fetches
  // ---------------------------------------------------------------------------
  // After a successful fetch, calling `refresh()` should invalidate the
  // provider so the next read triggers a fresh `build()`.
  // ---------------------------------------------------------------------------
  test('refresh re-fetches data', () async {
    final container = ProviderContainer(
      overrides: [
        statsProvider.overrideWith(() => _FakeSuccessNotifier()),
      ],
    );

    // First fetch — should succeed with 3 items.
    final firstFetch = await container.read(statsProvider.future);
    expect(firstFetch, hasLength(3));

    // Now call refresh on the notifier instance.
    // This invalidates the provider, causing a new future to be created.
    container.read(statsProvider.notifier).refresh();

    // After invalidation, the provider enters a "refreshing" state.
    // In Riverpod 2.x, this is represented as AsyncData with isLoading=true
    // (it keeps the previous value while re-fetching).
    final refreshingState = container.read(statsProvider);
    expect(refreshingState, isA<AsyncData<List<StatItem>>>());
    // The isLoading flag tells us a re-fetch is in progress.
    expect(refreshingState.isLoading, isTrue);

    // Await the second fetch — should return the same 3 items.
    final secondFetch = await container.read(statsProvider.future);
    expect(secondFetch, hasLength(3));
  });

  // ---------------------------------------------------------------------------
  // Test 5 — StatItem model fields are correct
  // ---------------------------------------------------------------------------
  // A simple model sanity check — ensures our data class holds values as
  // expected.
  // ---------------------------------------------------------------------------
  test('StatItem stores title, value, and icon correctly', () {
    const item = StatItem(
      title: 'Active Sessions',
      value: '42',
      icon: Icons.wifi,
    );

    expect(item.title, equals('Active Sessions'));
    expect(item.value, equals('42'));
    expect(item.icon, equals(Icons.wifi));
  });
}
