import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/theme.dart';
import '../../data/book_repository.dart';
import '../../data/bookmarks.dart';
import '../../data/settings.dart';
import '../../domain/book.dart';
import 'book_search.dart';
import 'md_renderer.dart';
import 'reader_content.dart';
import 'reader_menu_sheet.dart';
import 'typography_sheet.dart';

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
  int _first = 0;
  int _last = 0;
  int _total = 1;
  Timer? _debounce;
  bool _restored = false;
  late final BooksNotifier _notifier;

  // scroll rápido (barra de progreso arrastrable)
  bool _scrubbing = false;
  double _scrubFrac = 0;
  int _scrubChapter = -1;
  Timer? _scrubHide;

  // brillo
  double? _brightness;
  bool _showBrightness = false;
  Timer? _brightnessHide;

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
    _brightnessHide?.cancel();
    _scrubHide?.cancel();
    _persist();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    ScreenBrightness().resetApplicationScreenBrightness().catchError((_) {});
    super.dispose();
  }

  void _onScroll() {
    if (!_restored) return;
    final pos = _positions.itemPositions.value
        .where((p) => p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1);
    if (pos.isEmpty) return;
    final first = pos.reduce((a, b) => a.itemLeadingEdge < b.itemLeadingEdge ? a : b);
    final last = pos.reduce((a, b) => a.index > b.index ? a : b);
    final size = (first.itemTrailingEdge - first.itemLeadingEdge).clamp(.0001, 100);
    final frac = (first.index + (-first.itemLeadingEdge / size).clamp(0, 1)) /
        (_total <= 1 ? 1 : _total - 1);
    final p = frac.clamp(0.0, 1.0);
    final moved = (p - _progress).abs() > .0005;
    if (moved || first.index != _first || last.index != _last) {
      setState(() {
        _progress = p;
        _first = first.index;
        _last = last.index;
      });
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _persist);
  }

  void _persist() => _notifier.updateProgress(widget.bookId, _progress);

  void _onTap(TapUpDetails d, double width) {
    final x = d.localPosition.dx / width;
    if (x > .3 && x < .7) {
      HapticFeedback.selectionClick();
      setState(() => _controls = !_controls);
    } else if (_controls) {
      setState(() => _controls = false);
    }
  }

  Future<void> _dragBrightness(DragUpdateDetails d, double height) async {
    _brightness ??= await ScreenBrightness().application.catchError((_) => .5);
    final next = (_brightness! - d.delta.dy / (height * .6)).clamp(0.02, 1.0);
    _brightness = next;
    ScreenBrightness().setApplicationScreenBrightness(next).catchError((_) {});
    _brightnessHide?.cancel();
    _brightnessHide = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showBrightness = false);
    });
    if (mounted) setState(() => _showBrightness = true);
  }

  void _scrubStart(DragStartDetails d, double width, BookContent c) {
    _scrubHide?.cancel();
    HapticFeedback.selectionClick();
    setState(() {
      _scrubbing = true;
      _scrubChapter = -1;
    });
    _scrubTo(d.localPosition.dx, width, c);
  }

  void _scrubTo(double dx, double width, BookContent c) {
    const pad = 24.0;
    final f = ((dx - pad) / (width - pad * 2)).clamp(0.0, 1.0);
    final idx = (f * (c.blocks.length - 1)).round();
    var ch = 0;
    for (var i = 0; i < c.chapterStarts.length; i++) {
      if (c.chapterStarts[i] <= idx) ch = i;
    }
    if (ch != _scrubChapter && _scrubChapter != -1) HapticFeedback.selectionClick();
    _items.jumpTo(index: idx);
    setState(() {
      _scrubFrac = f;
      _scrubChapter = ch;
    });
  }

  void _scrubEnd() {
    _persist();
    _scrubHide?.cancel();
    _scrubHide = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _scrubbing = false);
    });
  }

  Future<void> _openMenu(BookContent c, {int tab = 0}) async {
    final idx = await showReaderMenu(context,
        bookId: widget.bookId, content: c, currentIndex: _first, initialTab: tab);
    if (idx != null && mounted) {
      setState(() => _controls = false);
      _items.scrollTo(
          index: idx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic);
    }
  }

  bool _hasBookmarkVisible(List<Bookmark> marks) => marks.any(
      (b) => b.bookId == widget.bookId && b.index >= _first && b.index <= _last);

  void _toggleBookmark(BookContent c) {
    final n = ref.read(bookmarksProvider.notifier);
    final marks = ref.read(bookmarksProvider);
    final here = marks.where(
        (b) => b.bookId == widget.bookId && b.index >= _first && b.index <= _last);
    HapticFeedback.mediumImpact();
    if (here.isNotEmpty) {
      for (final b in here.toList()) {
        n.remove(b);
      }
      return;
    }
    var ch = 0;
    for (var i = 0; i < c.chapterStarts.length; i++) {
      if (c.chapterStarts[i] <= _first) ch = i;
    }
    // el primer bloque con texto a partir del primero visible
    var idx = _first;
    while (idx < c.blocks.length - 1 && blockSnippet(c.blocks[idx]).isEmpty) {
      idx++;
    }
    n.add(Bookmark(
      bookId: widget.bookId,
      index: idx,
      snippet: blockSnippet(c.blocks[idx]),
      chapter: c.chapterTitles[ch],
      createdAt: DateTime.now(),
    ));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
          content: Text('Marcador guardado'),
          duration: Duration(milliseconds: 1200)));
  }

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(booksProvider).value ?? [];
    final book = books.where((b) => b.id == widget.bookId).firstOrNull;
    if (book == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final settings = ref.watch(settingsProvider);
    final palette = settings.resolve(MediaQuery.platformBrightnessOf(context));
    final content = ref.watch(bookContentProvider(book.path));

    return Scaffold(
      backgroundColor: palette.background,
      body: content.when(
        loading: () => Center(
            child: CircularProgressIndicator(color: palette.accent)),
        error: (e, _) => Center(
            child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('No se pudo abrir el libro.\n$e',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.text)),
        )),
        data: (c) => _buildReader(context, book, c, settings, palette),
      ),
    );
  }

  Widget _buildReader(BuildContext context, Book book, BookContent c,
      ReaderSettings settings, ReaderPalette palette) {
    _total = c.blocks.length;
    final initial = book.progress <= 0
        ? 0
        : (book.progress * (_total - 1)).floor().clamp(0, _total - 1);
    if (!_restored) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _restored = true;
          _progress = book.progress;
          _first = initial;
          _last = initial;
        }
      });
    }
    final style = ReaderStyle(
      fontSize: settings.fontSize,
      lineHeight: settings.lineHeight,
      text: palette.text,
      muted: palette.muted,
      accent: palette.accent,
      justify: settings.justify,
      font: settings.font.apply,
    );
    final top = MediaQuery.paddingOf(context).top;
    final marks = ref.watch(bookmarksProvider);
    final marked = _hasBookmarkVisible(marks);

    return LayoutBuilder(builder: (context, box) {
      final side = ((box.maxWidth - settings.maxWidth) / 2)
          .clamp(settings.margin, 4000.0);
      return Stack(children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (d) => _onTap(d, box.maxWidth),
          child: ScrollablePositionedList.builder(
            itemScrollController: _items,
            itemPositionsListener: _positions,
            initialScrollIndex: initial,
            itemCount: c.blocks.length,
            padding: EdgeInsets.fromLTRB(side, top + 24, side, 140),
            itemBuilder: (_, i) => buildBlock(c.blocks[i], style),
          ),
        ),
        // borde izquierdo: gesto vertical = brillo
        Positioned(
          left: 0,
          top: top + 80,
          bottom: 80,
          width: 28,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragUpdate: (d) => _dragBrightness(d, box.maxHeight),
          ),
        ),
        // barra de progreso: visible con los controles; un gesto en la zona
        // inferior la agranda y funciona como scroll rápido
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: (_controls || _scrubbing) ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              child: _ScrubBar(
                progress: _scrubbing ? _scrubFrac : _progress,
                expanded: _scrubbing,
                width: box.maxWidth,
                palette: palette,
                label: _scrubChapter >= 0 ? c.chapterTitles[_scrubChapter] : '',
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 8,
          height: 44,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (d) => _scrubStart(d, box.maxWidth, c),
            onPanUpdate: (d) => _scrubTo(d.localPosition.dx, box.maxWidth, c),
            onPanEnd: (_) => _scrubEnd(),
            onPanCancel: _scrubEnd,
          ),
        ),
        // indicador de brillo
        Positioned(
          left: 16,
          top: 0,
          bottom: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _showBrightness ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: Center(
                child: Container(
                  width: 44,
                  height: 140,
                  decoration: BoxDecoration(
                    color: palette.text.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: (_brightness ?? .5).clamp(.05, 1),
                            child: Container(
                              decoration: BoxDecoration(
                                color: palette.accent,
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(Icons.brightness_6,
                            size: 20, color: palette.text),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // barra superior
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          top: _controls ? 0 : -(top + 80),
          left: 0,
          right: 0,
          child: Material(
            color: palette.background.withValues(alpha: .97),
            elevation: 3,
            child: Padding(
              padding: EdgeInsets.only(top: top, left: 4, right: 4),
              child: SizedBox(
                height: 56,
                child: Row(children: [
                  IconButton(
                    tooltip: 'Volver',
                    icon: const Icon(Icons.arrow_back),
                    color: palette.text,
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Text(book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: settings.font.apply(TextStyle(
                            color: palette.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w600))),
                  ),
                  Text('${(_progress * 100).round()} %',
                      style: TextStyle(color: palette.muted, fontSize: 13)),
                  IconButton(
                    tooltip: marked ? 'Quitar marcador' : 'Añadir marcador',
                    icon: Icon(marked ? Icons.bookmark : Icons.bookmark_border),
                    color: marked ? palette.accent : palette.text,
                    onPressed: () => _toggleBookmark(c),
                  ),
                  IconButton(
                    tooltip: 'Buscar',
                    icon: const Icon(Icons.search),
                    color: palette.text,
                    onPressed: () => _openMenu(c, tab: 2),
                  ),
                  IconButton(
                    tooltip: 'Capítulos',
                    icon: const Icon(Icons.format_list_bulleted),
                    color: palette.text,
                    onPressed: () => _openMenu(c),
                  ),
                  IconButton(
                    tooltip: 'Tipografía y tema',
                    icon: const Icon(Icons.text_fields),
                    color: palette.text,
                    onPressed: () => showTypographySheet(context),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]);
    });
  }
}

class _ScrubBar extends StatelessWidget {
  const _ScrubBar({
    required this.progress,
    required this.expanded,
    required this.width,
    required this.palette,
    required this.label,
  });
  final double progress;
  final bool expanded;
  final double width;
  final ReaderPalette palette;
  final String label;

  @override
  Widget build(BuildContext context) {
    const pad = 24.0;
    final trackH = expanded ? 10.0 : 3.0;
    final inner = width - pad * 2;
    final x = pad + inner * progress.clamp(0.0, 1.0);
    return SizedBox(
      height: 120,
      width: width,
      child: Stack(clipBehavior: Clip.none, children: [
        // burbuja con capítulo y porcentaje
        Positioned(
          left: 0,
          right: 0,
          bottom: 52,
          child: AnimatedOpacity(
            opacity: expanded ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: width - 48),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: palette.isDark
                      ? palette.text.withValues(alpha: .18)
                      : palette.text.withValues(alpha: .92),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${(progress * 100).round()} %',
                      style: TextStyle(
                          color: palette.isDark ? palette.text : palette.background,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  if (label.isNotEmpty)
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: (palette.isDark ? palette.text : palette.background)
                                .withValues(alpha: .8),
                            fontSize: 13)),
                ]),
              ),
            ),
          ),
        ),
        // pista
        AnimatedPositioned(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          left: expanded ? pad : 0,
          right: expanded ? pad : 0,
          bottom: expanded ? 28 : 0,
          height: trackH,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(expanded ? 6 : 0),
            child: Stack(children: [
              Positioned.fill(
                  child: ColoredBox(color: palette.text.withValues(alpha: .14))),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: (expanded ? inner : width) * progress.clamp(0.0, 1.0),
                child: ColoredBox(color: palette.accent),
              ),
            ]),
          ),
        ),
        // tirador
        if (expanded)
          Positioned(
            left: x - 13,
            bottom: 28 + trackH / 2 - 13,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: palette.accent,
                shape: BoxShape.circle,
                border: Border.all(color: palette.background, width: 3),
                boxShadow: const [
                  BoxShadow(color: Color(0x44000000), blurRadius: 6),
                ],
              ),
            ),
          ),
      ]),
    );
  }
}
