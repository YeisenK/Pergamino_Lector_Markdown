import 'package:flutter/gestures.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:material_ui/material_ui.dart';

class ReaderStyle {
  final double fontSize;
  final double lineHeight;
  final Color text;
  final Color muted;
  final Color accent;
  final TextStyle Function(TextStyle) font;
  final bool justify;
  const ReaderStyle({
    required this.fontSize,
    required this.lineHeight,
    required this.text,
    required this.muted,
    required this.accent,
    required this.font,
    this.justify = false,
  });

  TextStyle get body =>
      font(TextStyle(fontSize: fontSize, height: lineHeight, color: text));
}

/// Rango de texto marcado dentro de un fragmento (subrayado o frase leída).
class Mark {
  final String key;
  final int part, start, end;
  final Color color;
  final bool underline; // subrayado punteado (p. ej. con nota)
  final VoidCallback? onTap;
  const Mark({
    required this.key,
    required this.part,
    required this.start,
    required this.end,
    required this.color,
    this.underline = false,
    this.onTap,
  });
}

typedef SelectAction = void Function(
    int part, int start, int end, String text, bool withNote);

/// Contexto de construcción de un bloque: marcas, selección y recolección de texto.
class BlockCtx {
  final List<Mark> marks;
  final SelectAction? onSelect; // si es null el texto no es seleccionable
  final void Function(String)? onPart; // recoge el texto de cada fragmento
  int _part = 0;
  BlockCtx({this.marks = const [], this.onSelect, this.onPart});
  int _next() => _part++;
}

/// Texto plano de cada fragmento de un bloque, en el mismo orden en que se
/// numeran las marcas (para leer en voz alta y para ubicar selecciones).
List<String> blockParts(md.Node node, ReaderStyle s) {
  final out = <String>[];
  buildBlock(node, s, BlockCtx(onPart: out.add));
  return out;
}

final _recognizers = <String, TapGestureRecognizer>{};

/// Convierte un bloque (nodo de nivel superior del AST) en un widget.
Widget buildBlock(md.Node node, ReaderStyle s, [BlockCtx? ctx]) {
  final c = ctx ?? BlockCtx();
  if (node is md.Text) return const SizedBox.shrink();
  final el = node as md.Element;
  switch (el.tag) {
    case 'h1':
    case 'h2':
    case 'h3':
    case 'h4':
    case 'h5':
    case 'h6':
      final scale = {'h1': 1.7, 'h2': 1.4, 'h3': 1.2, 'h4': 1.1, 'h5': 1.0, 'h6': .95}[el.tag]!;
      return Padding(
        padding: EdgeInsets.only(top: s.fontSize * 1.2, bottom: s.fontSize * .6),
        child: _rich(
            _inline(el.children, s, s.body.copyWith(
                fontSize: s.fontSize * scale,
                fontWeight: FontWeight.w700,
                height: 1.25)),
            c),
      );
    case 'p':
      return _para(el.children, s, s.body, c);
    case 'blockquote':
      return Container(
        margin: EdgeInsets.symmetric(vertical: s.fontSize * .4),
        padding: const EdgeInsets.only(left: 16),
        decoration: BoxDecoration(
            border: Border(left: BorderSide(color: s.accent, width: 3))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final k in el.children ?? <md.Node>[])
              if (k is md.Element)
                _para(k.children, s,
                    s.body.copyWith(fontStyle: FontStyle.italic, color: s.muted), c)
          ],
        ),
      );
    case 'ul':
    case 'ol':
      return _list(el, s, 0, c);
    case 'pre':
      final code = el.textContent;
      return Container(
        width: double.infinity,
        margin: EdgeInsets.symmetric(vertical: s.fontSize * .5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: s.text.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(8)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(code.trimRight(),
              style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: s.fontSize * .85,
                  height: 1.4,
                  color: s.text)),
        ),
      );
    case 'hr':
      return Padding(
        padding: EdgeInsets.symmetric(vertical: s.fontSize * 1.2),
        child: Center(
            child: Text('· · ·',
                style: s.body.copyWith(color: s.muted, letterSpacing: 6))),
      );
    case 'table':
      return _table(el, s);
    default:
      return _para(el.children, s, s.body, c);
  }
}

