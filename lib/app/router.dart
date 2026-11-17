import 'package:go_router/go_router.dart';

import '../features/library/library_page.dart';
import '../features/reader/reader_page.dart';

final router = GoRouter(
    // Cualquier ruta desconocida (p. ej. una URI de archivo) vuelve a la biblioteca.
    redirect: (context, state) =>
        (state.uri.scheme.isNotEmpty || state.uri.path.startsWith('/sdcard')) ? '/' : null,
    routes: [
  GoRoute(path: '/', builder: (_, _) => const LibraryPage()),
  GoRoute(
    path: '/read/:id',
    builder: (_, s) => ReaderPage(bookId: s.pathParameters['id']!),
  ),
]);
