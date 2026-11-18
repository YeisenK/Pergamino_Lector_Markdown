import 'package:flutter/painting.dart';
import 'package:markdown/markdown.dart' as md;

import 'md_renderer.dart';
import 'reader_content.dart';

/// Un trozo de página: un bloque entero, o un rango de caracteres de un párrafo/encabezado.
class PageItem {
  final int block;
  final int start; // solo para trozos de texto
  final int end;
  final bool whole;
  const PageItem(this.block, this.start, this.end, this.whole);
}

class BookPage {
  final List<PageItem> items;
  final int firstBlock;
  const BookPage(this.items, this.firstBlock);
}

/// Reparte el libro en páginas de alto fijo. Se calcula por partes (incremental):
/// solo se paginan las páginas que hacen falta para leer.
class Paginator {
  Paginator({
    required this.content,
    required this.style,
    required this.width,
    required this.height,
  });

  final BookContent content;
  final ReaderStyle style;
  final double width, height;

  final pages = <BookPage>[];
  int _block = 0; // primer bloque aún sin paginar
  List<PageItem> _cur = [];
  double _used = 0;
  int _curFirst = -1;

  bool get done => _block >= content.blocks.length;

  double get _lineH => style.fontSize * style.lineHeight;

  void _flush() {
    if (_cur.isNotEmpty) pages.add(BookPage(List.of(_cur), _curFirst));
    _cur = [];
    _used = 0;
    _curFirst = -1;
  }

  void _place(PageItem it, double h) {
    if (_curFirst < 0) _curFirst = it.block;
    _cur.add(it);
    _used += h;
  }

  /// Calcula hasta [maxPages] páginas nuevas.
  void advance({int maxPages = 20}) {
    final target = pages.length + maxPages;
    while (!done && pages.length < target) {
      _stepBlock();
    }
    // la última página incompleta cuenta solo cuando ya no hay más bloques
    if (done && _cur.isNotEmpty) _flush();
  }

  /// Índice de la página que contiene [block], paginando lo necesario.
  int pageOfBlock(int block) {
    while (!done && (pages.isEmpty || pages.last.firstBlock <= block)) {
      advance(maxPages: 10);
    }
    var idx = 0;
    for (var i = 0; i < pages.length; i++) {
      if (pages[i].firstBlock <= block) idx = i;
    }
    return idx;
  }

  void _stepBlock() {
    final node = content.blocks[_block];
    final info = textBlockInfo(node, style);
    if (info == null) {
      final h = _wholeHeight(node);
      if (_used + h > height && _cur.isNotEmpty) _flush();
      _place(PageItem(_block, 0, -1, true), h);
      if (_used >= height) _flush();
      _block++;
      return;
    }
    final plain = info.spans.map((s) => (s as TextSpan).text ?? '').join();
    final len = plain.length;
    if (len == 0) {
      _block++;
      return;
    }
    // posiciones en las que se puede cortar: después de cada espacio, y el final
    final breaks = <int>[
      for (var i = 0; i < len; i++)
        if (plain[i] == ' ' || plain[i] == '\n') i + 1,
      len,
    ];
    var start = 0;
    while (start < len) {
      final pad = start == 0 ? info.padTop : 0.0;
      final avail = height - _used - pad - info.padBottom;
      if (avail < _lineH * 2 && _cur.isNotEmpty) {
        _flush();
        continue;
      }
      var end = _fitEnd(info, start, breaks, avail);
      if (end == null) {
        if (_cur.isNotEmpty) {
          _flush();
          continue;
        }
        // ni una palabra cabe en la página vacía: se toma la primera palabra igualmente
        end = breaks.firstWhere((b) => b > start, orElse: () => len);
      }
      final h = _measure(info, start, end) + pad + info.padBottom;
      _place(PageItem(_block, start, end, false), h);
      start = end;
      while (start < len && (plain[start] == ' ' || plain[start] == '\n')) {
        start++;
      }
      if (start < len) _flush();
    }
    _block++;
  }

  /// Mayor corte (de la lista) cuyo trozo cabe en [avail] píxeles. Búsqueda binaria.
  int? _fitEnd(TextBlockInfo info, int start, List<int> breaks, double avail) {
    var lo = 0, hi = breaks.length - 1, best = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final b = breaks[mid];
      if (b <= start) {
        lo = mid + 1;
        continue;
      }
      if (_measure(info, start, b) <= avail) {
        best = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return best < 0 ? null : breaks[best];
  }

  double _measure(TextBlockInfo info, int start, int end) {
    final spans = sliceSpans(info.spans, start, end);
    final tp = TextPainter(
      text: TextSpan(style: info.base, children: spans),
      textDirection: TextDirection.ltr,
      textAlign: info.align,
    )..layout(maxWidth: width);
    final h = tp.height;
    tp.dispose();
    return h;
  }

  /// Altura estimada de un bloque que no se parte (listas, tablas, código, etc.).
  double _wholeHeight(md.Node node) {
    final el = node is md.Element ? node : null;
    if (el == null) return _lineH;
    switch (el.tag) {
      case 'hr':
        return style.fontSize * 3.4;
      case 'table':
        final rows = el.children
                ?.whereType<md.Element>()
                .expand((sec) => sec.children?.whereType<md.Element>() ?? const <md.Element>[])
                .length ??
            1;
        return rows * (style.fontSize * .9 * style.lineHeight + 16) + style.fontSize * .85;
      case 'pre':
        final lines = '\n'.allMatches(el.textContent).length + 1;
        return lines * style.fontSize * .85 * 1.4 + 24 + style.fontSize * .85;
      default:
        final tp = TextPainter(
          text: TextSpan(
              style: style.body,
              text: el.textContent.replaceAll(RegExp(r'\s+'), ' ').trim()),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: width - (el.tag == 'blockquote' ? 16 : 28));
        final h = tp.height + style.fontSize * .85;
        tp.dispose();
        return h;
    }
  }
}
