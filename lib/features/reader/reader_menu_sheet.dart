import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import '../../data/bookmarks.dart';
import '../../data/features.dart';
import '../../domain/library_view.dart';
import '../../data/highlights.dart';
import 'highlight_sheet.dart';
import 'book_search.dart';
import 'reader_content.dart';

/// Hoja con tres pestañas: capítulos, marcadores y búsqueda.
Future<int?> showReaderMenu(
  BuildContext context, {
  required String bookId,
  required String title,
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
        length: 4,
        initialIndex: initialTab,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .8,
          child: _Menu(bookId: bookId, title: title, content: content, current: currentIndex),
        ),
      ),
    );

class _Menu extends ConsumerStatefulWidget {
  const _Menu({required this.bookId, required this.title, required this.content, required this.current});
  final String bookId;
  final String title;
  final BookContent content;
  final int current;

  @override
  ConsumerState<_Menu> createState() => _MenuState();
}

class _MenuState extends ConsumerState<_Menu> {
  final _q = TextEditingController();
  final _noteQ = TextEditingController();
  List<SearchHit> _hits = const [];
  String _last = '';

  @override
  void dispose() {
    _q.dispose();
    _noteQ.dispose();
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

    final features = ref.watch(featuresProvider);
    final showChapterProgress = features.contains(Feature.timeLeft);
    final canExport = features.contains(Feature.notesExport);
    final notes = ref
        .watch(highlightsProvider)
        .where((h) => h.bookId == widget.bookId)
        .where((h) => !canExport || foldText('${h.text} ${h.note ?? ''}')
            .contains(foldText(_noteQ.text.trim())))
        .toList()
      ..sort((a, b) =>
          a.block != b.block ? a.block.compareTo(b.block) : a.start.compareTo(b.start));
    final allNotes = ref
        .watch(highlightsProvider)
        .where((h) => h.bookId == widget.bookId)
        .toList();

    return Column(children: [
      const TabBar(tabs: [
        Tab(text: 'Capítulos'),
        Tab(text: 'Marcadores'),
        Tab(text: 'Notas'),
        Tab(text: 'Buscar'),
      ]),
      Expanded(
        child: TabBarView(children: [
          // Capítulos
          ListView.builder(
            itemCount: c.chapterTitles.length,
            itemBuilder: (_, i) {
              final active = i == _currentChapter;
              final start = c.chapterStarts[i];
              final end = i + 1 < c.chapterStarts.length
                  ? c.chapterStarts[i + 1]
                  : c.blocks.length;
              final frac = widget.current >= end
                  ? 1.0
                  : widget.current < start
                      ? 0.0
                      : (widget.current - start) / (end - start).clamp(1, 1 << 30);
              return ListTile(
                selected: active,
                title: Text(c.chapterTitles[i],
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: showChapterProgress
                    ? Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: LinearProgressIndicator(
                          value: frac,
                          minHeight: 3,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      )
                    : null,
                trailing: active ? const Icon(Icons.bookmark_outline, size: 18) : null,
                onTap: () => _go(start),
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
          // Notas y subrayados
          allNotes.isEmpty
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                      'Aún no hay subrayados.\nMantén pulsado un texto, selecciónalo y elige «Subrayar» o «Nota».',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium),
                ))
              : Column(children: [
                  if (canExport)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: TextField(
                        controller: _noteQ,
                        decoration: InputDecoration(
                          hintText: 'Buscar en notas',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          filled: true,
                          fillColor: theme.colorScheme.onSurface.withValues(alpha: .06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton.icon(
                      icon: const Icon(Icons.copy_all, size: 18),
                      label: const Text('Copiar'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(
                            text: exportHighlights(widget.title, allNotes)));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Notas copiadas como Markdown'),
                            duration: Duration(milliseconds: 1400)));
                      },
                    ),
                    if (canExport)
                      TextButton.icon(
                        icon: const Icon(Icons.save_alt, size: 18),
                        label: const Text('Guardar .md'),
                        onPressed: () async {
                          final text = exportHighlights(widget.title, allNotes);
                          final saved = await FilePicker.saveFile(
                            fileName: 'Notas - ${widget.title}.md'.replaceAll('/', '-'),
                            bytes: Uint8List.fromList(utf8.encode(text)),
                          );
                          if (saved != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('Notas guardadas'),
                                duration: Duration(milliseconds: 1400)));
                          }
                        },
                      ),
                  ]),
                  if (notes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Ninguna nota coincide con la búsqueda.',
                          style: theme.textTheme.bodyMedium),
                    ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: notes.length,
                      itemBuilder: (_, i) {
                        final h = notes[i];
                        return ListTile(
                          leading: Container(
                              width: 6, height: 40, color: h.color.color),
                          title: Text(h.text,
                              maxLines: 3, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                              [
                                if (h.note != null && h.note!.trim().isNotEmpty)
                                  h.note!.trim(),
                                h.chapter,
                              ].join('\n'),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis),
                          isThreeLine: h.note != null && h.note!.trim().isNotEmpty,
                          trailing: IconButton(
                            tooltip: 'Editar',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => showHighlightSheet(context, h.id),
                          ),
                          onTap: () => _go(h.block),
                        );
                      },
                    ),
                  ),
                ]),
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
