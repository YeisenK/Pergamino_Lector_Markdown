import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/book_repository.dart';
import '../../data/bookmarks.dart';
import '../../data/highlights.dart';
import '../reader/typography_sheet.dart';
import '../../domain/book.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  String _query = '';

  Future<void> _import() async {
    final book = await ref.read(booksProvider.notifier).importFromPicker();
    if (book != null && mounted) context.push('/read/${book.id}');
  }

  Future<void> _confirmDelete(Book b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Eliminar libro'),
        content: Text('«${b.title}» se quitará de tu biblioteca.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true) {
      ref.read(bookmarksProvider.notifier).removeBook(b.id);
      ref.read(highlightsProvider.notifier).removeBook(b.id);
      ref.read(booksProvider.notifier).remove(b);
    }
  }

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(booksProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
              child: Row(children: [
                Expanded(
                  child: Text('Biblioteca',
                      style: GoogleFonts.literata(
                          fontSize: 34, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  tooltip: 'Voces',
                  icon: const Icon(Icons.record_voice_over_outlined),
                  onPressed: () => context.push('/voices'),
                ),
                IconButton(
                  tooltip: 'Tema',
                  icon: const Icon(Icons.palette_outlined),
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    showDragHandle: true,
                    builder: (_) => const TypographySheet(paletteOnly: true),
                  ),
                ),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: TextField(
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Buscar',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: scheme.onSurface.withValues(alpha: .06),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
          books.when(
            loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) =>
                SliverFillRemaining(child: Center(child: Text('$e'))),
            data: (list) {
              final shown = list
                  .where((b) => b.title.toLowerCase().contains(_query))
                  .toList()
                ..sort((a, b) => (b.lastOpened ?? b.addedAt)
                    .compareTo(a.lastOpened ?? a.addedAt));
              if (list.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_stories_outlined,
                              size: 56,
                              color: scheme.onSurface.withValues(alpha: .4)),
                          const SizedBox(height: 16),
                          Text('Aún no tienes libros',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text('Importa un archivo .md para empezar a leer.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color:
                                      scheme.onSurface.withValues(alpha: .6))),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 16,
                    childAspectRatio: .58,
                  ),
                  itemCount: shown.length,
                  itemBuilder: (_, i) => _BookCard(
                    book: shown[i],
                    onTap: () => context.push('/read/${shown[i].id}'),
                    onLongPress: () => _confirmDelete(shown[i]),
                  ),
                ),
              );
            },
          ),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _import,
        icon: const Icon(Icons.add),
        label: const Text('Importar'),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard(
      {required this.book, required this.onTap, required this.onLongPress});
  final Book book;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  Color get _cover {
    final h = (book.title.hashCode.abs() % 360).toDouble();
    return HSLColor.fromAHSL(1, h, .28, .32).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _cover,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 10,
                      offset: Offset(0, 4)),
                ],
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  book.title,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.literata(
                      color: Colors.white.withValues(alpha: .92),
                      fontSize: 16,
                      height: 1.25,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: book.progress,
              minHeight: 3,
              backgroundColor:
                  Theme.of(context).colorScheme.onSurface.withValues(alpha: .1),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            book.progress == 0 ? 'Nuevo' : '${(book.progress * 100).round()} %',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