Widget _para(List<md.Node>? kids, ReaderStyle s, TextStyle style, BlockCtx c) =>
    Padding(
      padding: EdgeInsets.only(bottom: s.fontSize * .85),
      child: _rich(_inline(kids, s, style), c,
          align: s.justify ? TextAlign.justify : TextAlign.start),
    );

/// Un fragmento de texto: seleccionable y con marcas si el contexto lo pide.
Widget _rich(List<InlineSpan> spans, BlockCtx c, {TextAlign? align}) {
  final part = c._next();
  final plain = spans.map((e) => (e as TextSpan).text ?? '').join();
  c.onPart?.call(plain);
  final mine = c.marks.where((m) => m.part == part).toList();
  final root = TextSpan(children: mine.isEmpty ? spans : _applyMarks(spans, mine));
  if (c.onSelect == null) return Text.rich(root, textAlign: align);
  return SelectableText.rich(
    root,
    textAlign: align,
    contextMenuBuilder: (context, state) {
      final v = state.textEditingValue;
      final sel = v.selection;
      final items = <ContextMenuButtonItem>[];
      if (sel.isValid && !sel.isCollapsed) {
        final text = sel.textInside(v.text);
        items.add(ContextMenuButtonItem(
          label: 'Subrayar',
          onPressed: () {
            c.onSelect!(part, sel.start, sel.end, text, false);
            state.hideToolbar();
          },
        ));
        items.add(ContextMenuButtonItem(
          label: 'Nota',
          onPressed: () {
            c.onSelect!(part, sel.start, sel.end, text, true);
            state.hideToolbar();
          },
        ));
      }
      items.addAll(state.contextMenuButtonItems.where((i) =>
          i.type == ContextMenuButtonType.copy ||
          i.type == ContextMenuButtonType.selectAll));
      return AdaptiveTextSelectionToolbar.buttonItems(
        anchors: state.contextMenuAnchors,
        buttonItems: items,
      );
    },
  );
}

/// Parte los TextSpan planos en los límites de las marcas y les da fondo.
List<InlineSpan> _applyMarks(List<InlineSpan> spans, List<Mark> marks) {
  final out = <InlineSpan>[];
  var offset = 0;
  for (final sp in spans) {
    final t = sp as TextSpan;
    final text = t.text ?? '';
    final a = offset, b = offset + text.length;
    offset = b;
    if (text.isEmpty) {
      out.add(t);
      continue;
    }
    final cuts = <int>{a, b};
    for (final m in marks) {
      if (m.end > a && m.start < b) {
        cuts.add(m.start.clamp(a, b));
        cuts.add(m.end.clamp(a, b));
      }
    }
    final pts = cuts.toList()..sort();
    for (var i = 0; i < pts.length - 1; i++) {
      final from = pts[i], to = pts[i + 1];
      final piece = text.substring(from - a, to - a);
      final active = marks.where((m) => m.start <= from && m.end >= to).toList();
      if (active.isEmpty) {
        out.add(TextSpan(text: piece, style: t.style));
        continue;
      }
      Color? bg;
      var under = false;
      VoidCallback? tap;
      String? key;
      for (final m in active) {
        bg = bg == null ? m.color : Color.alphaBlend(m.color, bg);
        under = under || m.underline;
        if (m.onTap != null) {
          tap = m.onTap;
          key = m.key;
        }
      }
      TapGestureRecognizer? rec;
      if (tap != null && key != null) {
        rec = _recognizers.putIfAbsent(key, TapGestureRecognizer.new)..onTap = tap;
      }
      out.add(TextSpan(
        text: piece,
        recognizer: rec,
        style: (t.style ?? const TextStyle()).copyWith(
          backgroundColor: bg,
          decoration: under ? TextDecoration.underline : null,
          decorationStyle: under ? TextDecorationStyle.dotted : null,
          decorationThickness: under ? 2 : null,
        ),
      ));
    }
  }
  return out;
}

