// =============================================================================
// main.dart — Entry point for the Flutter application
// =============================================================================
//
// Key changes from the default template:
//   1. Import flutter_riverpod so we can use ProviderScope.
//   2. Wrap the MaterialApp with ProviderScope — this is MANDATORY for any
//      Riverpod-based app. ProviderScope creates the internal state container
//      that all providers read/write to. Without it, every ref.watch / ref.read
//      call will throw at runtime.
//   3. Point `home:` at StatsPage so we see our stats screen on launch.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import the stats page we created in stats_page.dart.
import 'stats_page.dart';

void main() {
  // ---------------------------------------------------------------------------
  // ProviderScope must wrap the entire widget tree.
  //
  // It creates an InheritedWidget that stores every provider's state. Think
  // of it as the "dependency injection root" for Riverpod — all descendants
  // can access providers through their WidgetRef.
  // ---------------------------------------------------------------------------
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stats Demo',
      debugShowCheckedModeBanner: false,

      // A clean Material 3 theme.
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),

      // Our StatsPage is now the landing screen.
      home: const StatsPage(),
    );
  }
}
