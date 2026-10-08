import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/api_client.dart';
import 'data/auth_repository.dart';
import 'data/token_store.dart';
import 'messaging/push_service.dart';
import 'pages/announcement_page.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'providers/auth_provider.dart';
import 'routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  registerBackgroundHandler();

  runApp(const ProviderScope(child: MyApp()));

  WidgetsBinding.instance.addPostFrameCallback((_) => _initMessaging());
}

Future<void> _initMessaging() async {
  await initLocalNotifications(go: router.go);
  await requestNotificationPermission();
  await initFcmToken(onToken: _registerToken);
  listenForeground(router.go);
  await handleTerminated(router.go);
}

Future<void> _registerToken(String token) async {
  fcmToken.value = token; 

  final dio = buildApiClient(TokenStore(), AuthRepository());
  try {
    await dio.post(
      '/devices',
      data: {'fcm_token': token, 'platform': 'android'},
    );
  } catch (_) {
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      routerConfig: router,
    );
  }
}

final GoRouter router = GoRouter(
  redirect: (context, state) {
    final loggedIn = ProviderScope.containerOf(context, listen: false)
            .read(authStateProvider)
            .value ??
        false;
    final goingLogin = state.matchedLocation == Routes.login;
    if (!loggedIn && !goingLogin) return Routes.login;
    if (loggedIn && goingLogin) return Routes.home;
    return null;
  },
  routes: [
    GoRoute(path: Routes.login, builder: (_, _) => const LoginPage()),
    GoRoute(path: Routes.home, builder: (_, _) => const HomePage()),
    GoRoute(
      path: Routes.announcement,
      builder: (_, s) =>
          AnnouncementPage(id: s.pathParameters[Routes.announcementIdParam] ?? ''),
    ),
  ],
);
