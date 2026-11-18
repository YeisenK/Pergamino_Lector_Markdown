import 'package:go_router/go_router.dart';

import '../features/library/library_page.dart';
import '../features/reader/reader_page.dart';
import '../features/settings/backup_page.dart';
import '../features/dictionary/dictionary_page.dart';
import '../features/editor/editor_page.dart';
import '../features/library/library_search_page.dart';
import '../features/gestures/gestures_page.dart';
import '../features/stats/stats_page.dart';
import '../features/settings/features_page.dart';
import '../features/voices/voices_page.dart';

final router = GoRouter(
    // Cualquier ruta desconocida (p. ej. una URI de archivo) vuelve a la biblioteca.
    redirect: (context, state) =>
        (state.uri.scheme.isNotEmpty || state.uri.path.startsWith('/sdcard')) ? '/' : null,
    routes: [
  GoRoute(path: '/', builder: (_, _) => const LibraryPage()),
  GoRoute(
    path: '/edit/:id',
    builder: (_, s) => EditorPage(bookId: s.pathParameters['id']!),
  ),
  GoRoute(path: '/gestures', builder: (_, _) => const GesturesPage()),
  GoRoute(path: '/stats', builder: (_, _) => const StatsPage()),
  GoRoute(path: '/backup', builder: (_, _) => const BackupPage()),
  GoRoute(path: '/features', builder: (_, _) => const FeaturesPage()),
  GoRoute(path: '/voices', builder: (_, _) => const VoicesPage()),
  GoRoute(path: '/diccionario', builder: (_, _) => const DictionaryPage()),
  GoRoute(path: '/buscar', builder: (_, _) => const LibrarySearchPage()),
  GoRoute(
    path: '/read/:id',
    builder: (_, s) => ReaderPage(
      bookId: s.pathParameters['id']!,
      startFraction: double.tryParse(s.uri.queryParameters['f'] ?? ''),
    ),
  ),
]);
