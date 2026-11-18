import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/book_repository.dart';
import '../../data/features.dart';
import '../../data/library_prefs.dart';
import '../../domain/library_view.dart';
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


  final Set<String> _selected = {};
  bool get _selecting => _selected.isNotEmpty;

  Future<void> _import() async {
    final r = await ref.read(booksProvider.notifier).importFromPicker();
    if (r == null || !mounted) return;
    if (r.added.length == 1 && r.skipped == 0) {
      context.push('/read/${r.added.first.id}');
      return;
    }
    final n = r.added.length;
    final msg = [
      if (n > 0) '$n ${n == 1 ? 'libro importado' : 'libros importados'}',
      if (r.skipped > 0)
        '${r.skipped} ${r.skipped == 1 ? 'archivo omitido' : 'archivos omitidos'} (solo .md, .markdown o .txt)',
    ].join(' · ');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _toggle(Book b) {
    HapticFeedback.selectionClick();
    setState(
      () => _selected.contains(b.id)
          ? _selected.remove(b.id)
          : _selected.add(b.id),
    );
  }

  Future<void> _deleteSelected(List<Book> all) async {
    final chosen = all.where((b) => _selected.contains(b.id)).toList();
    if (chosen.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          chosen.length == 1
              ? 'Eliminar libro'
              : 'Eliminar ${chosen.length} libros',
        ),
        content: Text(
          chosen.length == 1
              ? '«${chosen.first.title}» se quitará de tu biblioteca, con sus marcadores y notas.'
              : 'Se quitarán de tu biblioteca, con sus marcadores y notas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    for (final b in chosen) {
      ref.read(bookmarksProvider.notifier).removeBook(b.id);
      ref.read(highlightsProvider.notifier).removeBook(b.id);
    }
    await ref.read(booksProvider.notifier).removeMany(chosen);
    if (mounted) setState(_selected.clear);
  }

  Widget _selectionBar(List<Book> all) => Row(
    children: [
      IconButton(
        tooltip: 'Cancelar selección',
        icon: const Icon(Icons.close),
        onPressed: () => setState(_selected.clear),
      ),
      Expanded(
        child: Text(
          '${_selected.length} seleccionado${_selected.length == 1 ? '' : 's'}',
          style: GoogleFonts.literata(
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      IconButton(
        tooltip: 'Seleccionar todos',
        icon: const Icon(Icons.select_all),
        onPressed: () => setState(() => _selected.addAll(all.map((b) => b.id))),
      ),
      IconButton(
        tooltip: 'Eliminar seleccionados',
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _deleteSelected(all),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(booksProvider);
    final scheme = Theme.of(context).colorScheme;

    final all = books.value ?? <Book>[];

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
                  child: _selecting
                      ? _selectionBar(all)
                      : Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Biblioteca',
                                style: GoogleFonts.literata(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (ref.watch(featuresProvider).contains(Feature.stats))
                              IconButton(
                                tooltip: 'Estadísticas',
                                icon: const Icon(Icons.bar_chart_rounded),
                                onPressed: () => context.push('/stats'),
                              ),
                            PopupMenuButton<String>(
                              tooltip: 'Más',
                              icon: const Icon(Icons.more_vert),
                              onSelected: (v) => context.push(v),
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: '/features',
                                  child: Text('Funciones'),
                                ),
                                if (ref.watch(featuresProvider).contains(Feature.backup))
                                  const PopupMenuItem(
                                    value: '/backup',
                                    child: Text('Copia de seguridad'),
                                  ),
                              ],
                            ),
                            IconButton(
                              tooltip: 'Voces',
                              icon: const Icon(
                                Icons.record_voice_over_outlined,
                              ),
                              onPressed: () => context.push('/voices'),
                            ),
                            IconButton(
                              tooltip: 'Tema',
                              icon: const Icon(Icons.palette_outlined),
                              onPressed: () => showModalBottomSheet(
                                context: context,
                                showDragHandle: true,
                                builder: (_) =>
                                    const TypographySheet(paletteOnly: true),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Buscar',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: scheme.onSurface.withValues(alpha: .06),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
              if (ref.watch(featuresProvider).contains(Feature.libraryFilters))
                SliverToBoxAdapter(
                  child: _ViewBar(
                    view: ref.watch(libraryViewProvider),
                    onChanged: (v) => ref.read(libraryViewProvider.notifier).update(v),
                  ),
                ),
              books.when(
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) =>
                    SliverFillRemaining(child: Center(child: Text('$e'))),
                data: (list) {
                  final view = ref.watch(libraryViewProvider);
                  final filtersOn = ref.watch(featuresProvider).contains(Feature.libraryFilters);
                  final shown = applyLibraryView(
                    list,
                    filter: filtersOn ? view.filter : LibraryFilter.todos,
                    sort: filtersOn ? view.sort : LibrarySort.ultimoLeido,
                    query: _query,
                  );
                  if (list.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_stories_outlined,
                                size: 56,
                                color: scheme.onSurface.withValues(alpha: .4),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Aún no tienes libros',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Importa un archivo .md para empezar a leer.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: scheme.onSurface.withValues(alpha: .6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            mainAxisSpacing: 20,
                            crossAxisSpacing: 16,
                            childAspectRatio: .58,
                          ),
                      itemCount: shown.length,
                      itemBuilder: (_, i) => _BookCard(
                        book: shown[i],
                        selecting: _selecting,
                        selected: _selected.contains(shown[i].id),
                        onTap: () => _selecting
                            ? _toggle(shown[i])
                            : context.push('/read/${shown[i].id}'),
                        onLongPress: () => _toggle(shown[i]),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        floatingActionButton: _selecting
            ? null
            : FloatingActionButton.extended(
                onPressed: _import,
                icon: const Icon(Icons.add),
                label: const Text('Importar'),
              ),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.book,
    required this.onTap,
    required this.onLongPress,
    this.selecting = false,
    this.selected = false,
  });
  final Book book;
  final bool selecting;
  final bool selected;
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
                border: selected
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 3,
                      )
                    : null,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  if (selecting)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Icon(
                        selected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: Colors.white.withValues(
                          alpha: selected ? 1 : .7,
                        ),
                        size: 24,
                      ),
                    ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Builder(builder: (context) {
                      final t = splitTitle(book.title);
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (t.kicker != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                t.kicker!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.literata(
                                  color: Colors.white.withValues(alpha: .7),
                                  fontSize: 11,
                                  height: 1.2,
                                  letterSpacing: .6,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          Text(
                            t.main,
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.literata(
                              color: Colors.white.withValues(alpha: .92),
                              fontSize: 16,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: book.progress,
              minHeight: 3,
              backgroundColor: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: .1),
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

class _ViewBar extends StatelessWidget {
  const _ViewBar({required this.view, required this.onChanged});
  final LibraryView view;
  final ValueChanged<LibraryView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final f in LibraryFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f.label),
                        selected: view.filter == f,
                        onSelected: (_) => onChanged(view.copyWith(filter: f)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          PopupMenuButton<LibrarySort>(
            tooltip: 'Ordenar',
            icon: const Icon(Icons.sort),
            onSelected: (v) => onChanged(view.copyWith(sort: v)),
            itemBuilder: (_) => [
              for (final s in LibrarySort.values)
                CheckedPopupMenuItem(
                  value: s,
                  checked: view.sort == s,
                  child: Text(s.label),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
