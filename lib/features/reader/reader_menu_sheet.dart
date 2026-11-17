import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/bookmarks.dart';
import 'book_search.dart';
import 'reader_content.dart';

/// Hoja con tres pestañas: capítulos, marcadores y búsqueda.
Future<int?> showReaderMenu(
  BuildContext context, {
  required String bookId,
  required BookContent content,
  required int currentIndex,
  int initialTab = 0,
}) =>
    showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => DefaultTabController(
        length: 3,
        initialIndex: initialTab,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .8,
          child: _Menu(bookId: bookId, content: content, current: currentIndex),
        ),
      ),
    );

class _Menu extends ConsumerStatefulWidget {
  const _Menu({required this.bookId, required this.content, required this.current});
  final String bookId;
  final BookContent content;
  final int current;

  @override
  ConsumerState<_Menu> createState() => _MenuState();
}

class _MenuState extends ConsumerState<_Menu> {
  final _q = TextEditingController();
  List<SearchHit> _hits = const [];
  String _last = '';

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  int get _currentChapter {
    var ch = 0;
    for (var i = 0; i < widget.content.chapterStarts.length; i++) {
      if (widget.content.chapterStarts[i] <= widget.current) ch = i;
    }
    return ch;
  }

  void _go(int index) {
    HapticFeedback.selectionClick();
    Navigator.pop(context, index);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.content;
    final theme = Theme.of(context);
    final marks = ref
        .watch(bookmarksProvider)
        .where((b) => b.bookId == widget.bookId)
        .toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return Column(children: [
      const TabBar(tabs: [
        Tab(text: 'Capítulos'),
        Tab(text: 'Marcadores'),
        Tab(text: 'Buscar'),
      ]),
      Expanded(
        child: TabBarView(children: [
          // Capítulos
          ListView.builder(
            itemCount: c.chapterTitles.length,
            itemBuilder: (_, i) {
              final active = i == _currentChapter;
              return ListTile(
                selected: active,
                title: Text(c.chapterTitles[i],
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: active ? const Icon(Icons.bookmark_outline, size: 18) : null,
                onTap: () => _go(c.chapterStarts[i]),
              );
            },
          ),
          // Marcadores
          marks.isEmpty
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                      'Aún no hay marcadores.\nToca el icono de marcador en la barra superior para guardar el punto donde vas.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium),
                ))
              : ListView.builder(
                  itemCount: marks.length,
                  itemBuilder: (_, i) {
                    final m = marks[i];
                    return Dismissible(
                      key: ValueKey('${m.bookId}-${m.index}'),
                      background: Container(
                          color: theme.colorScheme.errorContainer,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete_outline)),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) =>
                          ref.read(bookmarksProvider.notifier).remove(m),
                      child: ListTile(
                        title: Text(m.snippet,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(m.chapter),
                        onTap: () => _go(m.index),
                      ),
                    );
                  },
                ),
          // Búsqueda
          Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _q,
                autofocus: false,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Buscar en el libro',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _q.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            _q.clear();
                            _hits = const [];
                            _last = '';
                          })),
                  filled: true,
                  fillColor: theme.colorScheme.onSurface.withValues(alpha: .06),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (v) => setState(() {
                  _last = v;
                  _hits = searchBlocks(c.blocks, v);
                }),
              ),
            ),
            if (_last.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      _hits.isEmpty
                          ? 'Sin resultados'
                          : '${_hits.length}${_hits.length >= 200 ? '+' : ''} resultados',
                      style: theme.textTheme.labelMedium),
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _hits.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(_hits[i].snippet,
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                  onTap: () => _go(_hits[i].index),
                ),
              ),
            ),
          ]),
        ]),
      ),
    ]);
  }
}
