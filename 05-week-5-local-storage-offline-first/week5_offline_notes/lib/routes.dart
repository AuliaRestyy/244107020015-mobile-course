import 'package:go_router/go_router.dart';

import 'core/format.dart';
import 'features/notes/presentation/pages/note_detail_page.dart';
import 'features/notes/presentation/pages/notes_page.dart';
import 'features/posts/presentation/pages/posts_cache_page.dart';
import 'features/settings/presentation/pages/settings_page.dart';

abstract final class AppRoutes {
  static const notes = '/';
  static const postsCache = '/posts';
  static const settings = '/settings';
  static const noteDetailPattern = '/note/:id';
  static String noteDetail(int id) => '/note/$id';
}

final appRouter = createAppRouter();

GoRouter createAppRouter() => GoRouter(
      initialLocation: AppRoutes.notes,
      routes: [
        GoRoute(
          path: AppRoutes.notes,
          builder: (context, state) => const NotesPage(),
        ),
        GoRoute(
          path: AppRoutes.postsCache,
          builder: (context, state) => const PostsCachePage(),
        ),
        GoRoute(
          path: AppRoutes.settings,
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: AppRoutes.noteDetailPattern,
          redirect: (context, state) =>
              parseNoteId(state.pathParameters['id']) == null
                  ? AppRoutes.notes
                  : null,
          builder: (context, state) =>
              NoteDetailPage(id: parseNoteId(state.pathParameters['id'])!),
        ),
      ],
    );