Widget _list(md.Element el, ReaderStyle s, int depth, BlockCtx c) {
  final ordered = el.tag == 'ol';
  var i = 0;
  return Padding(
    padding: EdgeInsets.only(
        left: depth * 18.0, bottom: depth == 0 ? s.fontSize * .85 : 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final li in el.children ?? <md.Node>[])
          if (li is md.Element && li.tag == 'li')
            () {
              i++;
              final inline = <md.Node>[];
              final nested = <md.Element>[];
              for (final k in li.children ?? <md.Node>[]) {
                if (k is md.Element && (k.tag == 'ul' || k.tag == 'ol')) {
                  nested.add(k);
                } else if (k is md.Element && k.tag == 'p') {
                  inline.addAll(k.children ?? []);
                } else {
                  inline.add(k);
                }
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: s.fontSize * .3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                            width: 28,
                            child: Text(ordered ? '$i.' : '•',
                                style: s.body.copyWith(color: s.accent))),
                        Expanded(child: _rich(_inline(inline, s, s.body), c)),
                      ],
                    ),
                  ),
                  for (final n in nested) _list(n, s, depth + 1, c),
                ],
              );
            }()
      ],
    ),
  );
}

Widget _table(md.Element el, ReaderStyle s) {
  final rows = <TableRow>[];
  void collect(md.Element section, bool head) {
    for (final tr in section.children ?? <md.Node>[]) {
      if (tr is! md.Element) continue;
      rows.add(TableRow(
        children: [
          for (final cell in tr.children ?? <md.Node>[])
            if (cell is md.Element)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text.rich(TextSpan(
                    children: _inline(
                        cell.children,
                        s,
                        s.body.copyWith(
                            fontSize: s.fontSize * .9,
                            fontWeight: head ? FontWeight.w700 : null)))),
              )
        ],
      ));
    }
  }

  for (final sec in el.children ?? <md.Node>[]) {
    if (sec is md.Element) collect(sec, sec.tag == 'thead');
  }
  return Padding(
    padding: EdgeInsets.only(bottom: s.fontSize * .85),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: s.text.withValues(alpha: .2)),
        children: rows,
      ),
    ),
  );
}

List<InlineSpan> _inline(List<md.Node>? nodes, ReaderStyle s, TextStyle base) {
  final out = <InlineSpan>[];
  for (final n in nodes ?? <md.Node>[]) {
    if (n is md.Text) {
      out.add(TextSpan(text: n.text, style: base));
    } else if (n is md.Element) {
      switch (n.tag) {
        case 'em':
          out.addAll(_inline(n.children, s, base.copyWith(fontStyle: FontStyle.italic)));
        case 'strong':
          out.addAll(_inline(n.children, s, base.copyWith(fontWeight: FontWeight.w700)));
        case 'del':
          out.addAll(_inline(n.children, s, base.copyWith(decoration: TextDecoration.lineThrough)));
        case 'code':
          out.add(TextSpan(
              text: n.textContent,
              style: base.copyWith(
                  fontFamily: 'monospace',
                  fontSize: (base.fontSize ?? s.fontSize) * .88,
                  backgroundColor: s.text.withValues(alpha: .08))));
        case 'a':
          out.addAll(_inline(n.children, s,
              base.copyWith(color: s.accent, decoration: TextDecoration.underline)));
        case 'br':
          out.add(const TextSpan(text: '\n'));
        case 'img':
          out.add(TextSpan(
              text: '[${n.attributes['alt'] ?? 'imagen'}]',
              style: base.copyWith(color: s.muted)));
        default:
          out.addAll(_inline(n.children, s, base));
      }
    }
  }
  return out;
}
