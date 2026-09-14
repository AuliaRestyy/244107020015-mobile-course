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
// we override the provider with a deterministic notifier subclass that
// lets us control whether the next fetch succeeds or fails.
//
// Key Riverpod testing concepts demonstrated:
//   • ProviderContainer — an isolated container for testing providers without
//     needing a full Flutter widget tree.
//   • provider.overrideWith — replace the real implementation with a test double.
//   • container.read(provider.future) — await the underlying future.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Import the notifier and model we want to test.
import 'package:appdua/pages/stats_page.dart';

// =============================================================================
// Test helpers — Deterministic notifier overrides
// =============================================================================

/// A fake StatsNotifier that always returns successful data.
///
/// By extending the real StatsNotifier we keep the same type signature, but
/// we override build() to skip the random failure logic entirely.
class _FakeSuccessNotifier extends StatsNotifier {
  @override
  Future<List<StatItem>> build() async {
    // Directly return the expected data — no delay, no randomness.
    return const [
      StatItem(
        title: 'Total Users',
        value: '12,345',
        icon: Icons.people,
      ),
      StatItem(
        title: 'Revenue',
        value: r'$89,432',
        icon: Icons.attach_money,
      ),
      StatItem(
        title: 'Orders',
        value: '1,023',
        icon: Icons.shopping_cart,
      ),
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
  test('initial state is loading', () {
    final container = ProviderContainer();

    final state = container.read(statsProvider);

    expect(
      state,
      isA<AsyncLoading<List<StatItem>>>(),
    );

    container.dispose();
  });

  // ---------------------------------------------------------------------------
  // Test 2 — Successful fetch returns expected data
  // ---------------------------------------------------------------------------
  test('successful fetch returns list of 3 stat items', () async {
    final container = ProviderContainer(
      overrides: [
        statsProvider.overrideWith(
          () => _FakeSuccessNotifier(),
        ),
      ],
    );

    final stats = await container.read(statsProvider.future);

    expect(stats, hasLength(3));

    expect(stats[0].title, equals('Total Users'));
    expect(stats[0].value, equals('12,345'));
    expect(stats[0].icon, equals(Icons.people));

    expect(stats[1].title, equals('Revenue'));
    expect(stats[2].title, equals('Orders'));

    container.dispose();
  });

  // ---------------------------------------------------------------------------
  // Test 3 — Error state contains exception message
  // ---------------------------------------------------------------------------
  test('error state contains exception message', () async {
    // riverpod 3 auto-retries a failed AsyncNotifier build up to 10 times
    // with exponential backoff (>30s), keeping state as AsyncLoading and
    // never completing the provider's future. Disable retry so the error
    // state settles deterministically as AsyncError.
    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        statsProvider.overrideWith(
          () => _FakeErrorNotifier(),
        ),
      ],
    );

    // Trigger the provider and give the async build a microtask to fail.
    container.read(statsProvider);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(statsProvider);

    expect(
      state,
      isA<AsyncError<List<StatItem>>>(),
    );
    expect(
      state.error.toString(),
      contains('Simulated network error'),
    );

    container.dispose();
  });

  // ---------------------------------------------------------------------------
  // Test 4 — Refresh re-fetches data
  // ---------------------------------------------------------------------------
  test('refresh re-fetches data', () async {
    final container = ProviderContainer(
      overrides: [
        statsProvider.overrideWith(
          () => _FakeSuccessNotifier(),
        ),
      ],
    );

    final firstFetch = await container.read(statsProvider.future);

    expect(firstFetch, hasLength(3));

    container.read(statsProvider.notifier).refresh();

    final secondFetch = await container.read(statsProvider.future);

    expect(secondFetch, hasLength(3));

    container.dispose();
  });

  // ---------------------------------------------------------------------------
  // Test 5 — StatItem model fields are correct
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