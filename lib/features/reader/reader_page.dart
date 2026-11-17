import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:material_ui/material_ui.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/theme.dart';
import '../../data/book_repository.dart';
import '../../domain/book.dart';
import 'chapter_parser.dart';
import 'md_renderer.dart';

class BookContent {
  final List<md.Node> blocks;
  final List<int> chapterStarts; // índice de bloque donde empieza cada capítulo
  final List<String> chapterTitles;
  const BookContent(this.blocks, this.chapterStarts, this.chapterTitles);
}

/// Lee el archivo y parsea en un Isolate para no bloquear la UI.
Future<BookContent> loadBook(String path) async {
  final text = await File(path).readAsString();
  return compute(parseBookText, text);
}

BookContent parseBookText(String text) {
  final chapters = parseChapters(text);
  final blocks = <md.Node>[];
  final starts = <int>[];
  final titles = <String>[];
  final doc = md.Document(extensionSet: md.ExtensionSet.gitHubFlavored);
  for (final c in chapters) {
    starts.add(blocks.length);
    titles.add(c.title);
    blocks.addAll(doc.parseLines(c.markdown.split('\n')));
  }
  return BookContent(blocks, starts, titles);
}

final bookContentProvider =
    FutureProvider.family<BookContent, String>((ref, path) => loadBook(path));

class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({super.key, required this.bookId});
  final String bookId;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  final _items = ItemScrollController();
  final _positions = ItemPositionsListener.create();
  bool _controls = false;
  double _progress = 0;
  Timer? _debounce;
  bool _restored = false;
  late final BooksNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(booksProvider.notifier);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    _positions.itemPositions.addListener(_onScroll);
  }

  @override
  void dispose() {
    _positions.itemPositions.removeListener(_onScroll);
    _debounce?.cancel();
    _persist();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    super.dispose();
  }

  int _total = 1;

  void _onScroll() {
    if (!_restored) return;
    final pos = _positions.itemPositions.value;
    if (pos.isEmpty) return;
    final first = pos
        .where((p) => p.itemTrailingEdge > 0)
        .reduce((a, b) => a.itemLeadingEdge < b.itemLeadingEdge ? a : b);
    final frac = (first.index - first.itemLeadingEdge /
            (first.itemTrailingEdge - first.itemLeadingEdge).clamp(.0001, 100)) /
        (_total <= 1 ? 1 : _total - 1);
    final p = frac.clamp(0.0, 1.0);
    if ((p - _progress).abs() > .0005) setState(() => _progress = p);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _persist);
  }

  void _persist() => _notifier.updateProgress(widget.bookId, _progress);

  void _onTap(TapUpDetails d, double width) {
    final x = d.localPosition.dx / width;
    if (x > .3 && x < .7) {
      setState(() => _controls = !_controls);
    } else if (_controls) {
      setState(() => _controls = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(booksProvider).value ?? [];
    final book = books.where((b) => b.id == widget.bookId).firstOrNull;
    if (book == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final content = ref.watch(bookContentProvider(book.path));
    final palette = Theme.of(context).brightness == Brightness.dark
        ? ReaderPalette.oled
        : ReaderPalette.paper;
    final style = ReaderStyle(
      fontSize: 19,
      lineHeight: 1.6,
      text: palette.text,
      muted: palette.muted,
      accent: palette.accent,
      font: (t) => GoogleFonts.literata(textStyle: t),
    );

    return Scaffold(
      backgroundColor: palette.background,
      body: content.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('No se pudo abrir: $e')),
        data: (c) => _buildReader(context, book, c, style, palette),
      ),
    );
  }

  Widget _buildReader(BuildContext context, Book book, BookContent c,
      ReaderStyle style, ReaderPalette palette) {
    _total = c.blocks.length;
    final initial = book.progress <= 0
        ? 0
        : (book.progress * (_total - 1)).floor().clamp(0, _total - 1);
    if (!_restored) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _restored = true;
          _progress = book.progress;
        }
      });
    }
    final top = MediaQuery.paddingOf(context).top;

    return LayoutBuilder(builder: (context, box) {
      final side = box.maxWidth > 720 ? (box.maxWidth - 680) / 2 : 24.0;
      return Stack(children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (d) => _onTap(d, box.maxWidth),
          child: ScrollablePositionedList.builder(
            itemScrollController: _items,
            itemPositionsListener: _positions,
            initialScrollIndex: initial,
            itemCount: c.blocks.length,
            padding: EdgeInsets.fromLTRB(side, top + 24, side, 120),
            itemBuilder: (_, i) => buildBlock(c.blocks[i], style),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: 2,
            color: palette.accent.withValues(alpha: .8),
            backgroundColor: Colors.transparent,
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          top: _controls ? 0 : -(top + 72),
          left: 0,
          right: 0,
          child: Material(
            color: palette.background.withValues(alpha: .96),
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.only(top: top, left: 4, right: 12),
              child: SizedBox(
                height: 56,
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    color: palette.text,
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Text(book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.literata(
                            color: palette.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                  Text('${(_progress * 100).round()} %',
                      style: TextStyle(color: palette.muted)),
                ]),
              ),
            ),
          ),
        ),
      ]);
    });
  }
}
