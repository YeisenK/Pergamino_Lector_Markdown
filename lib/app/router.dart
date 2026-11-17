import 'package:go_router/go_router.dart';

import '../features/library/library_page.dart';
import '../features/reader/reader_page.dart';

final router = GoRouter(routes: [
  GoRoute(path: '/', builder: (_, _) => const LibraryPage()),
  GoRoute(
    path: '/read/:id',
    builder: (_, s) => ReaderPage(bookId: s.pathParameters['id']!),
  ),
]);
