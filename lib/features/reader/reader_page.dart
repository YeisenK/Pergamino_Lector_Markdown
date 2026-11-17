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
import '../../data/highlights.dart';
import '../../data/settings.dart';
import '../../domain/book.dart';
import '../../tts/read_aloud.dart';
import 'book_search.dart';
import 'highlight_sheet.dart';
import 'md_renderer.dart';
import 'reader_clock.dart';
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
  late final ReadAloud _read;

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
    _read = ref.read(readAloudProvider.notifier);
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
    _read.stop();
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

  // Detección de toques propia: el texto seleccionable consume los toques,
  // así que se observan los eventos de puntero directamente.
  Offset? _downPos;
  Duration _downTime = Duration.zero;
  Duration _lastTapTime = Duration(days: -1);
  Offset _lastTapPos = Offset.zero;
  bool _lastToggled = false;
  bool _hlTapped = false;

  void _pointerUp(PointerUpEvent e, double width) {
    final down = _downPos;
    _downPos = null;
    if (down == null) return;
    if ((e.position - down).distance > 14 ||
        e.timeStamp - _downTime > const Duration(milliseconds: 300)) {
      return;
    }
    // doble toque (seleccionar palabra): deshace el cambio del primer toque
    if (e.timeStamp - _lastTapTime < const Duration(milliseconds: 350) &&
        (e.position - _lastTapPos).distance < 40) {
      _lastTapTime = Duration(days: -1);
      if (_lastToggled) setState(() => _controls = !_controls);
      _lastToggled = false;
      return;
    }
    _lastTapTime = e.timeStamp;
    _lastTapPos = e.position;
    final x = e.position.dx / width;
    // deja que un toque sobre un subrayado lo atienda primero
    Timer(Duration.zero, () {
      if (!mounted) return;
      if (_hlTapped) {
        _hlTapped = false;
        _lastToggled = false;
        return;
      }
      if (x > .3 && x < .7) {
        HapticFeedback.selectionClick();
        setState(() => _controls = !_controls);
        _lastToggled = true;
      } else if (_controls) {
        setState(() => _controls = false);
        _lastToggled = true;
      } else {
        _lastToggled = false;
      }
    });
  }

  String _chapterOf(BookContent c, int block) {
    var ch = 0;
    for (var i = 0; i < c.chapterStarts.length; i++) {
      if (c.chapterStarts[i] <= block) ch = i;
    }
    return c.chapterTitles[ch];
  }

  final HlColor _lastColor = HlColor.yellow;

  void _onSelect(BookContent c, int block, int part, int start, int end,
      String text, bool withNote) {
    final h = Highlight(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      bookId: widget.bookId,
      block: block,
      part: part,
      start: start,
      end: end,
      text: text,
      color: _lastColor,
      chapter: _chapterOf(c, block),
      createdAt: DateTime.now(),
    );
    ref.read(highlightsProvider.notifier).add(h);
    HapticFeedback.mediumImpact();
    if (withNote) showHighlightSheet(context, h.id);
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

  int _chapterIndexOf(BookContent c, int block) {
    var ch = 0;
    for (var i = 0; i < c.chapterStarts.length; i++) {
      if (c.chapterStarts[i] <= block) ch = i;
    }
    return ch;
  }

  /// Abre la barra grande (se cierra sola a los 3 s sin tocarla).
  void _scrubOpen(BookContent c) {
    HapticFeedback.selectionClick();
    setState(() {
      _scrubbing = true;
      _scrubFrac = _progress;
      _scrubChapter = _chapterIndexOf(c, _first);
    });
    _armScrubClose();
  }

  void _armScrubClose() {
    _scrubHide?.cancel();
    _scrubHide = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _scrubbing = false);
    });
  }

  void _scrubStart(DragStartDetails d, double width, BookContent c) {
    _scrubHide?.cancel();
    HapticFeedback.selectionClick();
    _scrubTo(d.localPosition.dx, width, c);
  }

  void _scrubTo(double dx, double width, BookContent c) {
    const pad = 24.0;
    final f = ((dx - pad) / (width - pad * 2)).clamp(0.0, 1.0);
    final idx = (f * (c.blocks.length - 1)).round();
    final ch = _chapterIndexOf(c, idx);
    if (ch != _scrubChapter && _scrubChapter != -1) HapticFeedback.selectionClick();
    _items.jumpTo(index: idx);
    setState(() {
      _scrubFrac = f;
      _scrubChapter = ch;
    });
  }

  void _scrubEnd() {
    _persist();
    _armScrubClose();
  }

  Future<void> _openMenu(BookContent c, {int tab = 0}) async {
    final idx = await showReaderMenu(context,
        bookId: widget.bookId,
        title: ref.read(booksProvider).value?.where((b) => b.id == widget.bookId).firstOrNull?.title ?? '',
        content: c,
        currentIndex: _first,
        initialTab: tab);
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
    // sigue la frase que se lee: si su bloque no está a la vista, se desplaza
    ref.listen<ReadState>(readAloudProvider, (prev, next) {
      final seg = next.segment;
      if (seg == null || !next.playing || prev?.segment?.block == seg.block) return;
      final pos = _positions.itemPositions.value
          .where((p) => p.index == seg.block)
          .firstOrNull;
      final visible = pos != null && pos.itemLeadingEdge >= 0 && pos.itemTrailingEdge <= 1;
      if (!visible && _items.isAttached) {
        _items.scrollTo(
            index: seg.block,
            alignment: .12,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOutCubic);
      }
    });
    ref.listen<String?>(ttsVoiceProvider, (_, _) => _read.voiceChanged());
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
    final marksByBlock = <int, List<Mark>>{};
    for (final h in ref.watch(highlightsProvider)) {
      if (h.bookId != widget.bookId) continue;
      (marksByBlock[h.block] ??= []).add(Mark(
        key: h.id,
        part: h.part,
        start: h.start,
        end: h.end,
        color: h.color.color.withValues(alpha: .38),
        underline: (h.note ?? '').trim().isNotEmpty,
        onTap: () {
          _hlTapped = true;
          showHighlightSheet(context, h.id);
        },
      ));
    }

    final reading = ref.watch(readAloudProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // la barra grande y el icono quedan por encima de la zona de gestos del sistema
    final scrubBase = (reading.active ? 124.0 : 64.0) + bottomInset;
    final scrubIconBottom = (reading.active ? 128.0 : 72.0) + bottomInset;
    final seg = reading.segment;
    if (reading.active && seg != null) {
      (marksByBlock[seg.block] ??= []).add(Mark(
        key: 'tts',
        part: seg.part,
        start: seg.start,
        end: seg.end,
        color: palette.accent.withValues(alpha: .32),
      ));
    }

    return LayoutBuilder(builder: (context, box) {
      final side = ((box.maxWidth - settings.maxWidth) / 2)
          .clamp(settings.margin, 4000.0);
      return Stack(children: [
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) {
            _downPos = e.position;
            _downTime = e.timeStamp;
          },
          onPointerMove: (e) {
            if (_downPos != null && (e.position - _downPos!).distance > 14) {
              _downPos = null;
            }
          },
          onPointerUp: (e) => _pointerUp(e, box.maxWidth),
          onPointerCancel: (_) => _downPos = null,
          child: ScrollablePositionedList.builder(
            itemScrollController: _items,
            itemPositionsListener: _positions,
            initialScrollIndex: initial,
            itemCount: c.blocks.length,
            padding: EdgeInsets.fromLTRB(side, top + (settings.showClock ? 40 : 24), side, 140),
            itemBuilder: (_, i) => buildBlock(
              c.blocks[i],
              style,
              BlockCtx(
                marks: marksByBlock[i] ?? const [],
                onSelect: (part, s, e, t, note) =>
                    _onSelect(c, i, part, s, e, t, note),
              ),
            ),
          ),
        ),
        // franja superior con el reloj (tapa el texto que pasa por debajo)
        if (settings.showClock)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: top + 30,
                color: palette.background,
                alignment: Alignment.bottomCenter,
                padding: const EdgeInsets.only(bottom: 6),
                child: ReaderClock(color: palette.muted),
              ),
            ),
          ),
        // borde izquierdo: gesto vertical = brillo
        Positioned(
          left: 0,
          top: top + 80,
          bottom: 140,
          width: 28,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragUpdate: (d) => _dragBrightness(d, box.maxHeight),
          ),
        ),
        // barra de progreso: fina con los controles; con el icono de la derecha
        // se abre grande (lejos del borde, donde Android usa sus gestos) y
        // sirve como scroll rápido
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          left: 0,
          right: 0,
          bottom: _scrubbing ? scrubBase : 0,
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
        if (_scrubbing)
          Positioned(
            left: 0,
            right: 0,
            bottom: scrubBase + 8,
            height: 56,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (d) {
                _scrubHide?.cancel();
                _scrubTo(d.localPosition.dx, box.maxWidth, c);
                _scrubEnd();
              },
              onHorizontalDragStart: (d) => _scrubStart(d, box.maxWidth, c),
              onHorizontalDragUpdate: (d) =>
                  _scrubTo(d.localPosition.dx, box.maxWidth, c),
              onHorizontalDragEnd: (_) => _scrubEnd(),
              onHorizontalDragCancel: _scrubEnd,
            ),
          ),
        // icono pequeño y semitransparente (a la izquierda) para abrir la barra
        Positioned(
          left: 8,
          bottom: scrubIconBottom,
          child: IgnorePointer(
            ignoring: _scrubbing || !_controls,
            child: AnimatedOpacity(
              // solo visible cuando se muestran los controles (toque central)
              opacity: (_scrubbing || !_controls) ? 0 : .7,
              duration: const Duration(milliseconds: 200),
              child: Semantics(
                button: true,
                label: 'Barra de progreso y desplazamiento rápido',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _scrubOpen(c),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: palette.text.withValues(alpha: .12),
                      ),
                      child: Icon(Icons.linear_scale,
                          size: 20, color: palette.text),
                    ),
                  ),
                ),
              ),
            ),
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
        // reproductor de lectura en voz alta
        if (reading.active)
          Positioned(
            left: 12,
            right: 12,
            bottom: 60 + MediaQuery.paddingOf(context).bottom,
            child: _Player(
              state: reading,
              palette: palette,
              rate: ref.watch(ttsRateProvider),
              onToggle: _read.toggle,
              onNext: _read.next,
              onPrev: _read.previous,
              onRate: _read.setRate,
              onVoices: () => context.push('/voices'),
              onClose: _read.stop,
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
                    onPressed: () => _openMenu(c, tab: 3),
                  ),
                  IconButton(
                    tooltip: 'Capítulos',
                    icon: const Icon(Icons.format_list_bulleted),
                    color: palette.text,
                    onPressed: () => _openMenu(c),
                  ),
                  IconButton(
                    tooltip: 'Leer en voz alta',
                    icon: Icon(reading.active ? Icons.headphones : Icons.headphones_outlined),
                    color: reading.active ? palette.accent : palette.text,
                    onPressed: () {
                      if (reading.active) {
                        _read.toggle();
                      } else {
                        _read.start(c, style, fromBlock: _first);
                        setState(() => _controls = false);
                      }
                    },
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

class _Player extends StatelessWidget {
  const _Player({
    required this.state,
    required this.palette,
    required this.rate,
    required this.onToggle,
    required this.onNext,
    required this.onPrev,
    required this.onRate,
    required this.onVoices,
    required this.onClose,
  });
  final ReadState state;
  final ReaderPalette palette;
  final double rate;
  final VoidCallback onToggle, onNext, onPrev, onVoices, onClose;
  final ValueChanged<double> onRate;

  static const _rates = [0.8, 1.0, 1.2, 1.5, 1.8];

  @override
  Widget build(BuildContext context) {
    final fg = palette.text;
    final next = _rates.firstWhere((r) => r > rate + .01, orElse: () => _rates.first);
    return Material(
      color: palette.isDark
          ? Color.alphaBlend(palette.text.withValues(alpha: .12), palette.background)
          : Color.alphaBlend(palette.text.withValues(alpha: .06), palette.background),
      elevation: 6,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Text(state.error!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
            ),
          Row(children: [
            IconButton(
                tooltip: 'Frase anterior',
                icon: const Icon(Icons.skip_previous),
                color: fg,
                onPressed: onPrev),
            state.loading
                ? const SizedBox(
                    width: 48,
                    height: 48,
                    child: Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(strokeWidth: 3)))
                : IconButton.filled(
                    tooltip: state.playing ? 'Pausar' : 'Reanudar',
                    icon: Icon(state.playing ? Icons.pause : Icons.play_arrow),
                    style: IconButton.styleFrom(
                        backgroundColor: palette.accent,
                        foregroundColor: palette.isDark ? Colors.black : Colors.white),
                    onPressed: onToggle),
            IconButton(
                tooltip: 'Frase siguiente',
                icon: const Icon(Icons.skip_next),
                color: fg,
                onPressed: onNext),
            const Spacer(),
            TextButton(
              onPressed: () => onRate(next),
              style: TextButton.styleFrom(foregroundColor: fg, minimumSize: const Size(56, 40)),
              child: Text('${rate.toStringAsFixed(rate * 10 % 10 == 0 ? 0 : 1)}×',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            IconButton(
                tooltip: 'Voces',
                icon: const Icon(Icons.record_voice_over_outlined),
                color: fg,
                onPressed: onVoices),
            IconButton(
                tooltip: 'Cerrar lectura',
                icon: const Icon(Icons.close),
                color: fg,
                onPressed: onClose),
          ]),
        ]),
      ),
    );
  }
}
